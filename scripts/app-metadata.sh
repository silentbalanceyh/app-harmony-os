#!/usr/bin/env bash

read_json_string() {
  local file="$1"
  local key="$2"

  python3 - "$file" "$key" <<'PY'
import json
import sys

path, key = sys.argv[1], sys.argv[2]
try:
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
except FileNotFoundError:
    print("")
    raise SystemExit(0)

value = data.get(key, "")
print(value if isinstance(value, str) else "")
PY
}

read_json_array() {
  local file="$1"
  local key="$2"

  python3 - "$file" "$key" <<'PY'
import json
import sys

path, key = sys.argv[1], sys.argv[2]
try:
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
except FileNotFoundError:
    raise SystemExit(0)

for item in data.get(key, []):
    if isinstance(item, str):
        print(item)
PY
}

validate_app_config() {
  local config="$1"

  python3 - "$config" <<'PY'
import json
import sys

path = sys.argv[1]
required = ["app", "bundleName", "moduleName", "abilityName"]
try:
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
except Exception as exc:
    print(f"invalid json: {exc}")
    raise SystemExit(1)

missing = [key for key in required if not isinstance(data.get(key), str) or not data.get(key)]
if missing:
    print("missing required keys: " + ", ".join(missing))
    raise SystemExit(1)
PY
}

app_config_path() {
  local app_name="$1"
  echo "$WORKSPACE_ROOT/$app_name/app.json"
}

app_root_path() {
  local app_name="$1"
  echo "$WORKSPACE_ROOT/$app_name"
}

workspace_app_names() {
  local app_dir

  if [[ -d "$WORKSPACE_ROOT/app-center" ]]; then
    echo "app-center"
  fi

  for app_dir in "$WORKSPACE_ROOT"/app-*; do
    [[ -d "$app_dir" && -f "$app_dir/app.json" ]] || continue
    [[ "$(basename "$app_dir")" != "app-center" ]] || continue
    basename "$app_dir"
  done | sort
}
