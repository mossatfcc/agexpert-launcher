function Start-AgExpertApp {
    <#
        .SYNOPSIS
            Starts an AgExpert web app client watch, its server, or both.
        .DESCRIPTION
            -Configuration selects the Angular build configuration for the client. 'default' passes
            no flag, so angular.json's defaultConfiguration applies; the others add
            '--configuration <name>'. The server ignores it.
        .EXAMPLE
            Start-AgExpertApp field
            Start-AgExpertApp field server
            Start-AgExpertApp field client -Configuration localized
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0)][string]$App,
        [Parameter(Position = 1)][ValidateSet('all', 'client', 'server')][string]$Target = 'all',
        [Parameter(Position = 2)][ValidateSet('default', 'localized', 'development', 'production')]
        [string]$Configuration = 'default'
    )

    $settings = Get-AgExpertSettings
    $key = ConvertTo-AgExpertKey $App -KeepApiSuffix
    $config = Get-AgExpertAppRegistry | Where-Object { (ConvertTo-AgExpertKey $_.name -KeepApiSuffix) -eq $key } |
        Select-Object -First 1

    if (-not $config) {
        $validNames = (Get-AgExpertAppRegistry | Select-Object -ExpandProperty name) -join ', '
        throw "Unknown AgExpert app '$App'. Valid apps: $validNames"
    }

    if ($config.clientOnly -and $Target -eq 'server') {
        throw "$($config.name) is client-only and does not have a server to start."
    }

    $Configuration = $Configuration.ToLowerInvariant()
    if ($Target -eq 'server' -and $Configuration -ne 'default') {
        Write-Warning "The '$Configuration' build configuration applies to the client only; the server ignores it."
    }

    if (-not $PSCmdlet.ShouldProcess($config.name, "start $Target ($Configuration configuration)")) { return }

    if (Test-AgExpertVSCodeHost) {
        $route = "$($config.name)|$Target"
        if ($Configuration -ne 'default') { $route += "|$Configuration" }
        Open-AgExpertLauncherUri -Route $route
        return
    }

    $clientPath = $settings.clientPath
    $configurationArgument = if ($Configuration -ne 'default') { " --configuration $Configuration" } else { '' }

    if ($config.clientOnly) {
        wt -w 0 new-tab --title "$($config.name) client" --startingDirectory $clientPath pwsh -NoExit -Command "ng serve $($config.name)$configurationArgument"
        return
    }

    $clientCommand = "ng build $($config.name) --watch$configurationArgument"
    # Incremental build (no --no-build) self-heals a missing binary and picks up server
    # source changes; --no-restore still skips the Azure Artifacts device-flow hang.
    $serverCommand = "dotnet run --no-restore --project $($config.project) --launch-profile `"$($config.launchProfile)`""

    switch ($Target) {
        'client' {
            wt -w 0 new-tab --title "$($config.name) client" --startingDirectory $clientPath pwsh -NoExit -Command $clientCommand
        }
        'server' {
            wt -w 0 new-tab --title "$($config.name) server" --startingDirectory $clientPath pwsh -NoExit -Command $serverCommand
        }
        default {
            wt -w 0 `
                new-tab --title "$($config.name) client" --startingDirectory $clientPath pwsh -NoExit -Command $clientCommand `
                `; new-tab --title "$($config.name) server" --startingDirectory $clientPath pwsh -NoExit -Command $serverCommand
        }
    }
}
