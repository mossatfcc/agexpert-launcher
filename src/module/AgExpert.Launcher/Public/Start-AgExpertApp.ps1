function Start-AgExpertApp {
    <#
        .SYNOPSIS
            Starts an AgExpert web app client watch, its server, or both.
        .EXAMPLE
            Start-AgExpertApp field
            Start-AgExpertApp field server
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0)][string]$App,
        [Parameter(Position = 1)][ValidateSet('all', 'client', 'server')][string]$Target = 'all'
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

    if (-not $PSCmdlet.ShouldProcess($config.name, "start $Target")) { return }

    if (Test-AgExpertVSCodeHost) {
        Open-AgExpertLauncherUri -Route "$($config.name)|$Target"
        return
    }

    $clientPath = $settings.clientPath

    if ($config.clientOnly) {
        wt -w 0 new-tab --title "$($config.name) client" --startingDirectory $clientPath pwsh -NoExit -Command "ng serve $($config.name)"
        return
    }

    $clientCommand = "ng build $($config.name) --watch"
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
