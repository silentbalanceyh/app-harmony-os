#!/usr/bin/env bash
# deploy.sh - Install/deploy to device

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/common.sh"
source "$SCRIPT_DIR/../env/deveco.sh"

main() {
  local root
  root="$(workspace_root)"

  parse_args "$@"
  source "$root/scripts/config/prod.sh"

  check_deveco_installation

  if [[ ${#APP_NAMES[@]} -eq 0 ]]; then
    error "Please specify --app <name> or --apps <a,b,c> for deploy"
    exit 1
  fi

  for app in "${APP_NAMES[@]}"; do
    install_app "$app" "$DEVICE_ID"
  done

  ok "Deploy completed"
}

main "$@"