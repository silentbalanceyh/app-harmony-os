# app-hello Requirements Baseline

## App Positioning

`app-hello` is the sample business app for validating the workspace's app lifecycle, launch, return, and harness conventions with minimal domain complexity.

## Core Goals

- Provide a lightweight app that proves the workspace integration path.
- Stay easy to inspect for new agents and developers.
- Demonstrate child-app return behavior.
- Avoid adding product-specific complexity that belongs in domain apps.

## Target Users

- Developers onboarding to the HarmonyOS workspace.
- Agents needing a simple child app for verification.
- Product teams validating baseline cross-app behavior.

## MVP Scope

- Show a simple primary screen.
- Build and start independently.
- Launch back to `app-center`.
- Follow the same file structure and script conventions as sibling apps.

## Workspace Integration Expectations

- Stay hidden from the desktop by default.
- Use `app-center` as the discovery and launch entry.
- Keep source isolated inside `app-hello`.
- Serve as a conservative reference for new simple child apps.
