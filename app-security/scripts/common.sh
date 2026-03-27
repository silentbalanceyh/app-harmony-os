#!/usr/bin/env bash

set -euo pipefail

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

APP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="$(basename "$APP_ROOT")"
APP_CONFIG="$APP_ROOT/app.json"
WORKSPACE_ROOT="$(cd "$APP_ROOT/.." && pwd)"
SIMULATOR_SCRIPT="$WORKSPACE_ROOT/start-simulator.sh"
DEVECO_STUDIO_PATH="${DEVECO_STUDIO_PATH:-/Applications/DevEco-Studio.app}"
DEVECO_HVIGORW="$DEVECO_STUDIO_PATH/Contents/tools/hvigor/bin/hvigorw"
DEVECO_HDC="$DEVECO_STUDIO_PATH/Contents/sdk/default/openharmony/toolchains/hdc"
DEVECO_SDK_ROOT="$DEVECO_STUDIO_PATH/Contents/sdk/default"

info()  { echo -e "${CYAN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }

read_config_string() {
  local file="$1"
  local key="$2"

  python3 - "$file" "$key" <<'PY'
import json
import sys

path, key = sys.argv[1], sys.argv[2]
try:
    with open(path, encoding='utf-8') as f:
        data = json.load(f)
except FileNotFoundError:
    print("")
    raise SystemExit(0)

value = data.get(key, "")
print(value if isinstance(value, str) else "")
PY
}

read_sdk_version_path() {
  local sdk_pkg_json="$1/sdk-pkg.json"

  python3 - "$sdk_pkg_json" <<'PY'
import json
import sys

path = sys.argv[1]
with open(path, encoding='utf-8') as f:
    data = json.load(f)
print(data.get("data", {}).get("path", ""))
PY
}

ensure_sdk_environment() {
  local sdk_root="$DEVECO_SDK_ROOT"
  local version_path
  local shim_root

  if [[ -n "${DEVECO_SDK_HOME:-}" && -n "${OHOS_BASE_SDK_HOME:-}" ]]; then
    return 0
  fi

  if [[ ! -f "$sdk_root/sdk-pkg.json" ]]; then
    error "DevEco SDK metadata not found: $sdk_root/sdk-pkg.json"
    return 1
  fi

  version_path="$(read_sdk_version_path "$sdk_root")"
  if [[ -z "$version_path" ]]; then
    error "Unable to resolve HarmonyOS SDK version path from $sdk_root/sdk-pkg.json"
    return 1
  fi

  shim_root="$APP_ROOT/.deveco-sdk-shim"
  mkdir -p "$shim_root"
  cp "$sdk_root/sdk-pkg.json" "$shim_root/sdk-pkg.json"
  ln -sfn "$sdk_root" "$shim_root/$version_path"

  export DEVECO_SDK_HOME="${DEVECO_SDK_HOME:-$shim_root}"
  export OHOS_BASE_SDK_HOME="${OHOS_BASE_SDK_HOME:-$shim_root/$version_path/openharmony}"
}

read_config_array() {
  local file="$1"
  local key="$2"

  python3 - "$file" "$key" <<'PY'
import json
import sys

path, key = sys.argv[1], sys.argv[2]
try:
    with open(path, encoding='utf-8') as f:
        data = json.load(f)
except FileNotFoundError:
    raise SystemExit(0)

for item in data.get(key, []):
    if isinstance(item, str):
        print(item)
PY
}

read_device_id() {
  read_config_string "$APP_CONFIG" "device"
}

app_bundle_name() {
  read_config_string "$APP_CONFIG" "bundleName"
}

app_module_name() {
  read_config_string "$APP_CONFIG" "moduleName"
}

app_ability_name() {
  read_config_string "$APP_CONFIG" "abilityName"
}

read_app_dependencies() {
  read_config_array "$APP_CONFIG" "dependsOn"
}

read_launch_targets() {
  read_config_array "$APP_CONFIG" "launchTargets"
}

peer_app_config() {
  local app_name="$1"
  echo "$WORKSPACE_ROOT/$app_name/app.json"
}

peer_app_root() {
  local app_name="$1"
  echo "$WORKSPACE_ROOT/$app_name"
}

peer_bundle_name() {
  read_config_string "$(peer_app_config "$1")" "bundleName"
}

peer_ability_name() {
  read_config_string "$(peer_app_config "$1")" "abilityName"
}

get_hvigor_cmd_for_root() {
  local target_root="$1"

  if [[ -x "$target_root/hvigorw" ]]; then
    echo "$target_root/hvigorw"
    return 0
  fi

  if command -v hvigorw >/dev/null 2>&1; then
    command -v hvigorw
    return 0
  fi

  if [[ -x "$DEVECO_HVIGORW" ]]; then
    echo "$DEVECO_HVIGORW"
    return 0
  fi

  error "hvigorw not found in $target_root or PATH"
  return 1
}

require_cmd() {
  local cmd="$1"
  resolve_cmd "$cmd" >/dev/null
}

resolve_cmd() {
  local cmd="$1"

  if command -v "$cmd" >/dev/null 2>&1; then
    command -v "$cmd"
    return 0
  fi

  case "$cmd" in
    hdc)
      if [[ -x "$DEVECO_HDC" ]]; then
        echo "$DEVECO_HDC"
        return 0
      fi
      ;;
    hvigorw)
      if [[ -x "$DEVECO_HVIGORW" ]]; then
        echo "$DEVECO_HVIGORW"
        return 0
      fi
      ;;
  esac

  error "Required command not found: $cmd"
  return 1
}

