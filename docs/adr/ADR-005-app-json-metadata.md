# ADR-005: app.json Metadata

## Status

Accepted

## Context

Workspace automation needs app identity, target device selection, bundle/module/ability names, dependency lists, and launch targets. Extending HarmonyOS build files for workspace-only metadata would mix runtime orchestration concerns into build configuration.

## Decision

Use each app's root-level `app.json` as the workspace metadata source for harness scripts and app relationship discovery. Keep HarmonyOS build and manifest files focused on platform configuration.

## Consequences

- Script logic can read a small stable metadata file before invoking platform tools.
- App relationships are easier for agents and humans to inspect.
- `app.json` must be kept in sync with module manifests and center launch UX.
- Schema changes need documentation in `docs/app-json-schema.md`.
