BeforeAll {
    $script:RepoRoot = Split-Path $PSScriptRoot -Parent
    $script:ExtensionPath = Join-Path $script:RepoRoot 'src\extension\extension.js'
    $script:HarnessPath = Join-Path $PSScriptRoot 'harness\launch-harness.js'
    $script:NodeAvailable = [bool](Get-Command node -ErrorAction SilentlyContinue)
}

Describe 'VS Code extension' {
    It 'is syntactically valid' {
        if (-not $script:NodeAvailable) {
            Set-ItResult -Skipped -Because 'node is not available'
            return
        }

        node --check $script:ExtensionPath
        $LASTEXITCODE | Should -Be 0
    }

    It 'creates one API terminal with the requested profile' {
        if (-not $script:NodeAvailable) {
            Set-ItResult -Skipped -Because 'node is not available'
            return
        }

        $result = node $script:HarnessPath 'launch=field%7Capi%7CTest' | ConvertFrom-Json
        $result.Count | Should -Be 1
        $result[0].name | Should -Be 'field api'
        $result[0].command | Should -Be 'dotnet run --no-restore --launch-profile "Test"'
        $result[0].cwd | Should -BeLike '*AgExpert.Field\src\Api'
    }

    It 'honours an explicit launch profile' {
        if (-not $script:NodeAvailable) {
            Set-ItResult -Skipped -Because 'node is not available'
            return
        }

        $result = node $script:HarnessPath 'launch=mcCain%7Capi%7CUAT' | ConvertFrom-Json
        $result[0].command | Should -Be 'dotnet run --no-restore --launch-profile "UAT"'
    }

    It 'creates client and server terminals for an app' {
        if (-not $script:NodeAvailable) {
            Set-ItResult -Skipped -Because 'node is not available'
            return
        }

        $result = node $script:HarnessPath 'launch=field%7Call' | ConvertFrom-Json
        $result.Count | Should -Be 2
        $result[0].name | Should -Be 'field client'
        $result[1].name | Should -Be 'field server'
        $result[1].command | Should -Be 'dotnet run --no-restore --project ../Server --launch-profile "Field"'
    }

    It 'creates only the server terminal when asked' {
        if (-not $script:NodeAvailable) {
            Set-ItResult -Skipped -Because 'node is not available'
            return
        }

        $result = node $script:HarnessPath 'launch=field%7Cserver' | ConvertFrom-Json
        $result.Count | Should -Be 1
        $result[0].name | Should -Be 'field server'
    }

    It 'builds the client with the <Configuration> configuration' -ForEach @(
        @{ Configuration = ''; Command = 'ng build field --watch' }
        @{ Configuration = '%7Cdefault'; Command = 'ng build field --watch' }
        @{ Configuration = '%7Clocalized'; Command = 'ng build field --watch --configuration localized' }
        @{ Configuration = '%7Cdevelopment'; Command = 'ng build field --watch --configuration development' }
        @{ Configuration = '%7Cproduction'; Command = 'ng build field --watch --configuration production' }
    ) {
        if (-not $script:NodeAvailable) {
            Set-ItResult -Skipped -Because 'node is not available'
            return
        }

        $result = node $script:HarnessPath "launch=field%7Call$Configuration" | ConvertFrom-Json
        $result.Count | Should -Be 2
        $result[0].command | Should -Be $Command
        $result[1].command | Should -Be 'dotnet run --no-restore --project ../Server --launch-profile "Field"'
    }

    It 'serves a client-only app with the requested configuration' {
        if (-not $script:NodeAvailable) {
            Set-ItResult -Skipped -Because 'node is not available'
            return
        }

        $result = node $script:HarnessPath 'launch=gallery%7Call%7Cdevelopment' | ConvertFrom-Json
        $result[0].command | Should -Be 'ng serve gallery --configuration development'
    }

    It 'refuses an unknown build configuration' {
        if (-not $script:NodeAvailable) {
            Set-ItResult -Skipped -Because 'node is not available'
            return
        }

        $result = node $script:HarnessPath 'launch=field%7Call%7Cstaging' | ConvertFrom-Json
        $result.Count | Should -Be 0
    }

    It 'reports an error for a proxy-only API' {
        if (-not $script:NodeAvailable) {
            Set-ItResult -Skipped -Because 'node is not available'
            return
        }

        $result = node $script:HarnessPath 'launch=benchmarking%7Capi%7CTest' | ConvertFrom-Json
        $result.Count | Should -Be 0
    }

    It 'opens the proxy tab as its own standalone tab alongside the app' {
        if (-not $script:NodeAvailable) {
            Set-ItResult -Skipped -Because 'node is not available'
            return
        }

        # Mirrors `agexpert start`: the app (client + server) and the proxy arrive
        # as two separate URI invocations. None of them is grouped or split.
        $result = node $script:HarnessPath 'launch=field%7Call' 'launch=proxy' | ConvertFrom-Json
        $result.Count | Should -Be 3
        $result[0].name | Should -Be 'field client'
        $result[1].name | Should -Be 'field server'
        $result[2].name | Should -Be 'proxy'
        $result | ForEach-Object { $_.parent | Should -Be $null }
    }

    It 'never parents one terminal to another' {
        if (-not $script:NodeAvailable) {
            Set-ItResult -Skipped -Because 'node is not available'
            return
        }

        $result = node $script:HarnessPath 'launch=proxy' 'launch=field%7Capi%7CTest' | ConvertFrom-Json
        $result.Count | Should -Be 2
        $result | ForEach-Object { $_.parent | Should -Be $null }
    }

    It 'opens the client, server, and proxy for a dev environment' {
        if (-not $script:NodeAvailable) {
            Set-ItResult -Skipped -Because 'node is not available'
            return
        }

        $result = node $script:HarnessPath 'launch=field%7Cenv' | ConvertFrom-Json
        $result.Count | Should -Be 3
        $result[0].name | Should -Be 'field client'
        $result[1].name | Should -Be 'field server'
        $result[2].name | Should -Be 'proxy'
        $result[2].command | Should -Be 'Start-AgExpertProxy start'
        $result | ForEach-Object { $_.parent | Should -Be $null }
    }

    It 'applies the build configuration to a dev environment client' {
        if (-not $script:NodeAvailable) {
            Set-ItResult -Skipped -Because 'node is not available'
            return
        }

        $result = node $script:HarnessPath 'launch=field%7Cenv%7Clocalized' | ConvertFrom-Json
        $result.Count | Should -Be 3
        $result[0].command | Should -Be 'ng build field --watch --configuration localized'
    }

    It 'opens no proxy tab when the dev environment request is invalid' -ForEach @(
        @{ Route = 'launch=field%7Cenv%7Cstaging' }
        @{ Route = 'launch=gallery%7Cenv' }
        @{ Route = 'launch=nope%7Cenv' }
    ) {
        if (-not $script:NodeAvailable) {
            Set-ItResult -Skipped -Because 'node is not available'
            return
        }

        $result = node $script:HarnessPath $Route | ConvertFrom-Json
        $result.Count | Should -Be 0
    }

    It 'toggles a single proxy service in its own tab' -ForEach @(
        @{ Route = 'launch=proxy%7Cfield%7Cstop'; Name = 'proxy field stop'; Command = 'Set-AgExpertProxyService field stop' }
        @{ Route = 'launch=proxy%7Cfield%7Cstart'; Name = 'proxy field start'; Command = 'Set-AgExpertProxyService field start' }
        @{ Route = 'launch=proxy%7CField%20API%7Cstatus'; Name = 'proxy field status'; Command = 'Set-AgExpertProxyService field status' }
        @{ Route = 'launch=proxy%7Cbenchmarking%7Cstop'; Name = 'proxy benchmarking stop'; Command = 'Set-AgExpertProxyService benchmarking stop' }
    ) {
        if (-not $script:NodeAvailable) {
            Set-ItResult -Skipped -Because 'node is not available'
            return
        }

        $result = node $script:HarnessPath $Route | ConvertFrom-Json
        $result.Count | Should -Be 1
        $result[0].name | Should -Be $Name
        $result[0].command | Should -Be $Command
    }

    It 'refuses an unknown proxy service or action' -ForEach @(
        @{ Route = 'launch=proxy%7Cnotaservice%7Cstop' }
        @{ Route = 'launch=proxy%7Cfield%7Cbounce' }
    ) {
        if (-not $script:NodeAvailable) {
            Set-ItResult -Skipped -Because 'node is not available'
            return
        }

        $result = node $script:HarnessPath $Route | ConvertFrom-Json
        $result.Count | Should -Be 0
    }

    It 'contributes the <Command> command' -ForEach @(
        @{ Command = 'agexpert.launcher.launch' }
        @{ Command = 'agexpert.launcher.environment' }
        @{ Command = 'agexpert.launcher.proxy' }
        @{ Command = 'agexpert.launcher.proxyService' }
    ) {
        $manifest = Get-Content (Join-Path $script:RepoRoot 'src\extension\package.json') -Raw | ConvertFrom-Json
        $manifest.contributes.commands.command | Should -Contain $Command
    }
}
