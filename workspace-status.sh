#!/usr/bin/env bash

set -euo pipefail

WORKSPACE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$WORKSPACE_ROOT/scripts/common.sh"

echo "Workspace: $WORKSPACE_ROOT"
echo "DevEco: $DEVECO_STUDIO_PATH"
if [[ -f "$DEVECO_SDK_ROOT/sdk-pkg.json" ]]; then
  echo "SDK: $DEVECO_SDK_ROOT ($(read_sdk_version_path "$DEVECO_SDK_ROOT" 2>/dev/null || echo unknown))"
else
  echo "[ENV_002] SDK metadata missing | Install SDK in DevEco SDK Manager."
fi

if require_cmd hdc >/dev/null 2>&1; then
  echo "Connected targets:"
  targets="$(list_connected_targets || true)"
  if [[ -n "${targets//[[:space:]]/}" ]]; then
    printf '%s\n' "$targets" | sed 's/^/  - /'
  else
    echo "  - none"
  fi
else
  echo "[ENV_001] hdc unavailable | Install DevEco Studio or add hdc to PATH."
fi

echo "Apps:"
for app in $(workspace_app_names); do
  root="$(peer_app_root "$app")"
  hap="$(find_hap_for_app "$app")"
  info_file="$root/build/outputs/default/build-info.json"
  bundle="$(peer_bundle_name "$app")"
  if [[ -n "$hap" ]]; then
    build_state="built ($(basename "$hap"))"
  else
    build_state="not built"
  fi
  duration=""
  if [[ -f "$info_file" ]]; then
    duration="$(python3 - "$info_file" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as f:
    data = json.load(f)
print(data.get("buildDurationSeconds", ""))
PY
)"
  fi
  installed="unknown"
  if [[ -n "$bundle" ]] && require_cmd hdc >/dev/null 2>&1 && check_bundle_installed "$bundle"; then
    installed="installed"
  elif require_cmd hdc >/dev/null 2>&1; then
    installed="not installed"
  fi
  printf '  - %s: %s, %s' "$app" "$build_state" "$installed"
  [[ -n "$duration" ]] && printf ', last duration: %ss' "$duration"
  printf '\n'
done
