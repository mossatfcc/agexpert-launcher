# agexpert-launcher

Terminal and VS Code launcher for the AgExpert development environment. Starts web apps,
APIs, and the environment proxy in dedicated terminal tabs from a single `agexpert` command.

```powershell
agexpert field              # field client + field server
agexpert field api          # field API on the Test launch profile
agexpert field api UAT      # field API on an explicit launch profile
agexpert mcCain api         # API-only product (the api suffix is required)
agexpert proxy status       # environment proxy state
Test-AgExpertEnvironment    # diagnose why something will not start
```

## Layout

| Path                            | Purpose                                                                |
| ------------------------------- | ---------------------------------------------------------------------- |
| `config/apis.json`              | Single source of truth for API name, project directory, and proxy port |
| `config/apps.json`              | Web apps and their server launch profiles                              |
| `config/settings.default.json`  | Default machine paths, overridden per machine at install time          |
| `src/module/AgExpert.Launcher/` | PowerShell module — everything you run daily                           |
| `src/extension/`                | VS Code extension that opens dedicated terminal tabs                   |
| `copilot/agents/`               | Copilot agent definition                                               |
| `copilot/skills/`               | Copilot skills for using and maintaining the toolkit                   |
| `tests/`                        | Pester suite                                                           |
| `tools/`                        | Install, release, and repo bootstrap scripts                           |

Both the module and the extension read `config/apis.json`, so an API is defined once.

## Install

```powershell
git clone https://github.com/<owner>/agexpert-launcher.git C:\AgExpert\agexpert-launcher
cd C:\AgExpert\agexpert-launcher
.\tools\install.ps1 -RepoRoot C:\AgExpert\FMPro
```

The installer copies the module onto `PSModulePath`, installs the packaged extension,
copies the Copilot agent and skills into `~/.copilot`, writes machine settings to
`~/.agexpert/launcher.settings.json`, and adds `Import-Module AgExpert.Launcher` to your profile.

Preview the changes first with `-WhatIf`. Re-run the installer after pulling.

## Command grammar

| Command                                                  | Result                                    |
| -------------------------------------------------------- | ----------------------------------------- |
| `agexpert <app>`                                         | Client watch + server tabs                |
| `agexpert <app> client` \| `server`                      | A single tab                              |
| `agexpert <api> api [Profile]`                           | API tab, defaulting to the `Test` profile |
| `agexpert proxy [start\|stop\|status\|restart\|migrate]` | Proxy container control                   |
| `agexpert proxy <service> <start\|stop\|status>`         | One proxy service                         |

Products with a front end (`field`, `accounting`, `home`) start their client and server when
named alone. API-only products require the explicit `api` suffix, so `agexpert mcCain` is an
error that tells you to run `agexpert mcCain api`.

## Launch profiles

APIs default to `Test`, matching the environment proxy. Pass any profile defined in the
project's `launchSettings.json`, such as `Default`, `UAT`, or `Open`. Unknown profiles fail
before a terminal opens.

APIs start with `dotnet run --no-restore`: your source changes are compiled, but NuGet
restore is skipped so startup does not block on Azure Artifacts device-flow authentication.
After changing package references, run `dotnet restore` once and authenticate.

## Requirements

- PowerShell 7+
- .NET SDK matching the target framework in the FMPro repository
- Docker Desktop for the environment proxy
- Windows Terminal, used when launching from outside VS Code

## Development

```powershell
Invoke-Pester ./tests
Invoke-ScriptAnalyzer -Recurse ./src/module
./tools/Build-AgExpertRelease.ps1 -BumpPatch
```

## License

MIT
