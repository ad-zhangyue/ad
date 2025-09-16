#!/bin/bash

#####################################################################
# AD.SH - Main Command Dispatcher
#####################################################################
# 
# STYLE GUIDELINES FOR AD.SH:
# - Keep this file minimal - it should only dispatch commands
# - All main functionality goes in scripts/[action].sh files
# - Command format: ad action [module] [options]
# - Each action should have its own script in scripts/ folder
# - Use scripts/common.sh for shared utilities
# - Help system should be dynamic and auto-discover available actions
# - Always validate input and provide clear error messages
# - Use consistent exit codes (0=success, 1=error, 2=usage error)
# - Support both --help and -h flags for all commands
# - Module names: ad-core, ad-db, ad-deployment, ad-gateway, ad-wp
#
#####################################################################

set -e  # Exit on any error

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$SCRIPT_DIR/scripts"

# Source common utilities
source "$SCRIPTS_DIR/common.sh"

# Main function
main() {
    local action="$1"
    
    # Handle empty command or help flags
    if [[ $# -eq 0 ]] || [[ "$action" == "--help" ]] || [[ "$action" == "-h" ]]; then
        "$SCRIPTS_DIR/help.sh" "main"
        exit 0
    fi
    
    # Validate action exists
    local action_script="$SCRIPTS_DIR/$action.sh"
    if [[ ! -f "$action_script" ]]; then
        echo "Error: Unknown action '$action'"
        echo "Run 'ad --help' to see available actions."
        exit 2
    fi
    
    # Dispatch to action script
    shift  # Remove action from arguments
    "$action_script" "$@"
}

# Run main function with all arguments
main "$@"
