function Get-AgExpertProxyPublishedPorts {
    <#
        .SYNOPSIS
            Returns the host ports currently published by the proxy container.
    #>
    [CmdletBinding()]
    param()

    $settings = Get-AgExpertSettings
    $inspection = docker container inspect $settings.containerName 2>$null | ConvertFrom-Json
    if ($LASTEXITCODE -ne 0) { return @() }

    @($inspection[0].HostConfig.PortBindings.PSObject.Properties.Name | ForEach-Object {
            [int]($_ -split '/')[0]
        })
}
