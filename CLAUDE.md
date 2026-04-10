# HarmonyOS Multi-App Workspace Handbook

## Project Overview

This repository is a HarmonyOS phone application workspace built around four independent apps that collaborate as a small product suite. The repository root is intentionally not a buildable HarmonyOS project. It exists to host documentation, task material, workspace rules, and shared startup helpers.

All actual build targets live in top-level `app-*` directories.

## Goals

- Keep each HarmonyOS app independently buildable and installable.
- Preserve a clean root directory with no restored legacy project files.
- Make `dev-start.sh` (macOS/Linux) or `dev-start.bat` (Windows) enough for most local development workflows.
- Allow a new session to understand the workspace quickly without reverse engineering the repo layout.

## When To Use App Initialization Flow

Use the dedicated initialization flow in `.cursor/rules/50-app-initialization.mdc` when the task is about creating a new top-level `app-*` project, cloning an existing app as a new app, wiring a new app into `app-center`, or producing the first requirement baseline for a new app via `REQ.md`.

Do not use that flow for normal edits inside an existing app unless the task also changes workspace-level app registration or app inventory.

## Quick Start (macOS / Linux)

```bash
./start-simulator.sh
cd app-center && ./dev-start.sh
hdc shell hilog -x
cd app-center && ./dev-stop.sh
```

## Quick Start (Windows)

```cmd
start-simulator.bat
cd app-center && dev-start.bat
hdc shell hilog -x
cd app-center && dev-stop.bat
```

## Repository Layout

```text
app-harmony-os/
├── app-center/                 # Unified launcher / app center
├── app-monitor/                # Monitoring app
├── app-security/               # Security app
├── app-hello/                  # Sample business app
├── app-medication/             # Medication reminder app for elderly health
├── .cursor/rules/              # MDC rule files for fast machine onboarding
├── .r2mo/                      # Hidden task, requirement, design material
├── .logs/                      # Root-level simulator startup logs
├── AGENTS.md                   # Session routing and workspace guardrails
├── CLAUDE.md                   # Human-readable project handbook
├── README.md                   # Lightweight repository overview
├── docs/                       # Extra notes and generated project material
└── start-simulator.sh          # Shared HarmonyOS simulator bootstrap script
```

## Architecture

### Workspace Architecture

- The workspace is multi-app, not mono-entry.
- Every `app-*` directory owns its own HarmonyOS build files, resources, scripts, and runtime configuration.
- Cross-app relationships are described in each app’s `app.json`.

### App Responsibilities

- `app-center`
  - Main desktop-visible entry.
  - Shows the installed app matrix.
  - Opens other apps.
  - Manages desktop visibility for child apps.
  - Communicates state to the user about open/install/manage flows.

- `app-monitor`
  - Monitoring and runtime status app.
  - Can return to `app-center`.
  - Can launch other peer apps when needed.

- `app-security`
  - Security and risk-control app.
  - Can return to `app-center`.
  - Can launch selected peer apps when needed.

- `app-hello`
  - First sample business app.
  - Used to validate cross-app collaboration and runtime flow.

- `app-medication`
  - Reminder-oriented elderly health app.
  - Focuses on medication schedules, taken-state confirmation, and caregiver escalation.
  - Can return to `app-center`.

### Runtime Interaction Model

- `app-center` is the default desktop entry.
- `app-monitor`, `app-security`, `app-hello`, and `app-medication` are hidden from the desktop by default.
- `app-center -> other app` may show a system confirmation dialog.
  - This dialog is controlled by HarmonyOS.
  - App code cannot restyle, rewrite, or remove it reliably.
- `child app -> app-center` is designed as the lower-friction return path.
- Short local sound effects are used on open/return actions to make the flow feel intentional.

### Current ETS Structure

Each app currently follows this shape:

```text
entry/src/main/ets/
├── entryability/EntryAbility.ets
├── extensions/AppBridgeService.ets
├── pages/Index.ets
└── utils/SoundEffectPlayer.ets
```

