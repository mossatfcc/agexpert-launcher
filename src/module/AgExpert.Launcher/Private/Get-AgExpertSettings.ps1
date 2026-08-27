function Get-AgExpertSettings {
    <#
        .SYNOPSIS
            Returns machine settings, merging packaged defaults with per-machine overrides.
    #>
    [CmdletBinding()]
    param([switch]$Refresh)

    if ($script:AgExpertSettings -and -not $Refresh) { return $script:AgExpertSettings }

    $settings = [ordered]@{}
    $defaults = Get-Content (Join-Path (Get-AgExpertConfigRoot) 'settings.default.json') -Raw | ConvertFrom-Json
    foreach ($property in $defaults.PSObject.Properties) { $settings[$property.Name] = $property.Value }

    $overridePath = Join-Path $HOME '.agexpert/launcher.settings.json'
    if (Test-Path $overridePath) {
        $overrides = Get-Content $overridePath -Raw | ConvertFrom-Json
        foreach ($property in $overrides.PSObject.Properties) { $settings[$property.Name] = $property.Value }
    }

    foreach ($key in @($settings.Keys)) {
        if ($settings[$key] -is [string]) {
            $settings[$key] = $settings[$key] -replace '^~', $HOME.Replace('\', '/')
        }
    }

    $settings['repoRoot'] = ConvertTo-AgExpertPath $settings['repoRoot']
    $settings['certificateDirectory'] = ConvertTo-AgExpertPath $settings['certificateDirectory']
    $settings['clientPath'] = Join-Path $settings['repoRoot'] (ConvertTo-AgExpertPath $settings['clientDirectory'])
    $settings['proxyPath'] = Join-Path $settings['repoRoot'] (ConvertTo-AgExpertPath $settings['proxyDirectory'])

    $script:AgExpertSettings = [pscustomobject]$settings
    $script:AgExpertSettings
}
