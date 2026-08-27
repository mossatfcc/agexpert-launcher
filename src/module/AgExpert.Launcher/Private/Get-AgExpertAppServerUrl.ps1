function Get-AgExpertAppServerUrl {
    <#
        .SYNOPSIS
            Resolves an app server's HTTPS URL from its launch profile.
        .DESCRIPTION
            Reads the Server project's Properties/launchSettings.json for the app's launchProfile
            and returns the applicationUrl, preferring the HTTPS binding. Used to poll the server
            for readiness once a dev environment has been started.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory, Position = 0)][string]$App)

    $settings = Get-AgExpertSettings
    $key = ConvertTo-AgExpertKey $App -KeepApiSuffix
    $config = Get-AgExpertAppRegistry | Where-Object { (ConvertTo-AgExpertKey $_.name -KeepApiSuffix) -eq $key } |
        Select-Object -First 1

    if (-not $config) { throw "Unknown AgExpert app '$App'." }
    if ($config.clientOnly) { throw "$($config.name) is client-only and has no server URL." }

    $projectPath = Join-Path $settings.clientPath (ConvertTo-AgExpertPath $config.project)
    $launchSettingsPath = Join-Path $projectPath 'Properties\launchSettings.json'
    if (-not (Test-Path $launchSettingsPath)) {
        throw "Missing launchSettings.json for $($config.name): $launchSettingsPath"
    }

    $profiles = (Get-Content $launchSettingsPath -Raw | ConvertFrom-Json).profiles
    $profileEntry = $profiles.$($config.launchProfile)
    if (-not $profileEntry) {
        $available = $profiles.PSObject.Properties.Name -join ', '
        throw "Launch profile '$($config.launchProfile)' not found for $($config.name). Available: $available"
    }

    $urls = @($profileEntry.applicationUrl -split ';' | Where-Object { $_ })
    $httpsUrl = $urls | Where-Object { $_ -match '^https://' } | Select-Object -First 1
    if (-not $httpsUrl) { $httpsUrl = $urls | Select-Object -First 1 }
    if (-not $httpsUrl) { throw "No applicationUrl for profile '$($config.launchProfile)' of $($config.name)." }

    $httpsUrl
}
