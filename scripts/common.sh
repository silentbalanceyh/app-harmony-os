#!/usr/bin/env bash

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

WORKSPACE_ROOT="${WORKSPACE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
DEVECO_STUDIO_PATH="${DEVECO_STUDIO_PATH:-/Applications/DevEco-Studio.app}"
DEVECO_HVIGORW="${DEVECO_HVIGORW:-$DEVECO_STUDIO_PATH/Contents/tools/hvigor/bin/hvigorw}"
DEVECO_HDC="${DEVECO_HDC:-$DEVECO_STUDIO_PATH/Contents/sdk/default/openharmony/toolchains/hdc}"
DEVECO_SDK_ROOT="${DEVECO_SDK_ROOT:-$DEVECO_STUDIO_PATH/Contents/sdk/default}"
HVIGOR_CACHE_DIR="${HVIGOR_CACHE_DIR:-$WORKSPACE_ROOT/.hvigor-cache}"
BUILD_FORCE="${BUILD_FORCE:-false}"
BUILD_MODE="${BUILD_MODE:-debug}"
USER_PROVIDED_DEVECO_SDK_HOME="${DEVECO_SDK_HOME:-}"
USER_PROVIDED_OHOS_BASE_SDK_HOME="${OHOS_BASE_SDK_HOME:-}"

source "$WORKSPACE_ROOT/scripts/app-metadata.sh"

info()  { echo -e "${CYAN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*" >&2; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
error_code() { printf '[%s] %s | %s\n' "$1" "$2" "$3" >&2; }

register_app() {
  APP_ROOT="$(cd "${1:-$APP_ROOT}" && pwd)"
  APP_NAME="$(basename "$APP_ROOT")"
  APP_CONFIG="${APP_CONFIG:-$APP_ROOT/app.json}"
  SIMULATOR_SCRIPT="$WORKSPACE_ROOT/start-simulator.sh"
  validate_app_config "$APP_CONFIG" || return 1

  if [[ -f "$APP_ROOT/scripts/overrides.sh" ]]; then
    # Per-app override hook. It may redefine functions or variables after registration.
    source "$APP_ROOT/scripts/overrides.sh"
  fi
}

read_config_string() { read_json_string "$1" "$2"; }
read_config_array() { read_json_array "$1" "$2"; }
read_device_id() {
  [[ -n "${APP_CONFIG:-}" ]] || { echo ""; return 0; }
  read_config_string "$APP_CONFIG" "device"
}
app_bundle_name() { read_config_string "$APP_CONFIG" "bundleName"; }
app_module_name() { read_config_string "$APP_CONFIG" "moduleName"; }
app_ability_name() { read_config_string "$APP_CONFIG" "abilityName"; }
read_app_dependencies() { read_config_array "$APP_CONFIG" "dependsOn"; }
read_launch_targets() { read_config_array "$APP_CONFIG" "launchTargets"; }
peer_app_config() { app_config_path "$1"; }
peer_app_root() { app_root_path "$1"; }
peer_bundle_name() { read_config_string "$(peer_app_config "$1")" "bundleName"; }
peer_ability_name() { read_config_string "$(peer_app_config "$1")" "abilityName"; }

normalize_hdc_output() { tr -d '\r'; }

resolve_cmd() {
  local cmd="$1"

  if command -v "$cmd" >/dev/null 2>&1; then
    command -v "$cmd"
    return 0
  fi

  case "$cmd" in
    hdc) [[ -x "$DEVECO_HDC" ]] && { echo "$DEVECO_HDC"; return 0; } ;;
    hvigorw) [[ -x "$DEVECO_HVIGORW" ]] && { echo "$DEVECO_HVIGORW"; return 0; } ;;
  esac

  error_code "ENV_001" "Required command not found: $cmd" "Install DevEco Studio or add $cmd to PATH."
  return 1
}

require_cmd() {
  resolve_cmd "$1" >/dev/null
}

run_hdc() {
  local device_id hdc_cmd
  device_id="$(read_device_id 2>/dev/null || true)"
  hdc_cmd="$(resolve_cmd hdc)"

  if [[ -n "$device_id" ]]; then
    "$hdc_cmd" -t "$device_id" "$@"
  else
    "$hdc_cmd" "$@"
  fi
}

hdc_output_is_failure() {
  [[ "$1" == *"[Fail]"* ]]
}

run_hdc_checked() {
  local output
  output="$(run_hdc "$@" 2>&1 | normalize_hdc_output || true)"
  [[ -n "$output" ]] && printf '%s\n' "$output" >&2
  ! hdc_output_is_failure "$output"
}

