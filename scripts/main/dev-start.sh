#!/usr/bin/env bash
# dev-start.sh (main) - Start dev environment

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/common.sh"
source "$SCRIPT_DIR/../env/deveco.sh"

main() {
  local root
  root="$(workspace_root)"

  parse_args "$@"
  source "$root/scripts/config/dev.sh"

  info "Starting HarmonyOS development environment..."
  check_deveco_installation

  local discovered
  discovered="$(discover_apps "$root")"

  if [[ -z "$discovered" ]]; then
    warn "No apps found under $root/apps/"
    warn "Add a HarmonyOS app under apps/<appName>/ to get started"
    info "Workspace is ready - add apps and re-run ./dev-start.sh"
    return 0
  fi

  # shellcheck disable=SC2206
  local all_apps=($discovered)
  info "Discovered apps: ${all_apps[*]}"

  bash "$root/scripts/apps/dev-server.sh" "$@"
}

main "$@"