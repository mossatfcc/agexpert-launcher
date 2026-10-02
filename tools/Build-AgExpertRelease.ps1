<#
    .SYNOPSIS
        Validates, versions, and packages the AgExpert launcher.
    .DESCRIPTION
        Runs the analyzer and test suite, syncs the shared config into the extension, bumps the
        module manifest and extension versions together, and packages a .vsix. Bumping the
        extension version is what forces VS Code to load new extension code. -Install then runs
        tools/install.ps1 so the module, extension, agent, and skills are all updated.
    .EXAMPLE
        ./tools/Build-AgExpertRelease.ps1 -BumpPatch
        ./tools/Build-AgExpertRelease.ps1 -BumpMinor -Install
#>
[CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'None')]
param(
    [Parameter(ParameterSetName = 'Patch')][switch]$BumpPatch,
    [Parameter(ParameterSetName = 'Minor')][switch]$BumpMinor,
    [Parameter(ParameterSetName = 'Major')][switch]$BumpMajor,
    [switch]$SkipTests,
    [switch]$Install
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
$manifestPath = Join-Path $repoRoot 'src\module\AgExpert.Launcher\AgExpert.Launcher.psd1'
$packageJsonPath = Join-Path $repoRoot 'src\extension\package.json'
$extensionConfig = Join-Path $repoRoot 'src\extension\config'

function Write-Step([string]$Message) { Write-Host "==> $Message" }

# 1. Sync shared config into the extension so the packaged copy cannot drift.
Write-Step 'Syncing shared config into the extension'
if ($PSCmdlet.ShouldProcess($extensionConfig, 'Sync config')) {
    New-Item -Path $extensionConfig -ItemType Directory -Force | Out-Null
    Copy-Item -Path (Join-Path $repoRoot 'config\*.json') -Destination $extensionConfig -Force
}

# 2. Static analysis
if (Get-Module -ListAvailable -Name PSScriptAnalyzer) {
    Write-Step 'Running PSScriptAnalyzer'
    $findings = Invoke-ScriptAnalyzer -Path (Join-Path $repoRoot 'src\module') -Recurse `
        -Settings (Join-Path $repoRoot 'PSScriptAnalyzerSettings.psd1')
    if ($findings) {
        $findings | Format-Table -AutoSize | Out-String | Write-Host
        throw "PSScriptAnalyzer reported $($findings.Count) issue(s)."
    }
}
else {
    Write-Warning 'PSScriptAnalyzer is not installed; skipping static analysis.'
}

# 3. Tests
if (-not $SkipTests) {
    Write-Step 'Running Pester'
    $testsPath = Join-Path $repoRoot 'tests'
    # Run in a clean -NoProfile session so a profile-imported AgExpert.Launcher module cannot
    # collide with the copy the tests import from the repo (Pester errors with "Multiple script
    # or manifest modules named 'AgExpert.Launcher' are currently loaded" otherwise).
    $command = "`$r = Invoke-Pester -Path '$testsPath' -PassThru -Output Detailed; if (`$r.FailedCount -gt 0) { exit 1 }"
    pwsh -NoProfile -Command $command
    if ($LASTEXITCODE -ne 0) {
        throw 'Pester reported test failures.'
    }
}

# 4. Version bump
$manifest = Import-PowerShellDataFile $manifestPath
$version = [version]$manifest.ModuleVersion
$newVersion = switch ($PSCmdlet.ParameterSetName) {
    'Patch' { [version]::new($version.Major, $version.Minor, $version.Build + 1) }
    'Minor' { [version]::new($version.Major, $version.Minor + 1, 0) }
    'Major' { [version]::new($version.Major + 1, 0, 0) }
    default { $version }
}

if ($newVersion -ne $version) {
    Write-Step "Bumping version $version -> $newVersion"
    if ($PSCmdlet.ShouldProcess('version', "bump to $newVersion")) {
        (Get-Content $manifestPath -Raw) -replace
        "ModuleVersion\s*=\s*'[^']+'", "ModuleVersion     = '$newVersion'" |
            Set-Content $manifestPath -Encoding utf8

        $packageJson = Get-Content $packageJsonPath -Raw
        $packageJson -replace '"version":\s*"[^"]+"', "`"version`": `"$newVersion`"" |
            Set-Content $packageJsonPath -Encoding utf8
    }
}

# 5. Package the extension
# Packaged natively rather than through npx @vscode/vsce so the build works offline and
# behind an outbound proxy that blocks the npm registry.
Write-Step 'Packaging the VS Code extension'
$vsixPath = Join-Path $repoRoot "agexpert-launcher-$newVersion.vsix"

if ($PSCmdlet.ShouldProcess($vsixPath, 'Package extension')) {
    Add-Type -AssemblyName System.IO.Compression.FileSystem

    $staging = Join-Path ([System.IO.Path]::GetTempPath()) "agexpert-vsix-$([guid]::NewGuid())"
    $extensionStaging = Join-Path $staging 'extension'
    New-Item -Path $extensionStaging -ItemType Directory -Force | Out-Null

    Copy-Item -Path (Join-Path $repoRoot 'src\extension\*') -Destination $extensionStaging -Recurse -Force -Exclude '.vscodeignore'
    Copy-Item -Path (Join-Path $repoRoot 'LICENSE') -Destination $extensionStaging -Force

    $package = Get-Content $packageJsonPath -Raw | ConvertFrom-Json

    $contentTypes = @'
<?xml version="1.0" encoding="utf-8"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="json" ContentType="application/json" />
  <Default Extension="js" ContentType="application/javascript" />
  <Default Extension="md" ContentType="text/markdown" />
  <Default Extension="xml" ContentType="text/xml" />
  <Default Extension="vsixmanifest" ContentType="text/xml" />
</Types>
'@
    # [Content_Types].xml must be literal: the brackets would otherwise parse as a wildcard.
    Set-Content -LiteralPath (Join-Path $staging '[Content_Types].xml') -Value $contentTypes -Encoding utf8

    $manifest = @"
<?xml version="1.0" encoding="utf-8"?>
<PackageManifest Version="2.0.0" xmlns="http://schemas.microsoft.com/developer/vsx-schema/2011" xmlns:d="http://schemas.microsoft.com/developer/vsx-schema-design/2011">
  <Metadata>
    <Identity Language="en-US" Id="$($package.name)" Version="$($package.version)" Publisher="$($package.publisher)" />
    <DisplayName>$($package.displayName)</DisplayName>
    <Description xml:space="preserve">$($package.description)</Description>
    <Categories>Other</Categories>
  </Metadata>
  <Installation>
    <InstallationTarget Id="Microsoft.VisualStudio.Code" />
  </Installation>
  <Dependencies />
  <Assets>
    <Asset Type="Microsoft.VisualStudio.Code.Manifest" Path="extension/package.json" Addressable="true" />
  </Assets>
</PackageManifest>
"@
    Set-Content -LiteralPath (Join-Path $staging 'extension.vsixmanifest') -Value $manifest -Encoding utf8

    if (Test-Path $vsixPath) { Remove-Item $vsixPath -Force }
    [System.IO.Compression.ZipFile]::CreateFromDirectory($staging, $vsixPath)
    Remove-Item $staging -Recurse -Force
}

if ($Install -and $PSCmdlet.ShouldProcess($vsixPath, 'Install module, extension, and Copilot assets')) {
    # Reuse the installer so the module, extension, agent, and skills all move together;
    # installing only the .vsix leaves the PowerShell module on the previous build.
    $settingsPath = Join-Path $HOME '.agexpert\launcher.settings.json'
    $installedRepoRoot = if (Test-Path $settingsPath) { (Get-Content $settingsPath -Raw | ConvertFrom-Json).repoRoot }
    if (-not $installedRepoRoot) {
        throw "No repoRoot in $settingsPath. Run ./tools/install.ps1 -RepoRoot <path to FMPro> once first."
    }

    Write-Step 'Installing the module, extension, and Copilot assets'
    & (Join-Path $PSScriptRoot 'install.ps1') -RepoRoot ($installedRepoRoot -replace '/', '\') -SkipProfile
    Write-Host 'Open a new terminal (or Import-Module AgExpert.Launcher -Force) and run "Developer: Restart Extension Host" to load the new build.'
}

Write-Step "Release $newVersion ready: $vsixPath"
