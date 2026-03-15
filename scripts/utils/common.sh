#!/usr/bin/env bash
# common.sh - Shared logging, argument parsing, safety checks

set -euo pipefail

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

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

# Parse --app / --apps / --mode / --device flags
# Usage: parse_args "$@"
# Sets: APP_NAME, APP_NAMES (array), BUILD_MODE, DEVICE_ID
APP_NAME=""
APP_NAMES=()
BUILD_MODE="dev"
DEVICE_ID=""

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --app)    APP_NAME="$2";  shift 2 ;;
      --apps)   IFS=',' read -ra APP_NAMES <<< "$2"; shift 2 ;;
      --mode)   BUILD_MODE="$2"; shift 2 ;;
      --device) DEVICE_ID="$2"; shift 2 ;;
      *) warn "Unknown argument: $1"; shift ;;
    esac
  done
  # If --app given, treat as single-element APP_NAMES
  if [[ -n "$APP_NAME" && ${#APP_NAMES[@]} -eq 0 ]]; then
    APP_NAMES=("$APP_NAME")
  fi
}
