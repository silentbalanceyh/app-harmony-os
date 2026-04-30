# ADR-004: Shared ETS Modules

## Status

Accepted for current stage

## Context

Some runtime helpers and patterns may be useful across apps. Packaging those helpers as a HAR can make boundaries clean, but it also introduces package publishing, dependency versioning, and build configuration overhead before the shared surface has stabilized.

## Decision

For the current stage, prefer explicit local app ownership and controlled shared-file approaches when needed instead of introducing a HAR package. Do not create hidden cross-app source imports. Revisit HAR packaging when shared APIs become stable and worth versioning.

## Consequences

- The workspace avoids premature package infrastructure.
- Shared logic must stay visible and intentional.
- Agents must not import one app's source tree from another app.
- Future migration to HAR remains possible once the shared contracts settle.
