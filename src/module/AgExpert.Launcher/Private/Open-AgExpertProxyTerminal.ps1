function Open-AgExpertProxyTerminal {
    <#
        .SYNOPSIS
            Opens the proxy in a dedicated terminal tab.
    #>
    [CmdletBinding()]
    param()

    $settings = Get-AgExpertSettings

    if (Test-AgExpertVSCodeHost) {
        Open-AgExpertLauncherUri -Route 'proxy'
        return
    }

    wt -w 0 new-tab --title 'proxy' --startingDirectory $settings.repoRoot pwsh -NoExit -Command 'Start-AgExpertProxy start'
}
