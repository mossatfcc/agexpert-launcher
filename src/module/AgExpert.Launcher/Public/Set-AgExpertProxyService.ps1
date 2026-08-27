function Set-AgExpertProxyService {
    <#
        .SYNOPSIS
            Starts, stops, or reports a single proxy service by republishing container ports.
        .EXAMPLE
            Set-AgExpertProxyService field stop
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0)][string]$ServiceName,
        [Parameter(Mandatory, Position = 1)][ValidateSet('start', 'stop', 'status')][string]$Action
    )

    $settings = Get-AgExpertSettings
    $service = Resolve-AgExpertProxyService $ServiceName
    $state = Get-AgExpertProxyContainerState
    $publishedPorts = @(Get-AgExpertProxyPublishedPorts)
    $isPublished = $publishedPorts -contains $service.Port

    if ($Action -eq 'status') {
        $isListening = $null -ne (Get-AgExpertPortOwner $service.Port)
        [pscustomobject]@{
            Status  = if ($isListening) { 'Up' } else { 'Down' }
            Service = $service.Service
            Port    = $service.Port
            URL     = "https://localhost:$($service.Port)"
        } | Format-Table -AutoSize
        return
    }

    if (-not $state) {
        $devContainers = @(docker ps --quiet --filter "label=devcontainer.local_folder=$($settings.proxyPath)")
        if ($devContainers.Count -gt 0) {
            throw "The proxy is managed by VS Code. Run 'agexpert proxy migrate' before managing individual services."
        }
        $publishedPorts = @(Get-AgExpertProxyService | Select-Object -ExpandProperty Port)
        $isPublished = $Action -eq 'stop'
    }

    if (($Action -eq 'start' -and $isPublished) -or ($Action -eq 'stop' -and -not $isPublished)) {
        if ($Action -eq 'start' -and $state -ne 'running') {
            docker start $settings.containerName | Out-Null
        }
        Write-Host "$($service.Service) is already $Action$(if ($Action -eq 'stop') { 'ped' } else { 'ed' })."
        Set-AgExpertProxyService $ServiceName status
        return
    }

    $enabledPorts = if ($Action -eq 'stop') {
        @($publishedPorts | Where-Object { $_ -ne $service.Port })
    }
    else {
        @($publishedPorts + $service.Port | Sort-Object -Unique)
    }

    if (-not $PSCmdlet.ShouldProcess($service.Service, "$Action proxy service")) { return }

    docker rm --force $settings.containerName 2>$null | Out-Null
    Start-AgExpertProxyContainer -Ports $enabledPorts
}
