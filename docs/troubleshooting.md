# Troubleshooting

Use this guide when the normal app harness commands fail or when an agent needs a repeatable diagnosis path. Prefer the app scripts first, then inspect logs and configuration.

## Environment Issues

### DevEco Studio is not installed

- Symptoms: `dev-start.*` cannot locate emulator tooling or SDK metadata.
- Root cause: DevEco Studio is missing or installed outside the expected platform location.
- Fix: Install DevEco Studio, open Device Manager once, then rerun the app script.
- Verify: `ls "/Applications/DevEco-Studio.app"` on macOS, or confirm DevEco from Windows Start menu.

### HarmonyOS SDK metadata is missing

- Symptoms: harness reports missing `sdk-pkg.json` or cannot resolve SDK version.
- Root cause: SDK packages are not installed or local SDK path is stale.
- Fix: Install the HarmonyOS SDK from DevEco Studio and let `ensure_sdk_environment` resolve it.
- Verify: `cd app-center && ./dev-build.sh`.

### `hdc` is unavailable

- Symptoms: `Required command not found: hdc` or device checks fail immediately.
- Root cause: SDK tools are not on the resolved path.
- Fix: Use `dev-start.*` so the harness sets up the SDK environment; reinstall command-line tools if needed.
- Verify: `hdc list targets`.

### Simulator does not start

- Symptoms: no connected target after `start-simulator.*`.
- Root cause: Device Manager is closed, emulator image is missing, or host virtualization is unavailable.
- Fix: Start a phone simulator manually in DevEco Device Manager and rerun `dev-start.*`.
- Verify: `hdc list targets`.

### Wrong platform script is used

- Symptoms: shell syntax errors on Windows or `.bat` commands fail in Unix shells.
- Root cause: wrong script family for the host OS.
- Fix: Use `.bat` on `MINGW*` / `MSYS*` / `CYGWIN*`; use `.sh` on Darwin/Linux.
- Verify: `uname -s`.

## Build Issues

### Signing configuration is missing

- Symptoms: build succeeds partly but HAP signing or install packaging fails.
- Root cause: signing material is absent or not generated for the app.
- Fix: Open the app in DevEco Studio or restore the expected signing configuration for the local environment.
- Verify: `cd <app> && ./dev-build.sh`.

### SDK version mismatch

- Symptoms: compile errors mention unavailable SDK APIs or unsupported API version.
- Root cause: local SDK does not match the workspace baseline.
- Fix: Install the expected SDK in DevEco Studio and rerun through the harness.
- Verify: `cd app-center && ./dev-build.sh`.

### ArkTS syntax is unsupported

- Symptoms: compile errors around spread syntax, `delete`, `require`, dynamic properties, or decorators.
- Root cause: generated code used TypeScript/JavaScript patterns not accepted by ArkTS.
- Fix: Follow `.cursor/rules/60-arkts-coding-standards.mdc` and rewrite to typed ArkTS patterns.
- Verify: `cd <app> && ./dev-build.sh`.

### Dependencies are not found

- Symptoms: build cannot resolve modules from `oh-package.json5`.
- Root cause: dependencies were not installed or package metadata is inconsistent.
- Fix: Inspect `oh-package.json5`, then run the app harness so dependency setup follows workspace conventions.
- Verify: `cd <app> && ./dev-build.sh`.

### `build-profile.json5` is inconsistent

- Symptoms: hvigor errors mention modules, targets, signing config, or product names.
- Root cause: app-level and module-level build profiles drifted apart.
- Fix: Compare `build-profile.json5` and `entry/build-profile.json5` with a working sibling app.
- Verify: `cd <app> && ./dev-build.sh`.

## Deployment Issues

### Install fails because signatures do not match

- Symptoms: `hdc install` fails after an app was already installed.
- Root cause: existing package on the device was signed with different local material.
- Fix: uninstall the old package or use a consistent signing setup.
- Verify: `hdc shell bm dump -a | rg <bundleName>`.

### Ability fails to start

- Symptoms: install succeeds but launch fails.
- Root cause: `bundleName`, `moduleName`, or `abilityName` in `app.json` does not match `module.json5`.
- Fix: Align `app.json` with `entry/src/main/module.json5`.
- Verify: `hdc shell aa dump --mission-list`.

