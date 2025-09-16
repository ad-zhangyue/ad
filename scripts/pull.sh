#!/bin/bash

#####################################################################
# PULL.SH - Git Pull Functionality for AD Modules
#####################################################################

set -e

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Show help for pull command
show_help() {
    cat << EOF
Usage: ad pull [OPTIONS] [MODULES...]

Pull latest code from GitHub for specified modules.

OPTIONS:
    --help, -h      Show this help message
    --all           Pull all modules
    --force         Force pull even if there are local changes

MODULES:
    If no modules specified, pulls all modules.
    Available modules: ${AVAILABLE_MODULES[*]}

EXAMPLES:
    ad pull                          # Pull all modules
    ad pull ad-core ad-db            # Pull specific modules
    ad pull --all                    # Pull all modules explicitly  
    ad pull --force ad-core          # Force pull ad-core module
    ad pull --help                   # Show this help

EOF
}

# Pull a single module
pull_module() {
    local module="$1"
    local force="$2"
    
    log_info "Pulling $module..."
    
    if [[ ! -d "$module" ]]; then
        log_error "Module directory '$module' not found"
        return 1
    fi
    
    cd "$module"
    
    # Check for uncommitted changes unless force is specified
    if [[ "$force" != "true" ]] && ! git diff-index --quiet HEAD --; then
        log_warning "Module '$module' has uncommitted changes. Use --force to override."
        cd ..
        return 1
    fi
    
    # Check if we're in a git repository
    if ! check_git_repo; then
        cd ..
        return 1
    fi
    
    # Get current branch
    local current_branch=$(git branch --show-current)
    
    # Pull latest changes
    if git pull origin "$current_branch"; then
        log_success "Successfully pulled $module ($current_branch)"
    else
        log_error "Failed to pull $module"
        cd ..
        return 1
    fi
    
    cd ..
    return 0
}

# Main pull function
main() {
    local modules_to_pull=()
    local force=false
    local pull_all=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help|-h)
                show_help
                exit 0
                ;;
            --all)
                pull_all=true
                shift
                ;;
            --force)
                force=true
                shift
                ;;
            -*)
                log_error "Unknown option: $1"
                echo "Run 'ad pull --help' for usage information."
                exit 2
                ;;
            *)
                modules_to_pull+=("$1")
                shift
                ;;
        esac
    done
    
    # If --all specified or no modules given, use all modules
    if [[ "$pull_all" == "true" ]] || [[ ${#modules_to_pull[@]} -eq 0 ]]; then
        modules_to_pull=("${AVAILABLE_MODULES[@]}")
    fi
    
    # Validate modules
    if ! validate_modules "${modules_to_pull[@]}"; then
        exit 2
    fi
    
    log_info "Starting pull operation for modules: ${modules_to_pull[*]}"
    
    # Track results
    local success_count=0
    local failed_modules=()
    
    # Pull each module
    for module in "${modules_to_pull[@]}"; do
        if pull_module "$module" "$force"; then
            ((success_count++))
        else
            failed_modules+=("$module")
        fi
    done
    
    # Summary
    echo ""
    log_info "Pull operation completed"
    log_success "Successfully pulled: $success_count/${#modules_to_pull[@]} modules"
    
    if [[ ${#failed_modules[@]} -gt 0 ]]; then
        log_warning "Failed modules: ${failed_modules[*]}"
        exit 1
    fi
    
    exit 0
}

# Run main function with all arguments
main "$@"
