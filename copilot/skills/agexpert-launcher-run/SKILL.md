---
name: agexpert-launcher-run
description: Start AgExpert web apps, APIs, or the environment proxy, and diagnose failures to start — stuck NuGet restore, device-flow authentication prompts, ports already in use, a stale VS Code Extension Host, or missing launch profiles. Use when the user says an API or app will not start, hangs, or when they ask to run field, accounting, home, or any AgExpert API locally.
---

# Running and diagnosing AgExpert locally

## 1. Start things

```powershell
agexpert field              # client + server
agexpert field api          # API on the Test profile
agexpert field api UAT      # explicit profile
agexpert proxy status
```

The `api` suffix is mandatory for API-only products. `agexpert mcCain` is an error by design.

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
build with `tools/Build-AgExpertRelease.ps1`.

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
| `dotnet run --no-build --no-restore` (app servers) | No — build first |

## 5. Never do this

- Do not add `--no-build` to API startup; it silently runs stale binaries.
- Do not stop the whole proxy to free one port; release just that service.
- Do not hand-write process or port checks — extend `Test-AgExpertEnvironment` instead.
