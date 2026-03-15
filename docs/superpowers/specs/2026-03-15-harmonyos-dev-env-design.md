# 2026-03-15-harmonyos-dev-env-design

## Summary

Set up a multi-App HarmonyOS development workspace with a layered shell-script architecture to manage:

- Development environment start/stop
- Multi-App build orchestration
- Dev/prod config switching
- Device/emulator run & deploy

This repo is currently an empty git repository; this spec defines the initial scaffolding to make it usable.

## Goals

1. **Multi-App ready**: Support multiple HarmonyOS apps under a single workspace.
2. **One-command workflows**: Common flows exposed via top-level scripts.
3. **Dev/prod split**: Clear separation between development startup and production run/deploy.
4. **Local-first**: Assume DevEco Studio is already installed locally.
5. **Extensible**: Easy to add apps and environment variants.

## Non-goals

- Implementing app business code
- CI/CD pipelines
- Automatic testing/coverage enforcement (handled separately)

## Proposed Repository Structure

```
app-harmony-os/
├── apps/                     # Multiple HarmonyOS apps (future)
├── shared/                   # Shared modules (future)
├── tools/                    # Tooling (future)
├── scripts/                  # Scripted workflows
│   ├── env/
│   │   ├── deveco.sh         # DevEco tool discovery, hvigor/hvd helpers
│   │   └── simulator.sh      # (Optional) emulator/device helpers
│   ├── apps/
│   │   ├── build-all.sh      # Build all or selected apps
│   │   ├── dev-server.sh     # Start dev mode for app(s)
│   │   └── deploy.sh         # Install/deploy to device
│   ├── config/
│   │   ├── dev.sh            # Dev env variables/config
│   │   └── prod.sh           # Prod env variables/config
│   ├── utils/
│   │   └── common.sh         # Logging, argument parsing, safety checks
│   └── main/
│       ├── dev-start.sh      # Entry: start dev environment
│       ├── dev-stop.sh       # Entry: stop dev environment
│       ├── dev-build.sh      # Entry: build (dev or prod)
│       └── run-prod.sh       # Entry: production run/deploy
├── dev-start.sh              # Thin wrappers → scripts/main/*
├── dev-stop.sh
├── dev-build.sh
├── run-prod.sh
├── CLAUDE.md
└── .claude/settings.local.json
```

## Design Details

### 1) Tool Discovery & External Tooling

We will not “rebuild” DevEco Studio. Instead we **discover and use** these CLI tools if available:

- `hvigorw` / `hvigor` for building
- `hdc` for device install/run

`./scripts/env/deveco.sh` will:
- Verify tool availability
- Print actionable errors if missing
- Provide helper functions:
  - `require_cmd hvigorw`
  - `require_cmd hdc`

### 2) Multi-App Support Model

Apps will live in `apps/<appName>/`.

For scripting, we’ll support:
- `--app <name>`: single app
- `--apps <a,b,c>`: multiple apps
- Default: build/run **all discovered apps** under `apps/*`.

Discovery rules:
- Treat a directory under `apps/` as an app if it contains a HarmonyOS project marker (to be defined when real apps are added).
- In the empty repo stage, scripts will gracefully warn if `apps/` is empty.

### 3) Dev / Prod Configuration Switching

`./scripts/config/dev.sh` and `./scripts/config/prod.sh` define:
- Environment variables (e.g. API endpoints, feature flags)
- Output directories (e.g. `dist/dev`, `dist/prod`)

Main scripts will source exactly one config:
- `dev-start.sh` → sources `config/dev.sh`
- `run-prod.sh` → sources `config/prod.sh`

### 4) Entry Scripts (User Interface)

Top-level scripts are stable entry points:
- `./dev-start.sh [--app xxx] [--device xxx]`
- `./dev-stop.sh`
- `./dev-build.sh [--app xxx] [--mode dev|prod]`
- `./run-prod.sh [--app xxx] [--device xxx]`

They will be thin wrappers that delegate to `scripts/main/*`.

### 5) Error Handling & UX

All scripts will:
- `set -euo pipefail`
- Use consistent logging helpers (`info`, `warn`, `error`)
- Validate inputs (`--app` must exist)
- Exit with non-zero status on failure

### 6) “Restart session” requirement

From the repo’s perspective, we interpret “restart current session” as:
- Make scripts idempotent
- Provide `dev-stop.sh` then `dev-start.sh` to reset running dev processes

(Claude session restart is a user-side action; scripts provide the equivalent env reset.)

## Trade-offs

- Using shell scripts keeps things lightweight and portable, but may require manual adjustment for DevEco install paths.
- Emulator control is optional; device install/run via `hdc` is primary.

## Acceptance Criteria

1. Running `./dev-start.sh` prints helpful guidance and does not crash on empty `apps/`.
2. Scripts expose consistent flags for selecting apps and mode.
3. `./dev-build.sh --mode prod` produces production build output (once apps exist).
4. Clear errors when required tools (`hvigorw`, `hdc`) are missing.

## Next Step

After this spec is approved, create an implementation plan and then scaffold the script files.
