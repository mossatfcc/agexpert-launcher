BeforeAll {
    $script:RepoRoot = Split-Path $PSScriptRoot -Parent
    Get-Module AgExpert.Launcher | Remove-Module -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $script:RepoRoot 'src\module\AgExpert.Launcher\AgExpert.Launcher.psd1') -Force
}

Describe 'Invoke-AgExpert routing' {
    BeforeEach {
        Mock -ModuleName AgExpert.Launcher Start-AgExpertApi { }
        Mock -ModuleName AgExpert.Launcher Start-AgExpertApp { }
        Mock -ModuleName AgExpert.Launcher Start-AgExpertProxy { }
        Mock -ModuleName AgExpert.Launcher Open-AgExpertProxyTerminal { }
        Mock -ModuleName AgExpert.Launcher Set-AgExpertProxyService { }
        Mock -ModuleName AgExpert.Launcher Start-AgExpertEnvironment { }
    }

    It 'starts the client and server for a front-end product' {
        Invoke-AgExpert field
        Should -Invoke -ModuleName AgExpert.Launcher Start-AgExpertApp -Times 1 -Exactly `
            -ParameterFilter { $App -eq 'field' -and $Target -eq 'all' }
        Should -Invoke -ModuleName AgExpert.Launcher Start-AgExpertApi -Times 0 -Exactly
    }

    It 'starts a single target when one is named' {
        Invoke-AgExpert field server
        Should -Invoke -ModuleName AgExpert.Launcher Start-AgExpertApp -Times 1 -Exactly `
            -ParameterFilter { $Target -eq 'server' }
    }

    It 'routes the api suffix to the API launcher' {
        Invoke-AgExpert field api
        Should -Invoke -ModuleName AgExpert.Launcher Start-AgExpertApi -Times 1 -Exactly `
            -ParameterFilter { $Name -eq 'field' }
        Should -Invoke -ModuleName AgExpert.Launcher Start-AgExpertApp -Times 0 -Exactly
    }

    It 'passes an explicit launch profile through' {
        Invoke-AgExpert field api UAT
        Should -Invoke -ModuleName AgExpert.Launcher Start-AgExpertApi -Times 1 -Exactly `
            -ParameterFilter { $LaunchProfile -eq 'UAT' }
    }

    It 'requires the api suffix for API-only products' {
        { Invoke-AgExpert mcCain -ErrorAction Stop } | Should -Throw "*agexpert mcCain api*"
        Should -Invoke -ModuleName AgExpert.Launcher Start-AgExpertApp -Times 0 -Exactly
    }

    It 'opens a proxy terminal for a bare proxy start' {
        Invoke-AgExpert proxy
        Should -Invoke -ModuleName AgExpert.Launcher Open-AgExpertProxyTerminal -Times 1 -Exactly
    }

    It 'forwards proxy actions' {
        Invoke-AgExpert proxy status
        Should -Invoke -ModuleName AgExpert.Launcher Start-AgExpertProxy -Times 1 -Exactly `
            -ParameterFilter { $Action -eq 'status' }
    }

    It 'forwards a single proxy service action' {
        Invoke-AgExpert proxy field stop
        Should -Invoke -ModuleName AgExpert.Launcher Set-AgExpertProxyService -Times 1 -Exactly `
            -ParameterFilter { $ServiceName -eq 'field' -and $Action -eq 'stop' }
    }

    It 'starts the dev environment with the saved default when no app is named' {
        Invoke-AgExpert start
        Should -Invoke -ModuleName AgExpert.Launcher Start-AgExpertEnvironment -Times 1 -Exactly `
            -ParameterFilter { -not $App }
        Should -Invoke -ModuleName AgExpert.Launcher Start-AgExpertApp -Times 0 -Exactly
    }

    It 'starts the dev environment for an explicitly named app' {
        Invoke-AgExpert start accounting
        Should -Invoke -ModuleName AgExpert.Launcher Start-AgExpertEnvironment -Times 1 -Exactly `
            -ParameterFilter { $App -eq 'accounting' }
    }

    It 'prints the version for <Flag> without launching anything' -ForEach @(
        @{ Flag = '--version' }
        @{ Flag = '-v' }
        @{ Flag = 'version' }
    ) {
        $output = Invoke-AgExpert $Flag 6>&1
        $output | Should -BeLike "*AgExpert Launcher*"
        $output | Should -BeLike "*$(Get-AgExpertVersion)*"
        Should -Invoke -ModuleName AgExpert.Launcher Start-AgExpertApp -Times 0 -Exactly
        Should -Invoke -ModuleName AgExpert.Launcher Start-AgExpertEnvironment -Times 0 -Exactly
    }
}

