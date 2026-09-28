@{
    RootModule        = 'AgExpert.Launcher.psm1'
    ModuleVersion     = '0.2.4'
    GUID              = '6f3b1c84-9a2e-4d57-9d0b-1c7a5e8f4b21'
    Author            = 'Shane Moss'
    Description       = 'Launches AgExpert web apps, APIs, and the environment proxy in dedicated terminal tabs.'
    PowerShellVersion = '7.0'

    FunctionsToExport = @(
        'Get-AgExpertApiConfig'
        'Get-AgExpertDefaultApp'
        'Get-AgExpertProxyService'
        'Get-AgExpertVersion'
        'Invoke-AgExpert'
        'Open-AgExpertLauncherUri'
        'Repair-AgExpertProxy'
        'Resolve-AgExpertProxyService'
        'Set-AgExpertDefaultApp'
        'Set-AgExpertProxyService'
        'Show-AgExpertProxyStatus'
        'Start-AgExpertApi'
        'Start-AgExpertApp'
        'Start-AgExpertEnvironment'
        'Start-AgExpertProxy'
        'Test-AgExpertEnvironment'
    )

    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @('agexpert', 'app')

    PrivateData       = @{
        PSData = @{
            Tags       = @('AgExpert', 'Launcher', 'DotNet', 'Angular', 'Docker')
            LicenseUri = 'https://opensource.org/licenses/MIT'
            ProjectUri = 'https://github.com/mosss/agexpert-launcher'
        }
    }
}





