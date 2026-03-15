#!/usr/bin/env bash
# run-start.sh - Build and deploy HarmonyOS app to device
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "$SCRIPT_DIR/scripts/main/run-start.sh" "$@"
