function Restart-AgExpertApi {
    <#
        .SYNOPSIS
            Stops a running AgExpert API, then rebuilds and restarts it.
        .DESCRIPTION
            Stops the local dotnet process bound to the API port (if one is running), then hands
            off to Start-AgExpertApi, which recompiles the project via dotnet run and opens a
            fresh terminal tab. Works for any API in the registry. The launch profile defaults to
            the same Test profile that Start-AgExpertApi uses.
        .EXAMPLE
            Restart-AgExpertApi field
            Restart-AgExpertApi field UAT
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0)][string]$Name,
        [Parameter(Position = 1)][string]$LaunchProfile,
        [switch]$Restore
    )

    $config = Get-AgExpertApiConfig $Name
    if (-not $config) {
        $validNames = (Get-AgExpertRegistry | Where-Object { -not $_.proxyOnly } |
                Select-Object -ExpandProperty name | Sort-Object) -join ', '
        throw "Unknown AgExpert API '$Name'. Valid APIs: $validNames"
    }

    if ($config.proxyOnly) {
        throw "The $($config.name) API has no local project in this repository; it is available through the environment proxy only."
    }

    if (Stop-AgExpertApiProcess -Port $config.port) {
        Write-Verbose "Stopped the running $($config.name) API on port $($config.port)."
    }

    Start-AgExpertApi -Name $Name -LaunchProfile $LaunchProfile -Restore:$Restore
}
