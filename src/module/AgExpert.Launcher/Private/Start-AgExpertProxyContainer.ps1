function Start-AgExpertProxyContainer {
    <#
        .SYNOPSIS
            Creates or starts the proxy container, publishing the requested ports.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param([int[]]$Ports)

    $settings = Get-AgExpertSettings

    foreach ($certificate in @('localhost.crt', 'localhost.key')) {
        $certificatePath = Join-Path $settings.certificateDirectory $certificate
        if (-not (Test-Path $certificatePath)) {
            throw "Missing proxy certificate: $certificatePath"
        }
    }

    $state = Get-AgExpertProxyContainerState
    if ($state -eq 'running') {
        Show-AgExpertProxyStatus
        return
    }

    if ($state) {
        docker start $settings.containerName | Out-Null
        if ($LASTEXITCODE -ne 0) { throw 'Failed to start the AgExpert proxy container.' }
        Show-AgExpertProxyStatus
        return
    }

    if (-not $PSCmdlet.ShouldProcess($settings.containerName, 'create proxy container')) { return }

    docker image inspect $settings.imageTag *> $null
    if ($LASTEXITCODE -ne 0) {
        docker build --tag $settings.imageTag (Join-Path $settings.proxyPath '.devcontainer')
        if ($LASTEXITCODE -ne 0) { throw 'Failed to build the AgExpert proxy image.' }
    }

    if (-not $PSBoundParameters.ContainsKey('Ports')) {
        $Ports = @(Get-AgExpertProxyService | Select-Object -ExpandProperty Port)
    }

    $listeningPorts = @(Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
            Select-Object -ExpandProperty LocalPort -Unique)
    $busyPorts = @($Ports | Where-Object { $listeningPorts -contains $_ })
    if ($busyPorts.Count -gt 0) {
        throw "Proxy ports are already in use: $($busyPorts -join ', '). If the VS Code dev container is running, use 'agexpert proxy migrate'."
    }

    $dockerArgs = @(
        'run', '--detach',
        '--name', $settings.containerName,
        '--restart', 'unless-stopped',
        '--mount', "type=bind,source=$($settings.certificateDirectory),target=/root/.aspnet/https,readonly"
    )
    foreach ($port in $Ports) {
        $dockerArgs += @('--publish', "127.0.0.1:$port`:$port")
    }
    $dockerArgs += $settings.imageTag

    docker @dockerArgs | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Failed to create the AgExpert proxy container.' }

    Show-AgExpertProxyStatus
}
