# HarmonyOS Multi-App Development Environment

This workspace is configured for developing multiple HarmonyOS applications.

## Project Structure

```
app-harmony-os/
├── apps/           # Multiple HarmonyOS applications
├── shared/         # Shared modules and utilities
└── tools/          # Build and development tools
```

## Development Guidelines

### HarmonyOS Specifics

- **Language**: ArkTS (TypeScript-based)
- **UI Framework**: ArkUI declarative syntax
- **Build System**: DevEco Studio / hvigor
- **Target**: HarmonyOS NEXT (API 12+)

### Code Organization

- Each app in `apps/` is independent with its own entry point
- Shared code goes in `shared/` (components, utils, services)
- Follow immutable data patterns (see global coding-style.md)
- Keep files small (<800 lines)

### Build & Run

```bash
# Build specific app
hvigorw assembleApp --app-name=<app-name>

# Run on device/emulator
hdc install <app-package>
```

### Testing

- Unit tests: ArkTS test framework
- UI tests: ArkUI test framework
- Target: 80%+ coverage (see global testing.md)

## Multi-App Strategy

When working on multiple apps:
1. Identify shared functionality → extract to `shared/`
2. Keep app-specific logic in respective `apps/<app-name>/`
3. Use consistent naming and structure across apps
4. Share build configurations where possible

## Permissions

All tool permissions are bypassed via `.claude/settings.local.json` for faster development.
