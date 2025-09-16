#!/bin/bash

#####################################################################
# HELP.SH - Dynamic Help System for AD Commands
#####################################################################

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Show main help
show_main_help() {
    cat << 'EOF'
AD - Modular Command Tool for AD Project

USAGE:
    ad <action> [options] [arguments...]
    ad --help

DESCRIPTION:
    AD is a modular command-line tool for managing the AD project modules.
    Each action is implemented as a separate script in the scripts/ directory.

GLOBAL OPTIONS:
    --help, -h      Show this help message

AVAILABLE ACTIONS:
EOF

    # Dynamically list available actions
    local actions=($(get_available_actions))
    for action in "${actions[@]}"; do
        printf "    %-12s %s\n" "$action" "$(get_action_description "$action")"
    done

    cat << EOF

MODULES:
    The following modules are available: ${AVAILABLE_MODULES[*]}

EXAMPLES:
    ad pull                     # Pull all modules
    ad pull ad-core ad-db       # Pull specific modules  
    ad pull --help              # Show help for pull command

For detailed help on any action, use:
    ad <action> --help

EOF
}

# Get description for an action by checking its help output
get_action_description() {
    local action="$1"
    local action_script="$SCRIPT_DIR/$action.sh"
    
    if [[ -f "$action_script" ]]; then
        # Try to extract description from the script's help
        case "$action" in
            "pull")
                echo "Pull latest code from GitHub for specified modules"
                ;;
            "sync")
                echo "Sync changes by performing git add, commit, and push"
                ;;
            *)
                echo "Available action (run 'ad $action --help' for details)"
                ;;
        esac
    else
        echo "Unknown action"
    fi
}

# Show help for specific action
show_action_help() {
    local action="$1"
    local action_script="$SCRIPT_DIR/$action.sh"
    
    if [[ -f "$action_script" ]]; then
        # Execute the action script with --help
        "$action_script" --help
    else
        log_error "Unknown action: $action"
        echo "Run 'ad --help' to see available actions."
        exit 2
    fi
}

# Main help function
main() {
    local context="$1"
    
    case "$context" in
        "main"|"")
            show_main_help
            ;;
        *)
            show_action_help "$context"
            ;;
    esac
}

# Run main function with all arguments
main "$@"
