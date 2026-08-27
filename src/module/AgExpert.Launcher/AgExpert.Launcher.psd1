@{
    RootModule        = 'AgExpert.Launcher.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = '6f3b1c84-9a2e-4d57-9d0b-1c7a5e8f4b21'
    Author            = 'Shane Moss'
    Description       = 'Launches AgExpert web apps, APIs, and the environment proxy in dedicated terminal tabs.'
    PowerShellVersion = '7.0'

    FunctionsToExport = @(
        'Get-AgExpertApiConfig'
        'Get-AgExpertProxyService'
        'Invoke-AgExpert'
        'Open-AgExpertLauncherUri'
        'Repair-AgExpertProxy'
        'Resolve-AgExpertProxyService'
        'Set-AgExpertProxyService'
        'Show-AgExpertProxyStatus'
        'Start-AgExpertApi'
        'Start-AgExpertApp'
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
