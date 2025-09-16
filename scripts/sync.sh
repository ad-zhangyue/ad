#!/bin/bash

#####################################################################
# SYNC.SH - Git Add, Commit, and Push Functionality for AD Modules
#####################################################################

set -e

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Show help for sync command
show_help() {
    cat << EOF
Usage: ad sync [OPTIONS] [MODULES...]

Sync changes by performing git add, commit, and push for specified modules or parent repo.

OPTIONS:
    --help, -h          Show this help message
    --all               Sync all modules
    --message, -m MSG   Custom commit message (default: auto-generated)
    --force             Force push (use with caution)
    --dry-run           Show what would be done without executing

TARGETS:
    .                   Sync the parent repository (current directory)
    [MODULES...]        Sync specific modules
    If no target specified and not using --all, syncs parent repo

MODULES:
    Available modules: ${AVAILABLE_MODULES[*]}

EXAMPLES:
    ad sync .                           # Sync parent repository
    ad sync ad-core ad-db              # Sync specific modules
    ad sync --all                      # Sync all modules
    ad sync --all -m "Update all"      # Sync all with custom message
    ad sync ad-core --force            # Force push ad-core module
    ad sync --dry-run .                # See what would happen to parent repo
    ad sync --help                     # Show this help

NOTES:
    - Will automatically generate commit messages if none provided
    - Checks for uncommitted changes before proceeding
    - Supports both parent repo and submodule syncing
    - Use --force carefully as it can overwrite remote changes

EOF
}

# Generate automatic commit message based on changes
generate_commit_message() {
    local target="$1"
    local changes_count
    
    if [[ "$target" == "." ]]; then
        changes_count=$(git diff --cached --name-only | wc -l | tr -d ' ')
        if [[ $changes_count -eq 1 ]]; then
            echo "Update $(git diff --cached --name-only)"
        else
            echo "Update $changes_count files"
        fi
    else
        echo "Update $target module"
    fi
}

# Sync a single target (module or parent repo)
sync_target() {
    local target="$1"
    local commit_message="$2" 
    local force="$3"
    local dry_run="$4"
    local original_dir="$(pwd)"
    
    log_info "Syncing $target..."
    
    # Handle parent repo case
    if [[ "$target" == "." ]]; then
        if [[ "$dry_run" == "true" ]]; then
            log_info "Would sync parent repository:"
            git status --porcelain | head -10
            return 0
        fi
        
        # Check if there are changes to stage
        if git diff --quiet && git diff --cached --quiet; then
            log_warning "No changes to sync in parent repository"
            return 0
        fi
        
        # Add all changes
        git add .
        
        # Generate commit message if not provided
        if [[ -z "$commit_message" ]]; then
            commit_message=$(generate_commit_message ".")
        fi
        
        # Commit changes
        if git diff --cached --quiet; then
            log_warning "No staged changes to commit in parent repository"
            return 0
        fi
        
        git commit -m "$commit_message"
        
        # Push changes
        local current_branch=$(git branch --show-current)
        if [[ "$force" == "true" ]]; then
            git push --force origin "$current_branch"
        else
            git push origin "$current_branch"
        fi
        
        log_success "Successfully synced parent repository ($current_branch)"
        return 0
    fi
    
    # Handle module case
    if [[ ! -d "$target" ]]; then
        log_error "Module directory '$target' not found"
        return 1
    fi
    
    cd "$target"
    
    # Check if it's a git repository
    if ! check_git_repo; then
        cd "$original_dir"
        return 1
    fi
    
    if [[ "$dry_run" == "true" ]]; then
        log_info "Would sync module $target:"
        git status --porcelain | head -10
        cd "$original_dir"
        return 0
    fi
    
    # Check if there are changes to stage
    if git diff --quiet && git diff --cached --quiet; then
        log_warning "No changes to sync in $target"
        cd "$original_dir"
        return 0
    fi
    
    # Add all changes
    git add .
    
    # Generate commit message if not provided
    if [[ -z "$commit_message" ]]; then
        commit_message=$(generate_commit_message "$target")
    fi
    
    # Commit changes
    if git diff --cached --quiet; then
        log_warning "No staged changes to commit in $target"
        cd "$original_dir"
        return 0
    fi
    
    git commit -m "$commit_message"
    
    # Push changes
    local current_branch=$(git branch --show-current)
    if [[ -z "$current_branch" ]]; then
        log_error "Module $target is in detached HEAD state. Please checkout a branch first."
        cd "$original_dir"
        return 1
    fi
    
    if [[ "$force" == "true" ]]; then
        git push --force origin "$current_branch"
    else
        git push origin "$current_branch"  
    fi
    
    log_success "Successfully synced $target ($current_branch)"
    cd "$original_dir"
    return 0
}

# Main sync function
main() {
    local targets_to_sync=()
    local commit_message=""
    local force=false
    local sync_all=false
    local dry_run=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help|-h)
                show_help
                exit 0
                ;;
            --all)
                sync_all=true
                shift
                ;;
            --message|-m)
                if [[ -n "$2" && "$2" != -* ]]; then
                    commit_message="$2"
                    shift 2
                else
                    log_error "--message requires a commit message"
                    exit 2
                fi
                ;;
            --force)
                force=true
                shift
                ;;
            --dry-run)
                dry_run=true
                shift
                ;;
            -*)
                log_error "Unknown option: $1"
                echo "Run 'ad sync --help' for usage information."
                exit 2
                ;;
            *)
                targets_to_sync+=("$1")
                shift
                ;;
        esac
    done
    
    # Determine what to sync
    if [[ "$sync_all" == "true" ]]; then
        if [[ ${#targets_to_sync[@]} -gt 0 ]]; then
            log_error "Cannot specify both --all and specific targets"
            exit 2
        fi
        targets_to_sync=("${AVAILABLE_MODULES[@]}")
    elif [[ ${#targets_to_sync[@]} -eq 0 ]]; then
        # Default to parent repo if nothing specified
        targets_to_sync=(".")
    fi
    
    # Validate modules (skip validation for parent repo ".")
    local modules_to_validate=()
    for target in "${targets_to_sync[@]}"; do
        if [[ "$target" != "." ]]; then
            modules_to_validate+=("$target")
        fi
    done
    
    if [[ ${#modules_to_validate[@]} -gt 0 ]] && ! validate_modules "${modules_to_validate[@]}"; then
        exit 2
    fi
    
    if [[ "$dry_run" == "true" ]]; then
        log_info "DRY RUN: Showing what would be synced"
    else
        log_info "Starting sync operation for: ${targets_to_sync[*]}"
    fi
    
    # Track results
    local success_count=0
    local failed_targets=()
    
    # Sync each target
    for target in "${targets_to_sync[@]}"; do
        if sync_target "$target" "$commit_message" "$force" "$dry_run"; then
            ((success_count++))
        else
            failed_targets+=("$target")
        fi
    done
    
    # Summary
    echo ""
    if [[ "$dry_run" == "true" ]]; then
        log_info "Dry run completed"
    else
        log_info "Sync operation completed"
        log_success "Successfully synced: $success_count/${#targets_to_sync[@]} targets"
        
        if [[ ${#failed_targets[@]} -gt 0 ]]; then
            log_warning "Failed targets: ${failed_targets[*]}"
            exit 1
        fi
    fi
    
    exit 0
}

# Run main function with all arguments
main "$@"