Describe 'Get-AgExpertVersion' {
    It 'reports the module manifest version' {
        $manifest = Import-PowerShellDataFile (Join-Path $script:RepoRoot 'src\module\AgExpert.Launcher\AgExpert.Launcher.psd1')
        Get-AgExpertVersion | Should -Be ([version]$manifest.ModuleVersion)
    }
}

Describe 'Start-AgExpertApi' {
    BeforeEach {
        Mock -ModuleName AgExpert.Launcher Test-AgExpertVSCodeHost { $true }
        Mock -ModuleName AgExpert.Launcher Open-AgExpertLauncherUri { }
        Mock -ModuleName AgExpert.Launcher Get-AgExpertProxyContainerState { 'running' }
        Mock -ModuleName AgExpert.Launcher Get-AgExpertProxyPublishedPorts { @(44315) }
        Mock -ModuleName AgExpert.Launcher Set-AgExpertProxyService { }
        Mock -ModuleName AgExpert.Launcher Resolve-AgExpertLaunchProfile { $Name }
        Mock -ModuleName AgExpert.Launcher Test-Path { $true }
    }

    It 'defaults to the Test launch profile' {
        Start-AgExpertApi field
        Should -Invoke -ModuleName AgExpert.Launcher Open-AgExpertLauncherUri -Times 1 -Exactly `
            -ParameterFilter { $Route -eq 'field|api|Test' }
    }

    It 'honours an explicit launch profile' {
        Start-AgExpertApi field UAT
        Should -Invoke -ModuleName AgExpert.Launcher Open-AgExpertLauncherUri -Times 1 -Exactly `
            -ParameterFilter { $Route -eq 'field|api|UAT' }
    }

    It 'releases the proxy port that the API needs' {
        Start-AgExpertApi field
        Should -Invoke -ModuleName AgExpert.Launcher Set-AgExpertProxyService -Times 1 -Exactly `
            -ParameterFilter { $ServiceName -eq 'field' -and $Action -eq 'stop' }
    }

    It 'leaves the proxy alone when it does not hold the port' {
        Mock -ModuleName AgExpert.Launcher Get-AgExpertProxyPublishedPorts { @(44325) }
        Start-AgExpertApi field
        Should -Invoke -ModuleName AgExpert.Launcher Set-AgExpertProxyService -Times 0 -Exactly
    }

    It 'rejects a proxy-only product' {
        { Start-AgExpertApi benchmarking } | Should -Throw '*no local project*'
    }

    It 'rejects an unknown product' {
        { Start-AgExpertApi nonexistent } | Should -Throw '*Unknown AgExpert API*'
    }
}

Describe 'Start-AgExpertApp' {
    BeforeEach {
        Mock -ModuleName AgExpert.Launcher Test-AgExpertVSCodeHost { $true }
        Mock -ModuleName AgExpert.Launcher Open-AgExpertLauncherUri { }
    }

    It 'routes <App> <Target> as <Route>' -ForEach @(
        @{ App = 'field'; Target = 'all'; Route = 'field|all' }
        @{ App = 'field'; Target = 'server'; Route = 'field|server' }
        @{ App = 'accounting'; Target = 'client'; Route = 'accounting|client' }
    ) {
        Start-AgExpertApp -App $App -Target $Target
        Should -Invoke -ModuleName AgExpert.Launcher Open-AgExpertLauncherUri -Times 1 -Exactly `
            -ParameterFilter { $Route -eq $Route }
    }

    It 'refuses to start a server for a client-only app' {
        { Start-AgExpertApp -App gallery -Target server } | Should -Throw '*client-only*'
    }

    It 'rejects an unknown app' {
        { Start-AgExpertApp -App nonexistent } | Should -Throw '*Unknown AgExpert app*'
    }
}
