function Get-AgExpertDefaultApp {
    <#
        .SYNOPSIS
            Returns the saved default dev-environment app, or nothing when none is set.
        .DESCRIPTION
            Reads the defaultApp machine setting used by 'agexpert start' so a repeat request can
            skip the first-run prompt.
        .EXAMPLE
            Get-AgExpertDefaultApp
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    $settings = Get-AgExpertSettings
    if (($settings.PSObject.Properties.Name -contains 'defaultApp') -and $settings.defaultApp) {
        [string]$settings.defaultApp
    }
}
