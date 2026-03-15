#!/usr/bin/env bash
# deploy.sh - Install/deploy to device

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/common.sh"
source "$SCRIPT_DIR/../env/deveco.sh"

main() {
  local root
  root="$(workspace_root)"

  read_app_config "$root"
  source "$root/scripts/config/prod.sh"

  check_deveco_installation true

  install_app "$APP_NAME" "$DEVICE_ID"

  ok "Deploy completed"
}

main "$@"