#!/usr/bin/env bash
# dev-start.sh - Start HarmonyOS development environment
# Thin wrapper to scripts/main/dev-start.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "$SCRIPT_DIR/scripts/main/dev-start.sh" "$@"