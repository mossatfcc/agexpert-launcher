function Start-AgExpertProxy {
    <#
        .SYNOPSIS
            Controls the AgExpert environment proxy container.
        .EXAMPLE
            Start-AgExpertProxy status
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Position = 0)]
        [ValidateSet('start', 'status', 'stop', 'restart', 'rebuild', 'migrate', 'vscode')]
        [string]$Action = 'start'
    )

    $settings = Get-AgExpertSettings

    if ($Action -notin 'status', 'vscode' -and -not $PSCmdlet.ShouldProcess($settings.containerName, $Action)) {
        return
    }

    switch ($Action) {
        'status' { Show-AgExpertProxyStatus }
        'stop' {
            docker stop $settings.containerName | Out-Null
            if ($LASTEXITCODE -ne 0) { Write-Warning 'The profile-managed proxy container is not running.' }
            Show-AgExpertProxyStatus
        }
        'restart' {
            docker restart $settings.containerName | Out-Null
            if ($LASTEXITCODE -ne 0) { throw "The proxy container does not exist. Run 'agexpert proxy' first." }
            Show-AgExpertProxyStatus
        }
        'rebuild' {
            docker rm --force $settings.containerName 2>$null | Out-Null
            docker build --tag $settings.imageTag (Join-Path $settings.proxyPath '.devcontainer')
            if ($LASTEXITCODE -ne 0) { throw 'Failed to rebuild the AgExpert proxy image.' }
            Start-AgExpertProxyContainer
        }
        'migrate' {
            $devContainers = @(docker ps --quiet --filter "label=devcontainer.local_folder=$($settings.proxyPath)")
            if ($devContainers.Count -gt 0) { docker stop $devContainers | Out-Null }
            Start-AgExpertProxyContainer
        }
        'vscode' {
            $hex = -join ([System.Text.Encoding]::UTF8.GetBytes($settings.proxyPath) | ForEach-Object { $_.ToString('x2') })
            code --folder-uri "vscode-remote://dev-container+$hex"
        }
        default { Start-AgExpertProxyContainer }
    }
}
