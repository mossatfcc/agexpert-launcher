function Test-AgExpertEnvironment {
    <#
        .SYNOPSIS
            Diagnoses why an AgExpert API or the environment will not start.
        .DESCRIPTION
            Replaces ad-hoc troubleshooting with one reproducible pass over tooling, registry
            integrity, project layout, launch profiles, port ownership, and build freshness.
            Emits one object per check so results can be filtered or asserted against.
        .EXAMPLE
            Test-AgExpertEnvironment
            Test-AgExpertEnvironment -Api field
            Test-AgExpertEnvironment | Where-Object Status -ne 'Pass'
    #>
    [CmdletBinding()]
    [OutputType([psobject])]
    param(
        [Parameter(Position = 0)][string]$Api,
        [switch]$IncludePorts
    )

    $results = [System.Collections.Generic.List[psobject]]::new()
    function Add-Result([string]$Check, [string]$Status, [string]$Detail) {
        $results.Add([pscustomobject]@{ Check = $Check; Status = $Status; Detail = $Detail })
    }

    $settings = Get-AgExpertSettings

    if (Test-Path $settings.repoRoot) {
        Add-Result 'Repository root' 'Pass' $settings.repoRoot
    }
    else {
        Add-Result 'Repository root' 'Fail' "Not found: $($settings.repoRoot). Fix repoRoot in ~/.agexpert/launcher.settings.json."
    }

    foreach ($tool in 'dotnet', 'docker', 'code') {
        if (Get-Command $tool -ErrorAction SilentlyContinue) {
            Add-Result "Tool: $tool" 'Pass' 'Available'
        }
        else {
            Add-Result "Tool: $tool" 'Fail' "'$tool' is not on PATH."
        }
    }

    $registry = Get-AgExpertRegistry
    $duplicatePorts = @($registry | Group-Object port | Where-Object Count -gt 1 | Select-Object -ExpandProperty Name)
    if ($duplicatePorts) {
        Add-Result 'Registry ports' 'Fail' "Duplicate ports: $($duplicatePorts -join ', ')"
    }
    else {
        Add-Result 'Registry ports' 'Pass' "$($registry.Count) unique ports"
    }

    $containerState = Get-AgExpertProxyContainerState
    if ($containerState) {
        Add-Result 'Proxy container' $(if ($containerState -eq 'running') { 'Pass' } else { 'Warn' }) $containerState
    }
    else {
        Add-Result 'Proxy container' 'Warn' "Not created. Run 'agexpert proxy' to start it."
    }

    $targets = if ($Api) {
        $config = Get-AgExpertApiConfig $Api
        if (-not $config) { throw "Unknown AgExpert API '$Api'." }
        @($config)
    }
    else {
        @($registry)
    }

    $publishedPorts = @(Get-AgExpertProxyPublishedPorts)

    foreach ($config in $targets) {
        $label = $config.name

        if ($config.proxyOnly) {
            Add-Result "$label project" 'Skip' 'Proxy-only service; no local project.'
            continue
        }

        $apiPath = Join-Path $settings.repoRoot (ConvertTo-AgExpertPath $config.directory)
        if (-not (Test-Path $apiPath)) {
            Add-Result "$label project" 'Fail' "Missing directory: $apiPath"
            continue
        }
        Add-Result "$label project" 'Pass' $config.directory

        $launchSettingsPath = Join-Path $apiPath 'Properties\launchSettings.json'
        if (Test-Path $launchSettingsPath) {
            $profileNames = (Get-Content $launchSettingsPath -Raw | ConvertFrom-Json).profiles.PSObject.Properties.Name
            $wanted = if ($config.defaultProfile) { $config.defaultProfile } else { 'Test' }
            if ($profileNames -contains $wanted) {
                Add-Result "$label profile" 'Pass' $wanted
            }
            else {
                Add-Result "$label profile" 'Fail' "Missing '$wanted'. Available: $($profileNames -join ', ')"
            }
        }
        else {
            Add-Result "$label profile" 'Fail' "Missing launchSettings.json"
        }

        if ($Api -or $IncludePorts) {
            $owner = Get-AgExpertPortOwner $config.port
            if (-not $owner) {
                Add-Result "$label port $($config.port)" 'Pass' 'Free'
            }
            elseif ($publishedPorts -contains $config.port) {
                Add-Result "$label port $($config.port)" 'Warn' "Held by the proxy ($($owner.ProcessName)). Run: Repair-AgExpertProxy $label -Release"
            }
            else {
                Add-Result "$label port $($config.port)" 'Warn' "In use by $($owner.ProcessName) (PID $($owner.ProcessId))."
            }

            $buildOutput = Get-ChildItem -Path (Join-Path $apiPath 'bin') -Filter '*.dll' -Recurse -ErrorAction SilentlyContinue |
                Where-Object { $_.BaseName -like 'AgExpert.*.Api' } | Select-Object -First 1
            if ($buildOutput) {
                Add-Result "$label build" 'Pass' "Last built $($buildOutput.LastWriteTime)"
            }
            else {
                Add-Result "$label build" 'Warn' 'No build output; the first run compiles from scratch.'
            }
        }
    }

    $results
}
