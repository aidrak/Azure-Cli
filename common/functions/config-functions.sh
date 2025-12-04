#!/bin/bash

# Configuration management functions for Bash deployment scripts
#
# Purpose: Unified configuration loading, validation, and management
# Usage: source ../common/functions/config-functions.sh
#
# Functions:
#   load_config()           - Load configuration from file
#   validate_config_value() - Validate single configuration value
#   get_config()            - Get config value with fallback
#   set_config()            - Set config value in memory
#   export_config()         - Export configuration to environment
#   list_config()           - List all configuration variables
#   config_is_set()         - Check if config variable is set
#
# Configuration Priority (highest to lowest):
#   1. Environment variables (already set)
#   2. Local config file (passed parameter)
#   3. Centralized config file (../config/avd-config.sh)
#   4. Function defaults (provided in calls)

# Global config storage
declare -gA CONFIG_STORAGE=()
CONFIG_FILE=""
CENTRALIZED_CONFIG=""

# ============================================================================
# Core Configuration Functions
# ============================================================================

# Load configuration from file
# Usage: load_config "path/to/config.env"
load_config() {
    local config_file="${1:-.env}"
    local centralized="${2:-../config/avd-config.sh}"

    # Store file paths for later reference
    CONFIG_FILE="$config_file"
    CENTRALIZED_CONFIG="$centralized"

    # First, load centralized config if it exists
    if [[ -f "$centralized" ]]; then
        # shellcheck source=/dev/null
        source "$centralized"
        log_info "Loaded centralized config: $centralized"
    fi

    # Then, load local config (overrides centralized)
    if [[ -f "$config_file" ]]; then
        # shellcheck source=/dev/null
        source "$config_file"
        log_info "Loaded local config: $config_file"
    else
        log_warning "Configuration file not found: $config_file"
        return 1
    fi

    return 0
}

# Get configuration value with fallback chain
# Usage: get_config "VARIABLE_NAME" "default_value"
# Returns: Value from environment, storage, or default
get_config() {
    local var_name="$1"
    local default_value="${2:-}"

    # Check environment variable first (highest priority)
    if [[ -v "$var_name" ]]; then
        echo "${!var_name}"
        return 0
    fi

    # Check in-memory storage
    if [[ -v CONFIG_STORAGE[$var_name] ]]; then
        echo "${CONFIG_STORAGE[$var_name]}"
        return 0
    fi

    # Return default
    echo "$default_value"
    return 0
}

# Set configuration value in memory
# Usage: set_config "VARIABLE_NAME" "value"
set_config() {
    local var_name="$1"
    local value="$2"

    CONFIG_STORAGE[$var_name]="$value"

    # Also set as environment variable for access in subshells
    export "$var_name"="$value"
}

# Check if configuration variable is set (not empty)
# Usage: if config_is_set "VARIABLE_NAME"; then ... fi
config_is_set() {
    local var_name="$1"

    # Check environment first
    if [[ -v "$var_name" ]] && [[ -n "${!var_name}" ]]; then
        return 0
    fi

    # Check storage
    if [[ -v CONFIG_STORAGE[$var_name] ]] && [[ -n "${CONFIG_STORAGE[$var_name]}" ]]; then
        return 0
    fi

    return 1
}

# ============================================================================
# Configuration Validation
# ============================================================================

# Validate a single configuration value
# Usage: validate_config_value "VARIABLE_NAME" "pattern" "error_message"
validate_config_value() {
    local var_name="$1"
    local pattern="$2"
    local error_message="${3:-Invalid value for $var_name}"

    local value
    value=$(get_config "$var_name")

    if [[ -z "$value" ]]; then
        log_error "Configuration value not set: $var_name"
        return 1
    fi

    if [[ ! "$value" =~ $pattern ]]; then
        log_error "$error_message (got: $value)"
        return 1
    fi

    return 0
}

# Validate required configuration variables
# Usage: validate_required_config "VAR1" "VAR2" "VAR3"
validate_required_config() {
    local error_count=0

    for var_name in "$@"; do
        if ! config_is_set "$var_name"; then
            log_error "Required configuration missing: $var_name"
            ((error_count++))
        fi
    done

    if [[ $error_count -gt 0 ]]; then
        log_error "Missing $error_count required configuration variables"
        return 1
    fi

    return 0
}

# Validate Azure resource naming conventions
# Usage: validate_azure_name "resource-name" "storage" "lowercase with hyphens"
validate_azure_name() {
    local name="$1"
    local resource_type="$2"
    local allowed_chars="${3:-a-z0-9}"

    if [[ ! "$name" =~ ^[$allowed_chars]+$ ]]; then
        log_error "Invalid name for $resource_type: $name (allowed: $allowed_chars)"
        return 1
    fi

    return 0
}

# Validate CIDR block format
# Usage: validate_cidr "10.0.0.0/16"
validate_cidr() {
    local cidr="$1"

    if [[ ! "$cidr" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}$ ]]; then
        log_error "Invalid CIDR block: $cidr"
        return 1
    fi

    return 0
}

# ============================================================================
# Configuration Export & Output
# ============================================================================

# Export configuration to environment variables
# Usage: export_config
export_config() {
    local count=0

    for var_name in "${!CONFIG_STORAGE[@]}"; do
        export "$var_name"="${CONFIG_STORAGE[$var_name]}"
        ((count++))
    done

    log_info "Exported $count configuration variables to environment"
}

