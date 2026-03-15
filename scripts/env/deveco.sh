#!/usr/bin/env bash
# deveco.sh - DevEco tool discovery and helpers

set -euo pipefail

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/common.sh"

# Check DevEco Studio installation (non-fatal for empty workspace)
check_deveco_installation() {
  local strict="${1:-false}"
  info "Checking DevEco Studio installation..."

  local has_hvigor=false
  local has_hdc=false

  # Check for hvigorw (HarmonyOS build tool)
  if command -v hvigorw &>/dev/null; then
    ok "Found hvigorw: $(which hvigorw)"
    has_hvigor=true
  elif [[ -f "./hvigorw" ]]; then
    ok "Found local hvigorw in current directory"
    has_hvigor=true
  else
    warn "hvigorw not found in PATH or current directory"
  fi

  # Check for hdc (HarmonyOS device connector)
  if command -v hdc &>/dev/null; then
  ok "Found hdc: $(which hdc)"
    has_hdc=true
  else
    warn "hdc not found in PATH"
  fi

  # Check SDK path if set
  if [[ -n "${HARMONY_SDK_PATH:-}" && -d "$HARMONY_SDK_PATH" ]]; then
    ok "HarmonyOS SDK found at: $HARMONY_SDK_PATH"
  else
    warn "HARMONY_SDK_PATH not set or directory not found"
  fi

  # Only fail if strict mode and tools missing
  if [[ "$strict" == "true" ]]; then
    if [[ "$has_hvigor" == "false" ]]; then
      error "hvigorw is required for build operations"
      return 1
    fi
    if [[ "$has_hdc" == "false" ]]; then
      error "hdc is required for device operations"
      return 1
    fi
  fi

  return 0
}

# Get hvigor command (prefer local wrapper)
get_hvigor_cmd() {
  if [[ -f "./hvigorw" ]]; then
    echo "./hvigorw"
  elif command -v hvigorw &>/dev/null; then
    echo "hvigorw"
  else
    error "No hvigor command available"
    return 1
  fi
}

# Build an app using hvigor
build_app() {
  local app_name="$1"
  local mode="${2:-debug}"
  local root
  root="$(workspace_root)"

  info "Building app '$app_name' in $mode mode..."

  local app_dir="$root/apps/$app_name"
  if [[ ! -d "$app_dir" ]]; then
    error "App directory not found: $app_dir"
    return 1
  fi

  local hvigor_cmd
  hvigor_cmd="$(get_hvigor_cmd)"

  cd "$app_dir"
  case "$mode" in
    debug|dev)
      $hvigor_cmd assembleHap --mode module -p debuggable=true
      ;;
    release|prod)
      $hvigor_cmd assembleHap --mode module -p debuggable=false
      ;;
    *)
      error "Unknown build mode: $mode"
      return 1
      ;;
  esac
}

# Install app to device
install_app() {
  local app_name="$1"
  local device_id="${2:-}"
  local root
  root="$(workspace_root)"

  require_cmd hdc

  info "Installing app '$app_name'..."

  # Find the built HAP file
  local hap_file
  hap_file=$(find "$root/apps/$app_name" -name "*.hap" -type f | head -1)

  if [[ -z "$hap_file" ]]; then
    error "No HAP file found for app '$app_name'. Build the app first."
    return 1
  fi

  info "Found HAP: $hap_file"

  # Install to device
  if [[ -n "$device_id" ]]; then
    hdc -t "$device_id" install "$hap_file"
  else
    hdc install "$hap_file"
  fi

  ok "App '$app_name' installed successfully"
}