# app-security Requirements Baseline

## App Positioning

`app-security` is the security and risk-control app in the HarmonyOS workspace. It represents security-oriented workflows while following the same child-app integration model as other apps.

## Core Goals

- Present clear security status or risk-control actions.
- Keep security workflows separate from the launcher UX owned by `app-center`.
- Support return to `app-center`.
- Provide a baseline for future permission, audit, and policy features.

## Target Users

- Users or operators reviewing security status.
- Developers validating security app integration patterns.
- Agents checking permission-sensitive UI and launch behavior.

## MVP Scope

- Provide a primary security screen.
- Build, install, and launch independently.
- Return to `app-center`.
- Avoid hard-coded secrets or bypasses of HarmonyOS permission behavior.

## Workspace Integration Expectations

- Stay hidden from the desktop by default.
- Use `app.json` for dependency and launch metadata.
- Communicate with other apps only through approved HarmonyOS runtime mechanisms.
- Keep security-sensitive code outside generic UI components where possible.
