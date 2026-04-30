# Project Memory

## Workspace Facts

- This repository is a HarmonyOS multi-app phone workspace, not a root-level HarmonyOS app.
- Buildable applications live under top-level `app-*` directories.
- Current apps include `app-center`, `app-monitor`, `app-security`, `app-hello`, `app-medication`, and `app-album`.
- `app-center` is the default desktop-visible launcher and manages child app launch flows.
- Child apps are hidden from desktop by default unless a task explicitly changes the workspace model.

## Technical Stack

- Language/UI: ArkTS / ETS with ArkUI declarative syntax.
- Platform: HarmonyOS NEXT style phone apps.
- Build tooling: hvigor through DevEco Studio project files and per-app harness scripts.
- Device/runtime tooling: `hdc`, DevEco Studio Emulator CLI, and workspace simulator bootstrap scripts.

## Development Commands

- macOS/Linux build default app: `cd app-center && ./dev-build.sh`.
- macOS/Linux start default app: `cd app-center && ./dev-start.sh`.
- macOS/Linux stop hvigor processes: `cd app-center && ./dev-stop.sh`.
- Windows build default app: `cd app-center && dev-build.bat`.
- Windows start default app: `cd app-center && dev-start.bat`.
- Device list: `hdc list targets`.

## Guardrails

- Do not create HarmonyOS build files at the repository root.
- Prefer existing per-app harness scripts over direct `hvigorw`, `hdc install`, or `aa start` command chains.
- Use each app's `app.json` as the source of truth for `dependsOn` and `launchTargets`.
