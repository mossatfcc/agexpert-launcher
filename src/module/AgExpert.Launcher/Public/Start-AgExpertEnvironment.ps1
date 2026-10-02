function Start-AgExpertEnvironment {
    <#
        .SYNOPSIS
            Starts the full local dev environment: an app's client, its server, and the proxy.
        .DESCRIPTION
            Opens the app client watch and server tabs plus the proxy tab (three terminal tabs),
            leaving the client running locally against the proxy and Test APIs. With no app named,
            the saved default app is used; if none is set, an error explains that the caller should
            ask the user and run Set-AgExpertDefaultApp. Unless -SkipReadiness is given, it then
            polls until the proxy and app server respond and reports whether the environment is
            green and ready. -Configuration selects the Angular build configuration for the client.
        .EXAMPLE
            Start-AgExpertEnvironment
        .EXAMPLE
            Start-AgExpertEnvironment field
        .EXAMPLE
            Start-AgExpertEnvironment field -Configuration localized
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([psobject])]
    param(
        [Parameter(Position = 0)][string]$App,
        [Parameter(Position = 1)][ValidateSet('default', 'localized', 'development', 'production')]
        [string]$Configuration = 'default',
        [int]$TimeoutSeconds = 180,
        [switch]$SkipReadiness
    )

    $appName = if ($App) { $App } else { Get-AgExpertDefaultApp }
    if (-not $appName) {
        throw "No default app configured. Ask the user which app to run (for example field, accounting, or home), then run 'agexpert start <app>' (or Set-AgExpertDefaultApp <app>) to save it."
    }

    $key = ConvertTo-AgExpertKey $appName -KeepApiSuffix
    $config = Get-AgExpertAppRegistry | Where-Object { (ConvertTo-AgExpertKey $_.name -KeepApiSuffix) -eq $key } |
        Select-Object -First 1

    if (-not $config) {
        $validNames = (Get-AgExpertAppRegistry | Where-Object { -not $_.clientOnly } | Select-Object -ExpandProperty name) -join ', '
        throw "Unknown AgExpert app '$appName'. Valid apps: $validNames"
    }
    if ($config.clientOnly) {
        throw "$($config.name) is client-only and cannot start a full dev environment. Choose a server-backed app such as field, accounting, or home."
    }

    if (-not $PSCmdlet.ShouldProcess($config.name, 'start dev environment')) { return }

    Start-AgExpertApp -App $config.name -Target all -Configuration $Configuration
    Open-AgExpertProxyTerminal

    if ($SkipReadiness) { return }

    Wait-AgExpertEnvironmentReady -App $config.name -TimeoutSeconds $TimeoutSeconds
}
