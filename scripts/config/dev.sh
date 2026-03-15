#!/usr/bin/env bash
# dev.sh - Development environment configuration

# Development API endpoints
export API_BASE_URL="${API_BASE_URL:-http://localhost:3000}"
export DEBUG_MODE="${DEBUG_MODE:-true}"

# Build configuration
export BUILD_MODE="debug"
export OUTPUT_DIR="dist/dev"

# DevEco Studio paths (override via env if needed)
export DEVECO_STUDIO_PATH="${DEVECO_STUDIO_PATH:-/Applications/DevEco-Studio.app}"

# Default SDK path inside DevEco Studio
export HARMONY_SDK_PATH="${HARMONY_SDK_PATH:-$DEVECO_STUDIO_PATH/Contents/sdk/default/openharmony}"

# Add hvigor + toolchains to PATH so hvigorw/hdc are discoverable
if [[ -d "$DEVECO_STUDIO_PATH/Contents/tools/hvigor/bin" ]]; then
  export PATH="$DEVECO_STUDIO_PATH/Contents/tools/hvigor/bin:$PATH"
fi
if [[ -d "$HARMONY_SDK_PATH/toolchains" ]]; then
  export PATH="$HARMONY_SDK_PATH/toolchains:$PATH"
fi

# Development flags
export ENABLE_HOT_RELOAD="${ENABLE_HOT_RELOAD:-true}"
export LOG_LEVEL="${LOG_LEVEL:-debug}"
export ENABLE_PROFILING="${ENABLE_PROFILING:-true}"

info "Loaded development configuration"

if [[ -f "$HOME/.r2morc.dev" ]]; then source "$HOME/.r2morc.dev"; fi
