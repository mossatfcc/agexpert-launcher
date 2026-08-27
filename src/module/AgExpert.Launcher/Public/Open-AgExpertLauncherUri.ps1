function Open-AgExpertLauncherUri {
    <#
        .SYNOPSIS
            Hands a launch route to the VS Code launcher extension.
        .DESCRIPTION
            The route travels as a single encoded query parameter so that code.cmd cannot
            split it on ampersands.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory, Position = 0)][string]$Route)

    $settings = Get-AgExpertSettings
    code --open-url "$($settings.launcherUri)?launch=$([uri]::EscapeDataString($Route))"
}
