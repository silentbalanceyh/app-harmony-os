#!/usr/bin/env bash

set -euo pipefail

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

WORKSPACE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLAUDE_DIR="${HOME}/.claude"

PASS=0
FAIL=0
WARN=0

pass() { PASS=$((PASS + 1)); echo -e "  ${GREEN}[PASS]${NC} $*"; }
fail() { FAIL=$((FAIL + 1)); echo -e "  ${RED}[FAIL]${NC} $*"; }
warn() { WARN=$((WARN + 1)); echo -e "  ${YELLOW}[WARN]${NC} $*"; }
info() { echo -e "  ${CYAN}[INFO]${NC} $*"; }

section() { echo ""; echo -e "${CYAN}=== $1 ===${NC}"; }

discover_apps() {
  local apps=()
  for d in "$WORKSPACE_ROOT"/app-*/; do
    [[ -d "$d" && -f "$d/app.json" ]] || continue
    apps+=("$(basename "$d")")
  done
  printf '%s\n' "${apps[@]}" | sort
}

doc_app_list() {
  local file="$1"
  python3 - "$file" <<'PY'
import re, sys
text = open(sys.argv[1]).read()
return sorted(re.findall(r'`(app-[a-z0-9-]+)`', text))
PY
}

center_json_list() {
  python3 - "$WORKSPACE_ROOT/app-center/app.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
result = []
for k in ('dependsOn', 'launchTargets'):
    result.extend(d.get(k, []))
print('\n'.join(sorted(set(result))))
PY
}

center_ui_list() {
  grep -o "id: *'app-[^']*'" "$WORKSPACE_ROOT/app-center/entry/src/main/ets/pages/Index.ets" 2>/dev/null \
    | sed "s/.*'\(app-[^']*\)'.*/\1/" | sort -u || true
}

audit_claude_config() {
  section "1. Claude Configuration"

  local active_ok=true
  for f in "$CLAUDE_DIR"/settings*.json; do
    [[ -f "$f" ]] || continue
    local basename
    basename="$(basename "$f")"

    local has_api_key has_bypass has_hook has_lsp
    has_api_key=$(python3 -c "import json; d=json.load(open('$f')); print('yes' if d.get('apiKey') else 'no')" 2>/dev/null || echo "no")
    has_bypass=$(python3 -c "import json; d=json.load(open('$f')); print('yes' if d.get('bypassPermissions') else 'no')" 2>/dev/null || echo "no")
    has_hook=$(python3 -c "import json; d=json.load(open('$f')); print('yes' if d.get('hooks',{}).get('UserPromptSubmit') else 'no')" 2>/dev/null || echo "no")
    has_lsp=$(python3 -c "import json; d=json.load(open('$f')); print('yes' if d.get('lsp',{}).get('enabled') else 'no')" 2>/dev/null || echo "no")

    if [[ "$basename" == "settings.json" ]]; then
      if [[ "$has_api_key" == "no" && "$has_bypass" == "no" && "$has_hook" == "no" && "$has_lsp" == "no" ]]; then
        pass "Active settings.json is clean"
      else
        fail "Active settings.json contains sensitive items: apiKey=$has_api_key bypass=$has_bypass hook=$has_hook lsp=$has_lsp"
        active_ok=false
      fi
    else
      if [[ "$has_api_key" == "yes" || "$has_bypass" == "yes" || "$has_hook" == "yes" ]]; then
        warn "Backup $basename has residual config (apiKey=$has_api_key bypass=$has_bypass hook=$has_hook lsp=$has_lsp) — consider archiving"
      else
        pass "Backup $basename is clean"
      fi
    fi
  done

  local archive_dir="$CLAUDE_DIR/settings-archive"
  if [[ -d "$archive_dir" ]]; then
    local count
    count=$(ls "$archive_dir"/settings*.json 2>/dev/null | wc -l | tr -d ' ')
    info "Archived settings backups: $count files in $archive_dir"
  fi
}

audit_app_inventory() {
  section "2. Workspace App Inventory Consistency"

  local disk_apps
  disk_apps="$(discover_apps)"
  local disk_list
  disk_list="$(echo "$disk_apps" | tr '\n' ' ')"
  info "Disk app-* directories: $disk_list"

  local center_json
  center_json="$(center_json_list)"
  local json_list
  json_list="$(echo "$center_json" | tr '\n' ' ')"
  info "app-center/app.json (dependsOn + launchTargets): $json_list"

  local center_ui
  center_ui="$(center_ui_list)"
  local ui_list
  ui_list="$(echo "$center_ui" | tr '\n' ' ')"
  info "Index.ets ManagedApp ids: $ui_list"

  local all_consistent=true
  for app in $disk_apps; do
    if [[ "$app" == "app-center" ]]; then
      continue
    fi

    if echo "$center_json" | grep -qx "$app"; then
      pass "app-center/app.json includes $app"
    else
      fail "app-center/app.json MISSING $app"
      all_consistent=false
    fi

    if echo "$center_ui" | grep -qx "$app"; then
      pass "Index.ets includes $app"
    else
      fail "Index.ets MISSING $app"
      all_consistent=false
    fi
  done

  for doc_file in AGENTS.md CLAUDE.md README.md .cursor/rules/00-harmony-workspace.mdc .cursor/rules/10-workspace-structure.mdc; do
    local fpath="$WORKSPACE_ROOT/$doc_file"
    [[ -f "$fpath" ]] || continue
    local missing=false
    for app in $disk_apps; do
      if ! grep -q "$app" "$fpath" 2>/dev/null; then
        missing=true
        break
      fi
    done
    if $missing; then
      fail "$doc_file does not list all apps"
    else
      pass "$doc_file lists all apps"
    fi
  done
}

