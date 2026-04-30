#!/usr/bin/env bash

set -euo pipefail

WORKSPACE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$WORKSPACE_ROOT/scripts/common.sh"

usage() {
  cat <<'EOF'
Usage: scripts/clean-build.sh [--app app-name] [--all] [--deep]

Default from an app directory cleans that app build directory.
--all   clean every app build directory
--deep  also clean .hvigor, .deveco-sdk-shim, and workspace .hvigor-cache
EOF
}

apps=()
deep=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --app) apps+=("${2:?missing app name}"); shift 2 ;;
    --all) mapfile -t apps < <(workspace_app_names); shift ;;
    --deep) deep=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) error "Unknown argument: $1"; usage; exit 1 ;;
  esac
done

if [[ "${#apps[@]}" -eq 0 ]]; then
  if [[ "${PWD#$WORKSPACE_ROOT/app-}" != "$PWD" && -f "$PWD/app.json" ]]; then
    apps=("$(basename "$PWD")")
  else
    mapfile -t apps < <(workspace_app_names)
  fi
fi

for app in "${apps[@]}"; do
  root="$(peer_app_root "$app")"
  [[ -d "$root" ]] || { warn "Skipping unknown app: $app"; continue; }
  rm -rf "$root/build" "$root/entry/build"
  ok "Cleaned build outputs for $app"
  if [[ "$deep" == "true" ]]; then
    rm -rf "$root/.hvigor" "$root/.deveco-sdk-shim"
    ok "Deep-cleaned local caches for $app"
  fi
done

if [[ "$deep" == "true" ]]; then
  rm -rf "$HVIGOR_CACHE_DIR"
  ok "Removed workspace hvigor cache: $HVIGOR_CACHE_DIR"
fi
