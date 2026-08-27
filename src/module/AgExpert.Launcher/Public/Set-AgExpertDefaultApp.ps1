function Set-AgExpertDefaultApp {
    <#
        .SYNOPSIS
            Saves the default dev-environment app that 'agexpert start' launches.
        .DESCRIPTION
            Validates that the app is a known server-backed front end and persists it to
            ~/.agexpert/launcher.settings.json so future 'agexpert start' calls skip the prompt.
        .EXAMPLE
            Set-AgExpertDefaultApp field
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([string])]
    param([Parameter(Mandatory, Position = 0)][string]$App)

    $key = ConvertTo-AgExpertKey $App -KeepApiSuffix
    $config = Get-AgExpertAppRegistry | Where-Object { (ConvertTo-AgExpertKey $_.name -KeepApiSuffix) -eq $key } |
        Select-Object -First 1

    if (-not $config) {
        $validNames = (Get-AgExpertAppRegistry | Where-Object { -not $_.clientOnly } | Select-Object -ExpandProperty name) -join ', '
        throw "Unknown AgExpert app '$App'. Valid default apps: $validNames"
    }
    if ($config.clientOnly) {
        throw "$($config.name) is client-only and cannot be the dev-environment default app."
    }

    if (-not $PSCmdlet.ShouldProcess($config.name, 'set default app')) { return }

    Set-AgExpertSetting -Name 'defaultApp' -Value $config.name
    $config.name
}
