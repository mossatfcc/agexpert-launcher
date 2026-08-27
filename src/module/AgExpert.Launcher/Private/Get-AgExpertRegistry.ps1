function Get-AgExpertRegistry {
    <#
        .SYNOPSIS
            Returns the shared API registry from config/apis.json.
    #>
    [CmdletBinding()]
    param([switch]$Refresh)

    if (-not $script:AgExpertRegistry -or $Refresh) {
        $path = Join-Path (Get-AgExpertConfigRoot) 'apis.json'
        $script:AgExpertRegistry = (Get-Content $path -Raw | ConvertFrom-Json).apis
    }

    $script:AgExpertRegistry
}
