#!/usr/bin/env bash
# simulator.sh - Emulator/device helpers (optional)

set -euo pipefail

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/common.sh"

HDC_DEFAULT_BIN="/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc"

require_hdc() {
  local hdc_bin=""

  if command -v hdc &>/dev/null; then
    hdc_bin="$(command -v hdc)"
  elif [[ -x "$HDC_DEFAULT_BIN" ]]; then
    hdc_bin="$HDC_DEFAULT_BIN"
  fi

  if [[ -z "$hdc_bin" ]]; then
    error "hdc not found on PATH and default hdc not found: $HDC_DEFAULT_BIN"
    error "Please install DevEco Studio or add hdc to your PATH."
    exit 1
  fi

  echo "$hdc_bin"
}

# List connected devices
list_devices() {
  local hdc
  hdc="$(require_hdc)"

  info "Listing connected devices..."
  "$hdc" list targets
}

# Select a device interactively (writes device to app.json)
select_device_interactive() {
  local hdc
  hdc="$(require_hdc)"

  info "Detecting connected devices..."

  local output
  if ! output="$("$hdc" list targets)"; then
    error "Failed to list devices via hdc"
    return 1
  fi

  local -a device_ids=()
  local line
  while IFS= read -r line; do
    [[ -n "${line//[[:space:]]/}" ]] || continue
    # hdc outputs one target per line; use first whitespace-delimited token as id
    set -- $line
    [[ -n "${1:-}" ]] || continue
    device_ids+=("$1")
  done <<<"$output"

  if (( ${#device_ids[@]} == 0 )); then
    warn "No devices/emulators found. Start an emulator in DevEco Studio or connect a device, then re-run."
    return 0
  fi

  local selected=""
  if (( ${#device_ids[@]} == 1 )); then
    selected="${device_ids[0]}"
    ok "Using device: $selected"
  else
    info "Select a device:"
    local i
    for i in "${!device_ids[@]}"; do
      echo "  $((i + 1))) ${device_ids[$i]}"
    done

    local choice=""
    read -r -p "Enter number (1-${#device_ids[@]}): " choice

    if [[ ! "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#device_ids[@]} )); then
      error "Invalid selection: $choice"
      return 1
    fi

    selected="${device_ids[$((choice - 1))]}"
  fi

  local root
  root="$(workspace_root)"
  write_device_config "$root" "$selected"
  ok "Saved device to $root/app.json: $selected"
}

# Start HarmonyOS emulator (if available)
start_emulator() {
  local emulator_name="${1:-default}"

  info "Starting emulator: $emulator_name"
  warn "Emulator control not yet implemented - please start manually via DevEco Studio"

  # TODO: Implement emulator start logic when DevEco CLI supports it
  # This would typically involve:
  # - Finding emulator executable
  # - Starting with specified AVD name
  # - Waiting for boot completion
}

# Wait for device to be ready
wait_for_device() {
  local device_id="${1:-}"
  local timeout="${2:-30}"

  local hdc
  hdc="$(require_hdc)"

  info "Waiting for device to be ready..."

  local count=0
  while [[ $count -lt $timeout ]]; do
    if [[ -n "$device_id" ]]; then
      if "$hdc" -t "$device_id" shell echo "ready" &>/dev/null; then
        ok "Device $device_id is ready"
        return 0
      fi
    else
      if "$hdc" shell echo "ready" &>/dev/null; then
        ok "Device is ready"
        return 0
      fi
    fi

    sleep 1
    ((count++))
  done

  error "Device not ready after ${timeout}s timeout"
  return 1
}

# Get device info
device_info() {
  local device_id="${1:-}"

  local hdc
  hdc="$(require_hdc)"

  info "Getting device information..."

  if [[ -n "$device_id" ]]; then
    "$hdc" -t "$device_id" shell getprop
  else
    "$hdc" shell getprop
  fi
}