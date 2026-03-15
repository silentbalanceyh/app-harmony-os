#!/usr/bin/env bash
# dev-build.sh (main) - Build apps (dev or prod)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/common.sh"

main() {
  local root
  root="$(workspace_root)"

  parse_args "$@"

  info "Starting build (mode: $BUILD_MODE)..."
  bash "$root/scripts/apps/build-all.sh" "$@"
}

main "$@"