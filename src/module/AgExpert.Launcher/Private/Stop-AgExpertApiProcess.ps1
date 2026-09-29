function Stop-AgExpertApiProcess {
    <#
        .SYNOPSIS
            Stops a locally running AgExpert API listening on a port.
        .DESCRIPTION
            Returns $true when a local dotnet listener was found and stopped, and $false when
            the port was free or held by something other than a local dotnet process (for
            example the environment proxy, which publishes ports through Docker). The proxy is
            never touched here.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param([Parameter(Mandatory, Position = 0)][int]$Port)

    $owner = Get-AgExpertPortOwner -Port $Port
    if (-not $owner) { return $false }
    if ($owner.ProcessName -ne 'dotnet') { return $false }

    if (-not $PSCmdlet.ShouldProcess("$($owner.ProcessName) (PID $($owner.ProcessId)) on port $Port", 'stop process')) {
        return $false
    }

    Stop-Process -Id $owner.ProcessId -Force -ErrorAction Stop
    return $true
}
