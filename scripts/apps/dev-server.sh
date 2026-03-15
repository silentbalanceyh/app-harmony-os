#!/usr/bin/env bash
# dev-server.sh - Start dev mode for app(s)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/common.sh"
source "$SCRIPT_DIR/../env/deveco.sh"

main() {
  local root
  root="$(workspace_root)"

  read_app_config "$root"
  source "$root/scripts/config/dev.sh"

  check_deveco_installation false

  local app_dir="$root/apps/$APP_NAME"
  if [[ ! -d "$app_dir" ]]; then
    error "App directory not found: $app_dir"
    exit 1
  fi

  info "Starting dev mode for app: $APP_NAME"
  warn "Dev server orchestration is app/project specific; using build as placeholder."

  local hvigor_cfg="$app_dir/hvigor/hvigor-config.json5"
  if [[ ! -f "$hvigor_cfg" ]]; then
    warn "Missing hvigor config: $hvigor_cfg"
    warn "Skipping build placeholder. Create hvigor config to enable build."
    ok "Dev start completed (placeholder)"
    return 0
  fi

  build_app "$APP_NAME" "dev"
  warn "To run '$APP_NAME', use DevEco Studio or extend scripts/apps/dev-server.sh"

  ok "Dev start completed (placeholder)"
}

main "$@"