list_connected_targets() {
  local hdc_cmd raw_targets
  hdc_cmd="$(resolve_cmd hdc)"
  raw_targets="$("$hdc_cmd" list targets 2>/dev/null | normalize_hdc_output || true)"
  hdc_output_is_failure "$raw_targets" && return 0
  printf '%s\n' "$raw_targets" | awk 'NF && $0 != "[Empty]"'
}

read_sdk_version_path() {
  local sdk_pkg_json="$1/sdk-pkg.json"

  python3 - "$sdk_pkg_json" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as f:
    data = json.load(f)
print(data.get("data", {}).get("path", ""))
PY
}

ensure_sdk_environment_for_root() {
  local target_root="$1"
  local sdk_root="$DEVECO_SDK_ROOT"
  local version_path shim_root

  if [[ ! -f "$sdk_root/sdk-pkg.json" ]]; then
    error_code "ENV_002" "DevEco SDK metadata not found: $sdk_root/sdk-pkg.json" "Install HarmonyOS SDK from DevEco SDK Manager."
    return 1
  fi

  version_path="$(read_sdk_version_path "$sdk_root")"
  if [[ -z "$version_path" ]]; then
    error_code "ENV_002" "Unable to resolve HarmonyOS SDK version path" "Reinstall or repair the HarmonyOS SDK."
    return 1
  fi

  shim_root="$target_root/.deveco-sdk-shim"
  mkdir -p "$shim_root"
  cp "$sdk_root/sdk-pkg.json" "$shim_root/sdk-pkg.json"
  ln -sfn "$sdk_root" "$shim_root/$version_path"

  export DEVECO_SDK_HOME="${USER_PROVIDED_DEVECO_SDK_HOME:-$shim_root}"
  export OHOS_BASE_SDK_HOME="${USER_PROVIDED_OHOS_BASE_SDK_HOME:-$shim_root/$version_path/openharmony}"
}

ensure_sdk_environment() {
  ensure_sdk_environment_for_root "${APP_ROOT:-$WORKSPACE_ROOT}"
}

configure_hvigor_cache() {
  mkdir -p "$HVIGOR_CACHE_DIR"
  export HVIGOR_USER_HOME="$HVIGOR_CACHE_DIR"
  export HVIGOR_CACHE_HOME="$HVIGOR_CACHE_DIR"
  export OHPM_HOME="${OHPM_HOME:-$HVIGOR_CACHE_DIR/ohpm}"
}

get_hvigor_cmd_for_root() {
  local target_root="$1"

  if [[ -x "$target_root/hvigorw" ]]; then
    echo "$target_root/hvigorw"
  elif command -v hvigorw >/dev/null 2>&1; then
    command -v hvigorw
  elif [[ -x "$DEVECO_HVIGORW" ]]; then
    echo "$DEVECO_HVIGORW"
  elif [[ -x "$target_root/hvigorw.bat" ]]; then
    echo "$target_root/hvigorw.bat"
  else
    error_code "ENV_001" "hvigorw not found for $target_root" "Install DevEco Studio or restore the app hvigor wrapper."
    return 1
  fi
}

check_device_connection() {
  local device_id targets
  require_cmd hdc || return 1
  device_id="$(read_device_id)"
  targets="$(list_connected_targets)"

  if [[ -z "${targets//[[:space:]]/}" ]]; then
    error_code "ENV_003" "No HarmonyOS emulator/device connected" "Start a simulator or connect hardware, then rerun the script."
    return 1
  fi
  if [[ -n "$device_id" ]] && ! grep -Fq "$device_id" <<<"$targets"; then
    error_code "ENV_003" "Configured device '$device_id' is not connected" "Update app.json device or connect that device."
    return 1
  fi
  ok "Device connection check passed"
}

source "$WORKSPACE_ROOT/scripts/simulator.sh"

build_current_app() {
  local mode="${1:-debug}"
  build_named_app "$APP_NAME" "$mode"
}

latest_hap_for_app() {
  find_hap_for_app "$1"
}

find_hap() {
  find_hap_for_app "$APP_NAME"
}

find_hap_for_app() {
  local app_name="$1"
  local target_root
  target_root="$(peer_app_root "$app_name")"
  find "$target_root" -type f -name "*.hap" ! -name "*unsigned*" 2>/dev/null | sort | tail -1
}

