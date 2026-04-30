#!/usr/bin/env bash

DEVECO_STUDIO_PATH="${DEVECO_STUDIO_PATH:-/Applications/DevEco-Studio.app}"
DEVECO_HDC="${DEVECO_HDC:-$DEVECO_STUDIO_PATH/Contents/sdk/default/openharmony/toolchains/hdc}"
DEVECO_EMULATOR="${DEVECO_EMULATOR:-$DEVECO_STUDIO_PATH/Contents/tools/emulator/Emulator}"
DEFAULT_EMULATOR_INSTANCE_PATH="${EMULATOR_INSTANCE_PATH:-$HOME/.Huawei/Emulator/deployed}"
DEFAULT_EMULATOR_IMAGE_ROOT="${EMULATOR_IMAGE_ROOT:-$HOME/Library/Huawei/Sdk}"
LOG_DIR="${WORKSPACE_ROOT:-$(pwd)}/.logs"
LOG_FILE="$LOG_DIR/simulator-start.log"

sim_normalize_output() {
  tr -d '\r'
}

sim_require_executable() {
  local path="$1"
  local name="$2"

  if [[ ! -x "$path" ]]; then
    error_code "ENV_001" "$name not found: $path" "Install DevEco Studio or set DEVECO_STUDIO_PATH."
    return 1
  fi
}

sim_list_connected_targets() {
  local raw_targets

  raw_targets="$("$DEVECO_HDC" list targets 2>/dev/null | sim_normalize_output || true)"
  if [[ "$raw_targets" == *"[Fail]"* ]]; then
    return 0
  fi

  printf '%s\n' "$raw_targets" | awk 'NF && $0 != "[Empty]"'
}

sim_pick_emulator_instance() {
  if [[ -n "${EMULATOR_NAME:-}" ]]; then
    echo "$EMULATOR_NAME"
    return 0
  fi

  "$DEVECO_EMULATOR" -list 2>/dev/null | sim_normalize_output | awk 'NF { print; exit }'
}

sim_wait_for_connection_once() {
  local seconds="${1:-1}"

  if [[ -n "$(sim_list_connected_targets)" ]]; then
    return 0
  fi

  sleep "$seconds"
  return 1
}

sim_reposition_emulator_to_current_screen() {
  local max_wait="${1:-30}"
  local waited=0

  while [[ "$waited" -lt "$max_wait" ]]; do
    if osascript -e 'tell application "System Events" to return (name of processes) contains "Emulator"' 2>/dev/null | grep -q "true"; then
      osascript <<'AS' 2>/dev/null || true
        tell application "System Events"
          set termX to 0
          set termY to 50
          if (name of processes) contains "Terminal" then
            tell process "Terminal"
              try
                set {termX, termY} to (get position of front window)
              end try
            end tell
          else if (name of processes) contains "iTerm2" then
            tell process "iTerm2"
              try
                set {termX, termY} to (get position of front window)
              end try
            end tell
          end if
          if (name of processes) contains "Emulator" then
            tell process "Emulator"
              try
                set position of front window to {termX + 50, termY + 50}
              end try
            end tell
          end if
        end tell
AS
      return 0
    fi
    sleep 1
    waited=$((waited + 1))
  done
}

sim_launch_emulator_via_terminal() {
  local emulator_name="$1"
  local helper_script="$LOG_DIR/start-emulator.command"

  cat >"$helper_script" <<EOF
#!/usr/bin/env bash
exec "$DEVECO_EMULATOR" -hvd "$emulator_name" -path "$DEFAULT_EMULATOR_INSTANCE_PATH" -imageRoot "$DEFAULT_EMULATOR_IMAGE_ROOT"
EOF
  chmod +x "$helper_script"
  open -a Terminal "$helper_script" >/dev/null 2>&1
}

sim_launch_emulator_background() {
  nohup "$@" >"$LOG_FILE" 2>&1 &
}

ensure_simulator_running() {
  local auto_start="${AUTO_START_EMULATOR:-true}"
  local emulator_name
  local attempt
  local -a cmd

  sim_require_executable "$DEVECO_HDC" "hdc" || return 1
  sim_require_executable "$DEVECO_EMULATOR" "Emulator" || return 1

  if [[ -n "$(sim_list_connected_targets)" ]]; then
    ok "HarmonyOS simulator/device already connected"
    return 0
  fi

  if [[ "$auto_start" != "true" ]]; then
    error_code "ENV_003" "No HarmonyOS simulator/device connected" "Start a simulator or connect a device."
    return 1
  fi

  emulator_name="$(sim_pick_emulator_instance)"
  if [[ -z "$emulator_name" ]]; then
    error_code "ENV_003" "No local DevEco simulator instance found" "Create an emulator in DevEco Device Manager first."
    return 1
  fi

  mkdir -p "$LOG_DIR"
  cmd=("$DEVECO_EMULATOR" -hvd "$emulator_name")
  [[ -n "$DEFAULT_EMULATOR_INSTANCE_PATH" ]] && cmd+=(-path "$DEFAULT_EMULATOR_INSTANCE_PATH")
  [[ -n "$DEFAULT_EMULATOR_IMAGE_ROOT" ]] && cmd+=(-imageRoot "$DEFAULT_EMULATOR_IMAGE_ROOT")
  [[ -n "${EMULATOR_HDC_PORT:-}" ]] && cmd+=(-hdcport "$EMULATOR_HDC_PORT")

  info "No HarmonyOS simulator/device connected, attempting to start: $emulator_name"
  if [[ "$(uname -s)" == "Darwin" ]]; then
    sim_launch_emulator_via_terminal "$emulator_name" || sim_launch_emulator_background "${cmd[@]}"
    [[ "${EMULATOR_STICK_TO_SCREEN:-true}" == "true" ]] && sim_reposition_emulator_to_current_screen &
  else
    sim_launch_emulator_background "${cmd[@]}"
  fi

  for ((attempt = 1; attempt <= 5; attempt += 1)); do
    sim_wait_for_connection_once 1 && { ok "HarmonyOS simulator connected"; return 0; }
  done
  for ((attempt = 1; attempt <= 20; attempt += 1)); do
    sim_wait_for_connection_once 2 && { ok "HarmonyOS simulator connected"; return 0; }
  done

  warn "Automatic simulator start did not connect within timeout"
  warn "Check simulator log: $LOG_FILE"
  error_code "ENV_003" "No HarmonyOS simulator/device connected" "Review $LOG_FILE or start the emulator manually."
  return 1
}
