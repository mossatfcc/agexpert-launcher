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

    It 'reports an error for a proxy-only API' {
        if (-not $script:NodeAvailable) {
            Set-ItResult -Skipped -Because 'node is not available'
            return
        }

        $result = node $script:HarnessPath 'launch=benchmarking%7Capi%7CTest' | ConvertFrom-Json
        $result.Count | Should -Be 0
    }

    It 'groups the proxy tab with the app client and server' {
        if (-not $script:NodeAvailable) {
            Set-ItResult -Skipped -Because 'node is not available'
            return
        }

        # Mirrors `agexpert start`: the app (client + server) and the proxy arrive
        # as two separate URI invocations, yet must land in one terminal group.
        $result = node $script:HarnessPath 'launch=field%7Call' 'launch=proxy' | ConvertFrom-Json
        $result.Count | Should -Be 3
        $result[0].name | Should -Be 'field client'
        $result[0].parent | Should -Be $null
        $result[1].name | Should -Be 'field server'
        $result[1].parent | Should -Be $result[0].id
        $result[2].name | Should -Be 'proxy'
        $result[2].parent | Should -Be $result[0].id
    }

    It 'joins a later single launch to the existing group' {
        if (-not $script:NodeAvailable) {
            Set-ItResult -Skipped -Because 'node is not available'
            return
        }

        $result = node $script:HarnessPath 'launch=proxy' 'launch=field%7Capi%7CTest' | ConvertFrom-Json
        $result.Count | Should -Be 2
        $result[0].name | Should -Be 'proxy'
        $result[0].parent | Should -Be $null
        $result[1].name | Should -Be 'field api'
        $result[1].parent | Should -Be $result[0].id
    }
}
