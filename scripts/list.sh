#!/bin/bash

#####################################################################
# LIST.SH - List Information about AD Modules and Services
#####################################################################

set -e

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Show help for list command
show_help() {
    cat << EOF
Usage: ad list [OPTIONS] [MODULES...]

List information about AD modules and services.

OPTIONS:
    --help, -h      Show this help message
    --port          List service ports for modules
    --modules       List all available modules
    --all           Apply operation to all modules (used with --port)

MODULES:
    If specific modules are provided with --port, only those modules are checked.
    Available modules: ${AVAILABLE_MODULES[*]}

EXAMPLES:
    ad list --modules                   # List all available modules
    ad list --port                      # List ports for all modules  
    ad list --port ad-core ad-gateway   # List ports for specific modules
    ad list --port --all                # List ports for all modules (explicit)
    ad list --help                      # Show this help

NOTES:
    - Port information is extracted from application.yml and k8s service files
    - Module listing shows status and basic information
    - Use specific module names to filter results

EOF
}

# Extract port from Spring Boot application.yml
extract_spring_port() {
    local module="$1"
    local app_yml="$module/src/main/resources/application.yml"
    
    if [[ -f "$app_yml" ]]; then
        # Look for server.port or server: port: pattern
        grep -E "^\s*port:\s*[0-9]+" "$app_yml" 2>/dev/null | head -1 | grep -oE '[0-9]+' || echo ""
    fi
}

# Extract port from Kubernetes service.yml
extract_k8s_port() {
    local module="$1"
    local service_yml="$module/k8s/service.yml"
    
    if [[ -f "$service_yml" ]]; then
        # Look for port: number in the ports section
        grep -A 5 "ports:" "$service_yml" 2>/dev/null | grep -E "^\s*-?\s*port:\s*[0-9]+" | head -1 | grep -oE '[0-9]+' || echo ""
    fi
}

# Extract nodePort from Kubernetes service.yml
extract_k8s_nodeport() {
    local module="$1"
    local service_yml="$module/k8s/service.yml"
    
    if [[ -f "$service_yml" ]]; then
        # Look for nodePort: number
        grep -E "^\s*nodePort:\s*[0-9]+" "$service_yml" 2>/dev/null | head -1 | grep -oE '[0-9]+' || echo ""
    fi
}

# Extract port forward from Tiltfile
extract_tilt_port() {
    local module="$1"
    local tiltfile="$module/Tiltfile"
    
    if [[ -f "$tiltfile" ]]; then
        # Look for port_forwards=['XXXX:YYYY'] pattern
        grep -oE "port_forwards=\['[0-9]+:[0-9]+'\]" "$tiltfile" 2>/dev/null | grep -oE '[0-9]+:[0-9]+' || echo ""
    fi
}

