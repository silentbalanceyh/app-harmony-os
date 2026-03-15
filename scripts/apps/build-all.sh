#!/usr/bin/env bash
# build-all.sh - Build all or selected apps

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/common.sh"
source "$SCRIPT_DIR/../env/deveco.sh"

main() {
  local root
  root="$(workspace_root)"

  read_app_config "$root"

  check_deveco_installation

  local apps_to_build=()
  if [[ ${#APP_NAMES[@]} -gt 0 ]]; then
    apps_to_build=("${APP_NAMES[@]}")
  else
    local discovered
    discovered="$(discover_apps "$root")"
    if [[ -z "$discovered" ]]; then
      warn "No apps discovered under $root/apps"
      warn "Add apps under apps/<appName>/ with AppScope/ or entry/ directory"
      return 0
    fi
    # shellcheck disable=SC2206
    apps_to_build=($discovered)
  fi

  info "Apps to build: ${apps_to_build[*]}"

  for app in "${apps_to_build[@]}"; do
    build_app "$app" "${BUILD_MODE:-debug}"
  done

  ok "Build completed"
}

main "$@"