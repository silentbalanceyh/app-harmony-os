#!/usr/bin/env bash
# prod.sh - Production environment configuration

# Production API endpoints
export API_BASE_URL="https://api.production.com"
export DEBUG_MODE="false"

# Build configuration
export BUILD_MODE="release"
export OUTPUT_DIR="dist/prod"

# DevEco Studio paths (adjust as needed)
export DEVECO_STUDIO_PATH="/Applications/DevEco-Studio.app"
export HARMONY_SDK_PATH="$HOME/Huawei/Sdk"

# Production flags
export ENABLE_HOT_RELOAD="false"
export LOG_LEVEL="warn"
export ENABLE_PROFILING="false"

info "Loaded production configuration"