# Discovery phase needs the path before BeforeAll runs, so resolve it at file scope too.
$RepoRoot = Split-Path $PSScriptRoot -Parent

BeforeAll {
    $script:RepoRoot = Split-Path $PSScriptRoot -Parent
}

Describe 'PowerShell syntax' {
    It 'parses <RelativePath>' -ForEach @(
        Get-ChildItem -Path (Join-Path $RepoRoot 'src\module'), (Join-Path $RepoRoot 'tools') `
            -Filter '*.ps*1' -Recurse -File -ErrorAction SilentlyContinue |
            ForEach-Object { @{ FullPath = $_.FullName; RelativePath = $_.Name } }
    ) {
        $parseErrors = $null
        $tokens = $null
        [void][System.Management.Automation.Language.Parser]::ParseFile($FullPath, [ref]$tokens, [ref]$parseErrors)
        $parseErrors | Should -BeNullOrEmpty
    }
}

Describe 'Module manifest' {
    BeforeAll {
        $script:ManifestPath = Join-Path $script:RepoRoot 'src\module\AgExpert.Launcher\AgExpert.Launcher.psd1'
        $script:Manifest = Import-PowerShellDataFile $script:ManifestPath
    }

    It 'is a valid manifest' {
        { Test-ModuleManifest $script:ManifestPath -ErrorAction Stop } | Should -Not -Throw
    }

    It 'exports exactly the public function files' {
        $publicFunctions = Get-ChildItem (Join-Path $script:RepoRoot 'src\module\AgExpert.Launcher\Public') -Filter '*.ps1' |
            Select-Object -ExpandProperty BaseName | Sort-Object

        ($script:Manifest.FunctionsToExport | Sort-Object) -join ',' | Should -Be ($publicFunctions -join ',')
    }

    It 'declares the agexpert alias' {
        $script:Manifest.AliasesToExport | Should -Contain 'agexpert'
    }
}

Describe 'JSON configuration' {
    It 'parses <Name>' -ForEach @(
        @{ Name = 'apis.json' }
        @{ Name = 'apps.json' }
        @{ Name = 'settings.default.json' }
    ) {
        $path = Join-Path $script:RepoRoot "config\$Name"
        { Get-Content $path -Raw | ConvertFrom-Json } | Should -Not -Throw
    }
}

Describe 'Copilot assets' {
    It 'gives every skill a name and description' -ForEach @(
        @{ Skill = 'agexpert-launcher-run' }
        @{ Skill = 'agexpert-launcher-maintain' }
    ) {
        $content = Get-Content (Join-Path $script:RepoRoot "copilot\skills\$Skill\SKILL.md") -Raw
        $content | Should -Match '(?m)^name:\s*\S+'
        $content | Should -Match '(?m)^description:\s*\S+'
    }

    It 'gives the agent frontmatter' {
        $content = Get-Content (Join-Path $script:RepoRoot 'copilot\agents\agexpert-launcher.agent.md') -Raw
        $content | Should -Match '(?m)^name:\s*"AgExpert Launcher"'
        $content | Should -Match '(?m)^description:\s*\S+'
    }
}
