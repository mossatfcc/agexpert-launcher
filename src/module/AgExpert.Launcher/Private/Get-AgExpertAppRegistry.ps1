function Get-AgExpertAppRegistry {
    <#
        .SYNOPSIS
            Returns the shared web app registry from config/apps.json.
    #>
    [CmdletBinding()]
    param([switch]$Refresh)

    if (-not $script:AgExpertAppRegistry -or $Refresh) {
        $path = Join-Path (Get-AgExpertConfigRoot) 'apps.json'
        $script:AgExpertAppRegistry = (Get-Content $path -Raw | ConvertFrom-Json).apps
    }

    $script:AgExpertAppRegistry
}
