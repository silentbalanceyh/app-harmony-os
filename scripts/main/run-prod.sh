#!/usr/bin/env bash
# run-prod.sh (main) - Production run/deploy

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/common.sh"
source "$SCRIPT_DIR/../env/deveco.sh"

main() {
  local root
  root="$(workspace_root)"

  parse_args "$@"
  source "$root/scripts/config/prod.sh"

  info "Starting production deploy..."
  check_deveco_installation

  # Build first in prod mode
  bash "$root/scripts/apps/build-all.sh" --mode prod "${APP_NAME:+--app $APP_NAME}"

  # Then deploy
  bash "$root/scripts/apps/deploy.sh" "$@"
}

main "$@"