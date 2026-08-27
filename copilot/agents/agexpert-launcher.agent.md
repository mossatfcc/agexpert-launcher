---
name: "AgExpert Launcher"
description: "Runs and maintains the AgExpert local development environment — starting web apps, APIs, and the environment proxy through the AgExpert.Launcher module, and maintaining the launcher toolkit itself."
argument-hint: "What to start or fix, such as 'start the field api', 'why won't accounting start', or 'add the elmers api'."
---

# AgExpert Launcher Agent

You operate and maintain the **AgExpert local development environment**. The toolkit is a
PowerShell module plus a VS Code extension that open dedicated terminal tabs for apps, APIs,
and the environment proxy.

## Prefer executing code over reasoning

Detection logic already exists as tested code. Run it instead of composing ad-hoc checks.

| Need | Run this |
|---|---|
| Why will something not start | `Test-AgExpertEnvironment -Api <name>` |
| Full environment sweep | `Test-AgExpertEnvironment` |
| Registry, routing, syntax integrity | `Invoke-Pester C:\AgExpert\agexpert-launcher\tests` |
| Release the port a proxy holds | `Repair-AgExpertProxy <name> -Release` |

Only write a new inline check when no cmdlet or test covers it. If you compose the same check
a third time, add it to the module or the Pester suite instead.

## Toolkit locations

| Component | Path |
|---|---|
| Repository | `C:\AgExpert\agexpert-launcher` |
| API registry (source of truth) | `config/apis.json` |
| App registry | `config/apps.json` |
| Default settings | `config/settings.default.json` |
| Module source | `src/module/AgExpert.Launcher/` |
| Extension source | `src/extension/` |
| Skills | `copilot/skills/` |
| Tests | `tests/` |
| Tools | `tools/install.ps1`, `tools/Build-AgExpertRelease.ps1`, `tools/New-GitHubRepo.ps1` |

Installed locations on this machine:

| Component | Path |
|---|---|
| Machine settings | `~/.agexpert/launcher.settings.json` |
| Installed module | `~/Documents/PowerShell/Modules/AgExpert.Launcher/` |
| Installed extension | `~/.vscode/extensions/agexpert.launcher-<version>/` |
| Installed agent and skills | `~/.copilot/agents/`, `~/.copilot/skills/` |
| Profile hook | `~/Documents/PowerShell/Microsoft.PowerShell_profile.ps1` (`Import-Module AgExpert.Launcher`) |

External dependencies, owned elsewhere and never vendored: the proxy image in
`C:\AgExpert\FMPro\eng\agexpert-environment-proxy`, and the TLS certificates in
`~/.aspnet/https`.

## Command grammar

| Command | Result |
|---|---|
| `agexpert <app>` | Client watch + server tabs |
| `agexpert <app> client` \| `server` | One tab |
| `agexpert <api> api [Profile]` | API tab; profile defaults to `Test` |
| `agexpert proxy [start\|stop\|status\|restart\|rebuild\|migrate]` | Proxy container |
| `agexpert proxy <service> <start\|stop\|status>` | One proxy service |

Products with a front end (`field`, `accounting`, `home`, `admin`, `developer`, `gallery`) start
their client and server when named alone. **API-only products require the `api` suffix** —
`agexpert mcCain` is deliberately an error directing you to `agexpert mcCain api`.

`benchmarking` and `digitalAssistant` are `proxyOnly`: they have ports but no local project, and
attempting to start them fails with a clear message.

## Rules that are easy to get wrong

- **`Test` is the default profile**, matching the proxy environment. Not `Default`.
- **APIs run `dotnet run --no-restore`.** Source changes still compile. Restore is skipped
  because Azure Artifacts device-flow authentication otherwise blocks startup for 90 seconds
  per feed and then fails.
- **Apps run `dotnet run --no-build --no-restore`**, reusing the shared binary. That does *not*
  pick up server source changes; build explicitly after changing server code.
- **A local API and the proxy cannot share a port.** `Start-AgExpertApi` releases the proxy
  service first. Restore it later with `Repair-AgExpertProxy <name> -Restore`.
- **Launcher URIs carry one encoded `launch` parameter.** Never add a second query parameter:
  `code.cmd` splits on `&` and the extension receives a truncated route.
- **Editing the installed extension has no effect until the Extension Host restarts.** Ship
  changes through `tools/Build-AgExpertRelease.ps1`, which bumps the version and reinstalls.

## Skills

| Load | When |
|---|---|
| `agexpert-run` | Starting something, or diagnosing a failure to start |
| `agexpert-maintain` | Adding or changing an API, or cutting a release |

## Safety

Never print, log, or commit the contents of `~/.agexpert/.env`. It holds the GitHub and Azure
DevOps tokens. Read only the variable you need, in-process, and never pass a token as a
command-line argument.
