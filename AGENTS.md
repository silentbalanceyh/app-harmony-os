# HarmonyOS Workspace Agent Guide

This repository is a multi-app HarmonyOS phone workspace. The root directory is a documentation and rule entry only. All buildable application projects live under top-level `app-*` directories.

## Session Startup Order

For any new session in this repository, load context in this order:

1. Read `AGENTS.md`.
2. Read `CLAUDE.md`.
3. Read `.cursor/rules/*.mdc` in lexical order.
4. If the user references `.r2mo/task/*.md`, read the task body after frontmatter before changing code.
5. Inspect the target `app-*` directory before editing code.
6. Read the local `app.json`, `build-profile.json5`, `entry/src/main/module.json5`, and launch scripts for the app being changed.

## Root Policy

- Do not recreate HarmonyOS build files at repository root.
- Keep root limited to documentation, rules, hidden task material, and shared helper scripts such as `start-simulator.sh` (and `start-simulator.bat`).
- Every real app must remain isolated inside its own `app-*` directory.

## App Policy

- Each `app-*` directory is an independent HarmonyOS application project.
- Each app must keep its own `AppScope/`, `entry/`, `build-profile.json5`, `oh-package.json5`, `hvigorfile.ts`, and `app.json`.
- Each app must provide `dev-build.sh`, `dev-start.sh`, `dev-stop.sh`, and `run-start.sh` (plus matching `.bat` variants for Windows).
- Shared shell logic should stay inside each app’s `scripts/common.sh` (and `scripts/common.bat` for Windows).

## Current Apps

- `app-center`: desktop-visible unified entry and app distribution center.
- `app-monitor`: monitoring app.
- `app-security`: security app.
- `app-hello`: sample business app.
- `app-medication`: medication reminder app centered on elderly health.

## Runtime Rules

- `app-center` is the default desktop entry.
- Other apps are hidden from desktop by default and are managed through the center.
- Opening another app from `app-center` may trigger a system confirmation dialog. This is a platform behavior, not an app-owned dialog.
- Returning from child apps to `app-center` should remain a low-friction path.
- Current UX includes short local sound effects for open/return actions.

## Platform Detection

- This workspace runs on both macOS and Windows.
- Detect platform via `uname -s`:
  - `MINGW*` / `MSYS*` / `CYGWIN*` → Windows, use `.bat` scripts
  - `Darwin` / `Linux` → Unix, use `.sh` scripts
- On Windows, prefer `dev-start.bat` as the primary entry.
- On macOS/Linux, prefer `dev-start.sh` as the primary entry.
- Both `.sh` and `.bat` script sets exist for every app and at workspace root.

## Script Rules

- `dev-start.sh` (or `dev-start.bat` on Windows) must be treated as the primary entry for local development.
- `dev-start.*` and `run-start.*` must check simulator/device connectivity first.
- If no HarmonyOS target is connected, scripts should attempt root `start-simulator.sh` (or `start-simulator.bat`).
- Dependency installation is controlled by per-app `app.json` via `dependsOn`.
- Launch fan-out is controlled by per-app `app.json` via `launchTargets`.

## Documentation Rule

When project behavior changes in a way that affects onboarding, scripts, architecture, runtime UX, or development flow, update:

- `CLAUDE.md`
- `AGENTS.md`
- `.cursor/rules/*.mdc` when the change should be machine-loaded early in future sessions

## Preferred Debug Entry Points

### macOS / Linux

- Build: `cd app-center && ./dev-build.sh`
- Start: `cd app-center && ./dev-start.sh`
- Stop hvigor processes: `cd app-center && ./dev-stop.sh`
- Simulator bootstrap: `./start-simulator.sh`

### Windows

- Build: `cd app-center && dev-build.bat`
- Start: `cd app-center && dev-start.bat`
- Stop hvigor processes: `cd app-center && dev-stop.bat`
- Simulator bootstrap: `start-simulator.bat`

### Cross-Platform

- Device list: `hdc list targets`
- Ability state: `hdc shell aa dump --mission-list`
- System logs: `hdc shell hilog -x`

## Current Rule Extension

This repository ships split onboarding MDC files:

- `.cursor/rules/00-harmony-workspace.mdc`
- `.cursor/rules/10-workspace-structure.mdc`
- `.cursor/rules/20-launch-and-runtime.mdc`
- `.cursor/rules/30-scripts-and-debug.mdc`
- `.cursor/rules/40-task-workflow-and-docs.mdc`
- `.cursor/rules/50-app-initialization.mdc`

Read them in lexical order after `CLAUDE.md`.
