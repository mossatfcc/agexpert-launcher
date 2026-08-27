function Get-AgExpertVersion {
    <#
        .SYNOPSIS
            Returns the installed AgExpert launcher version.
        .DESCRIPTION
            Reports the module manifest version, so 'agexpert --version' and scripts can confirm
            which build is deployed. Falls back to reading the manifest directly when the function
            is dot-sourced outside an imported module.
        .EXAMPLE
            Get-AgExpertVersion
    #>
    [CmdletBinding()]
    [OutputType([version])]
    param()

    $module = $ExecutionContext.SessionState.Module
    if ($module) { return $module.Version }

    $manifestPath = Join-Path (Split-Path $PSScriptRoot -Parent) 'AgExpert.Launcher.psd1'
    [version](Import-PowerShellDataFile $manifestPath).ModuleVersion
}
