# ADR-002: App Center Orchestrator

## Status

Accepted

## Context

The workspace needs a user-visible place to discover, launch, install, and manage child apps. A peer-to-peer model would require each app to know too much about every other app and would make desktop visibility and launch UX inconsistent.

## Decision

Use `app-center` as the orchestrator and default desktop-visible entry. Child apps remain independently buildable and normally hidden from the desktop. Cross-app launch relationships are declared in `app.json` and implemented through HarmonyOS launch mechanisms.

## Consequences

- Users get one predictable entry point.
- Child apps can focus on their own domain screens and return path.
- `app-center` owns app matrix and management UX.
- Any change to app inventory or launch relationships must update metadata and center behavior together.
