#!/usr/bin/env pwsh
# Wrapper around `flutter run` that injects the project's --dart-define values
# from dart_defines.json. Forwards any extra arguments straight through
# (e.g. `./scripts/run.ps1 -d chrome`, `./scripts/run.ps1 --release`).

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$definesFile = Join-Path $repoRoot 'dart_defines.json'

if (Test-Path $definesFile) {
    # dart_defines.json present — override production defaults (local Supabase
    # stack, staging, or custom backend).
    & flutter run "--dart-define-from-file=$definesFile" @args
} else {
    # No dart_defines.json — run with production defaults baked into env_config.dart.
    # This is the standard path for a fresh fork that has not configured a
    # custom backend.
    & flutter run @args
}
