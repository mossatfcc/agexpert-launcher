function Get-AgExpertProxyService {
    <#
        .SYNOPSIS
            Lists the proxy services and their ports.
    #>
    [CmdletBinding()]
    [OutputType([psobject])]
    param()

    Get-AgExpertRegistry | ForEach-Object {
        [pscustomobject]@{
            Port    = $_.port
            Service = $_.proxyName
            Name    = $_.name
        }
    }
}
