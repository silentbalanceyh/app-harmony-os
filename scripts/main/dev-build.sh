#!/usr/bin/env bash
# dev-build.sh (main) - Build apps (dev or prod)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/common.sh"

main() {
  local root
  root="$(workspace_root)"

  read_app_config "$root"

  # Set BUILD_MODE for build-all.sh
  export BUILD_MODE="dev"

  info "Building app: $APP_NAME (mode: dev)..."
  bash "$root/scripts/apps/build-all.sh"
}

main "$@"