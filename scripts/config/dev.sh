#!/usr/bin/env bash
# dev.sh - Development environment configuration

# Development API endpoints
export API_BASE_URL="http://localhost:3000"
export DEBUG_MODE="true"

# Build configuration
export BUILD_MODE="debug"
export OUTPUT_DIR="dist/dev"

# DevEco Studio paths (adjust as needed)
export DEVECO_STUDIO_PATH="/Applications/DevEco-Studio.app"
export HARMONY_SDK_PATH="$HOME/Huawei/Sdk"

# Development flags
export ENABLE_HOT_RELOAD="true"
export LOG_LEVEL="debug"
export ENABLE_PROFILING="true"

info "Loaded development configuration"