audit_script_contract() {
  section "3. Harness Script Contract"

  local required_scripts="dev-build.sh dev-start.sh dev-stop.sh dev-preview.sh run-start.sh"
  local required_bats="dev-build.bat dev-start.bat dev-stop.bat dev-preview.bat run-start.bat"

  for app in $(discover_apps); do
    local app_dir="$WORKSPACE_ROOT/$app"
    local all_ok=true

    for script in $required_scripts; do
      if [[ -f "$app_dir/$script" ]]; then
        :
      else
        fail "$app missing $script"
        all_ok=false
      fi
    done

    for script in $required_bats; do
      if [[ -f "$app_dir/$script" ]]; then
        :
      else
        fail "$app missing $script"
        all_ok=false
      fi
    done

    if $all_ok; then
      pass "$app has all required scripts"
    fi
  done
}

audit_omc_state() {
  section "4. OMC State"

  local omc_dir="$WORKSPACE_ROOT/.omc/state"
  if [[ -d "$omc_dir" ]]; then
    local error_file="$omc_dir/last-tool-error.json"
    if [[ -f "$error_file" ]]; then
      fail "Stale error state exists: $error_file — resolve and delete"
    else
      pass "No stale error state"
    fi

    local session_count
    session_count=$(ls -d "$omc_dir"/sessions/*/ 2>/dev/null | wc -l | tr -d ' ' || true)
    info "OMC session directories: $session_count"
    if [[ "${session_count:-0}" -gt 20 ]]; then
      warn "OMC session count ($session_count) is high — consider cleanup"
    else
      pass "OMC session count is reasonable"
    fi
  else
    info "No .omc/state directory"
  fi
}

audit_plugin_hygiene() {
  section "5. Plugin Hygiene"

  if [[ -f "$CLAUDE_DIR/mcp-health-cache.json" ]]; then
    local stale
    stale=$(python3 - "$CLAUDE_DIR/mcp-health-cache.json" <<'PY'
import json, sys
from datetime import datetime, timezone, timedelta
d = json.load(open(sys.argv[1]))
servers = d.get("servers", d) if isinstance(d, dict) else d
threshold = datetime.now(timezone.utc) - timedelta(days=30)
stale_count = 0
for key, entry in (servers.items() if isinstance(servers, dict) else []):
    if not isinstance(entry, dict):
        continue
    ts = entry.get("checkedAt", "")
    if ts:
        try:
            if isinstance(ts, (int, float)):
                dt = datetime.fromtimestamp(ts / 1000, tz=timezone.utc)
            else:
                dt = datetime.fromisoformat(str(ts).replace("Z", "+00:00"))
            if dt < threshold:
                stale_count += 1
        except: pass
print(stale_count)
PY
    )
    stale=${stale:-0}
    if [[ "$stale" -gt 0 ]]; then
      warn "MCP health cache has $stale entries older than 30 days"
    else
      pass "MCP health cache entries are fresh"
    fi
  fi

  if [[ -f "$CLAUDE_DIR/plugins/blocklist.json" ]]; then
    local fetched_age
    fetched_age=$(python3 - "$CLAUDE_DIR/plugins/blocklist.json" <<'PY'
import json, sys
from datetime import datetime, timezone, timedelta
d = json.load(open(sys.argv[1]))
fa = d.get("fetchedAt", "")
if not fa:
    print("unknown")
    sys.exit(0)
try:
    dt = datetime.fromisoformat(fa.replace("Z", "+00:00"))
    age = (datetime.now(timezone.utc) - dt).days
    print(age)
except:
    print("unknown")
PY
    )
    if [[ "$fetched_age" == "unknown" ]]; then
      warn "Blocklist fetchedAt is unparseable"
    elif [[ "$fetched_age" -gt 30 ]]; then
      warn "Blocklist fetchedAt is $fetched_age days old — may be stale"
    else
      pass "Blocklist fetchedAt is recent ($fetched_age days)"
    fi
  fi
}

audit_app_req() {
  section "6. App REQ.md Coverage"

  for app in $(discover_apps); do
    if [[ -f "$WORKSPACE_ROOT/$app/REQ.md" ]]; then
      pass "$app has REQ.md"
    else
      fail "$app is missing REQ.md"
    fi
  done
}

print_summary() {
  section "Audit Summary"
  echo -e "  ${GREEN}PASS${NC}: $PASS"
  echo -e "  ${YELLOW}WARN${NC}: $WARN"
  echo -e "  ${RED}FAIL${NC}: $FAIL"

  if [[ "$FAIL" -gt 0 ]]; then
    echo ""
    echo -e "  ${RED}Action required: fix FAIL items above.${NC}"
    return 1
  fi
  return 0
}

main() {
  echo "HarmonyOS Harness Audit — $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "Workspace: $WORKSPACE_ROOT"

  audit_claude_config
  audit_app_inventory
  audit_script_contract
  audit_omc_state
  audit_plugin_hygiene
  audit_app_req
  print_summary
}

main "$@"
