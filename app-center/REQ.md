# app-center Requirements Baseline

## App Positioning

`app-center` is the unified desktop-visible entry for the HarmonyOS multi-app workspace. It presents the app matrix, coordinates installation/start flows, and keeps child app access consistent.

## Core Goals

- Provide one predictable entry point for all workspace apps.
- Show child apps as manageable products instead of isolated demos.
- Start child apps through declared workspace metadata.
- Preserve clear feedback when install, launch, or visibility actions are unavailable.

## Target Users

- Workspace users who need to open monitoring, security, sample, medication, or future child apps.
- Developers validating cross-app launch and management flows.
- Agents using the center as the default runtime verification entry.

## MVP Scope

- List supported child apps.
- Install or launch apps according to `app.json` metadata.
- Keep the center as the only default desktop-visible app.
- Provide a clear return destination for child apps.
- Preserve local sound cues for open/return interactions.

## Workspace Integration Expectations

- Own the main `entity.system.home` entry.
- Read app relationships from `app.json` conventions.
- Avoid direct source imports from child apps.
- Update app inventory when new `app-*` projects are initialized.