run_hdc() {
  local device_id
  local hdc_cmd
  device_id="$(read_device_id)"
  hdc_cmd="$(resolve_cmd hdc)"

  if [[ -n "$device_id" ]]; then
    "$hdc_cmd" -t "$device_id" "$@"
  else
    "$hdc_cmd" "$@"
  fi
}

hdc_output_is_failure() {
  local output="$1"

  [[ "$output" == *"[Fail]"* ]]
}

normalize_hdc_output() {
  tr -d '\r'
}

run_hdc_checked() {
  local output

  output="$(run_hdc "$@" 2>&1 | normalize_hdc_output || true)"
  if [[ -n "$output" ]]; then
    printf '%s\n' "$output" >&2
  fi

  if hdc_output_is_failure "$output"; then
    return 1
  fi

  return 0
}

list_connected_targets() {
  local hdc_cmd
  local raw_targets

  hdc_cmd="$(resolve_cmd hdc)"
  raw_targets="$("$hdc_cmd" list targets 2>/dev/null | normalize_hdc_output || true)"

  if hdc_output_is_failure "$raw_targets"; then
    return 0
  fi

  printf '%s\n' "$raw_targets" | awk 'NF && $0 != "[Empty]"'
}

ensure_simulator_running() {
  if [[ ! -x "$SIMULATOR_SCRIPT" ]]; then
    error "Simulator script not found: $SIMULATOR_SCRIPT"
    return 1
  fi

  bash "$SIMULATOR_SCRIPT"
}

check_device_connection() {
  require_cmd hdc || return 1

  local device_id
  local targets
  device_id="$(read_device_id)"
  targets="$(list_connected_targets)"

  if [[ -z "${targets//[[:space:]]/}" ]]; then
    error "No HarmonyOS emulator/device connected"
    error "Start a simulator in DevEco Device Manager or connect hardware, then rerun the script."
    return 1
  fi

  if [[ -n "$device_id" ]] && ! grep -Fq "$device_id" <<<"$targets"; then
    error "Configured device '$device_id' is not connected"
    return 1
  fi

  ok "Device connection check passed"
}

build_current_app() {
  local mode="$1"
  build_named_app "$APP_NAME" "$mode"
}

build_named_app() {
  local app_name="$1"
  local mode="$2"
  local target_root
  local hvigor_cmd

  target_root="$(peer_app_root "$app_name")"
  hvigor_cmd="$(get_hvigor_cmd_for_root "$target_root")"
  ensure_sdk_environment || return 1
  info "Building $app_name in $mode mode"
  (
    cd "$target_root"
    case "$mode" in
      debug|dev)
        "$hvigor_cmd" assembleApp -p product=default -p buildMode=debug
        ;;
      release|prod)
        "$hvigor_cmd" assembleApp -p product=default -p buildMode=release
        ;;
      *)
        error "Unsupported build mode: $mode"
        return 1
        ;;
    esac
  )
}

find_hap() {
  find_hap_for_app "$APP_NAME"
}

find_hap_for_app() {
  local app_name="$1"
  local target_root

  target_root="$(peer_app_root "$app_name")"
  find "$target_root" -type f -name "*.hap" | sort | tail -1
}

deploy_current_app() {
  deploy_named_app "$APP_NAME"
}

