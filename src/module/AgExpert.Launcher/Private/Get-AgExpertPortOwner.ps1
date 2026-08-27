function Get-AgExpertPortOwner {
    <#
        .SYNOPSIS
            Returns the process listening on a port, or nothing when the port is free.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory, Position = 0)][int]$Port)

    $connection = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if (-not $connection) { return }

    $process = Get-Process -Id $connection.OwningProcess -ErrorAction SilentlyContinue
    [pscustomobject]@{
        Port        = $Port
        ProcessId   = $connection.OwningProcess
        ProcessName = if ($process) { $process.ProcessName } else { 'unknown' }
    }
}
