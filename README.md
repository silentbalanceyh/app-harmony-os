# HarmonyOS Multi-App Workspace

This repository is a documentation-first HarmonyOS phone workspace. The repository root is not a buildable HarmonyOS project. All real applications live under top-level `app-*` directories and are built independently.

## Apps

- `app-center`: unified launcher and app center
- `app-monitor`: monitoring app
- `app-security`: security app
- `app-hello`: sample business app
- `app-medication`: medication reminder app focused on elderly health

## Directory Layout

```text
app-harmony-os/
├── app-center/
├── app-monitor/
├── app-security/
├── app-hello/
├── app-medication/
├── .cursor/rules/
├── .r2mo/
├── AGENTS.md
├── CLAUDE.md
├── README.md
└── start-simulator.sh
```

## Rule Files

The machine-readable workspace rules are split by topic under `.cursor/rules/` and should be read in lexical order:

- `00-harmony-workspace.mdc`
- `10-workspace-structure.mdc`
- `20-launch-and-runtime.mdc`
- `30-scripts-and-debug.mdc`
- `40-task-workflow-and-docs.mdc`

## Quick Start

```bash
./start-simulator.sh
cd app-center && ./dev-start.sh
```

## Per-App Scripts

Each app directory provides:

- `dev-build.sh`: build the current app in debug mode
- `dev-start.sh`: check simulator/device state, build, install, and launch the current app
- `dev-stop.sh`: stop local hvigor-related processes
- `run-start.sh`: release-oriented build, install, dependency handling, and launch

Shared shell logic lives in each app’s `scripts/common.sh`.

## Script Behavior

- `app-*/dev-start.sh` and `app-*/run-start.sh` call root `start-simulator.sh` first
- if no HarmonyOS target is connected, the scripts try to boot a local DevEco simulator
- the preferred instance can be set with `EMULATOR_NAME`
- failed simulator bootstrap is logged to `.logs/simulator-start.log`
- automatic simulator startup can be disabled with `AUTO_START_EMULATOR=false`
- dependency installation and peer launch flow are driven by each app’s `app.json`

## Development Notes

- `app-center` is the desktop-visible default entry
- child apps are hidden from the desktop by default
- `app-center -> child app` can trigger a HarmonyOS system confirmation dialog
- `child app -> app-center` is the preferred lower-friction return path
- local sound effects are used for open and return actions

## Task-Driven Workflow

- when work is assigned through `.r2mo/task/task-*.md`, read the Markdown body after frontmatter first
- append a `Changes` record back to the same task file when the task explicitly requires it

## More Context

- Read `AGENTS.md` for session routing rules
- Read `CLAUDE.md` for the full workspace handbook
- Read `.cursor/rules/*.mdc` in lexical order for fast machine-loaded context
