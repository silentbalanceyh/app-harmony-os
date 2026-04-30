#!/usr/bin/env bash

set -euo pipefail

WORKSPACE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$WORKSPACE_ROOT/scripts/common.sh"

usage() {
  cat <<'EOF'
Usage: scripts/watch-build.sh --app app-name [--no-restart]

Watches entry/src/main/ets for changes, rebuilds incrementally, installs the HAP,
and restarts the app unless --no-restart is supplied.
EOF
}

app=""
restart=true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --app) app="${2:?missing app name}"; shift 2 ;;
    --no-restart) restart=false; shift ;;
    -h|--help) usage; exit 0 ;;
    *) error "Unknown argument: $1"; usage; exit 1 ;;
  esac
done

[[ -n "$app" ]] || { usage; exit 1; }
app_root="$(peer_app_root "$app")"
watch_dir="$app_root/entry/src/main/ets"
[[ -d "$watch_dir" ]] || { error "Watch directory not found: $watch_dir"; exit 1; }

run_cycle() {
  BUILD_FORCE=false build_named_app "$app" "debug"
  deploy_named_app "$app"
  [[ "$restart" == "true" ]] && launch_bundle "$app"
}

info "Watching $watch_dir"
if command -v fswatch >/dev/null 2>&1; then
  fswatch -0 "$watch_dir" | while read -r -d '' _; do run_cycle; done
elif command -v inotifywait >/dev/null 2>&1; then
  while inotifywait -r -e modify,create,delete,move "$watch_dir"; do run_cycle; done
else
  warn "fswatch/inotifywait unavailable; falling back to 5s polling."
  last_state=""
  while true; do
    state="$(python3 - "$watch_dir" <<'PY'
import os
import sys

root = sys.argv[1]
rows = []
for current, _, files in os.walk(root):
    for name in files:
        if name.endswith(".ets"):
            path = os.path.join(current, name)
            try:
                rows.append(f"{os.path.getmtime(path):.0f} {path}")
            except OSError:
                pass
print("\n".join(sorted(rows)))
PY
)"
    if [[ -n "$last_state" && "$state" != "$last_state" ]]; then
      run_cycle
    fi
    last_state="$state"
    sleep 5
  done
fi
