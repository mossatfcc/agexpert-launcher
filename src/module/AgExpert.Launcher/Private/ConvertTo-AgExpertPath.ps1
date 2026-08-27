function ConvertTo-AgExpertPath {
    <#
        .SYNOPSIS
            Normalizes a config path to Windows separators.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory, Position = 0)][string]$Path)

    $Path -replace '/', '\'
}
