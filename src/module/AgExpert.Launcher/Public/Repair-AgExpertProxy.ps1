function Repair-AgExpertProxy {
    <#
        .SYNOPSIS
            Releases a proxy service port so a local API can bind it, or republishes it afterwards.
        .EXAMPLE
            Repair-AgExpertProxy field -Release
            Repair-AgExpertProxy field -Restore
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0)][string]$Name,
        [switch]$Release,
        [switch]$Restore
    )

    if ($Release -and $Restore) {
        throw 'Specify either -Release or -Restore, not both.'
    }

    $action = if ($Restore) { 'start' } else { 'stop' }
    if (-not $PSCmdlet.ShouldProcess($Name, "$action proxy service")) { return }

    Set-AgExpertProxyService -ServiceName $Name -Action $action
}
