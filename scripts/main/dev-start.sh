#!/usr/bin/env bash
# dev-start.sh (main) - Start dev environment

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/common.sh"
source "$SCRIPT_DIR/../env/deveco.sh"

main() {
  local root
  root="$(workspace_root)"

  read_app_config "$root"
  source "$root/scripts/config/dev.sh"

  info "Starting HarmonyOS development environment..."
  info "Current app: $APP_NAME"
  check_deveco_installation false

  local app_dir="$root/apps/$APP_NAME"
  if [[ ! -d "$app_dir" ]]; then
    error "App directory not found: $app_dir"
    error "Check app.json or create the app under apps/$APP_NAME/"
    exit 1
  fi

  bash "$root/scripts/apps/dev-server.sh"
}

main "$@"