link_shared_modules() {
  local target_root="${1:-$APP_ROOT}"
  local shared_root="$WORKSPACE_ROOT/shared/ets"
  local link_path="$target_root/entry/src/main/ets/_shared"

  [[ -d "$shared_root" ]] || return 0
  [[ -d "$target_root/entry/src/main/ets" ]] || return 0

  rm -rf "$link_path"
  mkdir -p "$link_path"
  cp -R "$shared_root"/. "$link_path"/
  ok "Synced shared ArkTS modules for $(basename "$target_root")"
}

source_newer_than_hap() {
  local target_root="$1"
  local hap_file="$2"

  [[ -f "$hap_file" ]] || return 0
  find "$target_root/AppScope" "$target_root/entry/src" "$target_root/entry/build-profile.json5" "$target_root/entry/oh-package.json5" "$target_root/entry/hvigorfile.ts" "$target_root/build-profile.json5" "$target_root/oh-package.json5" "$target_root/hvigorfile.ts" \
    -type f -newer "$hap_file" 2>/dev/null | grep -q .
}

ensure_signing_config() {
  local target_root="${1:-$APP_ROOT}"
  local profile="$target_root/build-profile.json5"

  [[ -f "$profile" ]] || return 0
  if python3 - "$profile" <<'PY'
import re
import sys
text = open(sys.argv[1], encoding="utf-8").read()
m = re.search(r'"signingConfigs"\s*:\s*\[(.*?)\]', text, re.S)
raise SystemExit(0 if m and m.group(1).strip() else 1)
PY
  then
    ok "Signing config present for $(basename "$target_root")"
    return 0
  fi

  warn "[BUILD_002] signingConfigs is empty for $(basename "$target_root") | Configure a DevEco debug signing profile if this build fails."
  warn "Automatic signing generation is not available in this CLI environment without DevEco certificate tooling."
  return 0
}

diagnose_build_failure() {
  local log_file="$1"
  local app_name="${2:-unknown}"

  warn "Build diagnosis for $app_name"
  [[ -f "$log_file" ]] || { warn "No build log available: $log_file"; return 1; }
  if rg -i "sdk|compatibleSdkVersion|api version|version.*mismatch" "$log_file" >/dev/null 2>&1; then
    error_code "ENV_002" "Possible SDK version mismatch" "Install the SDK version required by build-profile.json5."
  fi
  if rg -i "module.*not found|cannot find module|oh-package|build-profile" "$log_file" >/dev/null 2>&1; then
    error_code "BUILD_001" "Possible module/dependency configuration problem" "Check oh-package.json5 and build-profile.json5."
  fi
  if rg -i "signing|signature|certificate|profile" "$log_file" >/dev/null 2>&1; then
    error_code "BUILD_002" "Possible signing configuration problem" "Configure debug signing in build-profile.json5 or DevEco Studio."
  fi
  rg -n "ArkTS|ERROR|Error|error TS|\\.ets" "$log_file" 2>/dev/null | tail -20 || true
}

diagnose_runtime_failure() {
  local app_name="${1:-$APP_NAME}"
  local bundle_name
  bundle_name="$(peer_bundle_name "$app_name")"

  warn "Runtime diagnosis for $app_name"
  require_cmd hdc || return 1
  run_hdc shell bm dump -a 2>/dev/null | normalize_hdc_output | grep -F "$bundle_name" || warn "Bundle not visible in bm dump: $bundle_name"
  run_hdc shell hilog -x 2>/dev/null | normalize_hdc_output | rg -i "crash|fatal|exception|$bundle_name" | tail -80 || true
}

