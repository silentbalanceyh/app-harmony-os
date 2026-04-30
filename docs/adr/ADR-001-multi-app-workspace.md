# ADR-001: Multi-App Workspace

## Status

Accepted

## Context

The workspace contains several HarmonyOS phone experiences that need to be built, installed, and tested independently while still behaving as one product suite. A single project with multiple tightly coupled modules would make app boundaries less visible and would encourage shared build assumptions at the repository root.

## Decision

Keep each top-level `app-*` directory as an independent HarmonyOS application project with its own build files, manifest, resources, scripts, and `app.json`. Keep the repository root as documentation, rules, task material, and shared bootstrap scripts only.

## Consequences

- Each app can be built and launched independently.
- Agents must inspect the target app before editing because there is no single root HarmonyOS build target.
- Shared behavior needs an explicit contract instead of implicit source imports.
- Workspace-level docs and rules are more important because the root is not self-describing as a buildable app.
