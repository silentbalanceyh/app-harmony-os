#!/usr/bin/env bash

set -euo pipefail

WORKSPACE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$WORKSPACE_ROOT/scripts/common.sh"

apps=()
skip=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --app) apps+=("${2:?missing app name}"); shift 2 ;;
    --skip) skip+=("${2:?missing app name}"); shift 2 ;;
    --force) BUILD_FORCE=true; shift ;;
    -h|--help) echo "Usage: $0 [--app name] [--skip name] [--force]"; exit 0 ;;
    *) error "Unknown argument: $1"; exit 1 ;;
  esac
done

[[ "${#apps[@]}" -gt 0 ]] || mapfile -t apps < <(workspace_app_names)
ensure_simulator_running
for app in "${apps[@]}"; do
  for skipped in "${skip[@]}"; do [[ "$app" == "$skipped" ]] && continue 2; done
  build_named_app "$app" "debug"
  deploy_named_app "$app"
done
launch_bundle "app-center"
