#!/usr/bin/env bash

set -euo pipefail

APP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKSPACE_ROOT="$(cd "$APP_ROOT/.." && pwd)"
WORKSPACE_COMMON="$WORKSPACE_ROOT/scripts/common.sh"

if [[ ! -f "$WORKSPACE_COMMON" ]]; then
  echo "[ERROR] Workspace common script not found: $WORKSPACE_COMMON" >&2
  exit 1
fi

export APP_ROOT
export WORKSPACE_ROOT
source "$WORKSPACE_COMMON"
register_app "$APP_ROOT"
