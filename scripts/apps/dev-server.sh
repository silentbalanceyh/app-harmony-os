#!/usr/bin/env bash
# dev-server.sh - Start dev mode for app(s)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/common.sh"
source "$SCRIPT_DIR/../env/deveco.sh"

main() {
  local root
  root="$(workspace_root)"

  parse_args "$@"
  source "$root/scripts/config/dev.sh"

  check_deveco_installation

  local apps_to_run=()
  if [[ ${#APP_NAMES[@]} -gt 0 ]]; then
    apps_to_run=("${APP_NAMES[@]}")
  else
    local discovered
    discovered="$(discover_apps "$root")"
    if [[ -z "$discovered" ]]; then
      warn "No apps discovered under $root/apps"
      warn "Add apps under apps/<appName>/ with AppScope/ or entry/ directory"
      return 0
    fi
    # shellcheck disable=SC2206
    apps_to_run=($discovered)
  fi

  info "Starting dev mode for apps: ${apps_to_run[*]}"
  warn "Dev server orchestration is app/project specific; using build as placeholder."

  for app in "${apps_to_run[@]}"; do
    build_app "$app" "dev"
    warn "To run '$app', use DevEco Studio or extend scripts/apps/dev-server.sh"
  done

  ok "Dev start completed (placeholder)"
}

main "$@"