BeforeAll {
    $script:RepoRoot = Split-Path $PSScriptRoot -Parent
    Get-Module AgExpert.Launcher | Remove-Module -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $script:RepoRoot 'src\module\AgExpert.Launcher\AgExpert.Launcher.psd1') -Force
}

Describe 'Start-AgExpertEnvironment' {
    BeforeEach {
        Mock -ModuleName AgExpert.Launcher Start-AgExpertApp { }
        Mock -ModuleName AgExpert.Launcher Open-AgExpertProxyTerminal { }
        Mock -ModuleName AgExpert.Launcher Wait-AgExpertEnvironmentReady {
            [pscustomobject]@{ Check = 'Environment'; Status = 'Pass'; Detail = 'ready' }
        }
    }

    It 'launches the client, server, and proxy for the saved default app' {
        Mock -ModuleName AgExpert.Launcher Get-AgExpertDefaultApp { 'field' }

        Start-AgExpertEnvironment | Out-Null

        Should -Invoke -ModuleName AgExpert.Launcher Start-AgExpertApp -Times 1 -Exactly `
            -ParameterFilter { $App -eq 'field' -and $Target -eq 'all' }
        Should -Invoke -ModuleName AgExpert.Launcher Open-AgExpertProxyTerminal -Times 1 -Exactly
    }

    It 'prefers an explicitly named app over the default' {
        Mock -ModuleName AgExpert.Launcher Get-AgExpertDefaultApp { 'field' }

        Start-AgExpertEnvironment accounting | Out-Null

        Should -Invoke -ModuleName AgExpert.Launcher Start-AgExpertApp -Times 1 -Exactly `
            -ParameterFilter { $App -eq 'accounting' }
    }

    It 'passes the build configuration through to the app client' {
        Mock -ModuleName AgExpert.Launcher Get-AgExpertDefaultApp { 'field' }

        Start-AgExpertEnvironment -Configuration localized | Out-Null

        Should -Invoke -ModuleName AgExpert.Launcher Start-AgExpertApp -Times 1 -Exactly `
            -ParameterFilter { $App -eq 'field' -and $Configuration -eq 'localized' }
    }

    It 'returns the readiness report' {
        Mock -ModuleName AgExpert.Launcher Get-AgExpertDefaultApp { 'field' }

        $report = Start-AgExpertEnvironment
        $report.Check | Should -Contain 'Environment'
    }

    It 'skips the readiness wait when asked' {
        Mock -ModuleName AgExpert.Launcher Get-AgExpertDefaultApp { 'field' }

        Start-AgExpertEnvironment -SkipReadiness | Out-Null

        Should -Invoke -ModuleName AgExpert.Launcher Wait-AgExpertEnvironmentReady -Times 0 -Exactly
    }

    It 'errors when no app is named and no default is set' {
        Mock -ModuleName AgExpert.Launcher Get-AgExpertDefaultApp { }

        { Start-AgExpertEnvironment } | Should -Throw '*No default app configured*'
        Should -Invoke -ModuleName AgExpert.Launcher Start-AgExpertApp -Times 0 -Exactly
    }

    It 'rejects a client-only app' {
        { Start-AgExpertEnvironment gallery } | Should -Throw '*client-only*'
    }

    It 'rejects an unknown app' {
        { Start-AgExpertEnvironment nonexistent } | Should -Throw '*Unknown AgExpert app*'
    }
}

Describe 'Set-AgExpertDefaultApp' {
    BeforeEach {
        Mock -ModuleName AgExpert.Launcher Set-AgExpertSetting { }
    }

    It 'persists a valid server-backed app' {
        $result = Set-AgExpertDefaultApp field

        $result | Should -Be 'field'
        Should -Invoke -ModuleName AgExpert.Launcher Set-AgExpertSetting -Times 1 -Exactly `
            -ParameterFilter { $Name -eq 'defaultApp' -and $Value -eq 'field' }
    }

    It 'rejects a client-only app' {
        { Set-AgExpertDefaultApp gallery } | Should -Throw '*client-only*'
        Should -Invoke -ModuleName AgExpert.Launcher Set-AgExpertSetting -Times 0 -Exactly
    }

    It 'rejects an unknown app' {
        { Set-AgExpertDefaultApp nonexistent } | Should -Throw '*Unknown AgExpert app*'
    }
}

Describe 'Get-AgExpertDefaultApp' {
    It 'returns the saved default app' {
        Mock -ModuleName AgExpert.Launcher Get-AgExpertSettings { [pscustomobject]@{ defaultApp = 'field' } }
        Get-AgExpertDefaultApp | Should -Be 'field'
    }

    It 'returns nothing when no default is set' {
        Mock -ModuleName AgExpert.Launcher Get-AgExpertSettings { [pscustomobject]@{ defaultApp = $null } }
        Get-AgExpertDefaultApp | Should -BeNullOrEmpty
    }
}

Describe 'Wait-AgExpertEnvironmentReady' {
    BeforeEach {
        Mock -ModuleName AgExpert.Launcher Get-AgExpertAppServerUrl { 'https://localhost:5001' }
        Mock -ModuleName AgExpert.Launcher Start-Sleep { }
    }

    It 'reports green when the proxy and server respond' {
        Mock -ModuleName AgExpert.Launcher Get-AgExpertProxyContainerState { 'running' }
        Mock -ModuleName AgExpert.Launcher Test-AgExpertPortResponding { $true }

        $report = InModuleScope AgExpert.Launcher { Wait-AgExpertEnvironmentReady -App field -TimeoutSeconds 5 }
        ($report | Where-Object Check -eq 'Environment').Status | Should -Be 'Pass'
    }

    It 'warns when the environment is not ready before the timeout' {
        Mock -ModuleName AgExpert.Launcher Get-AgExpertProxyContainerState { 'created' }
        Mock -ModuleName AgExpert.Launcher Test-AgExpertPortResponding { $false }

        $report = InModuleScope AgExpert.Launcher { Wait-AgExpertEnvironmentReady -App field -TimeoutSeconds 0 }
        ($report | Where-Object Check -eq 'Environment').Status | Should -Be 'Warn'
    }
}

Describe 'Set-AgExpertSetting' {
    It 'merges the key while preserving existing settings' {
        InModuleScope AgExpert.Launcher {
            Mock Test-Path { $true }
            Mock Get-Content { '{ "repoRoot": "C:/AgExpert/FMPro" }' }
            Mock New-Item { }
            $script:capturedSetting = $null
            Mock Set-Content { $script:capturedSetting = $Value }

            Set-AgExpertSetting -Name 'defaultApp' -Value 'field'

            $saved = $script:capturedSetting | ConvertFrom-Json
            $saved.repoRoot | Should -Be 'C:/AgExpert/FMPro'
            $saved.defaultApp | Should -Be 'field'
        }
    }
}
