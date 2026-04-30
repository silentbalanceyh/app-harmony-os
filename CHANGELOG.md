# Changelog

All notable workspace-level changes are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/), and this workspace uses descriptive internal milestones instead of public semantic versions.

## [Unreleased]

### Added

- Added expanded agent rule files for ArkTS coding standards, module boundaries, harness usage, and code generation guardrails.
- Added ADRs for workspace architecture, app-center orchestration, shell harness usage, shared ETS module strategy, and `app.json` metadata.
- Added troubleshooting and `app.json` schema documentation.
- Added missing app requirement baselines for `app-center`, `app-monitor`, `app-security`, and `app-hello`.

### Changed

- Expanded early-load documentation references for rule files and troubleshooting guidance.

## [Workspace Rebuild Baseline] - 2026-03

### Added

- Rebuilt the HarmonyOS multi-app workspace without committed secrets.
- Established `app-center` as the unified entry point.
- Added child apps including monitoring, security, hello, medication, and album-oriented work.
- Added per-app script harness files for build, start, stop, run-start, and preview flows.
- Added DevEco previewer setup and HarmonyOS run configuration support.

### Changed

- Moved buildable HarmonyOS project ownership into top-level `app-*` directories.
- Kept the repository root focused on documentation, task material, rules, and shared bootstrap scripts.
