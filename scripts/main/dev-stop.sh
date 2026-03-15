#!/usr/bin/env bash
# dev-stop.sh (main) - Stop dev environment

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/common.sh"

main() {
  info "Stopping HarmonyOS development environment..."

  # Kill any running hvigor processes
  if pgrep -f "hvigor" &>/dev/null; then
    info "Stopping hvigor processes..."
    pkill -f "hvigor" && ok "hvigor stopped" || warn "Failed to stop hvigor"
  else
    info "No hvigor processes running"
  fi

  ok "Dev environment stopped"
}

main "$@"