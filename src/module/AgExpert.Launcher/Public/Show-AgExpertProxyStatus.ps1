function Show-AgExpertProxyStatus {
    <#
        .SYNOPSIS
            Shows the proxy container state and the status of every proxied service.
    #>
    [CmdletBinding()]
    param()

    $settings = Get-AgExpertSettings
    $state = Get-AgExpertProxyContainerState
    $devContainerIds = @(docker ps --quiet --filter "label=devcontainer.local_folder=$($settings.proxyPath)" 2>$null)
    $listeningPorts = @(Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
            Select-Object -ExpandProperty LocalPort -Unique)

    Write-Host "Profile proxy: $(if ($state) { $state } else { 'not created' })"
    Write-Host "VS Code proxy: $(if ($devContainerIds.Count -gt 0) { 'running' } else { 'not running' })"

    Get-AgExpertProxyService | ForEach-Object {
        [pscustomobject]@{
            Status  = if ($listeningPorts -contains $_.Port) { 'Up' } else { 'Down' }
            Service = $_.Service
            Port    = $_.Port
            URL     = "https://localhost:$($_.Port)"
        }
    } | Format-Table -AutoSize
}
