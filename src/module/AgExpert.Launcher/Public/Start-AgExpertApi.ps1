function Start-AgExpertApi {
    <#
        .SYNOPSIS
            Starts an AgExpert API in a dedicated terminal tab.
        .DESCRIPTION
            Defaults to the Test launch profile, which matches the environment proxy. The proxy
            port for the API is released first so Kestrel can bind it. Startup uses
            --no-restore, so source changes still compile without blocking on NuGet
            device-flow authentication.
        .EXAMPLE
            Start-AgExpertApi field
            Start-AgExpertApi field UAT
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

    $settings = Get-AgExpertSettings
    $apiPath = Join-Path $settings.repoRoot (ConvertTo-AgExpertPath $config.directory)
    if (-not (Test-Path $apiPath)) {
        throw "API project directory not found: $apiPath"
    }

    if (-not $LaunchProfile) {
        $LaunchProfile = if ($config.defaultProfile) { $config.defaultProfile } else { 'Test' }
    }
    $resolvedProfile = Resolve-AgExpertLaunchProfile -ProjectPath $apiPath -Name $LaunchProfile

    if (-not $PSCmdlet.ShouldProcess("$($config.name) API", "start on the $resolvedProfile profile")) { return }

    if ((Get-AgExpertProxyContainerState) -eq 'running' -and
        (Get-AgExpertProxyPublishedPorts) -contains $config.port) {
        Set-AgExpertProxyService -ServiceName $config.name -Action stop
    }

    $restoreSwitch = if ($Restore) { '' } else { ' --no-restore' }
    $command = "dotnet run$restoreSwitch --launch-profile `"$resolvedProfile`""

    if (Test-AgExpertVSCodeHost) {
        Open-AgExpertLauncherUri -Route "$($config.name)|api|$resolvedProfile"
        return
    }

    wt -w 0 new-tab --title "$($config.name) api" --startingDirectory $apiPath pwsh -NoExit -Command $command
}
