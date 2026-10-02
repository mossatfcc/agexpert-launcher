---
name: agexpert-launcher-run
description: Start AgExpert web apps, APIs, or the environment proxy, and diagnose failures to start — stuck NuGet restore, device-flow authentication prompts, ports already in use, a stale VS Code Extension Host, or missing launch profiles. Use when the user says an API or app will not start, hangs, or when they ask to run field, accounting, home, or any AgExpert API locally.
---

# Running and diagnosing AgExpert locally

## 1. Start things

```powershell
agexpert start                # whole dev environment for the saved default app
agexpert start accounting     # whole dev environment for a specific app
agexpert start field localized  # ...with an Angular build configuration
agexpert field                # client + server
agexpert field production     # client + server, production client build
agexpert field client development  # client only, development build
agexpert field api            # API on the Test profile
agexpert field api UAT        # explicit profile
agexpert field api restart    # stop the running API, then rebuild + restart it
agexpert proxy status
```

The `api` suffix is mandatory for API-only products. `agexpert mcCain` is an error by design.

Client build configurations are `default` (no flag, angular.json default), `localized`,
`development`, and `production`. The word may appear anywhere after the app; the server ignores it.

### Start the whole dev environment

`agexpert start` opens three tabs — the app **client** watch, its **server**, and the **proxy** —
leaving the client running locally against the proxy and Test APIs.

- **First run:** no default is saved. Ask which app to run (for example `field`, `accounting`, or
  `home`) and save it with `Set-AgExpertDefaultApp <app>`. Only server-backed front ends qualify;
  `gallery` (client-only) and API/proxy-only products are rejected.
- **Later runs:** `agexpert start` reuses the saved default; name an app to override once.
- **Readiness:** it polls until the proxy container is running and the app server port responds,
  then returns `Check`/`Status`/`Detail` rows. It is green when the `Environment` row is `Pass`;
  a timeout produces a `Warn` (the server or first `ng build --watch` may still be compiling).

`Get-AgExpertDefaultApp` returns the saved default (or nothing), so you know whether to prompt.

## 2. Diagnose with code, not guesswork

Always start here. One call replaces the whole manual sweep:

```powershell
Test-AgExpertEnvironment -Api field
Test-AgExpertEnvironment | Where-Object Status -ne 'Pass'
```

Each row is `Check` / `Status` / `Detail`. Interpret, then act.

## 3. Failure signatures and remedies

### Stuck on restore, then device-flow errors

```
[CredentialProvider]DeviceFlow: https://pkgs.dev.azure.com/...
[CredentialProvider]ATTENTION: User interaction required.
Device flow authentication failed. User was presented with device flow,
but didn't react within 90 seconds.
```

Startup is blocked on Azure Artifacts authentication, not on your code. The launcher passes
`--no-restore` precisely to avoid this, so seeing it means either a package reference changed
or an older command is running.

1. Confirm the running command really is `--no-restore`. If it is not, the installed extension
   is stale — see *Stale Extension Host* below.
2. If package references genuinely changed, authenticate once:
   ```powershell
   cd <api project>
   dotnet restore --interactive
   ```
   Open the printed URL, enter the code, then start normally.

### Port already in use

The proxy publishes every API port, so a local API cannot bind while the proxy owns it.
`Start-AgExpertApi` releases the port automatically; if something else holds it:

```powershell
Test-AgExpertEnvironment -Api field     # names the owning process
Repair-AgExpertProxy field -Release     # hand the port to the local API
Repair-AgExpertProxy field -Restore     # give it back to the proxy afterwards
```

### Stale Extension Host

Symptom: the terminal tab runs an old command, or a launcher URI opens the wrong tabs.
Editing files under `~/.vscode/extensions/` does nothing until the host restarts.

Fix: run **Developer: Restart Extension Host** from the Command Palette, or install a fresh
build with `tools/Build-AgExpertRelease.ps1 -BumpPatch -Install`.

If a new option is ignored (for example the client still runs plain `ng build <app> --watch`),
the installed build is stale. Compare `Get-AgExpertVersion` and
`code --list-extensions --show-versions | Select-String agexpert` with the repository manifest.

### `'target' is not recognized as an internal or external command`

A launcher URI reached `code.cmd` with more than one query parameter, so the shell split it
on `&`. Routes must be a single encoded `launch=<name>|<target>|<profile>` parameter.

### Unknown launch profile

`Start-AgExpertApi` validates the profile against the project's `launchSettings.json` before
opening a tab and lists the valid names. Pick one from that list.

## 4. What actually rebuilds

| Command | Compiles your changes |
|---|---|
| `dotnet run --no-restore` (APIs) | Yes |
| `dotnet run --no-restore` (app servers) | Yes — incremental build self-heals a missing/stale binary |
| `agexpert <api> api restart [Profile]` | Yes — stops the running API, then rebuilds and restarts it |

## 5. Never do this

- Do not add `--no-build` to app or API startup; it silently runs stale binaries and fails
  outright when the binary is missing (for example after a fresh checkout or restart).
- Do not stop the whole proxy to free one port; release just that service.
- Do not hand-write process or port checks — extend `Test-AgExpertEnvironment` instead.