## Technical Stack

- Language: ArkTS
- UI: ArkUI declarative syntax
- Build system: hvigor / DevEco Studio
- Platform: HarmonyOS NEXT style phone apps
- SDK baseline currently used in this workspace: HarmonyOS `6.0.2(22)`
- Device bridge: `hdc`
- Local simulator management: DevEco Studio Emulator CLI
- Shell automation: Bash

## Key Configuration Files

### Workspace-Level

- `AGENTS.md`
- `CLAUDE.md`
- `.cursor/rules/*.mdc`
- `.r2mo/task/*.md`
- `start-simulator.sh`

### Per App

- `app-*/app.json`
  - local runtime metadata
  - bundle/module/ability name
  - `dependsOn`
  - `launchTargets`

- `app-*/build-profile.json5`
- `app-*/entry/build-profile.json5`
- `app-*/entry/src/main/module.json5`
- `app-*/scripts/common.sh`

## Per-App Runtime Metadata

Current app relationships are defined in `app.json`:

- `app-center`
  - depends on `app-monitor`, `app-security`, `app-hello`, `app-medication`
  - launch targets `app-monitor`, `app-security`, `app-hello`, `app-medication`

- `app-monitor`
  - depends on `app-center`, `app-security`, `app-hello`, `app-medication`
  - launch target `app-center`

- `app-security`
  - depends on `app-center`, `app-monitor`, `app-hello`, `app-medication`
  - launch target `app-center`

- `app-hello`
  - depends on `app-center`, `app-monitor`, `app-security`, `app-medication`
  - launch target `app-center`

- `app-medication`
  - depends on `app-center`, `app-monitor`, `app-security`, `app-hello`
  - launch target `app-center`

## Task Material Conventions

- Task-driven work usually comes from `.r2mo/task/task-*.md`.
- When a session is asked to execute one of those task files, read the Markdown body after frontmatter first.
- If a task explicitly asks for a `Changes` append, write that record back into the same task file after implementation.

## Build, Start, Stop

### Build One App

```bash
cd app-center && ./dev-build.sh
cd app-monitor && ./dev-build.sh
cd app-security && ./dev-build.sh
cd app-hello && ./dev-build.sh
cd app-medication && ./dev-build.sh
```

### Start One App

```bash
cd app-center && ./dev-start.sh
cd app-monitor && ./dev-start.sh
cd app-security && ./dev-start.sh
cd app-hello && ./dev-start.sh
cd app-medication && ./dev-start.sh
```

### Stop Local hvigor Processes

```bash
cd app-center && ./dev-stop.sh
cd app-monitor && ./dev-stop.sh
cd app-security && ./dev-stop.sh
cd app-hello && ./dev-stop.sh
cd app-medication && ./dev-stop.sh
```

### Release-Oriented Start

```bash
cd app-center && ./run-start.sh
cd app-monitor && ./run-start.sh
cd app-security && ./run-start.sh
cd app-hello && ./run-start.sh
cd app-medication && ./run-start.sh
```

### Stop Notes

- `dev-stop.sh` stops local hvigor-related processes for one app.
- There is no dedicated root-level simulator stop script yet.
- Stop the HarmonyOS simulator from DevEco Device Manager when a full emulator shutdown is needed.

## Shared Script Behavior

All per-app scripts delegate to `scripts/common.sh`.

Important behavior:

- `dev-build.sh`
  - builds current app in debug mode

- `dev-start.sh`
  - ensures simulator/device connectivity
  - builds current app in debug mode
  - checks dependency apps declared in `dependsOn`
  - installs the current app
  - launches the current app

- `run-start.sh`
  - same general flow, but release-oriented

- `dev-stop.sh`
  - stops local hvigor-related development processes

## Simulator and Device Bootstrap

Root `start-simulator.sh` is the common simulator entry point.

### What It Does

