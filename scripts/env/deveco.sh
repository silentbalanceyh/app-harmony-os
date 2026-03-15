#!/usr/bin/env bash
# deveco.sh - DevEco tool discovery and helpers

set -euo pipefail

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/common.sh"

# Check DevEco Studio installation
check_deveco_installation() {
  info "Checking DevEco Studio installation..."

  # Check for hvigorw (HarmonyOS build tool)
  if command -v hvigorw &>/dev/null; then
    ok "Found hvigorw: $(which hvigorw)"
  elif [[ -f "./hvigorw" ]]; then
    ok "Found local hvigorw in current directory"
  else
    warn "hvigorw not found in PATH or current directory"
    error "Please ensure DevEco Studio is installed and hvigorw is available"
    return 1
  fi

  # Check for hdc (HarmonyOS device connector)
  if command -v hdc &>/dev/null; then
    ok "Found hdc: $(which hdc)"
  else
    warn "hdc not found in PATH"
    error "Please ensure HarmonyOS SDK is installed and hdc is available"
    return 1
  fi

  # Check SDK path if set
  if [[ -n "${HARMONY_SDK_PATH:-}" && -d "$HARMONY_SDK_PATH" ]]; then
    ok "HarmonyOS SDK found at: $HARMONY_SDK_PATH"
  else
    warn "HARMONY_SDK_PATH not set or directory not found"
  fi
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