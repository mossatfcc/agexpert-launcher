BeforeAll {
    $script:RepoRoot = Split-Path $PSScriptRoot -Parent
    Get-Module AgExpert.Launcher | Remove-Module -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $script:RepoRoot 'src\module\AgExpert.Launcher\AgExpert.Launcher.psd1') -Force
}

Describe 'Invoke-AgExpert routing' {
    BeforeEach {
        Mock -ModuleName AgExpert.Launcher Start-AgExpertApi { }
        Mock -ModuleName AgExpert.Launcher Restart-AgExpertApi { }
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

    It 'routes the restart suffix to the API restarter' {
        Invoke-AgExpert field api restart
        Should -Invoke -ModuleName AgExpert.Launcher Restart-AgExpertApi -Times 1 -Exactly `
            -ParameterFilter { $Name -eq 'field' }
        Should -Invoke -ModuleName AgExpert.Launcher Start-AgExpertApi -Times 0 -Exactly
    }

    It 'passes a launch profile through a restart' {
        Invoke-AgExpert field api restart UAT
        Should -Invoke -ModuleName AgExpert.Launcher Restart-AgExpertApi -Times 1 -Exactly `
            -ParameterFilter { $Name -eq 'field' -and $LaunchProfile -eq 'UAT' }
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
            -ParameterFilter { $App -eq 'accounting' -and $Configuration -eq 'default' }
    }

    It 'routes <Command> to Start-AgExpertEnvironment with app <App> and <Configuration>' -ForEach @(
        @{ Command = @('start', 'field', 'localized'); App = 'field'; Configuration = 'localized' }
        @{ Command = @('start', 'production'); App = $null; Configuration = 'production' }
        @{ Command = @('start', 'development', 'home'); App = 'home'; Configuration = 'development' }
    ) {
        $expectedApp = "$App"
        $expectedConfiguration = $Configuration
        Invoke-AgExpert @Command
        Should -Invoke -ModuleName AgExpert.Launcher Start-AgExpertEnvironment -Times 1 -Exactly `
            -ParameterFilter { "$App" -eq $expectedApp -and $Configuration -eq $expectedConfiguration }
    }

    It 'routes <Command> to Start-AgExpertApp with <Target> and <Configuration>' -ForEach @(
        @{ Command = @('field'); Target = 'all'; Configuration = 'default' }
        @{ Command = @('field', 'localized'); Target = 'all'; Configuration = 'localized' }
        @{ Command = @('field', 'client', 'production'); Target = 'client'; Configuration = 'production' }
        @{ Command = @('field', 'development', 'client'); Target = 'client'; Configuration = 'development' }
        @{ Command = @('field', 'default'); Target = 'all'; Configuration = 'default' }
    ) {
        $expectedTarget = $Target
        $expectedConfiguration = $Configuration
        Invoke-AgExpert @Command
        Should -Invoke -ModuleName AgExpert.Launcher Start-AgExpertApp -Times 1 -Exactly `
            -ParameterFilter { $App -eq 'field' -and $Target -eq $expectedTarget -and $Configuration -eq $expectedConfiguration }
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
        $expectedRoute = $Route
        Start-AgExpertApp -App $App -Target $Target
        Should -Invoke -ModuleName AgExpert.Launcher Open-AgExpertLauncherUri -Times 1 -Exactly `
            -ParameterFilter { $Route -eq $expectedRoute }
    }

    It 'routes the <Configuration> build configuration as <Route>' -ForEach @(
        @{ Configuration = 'default'; Route = 'field|all' }
        @{ Configuration = 'localized'; Route = 'field|all|localized' }
        @{ Configuration = 'development'; Route = 'field|all|development' }
        @{ Configuration = 'production'; Route = 'field|all|production' }
    ) {
        $expectedRoute = $Route
        Start-AgExpertApp -App field -Configuration $Configuration
        Should -Invoke -ModuleName AgExpert.Launcher Open-AgExpertLauncherUri -Times 1 -Exactly `
            -ParameterFilter { $Route -eq $expectedRoute }
    }

    It 'rejects an unknown build configuration' {
        { Start-AgExpertApp -App field -Configuration staging } | Should -Throw
    }

    It 'warns that a server-only start ignores the build configuration' {
        Start-AgExpertApp -App field -Target server -Configuration localized -WarningVariable warnings -WarningAction SilentlyContinue
        $warnings | Should -BeLike '*client only*'
    }

    It 'refuses to start a server for a client-only app' {
        { Start-AgExpertApp -App gallery -Target server } | Should -Throw '*client-only*'
    }

    It 'rejects an unknown app' {
        { Start-AgExpertApp -App nonexistent } | Should -Throw '*Unknown AgExpert app*'
    }
}

Describe 'Restart-AgExpertApi' {
    BeforeEach {
        Mock -ModuleName AgExpert.Launcher Stop-AgExpertApiProcess { $true }
        Mock -ModuleName AgExpert.Launcher Start-AgExpertApi { }
    }

    It 'stops the running API on its port before restarting' {
        Restart-AgExpertApi field
        Should -Invoke -ModuleName AgExpert.Launcher Stop-AgExpertApiProcess -Times 1 -Exactly `
            -ParameterFilter { $Port -eq 44315 }
    }

    It 'rebuilds and restarts through Start-AgExpertApi' {
        Restart-AgExpertApi field
        Should -Invoke -ModuleName AgExpert.Launcher Start-AgExpertApi -Times 1 -Exactly `
            -ParameterFilter { $Name -eq 'field' }
    }

    It 'passes an explicit launch profile through to the restart' {
        Restart-AgExpertApi field UAT
        Should -Invoke -ModuleName AgExpert.Launcher Start-AgExpertApi -Times 1 -Exactly `
            -ParameterFilter { $LaunchProfile -eq 'UAT' }
    }

    It 'works for any API in the registry' {
        Restart-AgExpertApi accounting
        Should -Invoke -ModuleName AgExpert.Launcher Stop-AgExpertApiProcess -Times 1 -Exactly `
            -ParameterFilter { $Port -eq 44325 }
        Should -Invoke -ModuleName AgExpert.Launcher Start-AgExpertApi -Times 1 -Exactly `
            -ParameterFilter { $Name -eq 'accounting' }
    }

    It 'restarts even when nothing was running' {
        Mock -ModuleName AgExpert.Launcher Stop-AgExpertApiProcess { $false }
        Restart-AgExpertApi field
        Should -Invoke -ModuleName AgExpert.Launcher Start-AgExpertApi -Times 1 -Exactly
    }

    It 'rejects a proxy-only product' {
        { Restart-AgExpertApi benchmarking } | Should -Throw '*no local project*'
        Should -Invoke -ModuleName AgExpert.Launcher Start-AgExpertApi -Times 0 -Exactly
    }

    It 'rejects an unknown product' {
        { Restart-AgExpertApi nonexistent } | Should -Throw '*Unknown AgExpert API*'
    }
}

Describe 'Stop-AgExpertApiProcess' {
    It 'stops a local dotnet listener and reports success' {
        InModuleScope AgExpert.Launcher {
            Mock Get-AgExpertPortOwner {
                [pscustomobject]@{ Port = 44315; ProcessId = 4242; ProcessName = 'dotnet' }
            }
            Mock Stop-Process { }

            Stop-AgExpertApiProcess -Port 44315 | Should -BeTrue
            Should -Invoke Stop-Process -Times 1 -Exactly -ParameterFilter { $Id -eq 4242 }
        }
    }

    It 'leaves a non-dotnet listener (the proxy) alone' {
        InModuleScope AgExpert.Launcher {
            Mock Get-AgExpertPortOwner {
                [pscustomobject]@{ Port = 44315; ProcessId = 10; ProcessName = 'com.docker.backend' }
            }
            Mock Stop-Process { }

            Stop-AgExpertApiProcess -Port 44315 | Should -BeFalse
            Should -Invoke Stop-Process -Times 0 -Exactly
        }
    }

    It 'does nothing when the port is free' {
        InModuleScope AgExpert.Launcher {
            Mock Get-AgExpertPortOwner { }
            Mock Stop-Process { }

            Stop-AgExpertApiProcess -Port 44315 | Should -BeFalse
            Should -Invoke Stop-Process -Times 0 -Exactly
        }
    }
}
