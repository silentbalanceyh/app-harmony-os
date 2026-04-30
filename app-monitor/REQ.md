# app-monitor Requirements Baseline

## App Positioning

`app-monitor` is the monitoring and runtime status app in the HarmonyOS workspace. It focuses on operational visibility and should remain independently buildable while integrating with `app-center`.

## Core Goals

- Present concise runtime or monitoring status.
- Support quick return to `app-center`.
- Validate that a child app can participate in workspace launch flows.
- Leave room for deeper device, app, or service health panels.

## Target Users

- Operators or developers checking workspace runtime status.
- Product teams validating monitoring-oriented child app patterns.
- Agents testing app-center to child-app navigation and return behavior.

## MVP Scope

- Provide a primary monitoring screen.
- Expose `EntryAbility` and `AppBridgeService` consistently with sibling apps.
- Launch back to `app-center`.
- Build and start through the per-app harness scripts.

## Workspace Integration Expectations

- Stay hidden from the desktop by default.
- Depend on `app-center` for primary discovery.
- Use Want or app service extension contracts for cross-app communication.
- Keep source code isolated inside `app-monitor`.
