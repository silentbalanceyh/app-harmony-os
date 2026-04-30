#!/usr/bin/env bash

set -euo pipefail

WORKSPACE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$WORKSPACE_ROOT/scripts/common.sh"

[[ -d "$DEVECO_STUDIO_PATH" ]] || { error_code "ENV_001" "DevEco Studio not found: $DEVECO_STUDIO_PATH" "Install DevEco Studio or set DEVECO_STUDIO_PATH."; exit 1; }
[[ -f "$DEVECO_SDK_ROOT/sdk-pkg.json" ]] || { error_code "ENV_002" "HarmonyOS SDK not found: $DEVECO_SDK_ROOT" "Install SDK from DevEco SDK Manager."; exit 1; }

if [[ -x "$WORKSPACE_ROOT/setup-deveco-config.sh" ]]; then
  "$WORKSPACE_ROOT/setup-deveco-config.sh"
else
  warn "setup-deveco-config.sh not found or not executable; shared scripts will create SDK shims on demand."
fi

"$WORKSPACE_ROOT/start-simulator.sh"
"$WORKSPACE_ROOT/workspace-build.sh" --force
"$WORKSPACE_ROOT/workspace-start.sh" --app app-center
"$WORKSPACE_ROOT/workspace-status.sh"