write_build_info() {
  local app_name="$1"
  local mode="$2"
  local duration="$3"
  local target_root hap_file output_dir
  target_root="$(peer_app_root "$app_name")"
  hap_file="$(find_hap_for_app "$app_name")"
  output_dir="$target_root/build/outputs/default"
  mkdir -p "$output_dir"

  python3 - "$target_root" "$hap_file" "$mode" "$duration" "$output_dir/build-info.json" <<'PY'
import json
import os
import subprocess
import sys
from datetime import datetime, timezone

root, hap, mode, duration, out = sys.argv[1:]

def run(args):
    try:
        return subprocess.check_output(args, cwd=root, text=True, stderr=subprocess.DEVNULL).strip()
    except Exception:
        return ""

commit = run(["git", "rev-parse", "HEAD"])
dirty = bool(run(["git", "status", "--porcelain"]))
sdk = os.environ.get("OHOS_BASE_SDK_HOME") or os.environ.get("DEVECO_SDK_HOME") or ""
rel_hap = os.path.relpath(hap, root) if hap and os.path.exists(hap) else ""
size = os.path.getsize(hap) if hap and os.path.exists(hap) else 0
data = {
    "buildTime": datetime.now(timezone.utc).isoformat(),
    "buildMode": mode,
    "buildDurationSeconds": int(duration),
    "gitCommit": commit,
    "gitDirty": dirty,
    "sdkVersion": sdk,
    "hapPath": rel_hap,
    "hapSize": size,
}
with open(out, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
    f.write("\n")
PY
}

build_named_app() {
  local app_name="$1"
  local mode="${2:-debug}"
  local target_root hvigor_cmd hap_file start_ts end_ts duration log_file

  target_root="$(peer_app_root "$app_name")"
  [[ -d "$target_root" ]] || { error_code "BUILD_001" "App not found: $app_name" "Check the --app value."; return 1; }
  link_shared_modules "$target_root"
  hap_file="$(find_hap_for_app "$app_name")"
  if [[ "${BUILD_FORCE:-false}" != "true" && -n "$hap_file" ]] && ! source_newer_than_hap "$target_root" "$hap_file"; then
    ok "Skipping $app_name: existing HAP is newer than sources"
    write_build_info "$app_name" "$mode-incremental-skip" 0
    return 0
  fi

  hvigor_cmd="$(get_hvigor_cmd_for_root "$target_root")" || return 1
  configure_hvigor_cache
  ensure_sdk_environment_for_root "$target_root" || return 1
  ensure_signing_config "$target_root"
  mkdir -p "$WORKSPACE_ROOT/.logs"
  log_file="$WORKSPACE_ROOT/.logs/${app_name}-build.log"

  info "Building $app_name in $mode mode"
  start_ts="$(date +%s)"
  if (
    cd "$target_root"
    case "$mode" in
      debug|dev) "$hvigor_cmd" assembleApp -p product=default -p buildMode=debug ;;
      release|prod) "$hvigor_cmd" assembleApp -p product=default -p buildMode=release ;;
      *) error_code "BUILD_001" "Unsupported build mode: $mode" "Use debug or release."; exit 2 ;;
    esac
  ) >"$log_file" 2>&1; then
    end_ts="$(date +%s)"
    duration=$((end_ts - start_ts))
    ok "$app_name built successfully in ${duration}s ($mode)"
    write_build_info "$app_name" "$mode" "$duration"
    return 0
  fi

  diagnose_build_failure "$log_file" "$app_name"
  if [[ ! -d "$target_root/.deveco-sdk-shim" ]]; then
    warn "Retrying $app_name once after SDK shim repair"
    ensure_sdk_environment_for_root "$target_root" || return 1
    if (cd "$target_root" && "$hvigor_cmd" assembleApp -p product=default -p buildMode="$mode") >>"$log_file" 2>&1; then
      end_ts="$(date +%s)"
      duration=$((end_ts - start_ts))
      ok "$app_name built successfully after retry in ${duration}s"
      write_build_info "$app_name" "$mode" "$duration"
      return 0
    fi
  fi
  error_code "BUILD_001" "Build failed for $app_name" "Inspect $log_file."
  return 1
}

deploy_current_app() { deploy_named_app "$APP_NAME"; }

deploy_named_app() {
  local app_name="$1"
  local hap_file

  hap_file="$(find_hap_for_app "$app_name")"
  if [[ -z "$hap_file" ]]; then
    error_code "DEPLOY_001" "No HAP package found for $app_name" "Build the app first."
    return 1
  fi
  require_cmd hdc || return 1
  check_device_connection || return 1
  info "Installing $hap_file"
  run_hdc_checked install "$hap_file" || { error_code "DEPLOY_001" "Install failed for $app_name" "Check device logs and signing."; return 1; }
  ok "$app_name installed successfully"
}

check_bundle_installed() {
  local bundle_name="$1"
  local installed_bundles
  require_cmd hdc >/dev/null 2>&1 || return 1
  installed_bundles="$(run_hdc shell bm dump -a 2>&1 | normalize_hdc_output || true)"
  hdc_output_is_failure "$installed_bundles" && return 1
  grep -Fqx "$bundle_name" <<<"$(printf '%s\n' "$installed_bundles" | sed 's/^[[:space:]]*//')"
}

