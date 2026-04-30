# ADR-003: Shell Script Harness

## Status

Accepted

## Context

Developers and agents need repeatable commands for build, install, launch, simulator preflight, and diagnosis across macOS, Linux, and Windows. Introducing a Node.js or Python harness would add another runtime dependency and another package lifecycle to every app.

## Decision

Use per-app shell and batch scripts as the workspace harness: `dev-build.*`, `dev-start.*`, `dev-stop.*`, `run-start.*`, and `dev-preview.*`. Keep shared logic in each app's `scripts/common.*` and use root `start-simulator.*` for simulator bootstrap.

## Consequences

- The primary workflow stays close to the HarmonyOS command-line tools.
- Agents can use the same commands as human developers.
- Cross-platform behavior must be maintained in both `.sh` and `.bat` variants.
- Harness improvements should be made in script code, not by bypassing scripts with custom command chains.
