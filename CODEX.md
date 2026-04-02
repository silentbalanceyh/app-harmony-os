# HarmonyOS Workspace Codex Notes

## Purpose

This file is the Codex-oriented quick routing note for the HarmonyOS multi-app workspace.

Use `CLAUDE.md` for the full handbook.
Use `.cursor/rules/*.mdc` for early-load machine guidance.

## When To Use App Initialization Flow

Use `.cursor/rules/50-app-initialization.mdc` when the task is about:

- creating a new top-level `app-*` project
- cloning an existing app into a new app
- scaffolding a new HarmonyOS child app and wiring it into `app-center`
- creating the first `REQ.md` baseline for a newly initialized app

Do not use that flow for ordinary feature work inside an app that already exists unless the task also changes workspace-level registration, app inventory, or the shared initialization convention.

## Default Expectation

- Prefer reusing the nearest existing `app-*` scaffold instead of generating a new HarmonyOS project structure from scratch.
- New apps must ship with all four launch scripts:
  - `dev-build.sh`
  - `dev-start.sh`
  - `dev-stop.sh`
  - `run-start.sh`
- Initialization is only complete after build validation is attempted for both the new app and `app-center`.
