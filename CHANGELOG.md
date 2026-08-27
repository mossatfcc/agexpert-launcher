# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `agexpert start [app]` and `Start-AgExpertEnvironment` bring up the whole local dev
  environment — the app client watch, its server, and the proxy (three tabs) — then poll until
  the proxy and app server respond and report whether it is green and ready.
- `Set-AgExpertDefaultApp` / `Get-AgExpertDefaultApp` remember a default app in
  `~/.agexpert/launcher.settings.json`, so repeat `agexpert start` calls skip the prompt.

### Fixed

- Every terminal the launcher opens now joins one VS Code tab group. The proxy tab from
  `agexpert start` (a separate URI invocation) splits off the app's client/server group instead
  of opening ungrouped, and a later single launch joins the existing group. A fresh group starts
  only once every launcher terminal is closed.
- `Build-AgExpertRelease.ps1` runs Pester in a clean `-NoProfile` session, and the tests remove
  any already-loaded `AgExpert.Launcher` module before importing the repo copy, so a
  profile-imported module no longer collides ("Multiple script or manifest modules ... loaded").

## [0.1.0] - 2026-08-27

### Added

- `AgExpert.Launcher` PowerShell module extracted from the personal profile.
- Shared `config/apis.json` and `config/apps.json` registries consumed by both the
  module and the VS Code extension, removing the duplicated API tables.
- `Test-AgExpertEnvironment` for one-call diagnosis of API startup problems.
- `Repair-AgExpertProxy` to release or republish a single proxy service port.
- Pester suite covering registry parity, command routing, extension terminals, and syntax.
- `agexpert-launcher` Copilot agent plus `agexpert-launcher-run` and `agexpert-launcher-maintain` skills.
- `tools/install.ps1` for reproducible setup on a new machine.

### Changed

- API launches default to the `Test` launch profile; pass a profile name to override.
- API launches run `dotnet run --no-restore` so source changes still compile without
  blocking on NuGet device-flow authentication.
- Launcher URIs use a single encoded `launch` parameter, so `code.cmd` no longer splits
  the query string on `&`.
- Proxy services resolve by product name with or without the `API` suffix.

### Fixed

- Field API path corrected to `AgExpert.Field/src/Api`.
