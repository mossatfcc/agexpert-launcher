<#
    .SYNOPSIS
        Installs the AgExpert launcher onto this machine.
    .DESCRIPTION
        Copies the module and shared config onto PSModulePath, installs the packaged VS Code
        extension when one is present, copies the Copilot agent and skills into ~/.copilot,
        writes machine settings, and adds the module import to the PowerShell profile.
    .EXAMPLE
        ./tools/install.ps1 -RepoRoot C:\AgExpert\FMPro -WhatIf
        ./tools/install.ps1 -RepoRoot C:\AgExpert\FMPro
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)][string]$RepoRoot,
    [string]$CertificateDirectory = (Join-Path $HOME '.aspnet\https'),
    [switch]$SkipExtension,
    [switch]$SkipProfile
)

$ErrorActionPreference = 'Stop'
$sourceRoot = Split-Path $PSScriptRoot -Parent

function Write-Step([string]$Message) { Write-Host "==> $Message" }

if (-not (Test-Path $RepoRoot)) {
    throw "FMPro repository not found: $RepoRoot"
}

# 1. Module and shared config
$moduleRoot = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'PowerShell\Modules\AgExpert.Launcher'
Write-Step "Installing module to $moduleRoot"

if ($PSCmdlet.ShouldProcess($moduleRoot, 'Install module')) {
    if (Test-Path $moduleRoot) { Remove-Item $moduleRoot -Recurse -Force }
    New-Item -Path $moduleRoot -ItemType Directory -Force | Out-Null

    Copy-Item -Path (Join-Path $sourceRoot 'src\module\AgExpert.Launcher\*') -Destination $moduleRoot -Recurse -Force
    Copy-Item -Path (Join-Path $sourceRoot 'config') -Destination $moduleRoot -Recurse -Force
}

# 2. Machine settings
$settingsDirectory = Join-Path $HOME '.agexpert'
$settingsPath = Join-Path $settingsDirectory 'launcher.settings.json'
Write-Step "Writing settings to $settingsPath"

if ($PSCmdlet.ShouldProcess($settingsPath, 'Write machine settings')) {
    New-Item -Path $settingsDirectory -ItemType Directory -Force | Out-Null

    $settings = [ordered]@{
        repoRoot             = $RepoRoot -replace '\\', '/'
        certificateDirectory = $CertificateDirectory -replace '\\', '/'
    }
    $settings | ConvertTo-Json | Set-Content -Path $settingsPath -Encoding utf8
}

# 3. VS Code extension
if (-not $SkipExtension) {
    $package = Get-ChildItem -Path $sourceRoot -Filter '*.vsix' -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1

    if (-not $package) {
        Write-Warning "No .vsix found. Run ./tools/Build-AgExpertRelease.ps1 first, or pass -SkipExtension."
    }
    elseif ($PSCmdlet.ShouldProcess($package.Name, 'Install VS Code extension')) {
        Write-Step "Installing extension $($package.Name)"
        code --install-extension $package.FullName --force
    }
}

# 4. Copilot agent and skills
$copilotRoot = Join-Path $HOME '.copilot'
foreach ($asset in @(
        @{ Source = 'copilot\agents'; Target = 'agents' }
        @{ Source = 'copilot\skills'; Target = 'skills' }
    )) {
    $source = Join-Path $sourceRoot $asset.Source
    $target = Join-Path $copilotRoot $asset.Target
    if (-not (Test-Path $source)) { continue }

    Write-Step "Installing $($asset.Target) to $target"
    if ($PSCmdlet.ShouldProcess($target, "Install $($asset.Target)")) {
        New-Item -Path $target -ItemType Directory -Force | Out-Null
        Copy-Item -Path (Join-Path $source '*') -Destination $target -Recurse -Force
    }
}

# 5. Profile import
if (-not $SkipProfile) {
    $profilePath = $PROFILE.CurrentUserAllHosts
    $importLine = 'Import-Module AgExpert.Launcher'

    $existing = if (Test-Path $profilePath) { Get-Content $profilePath -Raw } else { '' }
    if ($existing -match [regex]::Escape($importLine)) {
        Write-Step 'Profile already imports AgExpert.Launcher'
    }
    elseif ($PSCmdlet.ShouldProcess($profilePath, 'Add module import')) {
        Write-Step "Adding the module import to $profilePath"
        New-Item -Path (Split-Path $profilePath -Parent) -ItemType Directory -Force | Out-Null
        Add-Content -Path $profilePath -Value "`r`n$importLine`r`n"
    }
}

Write-Step 'Done. Open a new terminal, then run: agexpert proxy status'
