#!/usr/bin/env bash

set -euo pipefail

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

WORKSPACE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEVECO_STUDIO_PATH="${DEVECO_STUDIO_PATH:-/Applications/DevEco-Studio.app}"
DEVECO_HDC="$DEVECO_STUDIO_PATH/Contents/sdk/default/openharmony/toolchains/hdc"
DEVECO_EMULATOR="$DEVECO_STUDIO_PATH/Contents/tools/emulator/Emulator"
DEFAULT_EMULATOR_INSTANCE_PATH="${EMULATOR_INSTANCE_PATH:-$HOME/.Huawei/Emulator/deployed}"
DEFAULT_EMULATOR_IMAGE_ROOT="${EMULATOR_IMAGE_ROOT:-$HOME/Library/Huawei/Sdk}"
LOG_DIR="$WORKSPACE_ROOT/.logs"
LOG_FILE="$LOG_DIR/simulator-start.log"

info()  { echo -e "${CYAN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }

normalize_output() {
  tr -d '\r'
}

require_executable() {
  local path="$1"
  local name="$2"

  if [[ ! -x "$path" ]]; then
    error "$name not found: $path"
    return 1
  fi
}

list_connected_targets() {
  local raw_targets

  raw_targets="$("$DEVECO_HDC" list targets 2>/dev/null | normalize_output || true)"
  if [[ "$raw_targets" == *"[Fail]"* ]]; then
    return 0
  fi

  printf '%s\n' "$raw_targets" | awk 'NF && $0 != "[Empty]"'
}

list_emulator_instances() {
  "$DEVECO_EMULATOR" -list 2>/dev/null | normalize_output || true
}

pick_emulator_instance() {
  local preferred="${EMULATOR_NAME:-}"

  if [[ -n "$preferred" ]]; then
    echo "$preferred"
    return 0
  fi

  list_emulator_instances | awk 'NF { print; exit }'
}

wait_for_connection_once() {
  local seconds="${1:-1}"
  local targets

  targets="$(list_connected_targets)"
  if [[ -n "${targets//[[:space:]]/}" ]]; then
    return 0
  fi

  sleep "$seconds"
  return 1
}

main() {
  local auto_start="${AUTO_START_EMULATOR:-true}"
  local emulator_name
  local trace_name
  local emulator_pid
  local attempt
  local -a cmd

  require_executable "$DEVECO_HDC" "hdc" || return 1
  require_executable "$DEVECO_EMULATOR" "Emulator" || return 1

  if [[ -n "$(list_connected_targets)" ]]; then
    ok "HarmonyOS simulator/device already connected"
    return 0
  fi

  if [[ "$auto_start" != "true" ]]; then
    error "No HarmonyOS simulator/device connected"
    return 1
  fi

  emulator_name="$(pick_emulator_instance)"
  if [[ -z "$emulator_name" ]]; then
    error "No local DevEco simulator instance found"
    return 1
  fi

  mkdir -p "$LOG_DIR"
  cmd=("$DEVECO_EMULATOR" -hvd "$emulator_name")
  if [[ -n "$DEFAULT_EMULATOR_INSTANCE_PATH" ]]; then
    cmd+=(-path "$DEFAULT_EMULATOR_INSTANCE_PATH")
  fi
  trace_name="trace_$$_commandPipe"
  cmd+=(-t "$trace_name")
  if [[ -n "$DEFAULT_EMULATOR_IMAGE_ROOT" ]]; then
    cmd+=(-imageRoot "$DEFAULT_EMULATOR_IMAGE_ROOT")
  fi
  if [[ -n "${EMULATOR_HDC_PORT:-}" ]]; then
    cmd+=(-hdcport "$EMULATOR_HDC_PORT")
  fi

  info "No HarmonyOS simulator/device connected, attempting to start: $emulator_name"
  nohup "${cmd[@]}" >"$LOG_FILE" 2>&1 &
  emulator_pid="$!"

  for ((attempt = 1; attempt <= 5; attempt += 1)); do
    if wait_for_connection_once 1; then
      disown "$emulator_pid" 2>/dev/null || true
      ok "HarmonyOS simulator connected"
      return 0
    fi

    if ! kill -0 "$emulator_pid" 2>/dev/null; then
      warn "Automatic simulator start exited early"
      warn "Check simulator log: $LOG_FILE"
      error "No HarmonyOS simulator/device connected"
      return 1
    fi
  done

  disown "$emulator_pid" 2>/dev/null || true

  for ((attempt = 1; attempt <= 20; attempt += 1)); do
    if wait_for_connection_once 2; then
      ok "HarmonyOS simulator connected"
      return 0
    fi
  done

  warn "Automatic simulator start did not connect within timeout"
  warn "Check simulator log: $LOG_FILE"
  error "No HarmonyOS simulator/device connected"
  return 1
}

main "$@"
