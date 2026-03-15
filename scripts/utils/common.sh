#!/usr/bin/env bash
# common.sh - Shared logging, argument parsing, safety checks

set -euo pipefail

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

# Global config (set by read_app_config)
APP_NAME="${APP_NAME:-}"
APP_NAMES=("${APP_NAMES[@]+"${APP_NAMES[@]}"}")
DEVICE_ID="${DEVICE_ID:-}"
BUILD_MODE="${BUILD_MODE:-}"

info()  { echo -e "${CYAN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }

# Require a command to be available
require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" &>/dev/null; then
    error "Required command not found: $cmd"
    error "Please install DevEco Studio and ensure '$cmd' is on your PATH."
    exit 1
  fi
}

# Resolve workspace root (directory containing this scripts/ folder)
workspace_root() {
  local scripts_dir
  scripts_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  echo "$scripts_dir"
}

# Discover all apps under apps/
discover_apps() {
  local root="$1"
  local apps_dir="$root/apps"
  if [[ ! -d "$apps_dir" ]]; then
    echo ""
    return
  fi
  # An app dir is one that contains AppScope/ or entry/ (HarmonyOS markers)
  local found=()
  for d in "$apps_dir"/*/; do
    [[ -d "$d" ]] || continue
    if [[ -d "${d}AppScope" || -d "${d}entry" ]]; then
      found+=("$(basename "$d")")
    fi
  done
  echo "${found[*]:-}"
}

# Read current app/device from root app.json
# Sets: APP_NAME, APP_NAMES, DEVICE_ID
read_app_config() {
  local root="$1"
  local cfg="$root/app.json"

  if [[ ! -f "$cfg" ]]; then
    error "Missing $cfg"
    error "Create it like: { \"app\": \"demo\", \"device\": \"\" }"
    exit 1
  fi

  local app
  app="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("app",""))' "$cfg" 2>/dev/null || true)"
  local device
  device="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("device",""))' "$cfg" 2>/dev/null || true)"

  if [[ -z "$app" ]]; then
    error "app.json missing non-empty 'app' field"
    exit 1
  fi

  APP_NAME="$app"
  APP_NAMES=("$app")
  DEVICE_ID="$device"
}

# Write selected device into app.json
write_device_config() {
  local root="$1"
  local device="$2"
  local cfg="$root/app.json"

  python3 - "$cfg" "$device" <<'PY'
import json,sys
path=sys.argv[1]
device=sys.argv[2]
with open(path,'r',encoding='utf-8') as f:
  data=json.load(f)
data['device']=device
with open(path,'w',encoding='utf-8') as f:
  json.dump(data,f,ensure_ascii=False,indent=2)
  f.write('\n')
PY
}

# Parse args is disabled (dev-only workflow)
parse_args() {
  :
}
