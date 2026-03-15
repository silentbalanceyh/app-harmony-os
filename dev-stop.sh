#!/usr/bin/env bash
# dev-stop.sh - Stop HarmonyOS development environment
# Thin wrapper to scripts/main/dev-stop.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "$SCRIPT_DIR/scripts/main/dev-stop.sh" "$@"