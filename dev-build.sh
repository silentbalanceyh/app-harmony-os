#!/usr/bin/env bash
# dev-build.sh - Build HarmonyOS apps (dev or prod mode)
# Thin wrapper to scripts/main/dev-build.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "$SCRIPT_DIR/scripts/main/dev-build.sh" "$@"