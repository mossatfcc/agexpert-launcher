function Get-AgExpertProxyContainerState {
    <#
        .SYNOPSIS
            Returns the Docker state of the proxy container, or nothing when it does not exist.
    #>
    [CmdletBinding()]
    param()

    $settings = Get-AgExpertSettings
    $state = docker container inspect --format '{{.State.Status}}' $settings.containerName 2>$null
    if ($LASTEXITCODE -eq 0) { $state }
}