# Get comprehensive port information for a module
get_module_ports() {
    local module="$1"
    
    if [[ ! -d "$module" ]]; then
        echo "N/A (module not found)"
        return 1
    fi
    
    local spring_port=$(extract_spring_port "$module")
    local k8s_port=$(extract_k8s_port "$module")
    local node_port=$(extract_k8s_nodeport "$module")
    local tilt_port=$(extract_tilt_port "$module")
    
    local port_info=""
    
    # Primary port (prefer Spring Boot config, then K8s)
    local primary_port=""
    if [[ -n "$spring_port" ]]; then
        primary_port="$spring_port"
        port_info="$primary_port (app)"
    elif [[ -n "$k8s_port" ]]; then
        primary_port="$k8s_port"
        port_info="$primary_port (k8s)"
    fi
    
    # Add additional port information
    local additional_ports=()
    
    if [[ -n "$node_port" && "$node_port" != "$primary_port" ]]; then
        additional_ports+=("NodePort: $node_port")
    fi
    
    if [[ -n "$tilt_port" ]]; then
        additional_ports+=("Tilt: $tilt_port")
    fi
    
    if [[ ${#additional_ports[@]} -gt 0 ]]; then
        port_info="$port_info, ${additional_ports[*]}"
    fi
    
    if [[ -z "$port_info" ]]; then
        echo "N/A (no port config found)"
    else
        echo "$port_info"
    fi
}

# List ports for specified modules
list_ports() {
    local modules_to_check=("$@")
    
    if [[ ${#modules_to_check[@]} -eq 0 ]]; then
        modules_to_check=("${AVAILABLE_MODULES[@]}")
    fi
    
    log_info "Service Port Information:"
    echo ""
    
    # Calculate max width for alignment
    local max_width=0
    for module in "${modules_to_check[@]}"; do
        if [[ ${#module} -gt $max_width ]]; then
            max_width=${#module}
        fi
    done
    ((max_width += 2)) # Add some padding
    
    # Print header
    printf "%-${max_width}s %s\n" "MODULE" "PORTS"
    printf "%-${max_width}s %s\n" "$(printf '%*s' $max_width | tr ' ' '-')" "$(printf '%*s' 50 | tr ' ' '-')"
    
    # Print module port information
    for module in "${modules_to_check[@]}"; do
        local port_info=$(get_module_ports "$module")
        printf "%-${max_width}s %s\n" "$module" "$port_info"
    done
    
    echo ""
}

# List all available modules
list_modules() {
    log_info "Available AD Modules:"
    echo ""
    
    # Calculate max width for alignment
    local max_width=0
    for module in "${AVAILABLE_MODULES[@]}"; do
        if [[ ${#module} -gt $max_width ]]; then
            max_width=${#module}
        fi
    done
    ((max_width += 2)) # Add some padding
    
    # Print header
    printf "%-${max_width}s %-12s %s\n" "MODULE" "STATUS" "DESCRIPTION"
    printf "%-${max_width}s %-12s %s\n" "$(printf '%*s' $max_width | tr ' ' '-')" "$(printf '%*s' 12 | tr ' ' '-')" "$(printf '%*s' 30 | tr ' ' '-')"
    
    # Print module information
    for module in "${AVAILABLE_MODULES[@]}"; do
        local status="Unknown"
        local description="AD module"
        
        if [[ -d "$module" ]]; then
            if [[ -d "$module/.git" ]] || (cd "$module" && git rev-parse --git-dir &>/dev/null); then
                status="Available"
            else
                status="Not Git Repo"
            fi
        else
            status="Missing"
        fi
        
        # Add specific descriptions based on module name
        case "$module" in
            "ad-core")
                description="Core application service"
                ;;
            "ad-gateway")
                description="API gateway service"
                ;;
            "ad-db")
                description="Database service"
                ;;
            "ad-deployment")
                description="Deployment configurations"
                ;;
            "ad-wp")
                description="WordPress integration service"
                ;;
        esac
        
        # Color code status
        local colored_status
        case "$status" in
            "Available")
                colored_status="${GREEN}$status${NC}"
                ;;
            "Missing")
                colored_status="${RED}$status${NC}"
                ;;
            *)
                colored_status="${YELLOW}$status${NC}"
                ;;
        esac
        
        printf "%-${max_width}s %-12s %s\n" "$module" "$(echo -e "$colored_status")" "$description"
    done
    
    echo ""
}

# Main list function
main() {
    local show_ports=false
    local show_modules=false
    local modules_to_process=()
    local show_all=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help|-h)
                show_help
                exit 0
                ;;
            --port)
                show_ports=true
                shift
                ;;
            --modules)
                show_modules=true
                shift
                ;;
            --all)
                show_all=true
                shift
                ;;
            -*)
                log_error "Unknown option: $1"
                echo "Run 'ad list --help' for usage information."
                exit 2
                ;;
            *)
                modules_to_process+=("$1")
                shift
                ;;
        esac
    done
    
    # Validate that at least one action is specified
    if [[ "$show_ports" == "false" && "$show_modules" == "false" ]]; then
        log_error "No action specified. Use --port or --modules."
        echo "Run 'ad list --help' for usage information."
        exit 2
    fi
    
    # Validate modules if specified
    if [[ ${#modules_to_process[@]} -gt 0 ]] && ! validate_modules "${modules_to_process[@]}"; then
        exit 2
    fi
    
    # Execute requested actions
    if [[ "$show_modules" == "true" ]]; then
        list_modules
    fi
    
    if [[ "$show_ports" == "true" ]]; then
        # If --all is specified or no specific modules given, use all modules
        if [[ "$show_all" == "true" ]] || [[ ${#modules_to_process[@]} -eq 0 ]]; then
            list_ports
        else
            list_ports "${modules_to_process[@]}"
        fi
    fi
    
    exit 0
}

# Run main function with all arguments
main "$@"
