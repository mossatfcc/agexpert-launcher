function Set-AgExpertSetting {
    <#
        .SYNOPSIS
            Persists a single machine setting into ~/.agexpert/launcher.settings.json.
        .DESCRIPTION
            Merges the key into the per-machine override file, preserving every other key, then
            clears the cached settings so the next Get-AgExpertSettings reflects the change.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0)][string]$Name,
        [Parameter(Mandatory, Position = 1)][AllowNull()]$Value
    )

    $overridePath = Join-Path $HOME '.agexpert/launcher.settings.json'
    $directory = Split-Path $overridePath -Parent

    $settings = [ordered]@{}
    if (Test-Path $overridePath) {
        $existing = Get-Content $overridePath -Raw | ConvertFrom-Json
        foreach ($property in $existing.PSObject.Properties) { $settings[$property.Name] = $property.Value }
    }

    $settings[$Name] = $Value

    if (-not $PSCmdlet.ShouldProcess($overridePath, "set $Name")) { return }

    if (-not (Test-Path $directory)) { New-Item -ItemType Directory -Path $directory -Force | Out-Null }
    ([pscustomobject]$settings | ConvertTo-Json -Depth 10) | Set-Content -Path $overridePath -Encoding utf8

    $script:AgExpertSettings = $null
}
