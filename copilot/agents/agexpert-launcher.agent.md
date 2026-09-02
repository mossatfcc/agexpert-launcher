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
| `agexpert start [app]` | Whole dev environment: app client + server + proxy (three tabs) |
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

## Start the whole dev environment

When the user says something like "start app" or "start the development environment", bring up the
full local stack — the app **client** watch, its **server**, and the **proxy** (three tabs) — with
the client running locally against the proxy and Test APIs:

1. **First time only** — no default app is saved. Ask the user which app to run as the default
   (for example `field`, `accounting`, or `home`), then persist it: `Set-AgExpertDefaultApp <app>`
   (server-backed front ends only; `gallery` and API/proxy-only products are rejected).
2. **Every time** — run `agexpert start`. With no app named it uses the saved default; pass an app
   to override once (`agexpert start accounting`). This opens the three tabs.
3. **Report green** — `Start-AgExpertEnvironment` polls until the proxy container is running and the
   app server port responds, then returns `Check`/`Status`/`Detail` rows. Report back once the
   `Environment` row is `Pass` (green and ready), or relay the `Warn` detail if it times out.

`Get-AgExpertDefaultApp` tells you whether a default is already set, so you know whether to prompt.

## Rules that are easy to get wrong

- **`Test` is the default profile**, matching the proxy environment. Not `Default`.
- **APIs run `dotnet run --no-restore`.** Source changes still compile. Restore is skipped
  because Azure Artifacts device-flow authentication otherwise blocks startup for 90 seconds
  per feed and then fails.
- **Apps run `dotnet run --no-restore`** (like APIs): an incremental build self-heals a missing
  binary and picks up server source changes, while `--no-restore` skips the device-flow hang.
- **A local API and the proxy cannot share a port.** `Start-AgExpertApi` releases the proxy
  service first. Restore it later with `Repair-AgExpertProxy <name> -Restore`.
- **Launcher URIs carry one encoded `launch` parameter.** Never add a second query parameter:
  `code.cmd` splits on `&` and the extension receives a truncated route.
- **Editing the installed extension has no effect until the Extension Host restarts.** Ship
  changes through `tools/Build-AgExpertRelease.ps1`, which bumps the version and reinstalls.

## Skills

| Load | When |
|---|---|
| `agexpert-launcher-run` | Starting something, or diagnosing a failure to start |
| `agexpert-launcher-maintain` | Adding or changing an API, or cutting a release |

## Safety

Never print, log, or commit the contents of `~/.agexpert/.env`. It holds the GitHub and Azure
DevOps tokens. Read only the variable you need, in-process, and never pass a token as a
command-line argument.