# List all configuration variables
# Usage: list_config
list_config() {
    log_section "Current Configuration"

    # Get all variable names from environment and storage
    local var_name

    # From storage
    for var_name in "${!CONFIG_STORAGE[@]}"; do
        printf "%-40s = %s\n" "$var_name" "${CONFIG_STORAGE[$var_name]}"
    done

    # From environment (variables matching pattern)
    local pattern="${1:-.*}"
    while IFS= read -r var_line; do
        var_name=$(echo "$var_line" | cut -d= -f1)
        if [[ "$var_name" =~ $pattern ]]; then
            echo "$var_line"
        fi
    done < <(env | grep "=" | grep -E "(AVD|VD|CONFIG|RESOURCE|ADMIN|VM_|LOCATION|SUBSCRIPTION)" | sort)
}

# Save configuration to file (for backup/documentation)
# Usage: save_config "path/to/output.env"
save_config() {
    local output_file="${1:-config-backup.env}"

    {
        echo "# Configuration backup"
        echo "# Generated: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
        echo ""

        for var_name in "${!CONFIG_STORAGE[@]}"; do
            local value="${CONFIG_STORAGE[$var_name]}"
            # Escape quotes in values
            value="${value//\"/\\\"}"
            echo "export ${var_name}=\"${value}\""
        done
    } > "$output_file"

    log_success "Configuration saved to: $output_file"
}

# ============================================================================
# Configuration Checking Utilities
# ============================================================================

# Check if value is a valid Azure subscription ID (GUID)
# Usage: is_valid_subscription_id "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
is_valid_subscription_id() {
    local id="$1"

    if [[ ! "$id" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]; then
        return 1
    fi

    return 0
}

# Check if value is valid Azure resource group name
# Usage: is_valid_rg_name "RG-Azure-VDI-01"
is_valid_rg_name() {
    local name="$1"

    # Azure RG names: 1-90 chars, alphanumerics, hyphens, underscores, periods
    if [[ ! "$name" =~ ^[a-zA-Z0-9._-]{1,90}$ ]]; then
        return 1
    fi

    return 0
}

# Check if location is valid (basic list)
# Usage: is_valid_location "centralus"
is_valid_location() {
    local location="$1"

    # Common Azure regions
    local valid_locations=(
        "eastus" "eastus2" "westus" "westus2" "centralus"
        "northcentralus" "southcentralus"
        "westeurope" "northeurope"
        "southeastasia" "eastasia"
        "australiaeast" "australiasoutheast"
        "japaneast" "japanwest"
        "canadacentral" "canadaeast"
        "uksouth" "ukwest"
    )

    for region in "${valid_locations[@]}"; do
        if [[ "$location" == "$region" ]]; then
            return 0
        fi
    done

    return 1
}

# ============================================================================
# Configuration Templates
# ============================================================================

# Get a config template for a resource type
# Usage: get_config_template "storage"
get_config_template() {
    local resource_type="$1"

    case "$resource_type" in
        storage)
            cat <<'EOF'
# Storage configuration
STORAGE_ACCOUNT_NAME=""              # Must be globally unique, lowercase, no hyphens
STORAGE_ACCOUNT_SKU="Standard_LRS"   # Standard_LRS, Standard_GRS, Standard_RAGRS, Premium_LRS
STORAGE_ACCOUNT_KIND="StorageV2"     # Storage, StorageV2, BlobStorage, BlockBlobStorage
STORAGE_ACCOUNT_TIER="Hot"           # Hot, Cool, Archive
FILE_SHARE_QUOTA="100"               # Size in GB
EOF
            ;;
        network)
            cat <<'EOF'
# Network configuration
VNET_NAME=""                         # Virtual network name
VNET_CIDR="10.0.0.0/16"             # Address space for VNet
SUBNET_NAME=""                       # Subnet name
SUBNET_CIDR="10.0.1.0/24"           # Subnet address range
NSG_NAME=""                          # Network security group
EOF
            ;;
        vm)
            cat <<'EOF'
# VM configuration
VM_SIZE="Standard_D4s_v5"            # VM size SKU
VM_IMAGE="UbuntuLTS"                 # Image URN or custom image
ADMIN_USERNAME="azureuser"           # Admin username
OS_DISK_SIZE="128"                   # OS disk size in GB
EOF
            ;;
        *)
            log_error "Unknown resource type: $resource_type"
            return 1
            ;;
    esac
}

# ============================================================================
# Initialization
# ============================================================================

# Require logging functions to be loaded first
if ! declare -f log_info &>/dev/null; then
    # Minimal logging fallback if logging functions not loaded
    log_info() { echo "INFO: $*"; }
    log_error() { echo "ERROR: $*" >&2; }
    log_warning() { echo "WARNING: $*"; }
fi

# Export all functions for use in subshells
export -f load_config
export -f get_config
export -f set_config
export -f config_is_set
export -f validate_config_value
export -f validate_required_config
export -f validate_azure_name
export -f validate_cidr
export -f export_config
export -f list_config
export -f save_config
export -f is_valid_subscription_id
export -f is_valid_rg_name
export -f is_valid_location
export -f get_config_template
