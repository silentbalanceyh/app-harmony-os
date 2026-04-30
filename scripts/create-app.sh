#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULT_TEMPLATE="$ROOT_DIR/templates/app-template"
APP_CENTER_CONFIG="$ROOT_DIR/app-center/app.json"
APP_CENTER_INDEX="$ROOT_DIR/app-center/entry/src/main/ets/pages/Index.ets"
APP_CENTER_MEDIA_DIR="$ROOT_DIR/app-center/entry/src/main/resources/base/media"

APP_NAME=""
APP_LABEL=""
TEMPLATE_DIR="$DEFAULT_TEMPLATE"
RUN_BUILD="${CREATE_APP_BUILD:-false}"

info() { printf '[INFO] %s\n' "$*"; }
ok() { printf '[OK] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
fail() { printf '[ERROR] %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
Usage: scripts/create-app.sh --name app-example --label "示例应用" [--template templates/app-template] [--build]

Options:
  --name      New app directory name. Must match app-[a-z0-9][a-z0-9-]*.
  --label     Display label written to HarmonyOS resources and app-center.
  --template  Template directory. Defaults to templates/app-template.
  --build     Attempt dev-build for the new app and app-center after creation.
  --help      Show this help.
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --name)
        [[ $# -ge 2 ]] || fail "--name requires a value"
        APP_NAME="$2"
        shift 2
        ;;
      --label)
        [[ $# -ge 2 ]] || fail "--label requires a value"
        APP_LABEL="$2"
        shift 2
        ;;
      --template)
        [[ $# -ge 2 ]] || fail "--template requires a value"
        TEMPLATE_DIR="$2"
        shift 2
        ;;
      --build)
        RUN_BUILD="true"
        shift
        ;;
      --help|-h)
        usage
        exit 0
        ;;
      *)
        fail "Unknown argument: $1"
        ;;
    esac
  done
}

abs_path() {
  local path="$1"
  if [[ "$path" = /* ]]; then
    printf '%s\n' "$path"
  else
    printf '%s\n' "$ROOT_DIR/$path"
  fi
}

validate_input() {
  [[ -n "$APP_NAME" ]] || fail "--name is required"
  [[ -n "$APP_LABEL" ]] || fail "--label is required"
  [[ "$APP_NAME" =~ ^app-[a-z0-9][a-z0-9-]*$ ]] || fail "--name must match app-[a-z0-9][a-z0-9-]*"
  [[ "$APP_NAME" != *"--"* ]] || fail "--name cannot contain consecutive hyphens"
  [[ "$APP_NAME" != *"-" ]] || fail "--name cannot end with a hyphen"

  TEMPLATE_DIR="$(abs_path "$TEMPLATE_DIR")"
  [[ -d "$TEMPLATE_DIR" ]] || fail "Template directory not found: $TEMPLATE_DIR"
  [[ -f "$TEMPLATE_DIR/app.json" ]] || fail "Template is missing app.json: $TEMPLATE_DIR"
  [[ ! -e "$ROOT_DIR/$APP_NAME" ]] || fail "Target app already exists: $ROOT_DIR/$APP_NAME"
  [[ -f "$APP_CENTER_CONFIG" ]] || fail "app-center app.json not found"
  [[ -f "$APP_CENTER_INDEX" ]] || fail "app-center Index.ets not found"
}

bundle_name() {
  local suffix
  suffix="${APP_NAME#app-}"
  suffix="${suffix//-/}"
  printf 'com.zerows.app%s\n' "$suffix"
}

resource_name() {
  printf '%s\n' "$APP_NAME" | tr '-' '_'
}

replace_placeholders() {
  local target_root="$1"
  local bundle="$2"

  find "$target_root" -type f \
    ! -name '*.png' \
    ! -name '*.jpg' \
    ! -name '*.jpeg' \
    ! -name '*.webp' \
    ! -name '*.wav' \
    ! -name '*.hap' \
    ! -name '*.app' \
    -print0 |
    APP_NAME="$APP_NAME" APP_BUNDLE="$bundle" APP_LABEL="$APP_LABEL" \
      xargs -0 perl -pi -e 's/_APP_NAME_/$ENV{APP_NAME}/g; s/_BUNDLE_NAME_/$ENV{APP_BUNDLE}/g; s/_LABEL_/$ENV{APP_LABEL}/g'
}

clean_transient_artifacts() {
  local target_root="$1"
  rm -rf \
    "$target_root/.deveco-sdk-shim" \
    "$target_root/.hvigor" \
    "$target_root/build" \
    "$target_root/entry/build" \
    "$target_root/entry/.preview" \
    "$target_root/.preview"
}

make_scripts_executable() {
  local target_root="$1"
  find "$target_root" -type f -name '*.sh' -exec chmod +x {} +
}

register_app_center_config() {
  python3 - "$APP_CENTER_CONFIG" "$APP_NAME" <<'PY'
import json
import sys

path, app_name = sys.argv[1], sys.argv[2]
with open(path, encoding="utf-8") as f:
    data = json.load(f)

changed = False
for key in ("dependsOn", "launchTargets"):
    value = data.get(key)
    if not isinstance(value, list):
        value = []
    if app_name not in value:
        value.append(app_name)
        changed = True
    data[key] = value

if changed:
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")
PY
}

register_app_center_index() {
  local bundle="$1"
  local media_name="$2"

  set +e
  python3 - "$APP_CENTER_INDEX" "$APP_NAME" "$APP_LABEL" "$bundle" "$media_name" <<'PY'
import sys

path, app_id, label, bundle, media_name = sys.argv[1:6]
with open(path, encoding="utf-8") as f:
    text = f.read()

if f"id: '{app_id}'" in text:
    raise SystemExit(0)

anchor = "  ];"
insert_at = text.find(anchor)
if insert_at < 0:
    print("[WARN] Could not find ManagedApp array insertion anchor in Index.ets", file=sys.stderr)
    raise SystemExit(2)

needs_comma = text[:insert_at].rstrip().endswith("}")
prefix = ",\n" if needs_comma else "\n"
entry = f"""    {{
      id: '{app_id}',
      label: '{label}',
      bundleName: '{bundle}',
      moduleName: 'entry',
      abilityName: 'EntryAbility',
      icon: $r('app.media.{media_name}'),
      iconBgColor: '#F4F7FB',
      iconStrokeColor: '#64748B',
      installed: true,
      stylePreset: 0
    }}
"""

text = text[:insert_at] + prefix + entry + text[insert_at:]
with open(path, "w", encoding="utf-8") as f:
    f.write(text)
PY
  local status="$?"
  set -e
  case "$status" in
    0) ;;
    2) warn "Skipped app-center Index.ets registration; add the ManagedApp entry manually." ;;
    *) fail "Failed to update app-center Index.ets" ;;
  esac
}

create_center_icon_placeholder() {
  local media_name="$1"
  local icon_file="$APP_CENTER_MEDIA_DIR/${media_name}.svg"

  if [[ -f "$icon_file" ]]; then
    return 0
  fi

  mkdir -p "$APP_CENTER_MEDIA_DIR"
  cat >"$icon_file" <<'EOF'
<svg width="128" height="128" viewBox="0 0 64 64" fill="none" xmlns="http://www.w3.org/2000/svg">
  <rect x="12" y="12" width="40" height="40" rx="10" fill="#F8FAFC" stroke="#64748B" stroke-width="3"/>
  <path d="M22 32H42" stroke="#64748B" stroke-width="3" stroke-linecap="round"/>
  <path d="M32 22V42" stroke="#64748B" stroke-width="3" stroke-linecap="round"/>
</svg>
EOF
}

read_sdk_version_path() {
  local sdk_pkg="$1"

  python3 - "$sdk_pkg" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as f:
    data = json.load(f)
print(data.get("data", {}).get("path", ""))
PY
}

create_deveco_run_config() {
  local app_name="$1"
  local version_path="$2"
  local config_file="$ROOT_DIR/.idea/runConfigurations/${APP_NAME}_Entry.xml"

  mkdir -p "$ROOT_DIR/.idea/runConfigurations"
  cat >"$config_file" <<EOF
<component name="ProjectRunConfigurationManager">
  <configuration default="false" name="${app_name}-Entry" type="HvigorRunConfiguration" factoryName="HvigorRunConfiguration">
    <option name="applicationParameters" value="assembleApp -p product=default -p buildMode=debug" />
    <option name="nodeInterpreter" value="\$APPLICATION_HOME_DIR\$/tools/node/bin" />
    <option name="scriptFile" value="\$APPLICATION_HOME_DIR\$/tools/hvigor/bin/hvigorw.js" />
    <option name="workingDir" value="\$PROJECT_DIR\$/${app_name}" />
    <envs>
      <env name="DEVECO_SDK_HOME" value="\$PROJECT_DIR\$/${app_name}/.deveco-sdk-shim" />
      <env name="OHOS_BASE_SDK_HOME" value="\$PROJECT_DIR\$/${app_name}/.deveco-sdk-shim/${version_path}/openharmony" />
    </envs>
    <method v="2" />
  </configuration>
</component>
EOF
}

run_deveco_setup_if_available() {
  local target_root="$1"
  local deveco_path="${DEVECO_STUDIO_PATH:-/Applications/DevEco-Studio.app}"
  local sdk_root="$deveco_path/Contents/sdk/default"
  local sdk_pkg="$sdk_root/sdk-pkg.json"
  local version_path
  local shim_root

  if [[ ! -d "$deveco_path" || ! -f "$sdk_pkg" ]]; then
    warn "DevEco Studio SDK metadata not found; skipping SDK shim/run configuration setup"
    return 0
  fi

  version_path="$(read_sdk_version_path "$sdk_pkg")"
  if [[ -z "$version_path" ]]; then
    warn "Unable to resolve SDK version path; skipping SDK shim/run configuration setup"
    return 0
  fi

  shim_root="$target_root/.deveco-sdk-shim"
  mkdir -p "$shim_root"
  cp "$sdk_pkg" "$shim_root/sdk-pkg.json"
  ln -sfn "$sdk_root" "$shim_root/$version_path"
  create_deveco_run_config "$APP_NAME" "$version_path"
  ok "DevEco SDK shim and run configuration created for $APP_NAME"
}

run_builds_if_requested() {
  if [[ "$RUN_BUILD" != "true" ]]; then
    info "Build verification skipped. Pass --build or CREATE_APP_BUILD=true to attempt builds."
    return 0
  fi

  info "Building $APP_NAME"
  if ! (cd "$ROOT_DIR/$APP_NAME" && ./dev-build.sh); then
    warn "$APP_NAME build failed or environment is unavailable"
  fi

  info "Building app-center"
  if ! (cd "$ROOT_DIR/app-center" && ./dev-build.sh); then
    warn "app-center build failed or environment is unavailable"
  fi
}

main() {
  parse_args "$@"
  validate_input

  local bundle media_name target_root
  bundle="$(bundle_name)"
  media_name="ic_$(resource_name)"
  target_root="$ROOT_DIR/$APP_NAME"

  info "Creating $APP_NAME from $TEMPLATE_DIR"
  cp -R "$TEMPLATE_DIR" "$target_root"
  clean_transient_artifacts "$target_root"
  replace_placeholders "$target_root" "$bundle"
  make_scripts_executable "$target_root"

  register_app_center_config
  create_center_icon_placeholder "$media_name"
  register_app_center_index "$bundle" "$media_name"
  run_deveco_setup_if_available "$target_root"
  run_builds_if_requested

  ok "Created $APP_NAME"
  printf '  Path: %s\n' "$target_root"
  printf '  Bundle: %s\n' "$bundle"
  printf '  Label: %s\n' "$APP_LABEL"
  printf '  Registered in app-center: app.json and Index.ets\n'
}

main "$@"
