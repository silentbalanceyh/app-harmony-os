# HarmonyOS Development Scripts

Shell script toolkit for managing multi-app HarmonyOS development workflows.

## Prerequisites

- DevEco Studio installed
- `hvigorw` available (in project root or PATH)
- `hdc` available (HarmonyOS Device Connector)

## Quick Start

```bash
# Start development environment
./dev-start.sh

# Build apps (dev mode)
./dev-build.sh --mode dev

# Build specific app
./dev-build.sh --app myapp --mode prod

# Deploy to device
./run-prod.sh --app myapp --device <device-id>

# Stop development environment
./dev-stop.sh
```

## Script Structure

```
scripts/
├── env/           # Tool discovery (deveco.sh, simulator.sh)
├── apps/          # App operations (build-all.sh, dev-server.sh, deploy.sh)
├── config/        # Environment configs (dev.sh, prod.sh)
├── utils/         # Shared utilities (common.sh)
└── main/          # Entry point implementations
```

## Usage

### Development Mode

```bash
./dev-start.sh [--app <name>] [--device <id>]
```

Starts dev environment with hot reload enabled.

### Production Build & Deploy

```bash
./run-prod.sh [--app <name>] [--device <id>]
```

Builds in release mode and deploys to device.

### Build Only

```bash
./dev-build.sh --mode <dev|prod> [--app <name>]
```

### Multi-App Support

```bash
# Build multiple apps
./dev-build.sh --apps app1,app2,app3 --mode dev

# Deploy multiple apps
./run-prod.sh --apps app1,app2
```

## Configuration

Edit `scripts/config/dev.sh` or `scripts/config/prod.sh` to customize:
- API endpoints
- Build flags
- SDK paths
- Environment variables

## App Discovery

Scripts auto-discover apps under `apps/` that contain:
- `AppScope/` directory, or
- `entry/` directory

## Troubleshooting

**Error: hvigorw not found**
- Ensure DevEco Studio is installed
- Run from project root containing `hvigorw`

**Error: hdc not found**
- Install HarmonyOS SDK
- Add SDK bin directory to PATH

**No apps discovered**
- Add HarmonyOS apps under `apps/<appName>/`
- Ensure app contains `AppScope/` or `entry/`