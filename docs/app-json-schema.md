# app.json Schema

`app.json` is the workspace metadata file at the root of each `app-*` project. It is not a HarmonyOS platform manifest. Harness scripts and app orchestration docs use it to identify apps, dependencies, and launch targets.

## Schema

```json
{
  "app": "app-center",
  "device": "",
  "bundleName": "com.zerows.appcenter",
  "moduleName": "entry",
  "abilityName": "EntryAbility",
  "dependsOn": [],
  "launchTargets": []
}
```

## Fields

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `app` | string | yes | App directory name, for example `app-center`. Must match the top-level directory. |
| `device` | string | yes | Target HarmonyOS device ID. Empty string means use the default connected target. |
| `bundleName` | string | yes | HarmonyOS bundle name used for install, launch, and package lookup. |
| `moduleName` | string | yes | Main module name, usually `entry`. |
| `abilityName` | string | yes | Main ability name, usually `EntryAbility`. |
| `dependsOn` | string[] | yes | Other `app-*` directories that should be installed or considered before this app runs. |
| `launchTargets` | string[] | yes | Other `app-*` directories this app is allowed to launch through workspace flows. |

## Rules

- Keep `app`, `bundleName`, `moduleName`, and `abilityName` aligned with `entry/src/main/module.json5` and app resource identity.
- Use app directory names in `dependsOn` and `launchTargets`, not bundle names.
- Keep arrays present even when empty.
- Do not store secrets, signing passwords, or user-specific SDK paths in `app.json`.
- When adding a new app, update `app-center` metadata and UI wiring through the app initialization flow.

## Example: Child App

```json
{
  "app": "app-monitor",
  "device": "",
  "bundleName": "com.zerows.appmonitor",
  "moduleName": "entry",
  "abilityName": "EntryAbility",
  "dependsOn": [
    "app-center",
    "app-security",
    "app-hello",
    "app-medication"
  ],
  "launchTargets": [
    "app-center"
  ]
}
```