- checks whether a HarmonyOS simulator or device is already connected
- if connected, exits successfully
- if not connected, attempts to boot a local DevEco emulator instance
- waits for `hdc` connectivity
- writes simulator startup failures to `.logs/simulator-start.log`

### Important Environment Variables

- `DEVECO_STUDIO_PATH`
  - default: `/Applications/DevEco-Studio.app`

- `AUTO_START_EMULATOR`
  - default: `true`
  - set to `false` to disable automatic simulator startup

- `EMULATOR_NAME`
  - preferred emulator instance name

- `EMULATOR_INSTANCE_PATH`
  - default: `$HOME/.Huawei/Emulator/deployed`

- `EMULATOR_IMAGE_ROOT`
  - default: `$HOME/Library/Huawei/Sdk`

- `EMULATOR_HDC_PORT`
  - optional explicit emulator hdc port

## App Script Environment Variables

The shell layer also uses these behaviors:

- `LAUNCH_DEPENDENCIES`
  - controls whether dependency launch/install behavior is applied

- `device` field in `app.json`
  - if set, `hdc -t <device>` is used
  - if empty, default connected target is used

## Debug Workflow

### Fastest Local Check

```bash
./start-simulator.sh
cd app-center && ./dev-start.sh
```

### Useful Commands

```bash
hdc list targets
hdc shell aa dump --mission-list
hdc shell bm dump -a
hdc shell hilog -x
```

### Typical Runtime Investigation

1. Confirm target connectivity with `hdc list targets`.
2. Start the desired app with `./dev-start.sh`.
3. Reproduce the UI flow on the simulator.
4. Inspect logs with `hdc shell hilog -x`.
5. Inspect mission state with `hdc shell aa dump --mission-list`.
6. If the app crashes, inspect `/data/log/faultlog/faultlogger`.

### Common Log Targets

- app lifecycle logs
- `Open managed app failed`
- `Launch failed`
- `hilog -x`
- fault logs under `/data/log/faultlog/faultlogger`

## Platform Assumptions

This workspace currently assumes:

- macOS host
- DevEco Studio installed locally
- HarmonyOS SDK installed under the DevEco bundle
- `hdc` available from DevEco Studio
- HarmonyOS simulator or real device available

## Current UX Constraints

- System confirmation on `app-center -> child app` is a platform dialog.
- That dialog cannot be reliably restyled or removed from app code.
- App-owned styling should instead focus on:
  - clear launch wording
  - explicit “unified entry” framing
  - return-path consistency
  - sound cues

## Current Development Guidance

- Read `app.json` before editing app launch behavior.
- Read `entry/src/main/module.json5` before editing abilities or extension exports.
- Treat `app-center` as the orchestrator and UX owner.
- Keep other apps runnable in isolation even when they depend on peer apps.
- Do not move HarmonyOS project files back to repository root.

## MDC Integration

Machine-readable rule files belong under:

```text
.cursor/rules/
```

Current rule file:

- `.cursor/rules/00-harmony-workspace.mdc`
- `.cursor/rules/10-workspace-structure.mdc`
- `.cursor/rules/20-launch-and-runtime.mdc`
- `.cursor/rules/30-scripts-and-debug.mdc`
- `.cursor/rules/40-task-workflow-and-docs.mdc`

Any future session should read them after `AGENTS.md` and `CLAUDE.md`, in lexical order.

## Onboarding Checklist For A Fresh Session

1. Read `AGENTS.md`.
2. Read `CLAUDE.md`.
3. Read `.cursor/rules/*.mdc` in lexical order.
4. Identify the target app under `app-*`.
5. Read that app’s `app.json`.
6. Read that app’s `scripts/common.sh`.
7. If the task came from `.r2mo/task/task-*.md`, follow its body after frontmatter and write back `Changes` when requested.
8. Use `./dev-start.sh` before inventing a custom run flow.
9. Use `hdc shell hilog -x` and `aa dump --mission-list` for runtime debugging.

This is the baseline context any new session should have before editing code in this repository.
