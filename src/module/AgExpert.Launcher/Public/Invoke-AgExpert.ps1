function Invoke-AgExpert {
    <#
        .SYNOPSIS
            Dispatches the agexpert command.
        .DESCRIPTION
            Products with a front end start their client and server when named alone.
            API-only products require the explicit api suffix.
        .EXAMPLE
            agexpert field
            agexpert field localized
            agexpert field client production
            agexpert start field development            agexpert field api
            agexpert field api UAT
            agexpert field api restart
            agexpert proxy status
            agexpert --version
    #>
    [CmdletBinding()]
    param([Parameter(ValueFromRemainingArguments)][string[]]$Arguments)

    $settings = Get-AgExpertSettings
    $first = if ($Arguments.Count -ge 1) { $Arguments[0] } else { $null }
    $second = if ($Arguments.Count -ge 2) { $Arguments[1] } else { $null }
    $third = if ($Arguments.Count -ge 3) { $Arguments[2] } else { $null }
    $fourth = if ($Arguments.Count -ge 4) { $Arguments[3] } else { $null }

    if ($first -in @('--version', '-v', 'version')) {
        Write-Host "AgExpert Launcher $(Get-AgExpertVersion)"
        return
    }

    if ($first -eq 'proxy') {
        if ($Arguments.Count -ge 3) {
            Set-AgExpertProxyService -ServiceName $second -Action $third
            return
        }

        $action = if ($second) { $second } else { 'start' }
        if ($action -eq 'start') {
            Open-AgExpertProxyTerminal
            return
        }

        Start-AgExpertProxy $action
        return
    }

    if ($first -eq 'start') {
        $startArguments = Split-AgExpertBuildConfiguration $Arguments[1..($Arguments.Count)]
        $startApp = $startArguments.Remaining | Select-Object -First 1
        Start-AgExpertEnvironment -App $startApp -Configuration $startArguments.Configuration
        return
    }

    if ($second -eq 'api') {
        if ($third -eq 'restart') {
            Restart-AgExpertApi -Name $first -LaunchProfile $fourth
            return
        }

        Start-AgExpertApi -Name $first -LaunchProfile $third
        return
    }

    $appNames = Get-AgExpertAppRegistry | Select-Object -ExpandProperty name
    if ($appNames -contains $first) {
        $appArguments = Split-AgExpertBuildConfiguration $Arguments[1..($Arguments.Count)]
        $target = $appArguments.Remaining | Select-Object -First 1
        if (-not $target) { $target = 'all' }
        Start-AgExpertApp -App $first -Target $target -Configuration $appArguments.Configuration
        return
    }

    if ($first -and (Get-AgExpertApiConfig $first)) {
        Write-Error "Use 'agexpert $first api' to start this API."
        return
    }

    code $settings.repoRoot @Arguments
}

Set-Alias -Name agexpert -Value Invoke-AgExpert
Set-Alias -Name app -Value Start-AgExpertApp
