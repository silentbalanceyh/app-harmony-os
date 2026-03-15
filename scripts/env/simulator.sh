#!/usr/bin/env bash
# simulator.sh - Emulator/device helpers (optional)

set -euo pipefail

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/common.sh"

# List connected devices
list_devices() {
  require_cmd hdc

  info "Listing connected devices..."
  hdc list targets
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

  require_cmd hdc

  info "Waiting for device to be ready..."

  local count=0
  while [[ $count -lt $timeout ]]; do
    if [[ -n "$device_id" ]]; then
      if hdc -t "$device_id" shell echo "ready" &>/dev/null; then
        ok "Device $device_id is ready"
        return 0
      fi
    else
      if hdc shell echo "ready" &>/dev/null; then
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

  require_cmd hdc

  info "Getting device information..."

  if [[ -n "$device_id" ]]; then
    hdc -t "$device_id" shell getprop
  else
    hdc shell getprop
  fi
}