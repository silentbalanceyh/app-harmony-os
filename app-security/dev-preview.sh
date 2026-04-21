#!/usr/bin/env bash

set -euo pipefail

# dev-preview.sh — Open DevEco Studio Previewer for current app
# Usage: ./dev-preview.sh [page_name]
#   page_name: .ets page to preview (default: first page in main_pages.json)

APP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="$(basename "$APP_ROOT")"
DEVECO_STUDIO_PATH="${DEVECO_STUDIO_PATH:-/Applications/DevEco-Studio.app}"
PAGES_JSON="$APP_ROOT/entry/src/main/resources/base/profile/main_pages.json"
ETS_DIR="$APP_ROOT/entry/src/main/ets"

# Resolve the page to preview
if [[ $# -ge 1 ]]; then
  PAGE_NAME="$1"
else
  PAGE_NAME="$(python3 - "$PAGES_JSON" <<'PY'
import json, sys
with open(sys.argv[1], encoding='utf-8') as f:
    data = json.load(f)
pages = data.get("src", [])
print(pages[0].split("/")[-1] if pages else "Index")
PY
)"
fi

PAGE_FILE="$ETS_DIR/pages/${PAGE_NAME}.ets"
if [[ ! -f "$PAGE_FILE" ]]; then
  # Try without pages/ prefix
  PAGE_FILE="$ETS_DIR/${PAGE_NAME}.ets"
fi

if [[ ! -f "$PAGE_FILE" ]]; then
  echo "Page not found: $PAGE_NAME"
  echo "Available pages:"
  python3 - "$PAGES_JSON" <<'PY'
import json, sys
with open(sys.argv[1], encoding='utf-8') as f:
    data = json.load(f)
for p in data.get("src", []):
    print(f"  {p}")
PY
  exit 1
fi

echo "Opening DevEco Studio for $APP_NAME — Preview: $PAGE_NAME"
echo "File: $PAGE_FILE"
echo ""
echo "Steps in DevEco Studio:"
echo "  1. Open the file shown above"
echo "  2. Click Previewer tab on the right panel (or View → Tool Windows → Previewer)"
echo "  3. Edit code — preview auto-refreshes"

open -a "$DEVECO_STUDIO_PATH" "$PAGE_FILE"
