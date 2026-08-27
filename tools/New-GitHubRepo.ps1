<#
    .SYNOPSIS
        Creates the GitHub repository and pushes the initial commit.
    .DESCRIPTION
        Reads a GitHub token from ~/.agexpert/.env in-process only. The token is never written
        to disk, never placed in a command-line argument, never stored in .git/config, and never
        echoed. Credentials reach git through an environment-backed credential helper.
    .EXAMPLE
        ./tools/New-GitHubRepo.ps1 -Name agexpert-launcher -Private
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$Name = 'agexpert-launcher',
    [string]$Description = 'Launcher for AgExpert web apps, APIs, and the local environment proxy.',
    [switch]$Public,
    [string]$TokenVariable,
    [string]$EnvFile = (Join-Path $HOME '.agexpert\.env')
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent

function Get-EnvToken {
    param(
        [string]$Path,
        [string]$Variable
    )

    if (-not (Test-Path $Path)) { throw "Environment file not found: $Path" }

    $values = [ordered]@{}

    foreach ($line in Get-Content $Path) {
        $trimmed = $line.Trim()
        if (-not $trimmed -or $trimmed.StartsWith('#')) { continue }

        $trimmed = $trimmed -replace '^export\s+', ''
        $separator = $trimmed.IndexOf('=')
        if ($separator -lt 1) { continue }

        $key = $trimmed.Substring(0, $separator).Trim()
        $value = $trimmed.Substring($separator + 1).Trim().Trim('"', "'")
        if ($value) { $values[$key] = $value }
    }

    if ($Variable) {
        if (-not $values.Contains($Variable)) { throw "Variable '$Variable' not found in $Path." }
        Write-Host "Using token from $Variable."
        return $values[$Variable]
    }

    # Exact names first, then any prefixed variant such as MYORG_GITHUB_PAT.
    $exact = 'GITHUB_PAT', 'GH_PAT', 'GITHUB_TOKEN', 'GH_TOKEN'
    foreach ($candidate in $exact) {
        if ($values.Contains($candidate)) {
            Write-Host "Using token from $candidate."
            return $values[$candidate]
        }
    }

    $suffixMatch = @($values.Keys | Where-Object { $_ -match '(GITHUB_PAT|GITHUB_TOKEN|GH_PAT|GH_TOKEN)$' })
    if ($suffixMatch.Count -eq 1) {
        Write-Host "Using token from $($suffixMatch[0])."
        return $values[$suffixMatch[0]]
    }
    if ($suffixMatch.Count -gt 1) {
        throw "Multiple GitHub tokens found ($($suffixMatch -join ', ')). Pass -TokenVariable to choose one."
    }

    throw "No GitHub token found in $Path. Expected a variable ending in one of: $($exact -join ', ')."
}

$token = Get-EnvToken -Path $EnvFile -Variable $TokenVariable

try {
    $headers = @{
        Authorization          = "Bearer $token"
        Accept                 = 'application/vnd.github+json'
        'X-GitHub-Api-Version' = '2022-11-28'
        'User-Agent'           = 'agexpert-launcher-bootstrap'
    }

    $user = Invoke-RestMethod -Uri 'https://api.github.com/user' -Headers $headers
    Write-Host "Authenticated as $($user.login)."

    $existing = $null
    try {
        $existing = Invoke-RestMethod -Uri "https://api.github.com/repos/$($user.login)/$Name" -Headers $headers
    }
    catch {
        $existing = $null
    }

    if ($existing) {
        Write-Host "Repository already exists: $($existing.html_url)"
        $remoteUrl = $existing.clone_url
    }
    elseif ($PSCmdlet.ShouldProcess($Name, 'Create GitHub repository')) {
        $body = @{
            name        = $Name
            description = $Description
            private     = -not $Public
        } | ConvertTo-Json

        $created = Invoke-RestMethod -Uri 'https://api.github.com/user/repos' -Method Post -Headers $headers -Body $body -ContentType 'application/json'
        Write-Host "Created $($created.html_url)"
        $remoteUrl = $created.clone_url
    }
    else {
        return
    }

    Push-Location $repoRoot
    try {
        if (-not (Test-Path (Join-Path $repoRoot '.git'))) {
            git init -b main | Out-Null
        }

        git add --all

        git diff --cached --quiet
        if ($LASTEXITCODE -ne 0) {
            git commit -m 'feat: package the AgExpert launcher as a portable toolkit' | Out-Null
        }

        if (git remote | Select-String -SimpleMatch 'origin') {
            git remote set-url origin $remoteUrl
        }
        else {
            git remote add origin $remoteUrl
        }

        if ($PSCmdlet.ShouldProcess($remoteUrl, 'Push initial commit')) {
            # The helper reads the token from the environment, keeping it out of argv and .git/config.
            # The empty helper first clears inherited helpers so Credential Manager cannot answer instead.
            $env:AGEXPERT_GITHUB_TOKEN = $token
            $env:AGEXPERT_GITHUB_USER = $user.login
            $helper = '!f() { echo username=$AGEXPERT_GITHUB_USER; echo password=$AGEXPERT_GITHUB_TOKEN; }; f'

            git -c credential.helper= -c credential.helper=$helper push -u origin main
            if ($LASTEXITCODE -ne 0) { throw 'git push failed.' }
        }
    }
    finally {
        Pop-Location
        Remove-Item Env:AGEXPERT_GITHUB_TOKEN -ErrorAction SilentlyContinue
        Remove-Item Env:AGEXPERT_GITHUB_USER -ErrorAction SilentlyContinue
    }
}
finally {
    $token = $null
    [System.GC]::Collect()
}

Write-Host 'Repository ready.'
