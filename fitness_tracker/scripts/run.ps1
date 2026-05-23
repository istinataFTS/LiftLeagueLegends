#!/usr/bin/env pwsh
# Wrapper around `flutter run` that injects the project's --dart-define values
# from dart_defines.json. Forwards any extra arguments straight through
# (e.g. `./scripts/run.ps1 -d chrome`, `./scripts/run.ps1 --release`).

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$definesFile = Join-Path $repoRoot 'dart_defines.json'

if (-not (Test-Path $definesFile)) {
    throw "dart_defines.json not found at $definesFile. Copy dart_defines.example.json if present, or see CLAUDE.md."
}

& flutter run "--dart-define-from-file=$definesFile" @args
