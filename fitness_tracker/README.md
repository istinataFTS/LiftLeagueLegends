# Lift League Legends — App

A Flutter fitness tracker with offline-first SQLite storage and cloud sync
via Supabase. See the [root README](../README.md) for the full feature list
and architecture overview.

---

## Quick Start (3 steps)

The app ships pointed at the production backend. No Supabase account and no
configuration files are needed.

**Prerequisites**
- Flutter SDK ≥ 3.8.0 — [install guide](https://docs.flutter.dev/get-started/install)
- Android SDK / Android Studio (for Android targets)
- A physical Android device or emulator

```bash
git clone https://github.com/<your-username>/LiftLeagueLegends.git
cd LiftLeagueLegends/fitness_tracker
flutter pub get
flutter run
```

On first launch: tap **Create account**, enter your email and password, and
you're in.

---

## Running tests

```bash
# From fitness_tracker/
flutter test --coverage --dart-define=ENABLE_SUPABASE=false
```

`--dart-define=ENABLE_SUPABASE=false` keeps unit tests self-contained — they
must not reach the live backend.

---

## Using a custom Supabase backend (optional)

If you want to run against your own isolated Supabase project (local dev
stack, staging environment, or a completely independent deployment):

1. Copy the template: `cp dart_defines.example.json dart_defines.json`
2. Fill in your project's `SUPABASE_URL` and `SUPABASE_ANON_KEY`
3. Run: `flutter run --dart-define-from-file=dart_defines.json`
   — or just use `./scripts/run.ps1` (it picks up the file automatically)

For a local Supabase stack:
```bash
cd supabase
supabase start           # starts the local Postgres + Supabase stack
supabase status          # copy the API URL and anon key into dart_defines.json
supabase db push         # apply schema migrations
```

Then see `supabase/README.md` for deploying migrations to a cloud project.

---

## CI for forks

GitHub Actions runs automatically on push. For forks **without** the
`SUPABASE_URL` and `SUPABASE_ANON_KEY` repository secrets configured, CI
falls back to the production defaults baked into the code and still passes.

To connect CI to your own backend, add the secrets at:
**GitHub → your fork → Settings → Secrets and variables → Actions → New repository secret**

| Secret | Value |
|--------|-------|
| `SUPABASE_URL` | Your project URL |
| `SUPABASE_ANON_KEY` | Your project's anon/public key |

---

## Architecture and development guide

See [`CLAUDE.md`](CLAUDE.md) for the complete layered architecture, BLoC
conventions, offline-first sync protocol, convention checker rules, and
contributor guidelines.
