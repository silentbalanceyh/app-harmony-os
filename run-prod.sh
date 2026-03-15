#!/usr/bin/env bash
# run-prod.sh - Build and deploy HarmonyOS apps to device (production)
# Thin wrapper to scripts/main/run-prod.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "$SCRIPT_DIR/scripts/main/run-prod.sh" "$@"