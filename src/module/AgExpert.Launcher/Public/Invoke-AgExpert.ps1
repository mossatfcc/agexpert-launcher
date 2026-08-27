function Invoke-AgExpert {
    <#
        .SYNOPSIS
            Dispatches the agexpert command.
        .DESCRIPTION
            Products with a front end start their client and server when named alone.
            API-only products require the explicit api suffix.
        .EXAMPLE
            agexpert field
            agexpert field api
            agexpert field api UAT
            agexpert proxy status
    #>
    [CmdletBinding()]
    param([Parameter(ValueFromRemainingArguments)][string[]]$Arguments)

    $settings = Get-AgExpertSettings
    $first = if ($Arguments.Count -ge 1) { $Arguments[0] } else { $null }
    $second = if ($Arguments.Count -ge 2) { $Arguments[1] } else { $null }
    $third = if ($Arguments.Count -ge 3) { $Arguments[2] } else { $null }

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

    if ($second -eq 'api') {
        Start-AgExpertApi -Name $first -LaunchProfile $third
        return
    }

    $appNames = Get-AgExpertAppRegistry | Select-Object -ExpandProperty name
    if ($appNames -contains $first) {
        $target = if ($second) { $second } else { 'all' }
        Start-AgExpertApp -App $first -Target $target
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