deploy_named_app() {
  local app_name="$1"
  local hap_file

  hap_file="$(find_hap_for_app "$app_name")"
  if [[ -z "$hap_file" ]]; then
    error "No HAP package found for $app_name. Build the app first."
    return 1
  fi

  require_cmd hdc || return 1
  check_device_connection || return 1

  info "Installing $hap_file"
  run_hdc_checked install "$hap_file" || {
    error "Install failed for $app_name"
    return 1
  }
  ok "$app_name installed successfully"
}

check_bundle_installed() {
  local bundle_name="$1"
  local installed_bundles

  if ! require_cmd hdc >/dev/null 2>&1; then
    return 1
  fi

  installed_bundles="$(run_hdc shell bm dump -a 2>&1 | normalize_hdc_output || true)"
  if hdc_output_is_failure "$installed_bundles"; then
    return 1
  fi

  grep -Fqx "$bundle_name" <<<"$(printf '%s\n' "$installed_bundles" | sed 's/^[[:space:]]*//')"
}

launch_bundle() {
  local app_name="$1"
  local bundle_name
  local ability_name

  bundle_name="$(peer_bundle_name "$app_name")"
  ability_name="$(peer_ability_name "$app_name")"

  if [[ -z "$bundle_name" || -z "$ability_name" ]]; then
    warn "Skipping launch for $app_name: missing app metadata"
    return 0
  fi

  if ! check_bundle_installed "$bundle_name"; then
    warn "Skipping launch for $app_name: bundle $bundle_name is not installed on device"
    return 0
  fi

  info "Launching $app_name"
  run_hdc_checked shell aa start -a "$ability_name" -b "$bundle_name" || {
    error "Launch failed for $app_name"
    return 1
  }
}

launch_current_app() {
  launch_bundle "$APP_NAME"
}

check_dependencies() {
  local dependency
  local bundle_name

  while IFS= read -r dependency; do
    [[ -n "$dependency" ]] || continue
    bundle_name="$(peer_bundle_name "$dependency")"
    if [[ -z "$bundle_name" ]]; then
      warn "Dependency $dependency has no bundle metadata"
      continue
    fi

    if check_bundle_installed "$bundle_name"; then
      ok "Dependency ready: $dependency ($bundle_name)"
    else
      warn "Dependency missing on device: $dependency ($bundle_name)"
    fi
  done < <(read_app_dependencies)
}

ensure_dependency_ready() {
  local dependency="$1"
  local bundle_name

  bundle_name="$(peer_bundle_name "$dependency")"
  if [[ -z "$bundle_name" ]]; then
    warn "Dependency $dependency has no bundle metadata"
    return 0
  fi

  if check_bundle_installed "$bundle_name"; then
    ok "Dependency ready: $dependency ($bundle_name)"
    return 0
  fi

  warn "Dependency missing on device: $dependency ($bundle_name)"
  build_named_app "$dependency" "debug"
  deploy_named_app "$dependency"
}

ensure_dependencies_ready() {
  local dependency

  while IFS= read -r dependency; do
    [[ -n "$dependency" ]] || continue
    ensure_dependency_ready "$dependency"
  done < <(read_app_dependencies)
}

launch_targets_if_needed() {
  local auto_launch="${LAUNCH_DEPENDENCIES:-}"
  local target

  if [[ -z "$auto_launch" ]]; then
    auto_launch="false"
    if [[ "$APP_NAME" == "app-center" ]]; then
      auto_launch="true"
    fi
  fi

  if [[ "$auto_launch" != "true" ]]; then
    return 0
  fi

  while IFS= read -r target; do
    [[ -n "$target" ]] || continue
    launch_bundle "$target"
  done < <(read_launch_targets)
}

preflight_for_launch() {
  require_cmd hdc || return 1
  check_device_connection || return 1
  ensure_dependencies_ready
  check_dependencies
}

start_dev() {
  ensure_simulator_running || return 1
  build_current_app "debug"
  preflight_for_launch || return 1
  deploy_current_app
  launch_current_app
  launch_targets_if_needed
  ok "Dev start completed"
}

start_release() {
  ensure_simulator_running || return 1
  build_current_app "release"
  preflight_for_launch || return 1
  deploy_current_app
  launch_current_app
  launch_targets_if_needed
  ok "Release start completed"
}

stop_dev() {
  if pgrep -f "hvigor" >/dev/null 2>&1; then
    pkill -f "hvigor"
    ok "Stopped hvigor processes"
  else
    info "No hvigor processes were running"
  fi
}
