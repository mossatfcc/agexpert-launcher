function Resolve-AgExpertLaunchProfile {
    <#
        .SYNOPSIS
            Resolves a launch profile name to its canonical casing in launchSettings.json.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)][string]$ProjectPath,
        [Parameter(Mandatory, Position = 1)][string]$Name
    )

    $launchSettingsPath = Join-Path $ProjectPath 'Properties\launchSettings.json'
    if (-not (Test-Path $launchSettingsPath)) {
        throw "Missing launch settings: $launchSettingsPath"
    }

    $profileNames = (Get-Content $launchSettingsPath -Raw | ConvertFrom-Json).profiles.PSObject.Properties.Name
    $resolved = @($profileNames | Where-Object { $_ -ieq $Name })[0]
    if (-not $resolved) {
        throw "Unknown launch profile '$Name'. Valid profiles: $($profileNames -join ', ')"
    }

    $resolved
}