### Device disconnects during deployment

- Symptoms: install or launch intermittently reports no target.
- Root cause: simulator restart, USB issue, or stale `hdc` connection.
- Fix: reconnect device, restart simulator, then rerun `dev-start.*`.
- Verify: `hdc list targets`.

### Dependency app is not installed

- Symptoms: cross-app launch fails even though the current app starts.
- Root cause: a target listed in `launchTargets` was not installed.
- Fix: make sure `dependsOn` includes required apps and rerun `dev-start.*`.
- Verify: `hdc shell bm dump -a`.

### Desktop entry visibility is wrong

- Symptoms: a child app appears as a home-screen app, or `app-center` is not visible.
- Root cause: `entity.system.home` skill is declared in the wrong app.
- Fix: keep home skill on `app-center` only unless the workspace model changes.
- Verify: inspect `entry/src/main/module.json5`.

## Runtime Issues

### App crashes after launch

- Symptoms: launch succeeds and then the app exits or shows a blank screen.
- Root cause: runtime exception, resource lookup failure, or page initialization error.
- Fix: inspect hilog and fault logs, then trace the failing page or ability.
- Verify: `hdc shell hilog -x`.

### Cross-app launch fails

- Symptoms: tapping an app card does not open the target app.
- Root cause: Want parameters, bundle name, ability name, or installation state is wrong.
- Fix: compare `app.json` with the target `module.json5` and confirm installation.
- Verify: `hdc shell bm dump -a` and `hdc shell aa dump --mission-list`.

### UI renders incorrectly

- Symptoms: layout overlaps, clipped content, missing resources, or unexpected blank areas.
- Root cause: ArkUI constraints, resource mismatch, or state update timing.
- Fix: inspect the page file, resource references, and preview/build output.
- Verify: `cd <app> && ./dev-preview.sh <PageName>` or `cd <app> && ./dev-start.sh`.

### Sound effects do not play

- Symptoms: open/return action has no audible cue.
- Root cause: media resource path, permission, volume, or player lifecycle issue.
- Fix: compare `SoundEffectPlayer.ets` usage with a working sibling app.
- Verify: trigger the action on a simulator/device and inspect `hdc shell hilog -x`.

### Return to app-center is slow or blocked

- Symptoms: child app cannot return cleanly to `app-center`.
- Root cause: app-center is not installed, Want target is wrong, or the platform is showing a system confirmation.
- Fix: install `app-center`, align target metadata, and preserve the low-friction return path.
- Verify: `hdc shell aa dump --mission-list`.

## Agent-Specific Issues

### Generated code uses unsupported ArkTS patterns

- Symptoms: compile errors after AI-generated code changes.
- Root cause: the agent used generic TypeScript instead of ArkTS-safe syntax.
- Fix: rewrite according to `.cursor/rules/60-arkts-coding-standards.mdc`.
- Verify: `cd <app> && ./dev-build.sh`.

### Module import fails

- Symptoms: build cannot resolve a local file or `@ohos` module.
- Root cause: cross-app source import, wrong relative path, or invented API.
- Fix: keep imports inside the app boundary and check local SDK examples or official docs.
- Verify: `rg -n "from '../|from '../../|@ohos" <app>/entry/src/main/ets`.

### Hot reload or preview does not update

- Symptoms: DevEco Previewer shows stale UI.
- Root cause: Previewer cache, unsupported page pattern, or SDK limitation.
- Fix: rerun `dev-preview.*`; if still stale, verify through `dev-build.*` and simulator.
- Verify: `cd <app> && ./dev-preview.sh <PageName>`.

### Agent edits the wrong app

- Symptoms: unrelated sibling app files change during a single-app task.
- Root cause: app boundary rules were skipped.
- Fix: inspect `git diff --name-only`, keep only task-owned files, and avoid reverting other workers' changes.
- Verify: `git status --short`.

### Task Changes write-back is missing

- Symptoms: implementation is done but `.r2mo/task/task-*.md` lacks a `Changes` record.
- Root cause: task workflow was not followed or Team Leader owns final task-file write-back.
- Fix: in solo work, append `Changes`; in Team mode, report files and verification to the Team Leader without editing task files.
- Verify: `rg -n "^## Changes|^- .*Verification" .r2mo/task/task-*.md`.
