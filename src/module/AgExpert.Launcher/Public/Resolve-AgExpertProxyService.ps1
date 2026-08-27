function Resolve-AgExpertProxyService {
    <#
        .SYNOPSIS
            Resolves a proxy service by product name, display name, or port.
        .EXAMPLE
            Resolve-AgExpertProxyService field
            Resolve-AgExpertProxyService fieldApi
            Resolve-AgExpertProxyService 44315
    #>
    [CmdletBinding()]
    [OutputType([psobject])]
    param([Parameter(Mandatory, Position = 0)][string]$Name)

    $key = ConvertTo-AgExpertKey $Name
    $exactKey = ConvertTo-AgExpertKey $Name -KeepApiSuffix

    $matched = @(Get-AgExpertProxyService | Where-Object {
            (ConvertTo-AgExpertKey $_.Name) -eq $key -or
            (ConvertTo-AgExpertKey $_.Service -KeepApiSuffix) -eq $exactKey -or
            (ConvertTo-AgExpertKey $_.Service) -eq $key -or
            "$($_.Port)" -eq $Name
        })

    if ($matched.Count -ne 1) {
        $validNames = (Get-AgExpertProxyService | Select-Object -ExpandProperty Name) -join ', '
        throw "Unknown proxy service '$Name'. Valid services: $validNames"
    }

    $matched[0]
}
