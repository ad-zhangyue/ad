#!/bin/bash

#####################################################################
# COMMON.SH - Shared Utilities for AD Command System
#####################################################################

# Available modules
AVAILABLE_MODULES=("ad-core" "ad-db" "ad-deployment" "ad-gateway" "ad-wp")

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Log functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

# Check if module is valid
is_valid_module() {
    local module="$1"
    for valid_module in "${AVAILABLE_MODULES[@]}"; do
        if [[ "$module" == "$valid_module" ]]; then
            return 0
        fi
    done
    return 1
}

# Validate modules from command line arguments
validate_modules() {
    local modules=("$@")
    local invalid_modules=()
    
    for module in "${modules[@]}"; do
        if ! is_valid_module "$module"; then
            invalid_modules+=("$module")
        fi
    done
    
    if [[ ${#invalid_modules[@]} -gt 0 ]]; then
        log_error "Invalid modules: ${invalid_modules[*]}"
        log_info "Available modules: ${AVAILABLE_MODULES[*]}"
        return 1
    fi
    
    return 0
}

# Get all available actions by scanning scripts directory
get_available_actions() {
    local scripts_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local actions=()
    
    for script in "$scripts_dir"/*.sh; do
        local basename=$(basename "$script" .sh)
        # Exclude common and help scripts
        if [[ "$basename" != "common" ]] && [[ "$basename" != "help" ]]; then
            actions+=("$basename")
        fi
    done
    
    printf '%s\n' "${actions[@]}"
}

# Check if we're in a git repository
check_git_repo() {
    if ! git rev-parse --git-dir &> /dev/null; then
        log_error "Not in a git repository"
        return 1
    fi
    return 0
}
