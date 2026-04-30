#!/usr/bin/env bash

APP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKSPACE_ROOT="$(cd "$APP_ROOT/.." && pwd)"
APP_CONFIG="$APP_ROOT/app.json"
source "$WORKSPACE_ROOT/scripts/common.sh"
register_app "$APP_ROOT"
