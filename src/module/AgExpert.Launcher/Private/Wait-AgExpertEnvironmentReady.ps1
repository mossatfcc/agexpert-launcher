function Wait-AgExpertEnvironmentReady {
    <#
        .SYNOPSIS
            Polls a started dev environment until it is green, or the timeout elapses.
        .DESCRIPTION
            Waits for the proxy container to report running and the app server port to accept
            connections, then emits one Check/Status/Detail row per signal plus an overall row so
            the caller can report whether the environment is ready.
    #>
    [CmdletBinding()]
    [OutputType([psobject])]
    param(
        [Parameter(Mandatory, Position = 0)][string]$App,
        [int]$TimeoutSeconds = 180,
        [int]$PollSeconds = 3
    )

    $results = [System.Collections.Generic.List[psobject]]::new()
    function Add-Result([string]$Check, [string]$Status, [string]$Detail) {
        $results.Add([pscustomobject]@{ Check = $Check; Status = $Status; Detail = $Detail })
    }

    $serverUrl = $null
    $serverPort = $null
    $serverResolveError = $null
    try {
        $serverUrl = Get-AgExpertAppServerUrl -App $App
        $serverPort = ([uri]$serverUrl).Port
    }
    catch {
        $serverResolveError = $_.Exception.Message
    }

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    $proxyReady = $false
    $serverReady = $false

    do {
        if (-not $proxyReady) { $proxyReady = (Get-AgExpertProxyContainerState) -eq 'running' }
        if (-not $serverReady -and $serverPort) { $serverReady = Test-AgExpertPortResponding -Port $serverPort }
        if ($proxyReady -and ($serverReady -or -not $serverPort)) { break }
        if ((Get-Date) -ge $deadline) { break }
        Start-Sleep -Seconds $PollSeconds
    } while ($true)

    Add-Result 'Proxy container' $(if ($proxyReady) { 'Pass' } else { 'Warn' }) `
        $(if ($proxyReady) { 'running' } else { 'Not running yet; check the proxy tab.' })

    if (-not $serverPort) {
        Add-Result "$App server" 'Warn' "Could not resolve the server URL: $serverResolveError"
    }
    elseif ($serverReady) {
        Add-Result "$App server" 'Pass' "Responding on $serverUrl"
    }
    else {
        Add-Result "$App server" 'Warn' "No response on $serverUrl yet; the server or client build may still be compiling."
    }

    $ready = $proxyReady -and $serverReady
    Add-Result 'Environment' $(if ($ready) { 'Pass' } else { 'Warn' }) `
        $(if ($ready) { "$App is green and ready." } else { "Environment not fully ready within ${TimeoutSeconds}s." })

    $results
}
