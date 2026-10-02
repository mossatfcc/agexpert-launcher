# agexpert-launcher

Terminal and VS Code launcher for the AgExpert development environment. Starts web apps,
APIs, and the environment proxy in dedicated terminal tabs from a single `agexpert` command.

For how the pieces fit together, see [docs/architecture.md](docs/architecture.md).

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
| `docs/architecture.md`          | How the config, module, extension, and proxy fit together              |
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
| `agexpert <app> [client] <Configuration>`                | Client built with an Angular configuration |
| `agexpert start [app] [Configuration]`                   | Client + server + proxy                   |
| `agexpert <api> api [Profile]`                           | API tab, defaulting to the `Test` profile |
| `agexpert <api> api restart [Profile]`                   | Stop the running API, then rebuild + restart it |
| `agexpert proxy [start\|stop\|status\|restart\|migrate]` | Proxy container control                   |
| `agexpert proxy <service> <start\|stop\|status>`         | One proxy service                         |

Products with a front end (`field`, `accounting`, `home`) start their client and server when
named alone. API-only products require the explicit `api` suffix, so `agexpert mcCain` is an
error that tells you to run `agexpert mcCain api`.

## Angular build configurations

The client watch accepts one of four build configurations, matching the VS Code
`buildConfiguration` task input:

| Configuration | Client command                                   |
| ------------- | ------------------------------------------------ |
| `default`     | `ng build <app> --watch` (angular.json default)  |
| `localized`   | `ng build <app> --watch --configuration localized` |
| `development` | `ng build <app> --watch --configuration development` |
| `production`  | `ng build <app> --watch --configuration production` |

The word can go anywhere after the app name:

```powershell
agexpert field localized              # client + server, localized client build
agexpert field client production      # client only
agexpert start field development      # client + server + proxy
agexpert start localized              # saved default app
```

The server ignores the configuration. `Start-AgExpertApp` and `Start-AgExpertEnvironment` take
it as `-Configuration`, and the VS Code **Launch** command asks for it after you pick an app.

## Launch profiles

APIs default to `Test`, matching the environment proxy. Pass any profile defined in the
project's `launchSettings.json`, such as `Default`, `UAT`, or `Open`. Unknown profiles fail
before a terminal opens.

APIs start with `dotnet run --no-restore`: your source changes are compiled, but NuGet
restore is skipped so startup does not block on Azure Artifacts device-flow authentication.
After changing package references, run `dotnet restore` once and authenticate.

## Restarting an API

When an API is already running and you want it to pick up code changes, restart it in one step:

```powershell
agexpert field api restart          # stop the running Field API, then rebuild + restart it
agexpert accounting api restart UAT # same, but on the UAT launch profile
```

Restart works for any API in the registry. It stops the local `dotnet` process bound to that
API's port, then hands off to a normal start — recompiling via `dotnet run` and opening a fresh
terminal tab. The launch profile defaults to `Test`, exactly like a plain start; pass a profile
to override it.

If nothing is running on the port, restart simply starts the API. The environment proxy is never
touched: when the proxy (not a local dotnet process) owns the port, restart leaves it alone and
the start step releases the service the usual way.

## Requirements

- PowerShell 7+
- .NET SDK matching the target framework in the FMPro repository
- Docker Desktop for the environment proxy
- Windows Terminal, used when launching from outside VS Code

## Development

```powershell
Invoke-Pester ./tests
Invoke-ScriptAnalyzer -Recurse ./src/module
```

## Releasing and installing a new build

Run the release from the launcher checkout (`C:\AgExpert\agexpert-launcher`) after the change
has merged:

```powershell
cd C:\AgExpert\agexpert-launcher
git checkout main
git pull
./tools/Build-AgExpertRelease.ps1 -BumpPatch -Install   # or -BumpMinor / -BumpMajor
```

The script runs the analyzer and Pester, syncs `config/` into the extension, bumps the module
manifest and extension `package.json` together, and packages the `.vsix`. `-Install` then runs
`tools/install.ps1`, which updates the PowerShell module, the VS Code extension, and the Copilot
agent and skills, keeping your existing `~/.agexpert/launcher.settings.json` preferences.
**Without `-Install` nothing is installed.**

Then load the new build:

1. Open a new terminal (or run `Import-Module AgExpert.Launcher -Force`).
2. In VS Code, run **Developer: Restart Extension Host**.
3. Confirm both versions match the repository manifest:

   ```powershell
   agexpert --version
   code --list-extensions --show-versions | Select-String agexpert
   ```

Finally, commit the version bump (`AgExpert.Launcher.psd1` and `src/extension/package.json`)
with a `CHANGELOG.md` entry and open a PR. An uncommitted bump lets the installed build drift
ahead of the repository, and the next release then looks like a downgrade.

## License

MIT
