function Get-AgExpertApiConfig {
    <#
        .SYNOPSIS
            Returns one API registry entry, or every entry when no name is supplied.
        .EXAMPLE
            Get-AgExpertApiConfig field
    #>
    [CmdletBinding()]
    [OutputType([psobject])]
    param([Parameter(Position = 0)][string]$Name)

    $registry = Get-AgExpertRegistry
    if (-not $Name) { return $registry }

    $key = ConvertTo-AgExpertKey $Name
    $registry | Where-Object { (ConvertTo-AgExpertKey $_.name) -eq $key } | Select-Object -First 1
}
