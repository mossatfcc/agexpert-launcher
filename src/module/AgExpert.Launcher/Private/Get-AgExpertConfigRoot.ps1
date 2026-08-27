function Get-AgExpertConfigRoot {
    <#
        .SYNOPSIS
            Locates the shared config directory in both installed and repository layouts.
    #>
    [CmdletBinding()]
    param()

    if ($script:AgExpertConfigRoot) { return $script:AgExpertConfigRoot }

    $directory = $script:AgExpertModuleRoot
    for ($depth = 0; $depth -lt 5 -and $directory; $depth++) {
        $candidate = Join-Path $directory 'config'
        if (Test-Path (Join-Path $candidate 'apis.json')) {
            $script:AgExpertConfigRoot = $candidate
            return $candidate
        }
        $directory = Split-Path $directory -Parent
    }

    throw "Unable to locate 'config/apis.json' from module root '$script:AgExpertModuleRoot'."
}
