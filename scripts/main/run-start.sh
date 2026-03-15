#!/usr/bin/env bash
# run-start.sh (main) - Production run/deploy

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/common.sh"
source "$SCRIPT_DIR/../env/deveco.sh"

main() {
  local root
  root="$(workspace_root)"

  read_app_config "$root"
  source "$root/scripts/config/prod.sh"

  info "Deploying app: $APP_NAME to device: ${DEVICE_ID:-default}"
  check_deveco_installation true

  # Build first in prod mode
  bash "$root/scripts/apps/build-all.sh"

  # Then deploy
  bash "$root/scripts/apps/deploy.sh"
}

main "$@"