launch_bundle() {
  local app_name="$1"
  local bundle_name ability_name
  bundle_name="$(peer_bundle_name "$app_name")"
  ability_name="$(peer_ability_name "$app_name")"
  [[ -n "$bundle_name" && -n "$ability_name" ]] || { warn "Skipping launch for $app_name: missing app metadata"; return 0; }
  if ! check_bundle_installed "$bundle_name"; then
    warn "Skipping launch for $app_name: bundle $bundle_name is not installed on device"
    return 0
  fi
  info "Launching $app_name"
  run_hdc_checked shell aa start -a "$ability_name" -b "$bundle_name" || { error_code "DEPLOY_002" "Launch failed for $app_name" "Run diagnose_runtime_failure $app_name."; return 1; }
}

launch_current_app() { launch_bundle "$APP_NAME"; }

ensure_dependency_ready() {
  local dependency="$1"
  local bundle_name
  bundle_name="$(peer_bundle_name "$dependency")"
  [[ -n "$bundle_name" ]] || { warn "Dependency $dependency has no bundle metadata"; return 0; }
  if check_bundle_installed "$bundle_name"; then
    ok "Dependency ready: $dependency ($bundle_name)"
  else
    warn "Dependency missing on device: $dependency ($bundle_name)"
    build_named_app "$dependency" "debug"
    deploy_named_app "$dependency"
  fi
}

ensure_dependencies_ready() {
  local dependency
  while IFS= read -r dependency; do
    [[ -n "$dependency" ]] && ensure_dependency_ready "$dependency"
  done < <(read_app_dependencies)
}

check_dependencies() {
  local dependency bundle_name
  while IFS= read -r dependency; do
    [[ -n "$dependency" ]] || continue
    bundle_name="$(peer_bundle_name "$dependency")"
    if [[ -n "$bundle_name" ]] && check_bundle_installed "$bundle_name"; then
      ok "Dependency ready: $dependency ($bundle_name)"
    else
      warn "Dependency missing on device: $dependency ($bundle_name)"
    fi
  done < <(read_app_dependencies)
}

launch_targets_if_needed() {
  local target
  [[ "${LAUNCH_DEPENDENCIES:-false}" == "true" ]] || return 0
  while IFS= read -r target; do
    [[ -n "$target" ]] && launch_bundle "$target"
  done < <(read_launch_targets)
}

preflight_check() {
  local failures=0
  [[ -d "$DEVECO_STUDIO_PATH" ]] && ok "[OK] DevEco Studio: $DEVECO_STUDIO_PATH" || { error_code "ENV_001" "[FAIL] DevEco Studio not found" "Set DEVECO_STUDIO_PATH."; failures=$((failures + 1)); }
  [[ -f "$DEVECO_SDK_ROOT/sdk-pkg.json" ]] && ok "[OK] HarmonyOS SDK metadata found" || { error_code "ENV_002" "[FAIL] SDK metadata missing" "Install SDK in DevEco SDK Manager."; failures=$((failures + 1)); }
  if ensure_sdk_environment; then ok "[FIX] SDK shim ready"; else failures=$((failures + 1)); fi
  if require_cmd hdc >/dev/null 2>&1; then ok "[OK] hdc available"; else failures=$((failures + 1)); fi
  if get_hvigor_cmd_for_root "$APP_ROOT" >/dev/null 2>&1; then ok "[OK] hvigorw available"; else failures=$((failures + 1)); fi
  ensure_signing_config "$APP_ROOT" || failures=$((failures + 1))
  if [[ "${PREFLIGHT_REQUIRE_DEVICE:-true}" == "true" ]]; then
    ensure_simulator_running || failures=$((failures + 1))
  fi

  if [[ "$failures" -gt 0 ]]; then
    error "Action Required: resolve $failures preflight failure(s), then rerun the script."
    return 1
  fi
}

preflight_for_launch() {
  preflight_check || return 1
  check_device_connection || return 1
  ensure_dependencies_ready
  check_dependencies
}

start_dev() {
  BUILD_MODE=debug
  preflight_check || return 1
  build_current_app "debug"
  preflight_for_launch || return 1
  deploy_current_app
  launch_current_app
  launch_targets_if_needed
  ok "Dev start completed"
}

start_release() {
  BUILD_MODE=release
  preflight_check || return 1
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

workspace_build() {
  local app
  for app in $(workspace_app_names); do
    build_named_app "$app" "${BUILD_MODE:-debug}"
  done
}

start_previewer() {
  warn "DevEco Previewer CLI/headless mode is not exposed by the installed command-line tooling."
  warn "Use app dev-preview.* scripts to open DevEco Studio GUI previewer when a GUI session is available."
  return 1
}
