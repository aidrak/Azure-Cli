#!/bin/bash
# ==============================================================================
# Value Resolver - Dynamic Configuration Value Resolution Pipeline
# ==============================================================================
#
# Purpose: Resolve configuration values dynamically using a priority pipeline:
#          1. User-specified (environment variable or runtime parameter)
#          2. Azure Discovery (check state.db cache, then query Azure)
#          3. Config Defaults (from standards.yaml or config.yaml)
#          4. Interactive Prompt (ask user if in interactive mode)
#
# Usage:
#   source core/value-resolver.sh
#   resolve_value "STORAGE_ACCOUNT_NAME" "storage"
#   resolve_value "NETWORKING_VNET_NAME" "networking" '{"purpose":"avd"}'
#
# ==============================================================================

set -euo pipefail

# Project paths
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
STANDARDS_FILE="${PROJECT_ROOT}/standards.yaml"
CONFIG_FILE="${PROJECT_ROOT}/config.yaml"
SECRETS_FILE="${PROJECT_ROOT}/secrets.yaml"
STATE_DB="${PROJECT_ROOT}/state.db"

# Resolution mode
INTERACTIVE_MODE="${INTERACTIVE_MODE:-true}"
DISCOVERY_ENABLED="${DISCOVERY_ENABLED:-true}"

# Source dependencies (optional - graceful fallback if not available)
[[ -f "${PROJECT_ROOT}/core/naming-analyzer.sh" ]] && source "${PROJECT_ROOT}/core/naming-analyzer.sh"

# ==============================================================================
# MAIN RESOLUTION FUNCTION
# ==============================================================================

# Resolve a configuration value using the priority pipeline
# Usage: resolve_value "VARIABLE_NAME" "context" '{"key":"value"}'
# Returns: Resolved value or empty string
resolve_value() {
    local var_name="$1"
    local context="${2:-}"
    local context_json="${3:-"{}"}"

    local resolved=""
    local source=""

    # Priority 1: User-specified (environment variable)
    resolved=$(resolve_from_environment "$var_name")
    if [[ -n "$resolved" && "$resolved" != "null" ]]; then
        source="environment"
        echo "$resolved"
        log_resolution "$var_name" "$resolved" "$source"
        return 0
    fi

    # Priority 2: Azure Discovery (if enabled)
    if [[ "$DISCOVERY_ENABLED" == "true" ]]; then
        resolved=$(resolve_from_discovery "$var_name" "$context" "$context_json")
        if [[ -n "$resolved" && "$resolved" != "null" ]]; then
            source="discovery"
            echo "$resolved"
            log_resolution "$var_name" "$resolved" "$source"
            return 0
        fi
    fi

    # Priority 3: Config defaults (standards.yaml, then config.yaml)
    resolved=$(resolve_from_standards "$var_name")
    if [[ -n "$resolved" && "$resolved" != "null" ]]; then
        source="standards"
        echo "$resolved"
        log_resolution "$var_name" "$resolved" "$source"
        return 0
    fi

    resolved=$(resolve_from_config "$var_name")
    if [[ -n "$resolved" && "$resolved" != "null" ]]; then
        source="config"
        echo "$resolved"
        log_resolution "$var_name" "$resolved" "$source"
        return 0
    fi

    # Priority 4: Interactive prompt (if in interactive mode)
    if [[ "$INTERACTIVE_MODE" == "true" ]]; then
        resolved=$(prompt_for_value "$var_name" "$context")
        if [[ -n "$resolved" ]]; then
            source="user_input"
            echo "$resolved"
            log_resolution "$var_name" "$resolved" "$source"
            # Cache the user-provided value
            cache_resolved_value "$var_name" "$resolved" "$source"
            return 0
        fi
    fi

    # No value found
    log_resolution "$var_name" "" "not_found"
    return 1
}

# ==============================================================================
# RESOLUTION SOURCES
# ==============================================================================

# Resolve from environment variable
resolve_from_environment() {
    local var_name="$1"

    # Direct environment variable check
    if [[ -n "${!var_name:-}" ]]; then
        echo "${!var_name}"
        return 0
    fi

    return 1
}

# Resolve from Azure discovery
resolve_from_discovery() {
    local var_name="$1"
    local context="${2:-}"
    local context_json="${3:-"{}"}"

    # Check state.db cache first
    local cached
    cached=$(get_cached_value "$var_name")
    if [[ -n "$cached" && "$cached" != "null" ]]; then
        echo "$cached"
        return 0
    fi

    # Map variable name to resource type for discovery
    local resource_type
    resource_type=$(map_var_to_resource_type "$var_name")

    if [[ -z "$resource_type" ]]; then
        return 1
    fi

    # For name variables, propose a name based on discovered patterns
    if [[ "$var_name" == *_NAME || "$var_name" == *_name ]]; then
        if type propose_name &>/dev/null; then
            local proposed
            proposed=$(propose_name "$resource_type" "$context_json" "${AZURE_RESOURCE_GROUP:-}" 2>/dev/null)
            if [[ -n "$proposed" ]]; then
                echo "$proposed"
                return 0
            fi
        fi
    fi

    return 1
}

# Resolve from standards.yaml
resolve_from_standards() {
    local var_name="$1"

    [[ ! -f "$STANDARDS_FILE" ]] && return 1

    # Map variable name to YAML path
    local yaml_path
    yaml_path=$(map_var_to_yaml_path "$var_name" "standards")

    if [[ -z "$yaml_path" ]]; then
        return 1
    fi

    local value
    value=$(yq e "$yaml_path" "$STANDARDS_FILE" 2>/dev/null)

    if [[ -n "$value" && "$value" != "null" ]]; then
        echo "$value"
        return 0
    fi

    return 1
}

# Resolve from config.yaml (legacy support)
resolve_from_config() {
    local var_name="$1"

    [[ ! -f "$CONFIG_FILE" ]] && return 1

    # Map variable name to YAML path
    local yaml_path
    yaml_path=$(map_var_to_yaml_path "$var_name" "config")

    if [[ -z "$yaml_path" ]]; then
        return 1
    fi

    local value
    value=$(yq e "$yaml_path" "$CONFIG_FILE" 2>/dev/null)

    if [[ -n "$value" && "$value" != "null" ]]; then
        echo "$value"
        return 0
    fi

    return 1
}

# ==============================================================================
# CACHING
# ==============================================================================

# Get cached resolved value from state.db
get_cached_value() {
    local var_name="$1"

    [[ ! -f "$STATE_DB" ]] && return 1

    # Check if table exists
    local table_exists
    table_exists=$(sqlite3 "$STATE_DB" "SELECT name FROM sqlite_master WHERE type='table' AND name='config_overrides';" 2>/dev/null)
    [[ -z "$table_exists" ]] && return 1

    local cache_ttl=1800  # 30 minutes
    local now
    now=$(date +%s)
    local min_time=$((now - cache_ttl))

    # Escape var_name for SQL
    local escaped_var_name
    escaped_var_name=$(echo "$var_name" | sed "s/'/''/g")

    local value
    value=$(sqlite3 "$STATE_DB" \
        "SELECT value FROM config_overrides
         WHERE config_key = '$escaped_var_name'
         AND (expires_at IS NULL OR expires_at > $now)
         AND set_at > $min_time
         LIMIT 1;" 2>/dev/null)

    if [[ -n "$value" ]]; then
        echo "$value"
        return 0
    fi

    return 1
}

# Cache resolved value in state.db
cache_resolved_value() {
    local var_name="$1"
    local value="$2"
    local source="${3:-user_input}"

    [[ ! -f "$STATE_DB" ]] && return 0

    # Check if table exists
    local table_exists
    table_exists=$(sqlite3 "$STATE_DB" "SELECT name FROM sqlite_master WHERE type='table' AND name='config_overrides';" 2>/dev/null)
    [[ -z "$table_exists" ]] && return 0

    local now
    now=$(date +%s)

    # Escape all values for SQL
    local escaped_var_name escaped_source escaped_value
    escaped_var_name=$(echo "$var_name" | sed "s/'/''/g")
    escaped_source=$(echo "$source" | sed "s/'/''/g")
    escaped_value=$(echo "$value" | sed "s/'/''/g")

    sqlite3 "$STATE_DB" <<EOF
INSERT OR REPLACE INTO config_overrides (config_key, source, value, set_at)
VALUES ('$escaped_var_name', '$escaped_source', '$escaped_value', $now);
EOF
}

# ==============================================================================
# VARIABLE MAPPING
# ==============================================================================

# Map environment variable name to resource type
map_var_to_resource_type() {
    local var_name="$1"

    case "$var_name" in
        *VNET*|*VIRTUAL_NETWORK*)
            echo "vnet"
            ;;
        *SUBNET*)
            echo "subnet"
            ;;
        *NSG*|*NETWORK_SECURITY*)
            echo "nsg"
            ;;
        *STORAGE*ACCOUNT*|STORAGE_ACCOUNT_NAME)
            echo "storage_account"
            ;;
        *VM*|*VIRTUAL_MACHINE*|SESSION_HOST*)
            echo "vm"
            ;;
        *HOST_POOL*)
            echo "host_pool"
            ;;
        *WORKSPACE*)
            echo "workspace"
            ;;
        *APP_GROUP*|*APPLICATION_GROUP*)
            echo "app_group"
            ;;
        *GALLERY*)
            echo "gallery"
            ;;
        *LOG_ANALYTICS*WORKSPACE*)
            echo "log_analytics_workspace"
            ;;
        *)
            echo ""
            ;;
    esac
}

# Map environment variable name to YAML path
map_var_to_yaml_path() {
    local var_name="$1"
    local file_type="${2:-config}"

    # Convert UPPER_SNAKE_CASE to dot.notation
    # e.g., AZURE_SUBSCRIPTION_ID -> azure.subscription_id
    local yaml_path
    yaml_path=$(echo "$var_name" | tr '[:upper:]' '[:lower:]' | sed 's/_/./g')

    # Handle special mappings for standards.yaml
    if [[ "$file_type" == "standards" ]]; then
        case "$var_name" in
            # Compute defaults (structure: .defaults.compute.vm.size)
            *_VM_SIZE|GOLDEN_IMAGE_VM_SIZE|SESSION_HOST_VM_SIZE)
                echo ".defaults.compute.vm.size"
                return 0
                ;;
            GOLDEN_IMAGE_IMAGE_PUBLISHER)
                echo ".defaults.compute.vm.image.publisher"
                return 0
                ;;
            GOLDEN_IMAGE_IMAGE_OFFER)
                echo ".defaults.compute.vm.image.offer"
                return 0
                ;;
            GOLDEN_IMAGE_IMAGE_SKU)
                echo ".defaults.compute.vm.image.sku"
                return 0
                ;;
            # Storage defaults (structure: .defaults.storage.file_share.*)
            STORAGE_SKU|*_STORAGE_SKU)
                echo ".defaults.storage.sku"
                return 0
                ;;
            STORAGE_KIND)
                echo ".defaults.storage.kind"
                return 0
                ;;
            STORAGE_QUOTA_GB|*_QUOTA_GB)
                echo ".defaults.storage.file_share.quota_gb"
                return 0
                ;;
            STORAGE_HTTPS_ONLY)
                echo ".defaults.storage.https_only"
                return 0
                ;;
            STORAGE_MIN_TLS_VERSION)
                echo ".defaults.storage.min_tls_version"
                return 0
                ;;
            # AVD defaults (structure: .defaults.avd.host_pool.type)
            HOST_POOL_TYPE)
                echo ".defaults.avd.host_pool.type"
                return 0
                ;;
            HOST_POOL_MAX_SESSIONS)
                echo ".defaults.avd.host_pool.max_sessions"
                return 0
                ;;
            HOST_POOL_LOAD_BALANCER)
                echo ".defaults.avd.host_pool.load_balancer_type"
                return 0
                ;;
            # Networking defaults
            NETWORKING_VNET_ADDRESS_SPACE)
                echo ".defaults.networking.vnet.address_space"
                return 0
                ;;
            NETWORKING_LB_SKU)
                echo ".defaults.networking.load_balancer.sku"
                return 0
                ;;
            # General defaults
            AZURE_LOCATION)
                echo ".defaults.general.location"
                return 0
                ;;
            # Monitoring defaults
            LOG_ANALYTICS_SKU)
                echo ".best_practices.monitoring.log_analytics.sku"
                return 0
                ;;
            LOG_ANALYTICS_RETENTION_DAYS)
                echo ".best_practices.monitoring.log_analytics.retention_days"
                return 0
                ;;
            *)
                # Try defaults path
                echo ".defaults.$yaml_path"
                return 0
                ;;
        esac
    fi

    # Standard config.yaml mapping
    echo ".$yaml_path"
}

# ==============================================================================
# INTERACTIVE PROMPTS
# ==============================================================================

# Prompt user for a value
prompt_for_value() {
    local var_name="$1"
    local context="${2:-}"

    # Get a human-readable description
    local description
    description=$(get_var_description "$var_name")

    # Get default suggestion if available
    local default_value
    default_value=$(get_default_suggestion "$var_name" "$context")

    echo "" >&2
    if [[ -n "$description" ]]; then
        echo "[?] $description" >&2
    else
        echo "[?] Enter value for: $var_name" >&2
    fi

    if [[ -n "$default_value" ]]; then
        read -r -p "    Value [$default_value]: " user_input
        echo "${user_input:-$default_value}"
    else
        read -r -p "    Value: " user_input
        echo "$user_input"
    fi
}

# Get human-readable description for a variable
get_var_description() {
    local var_name="$1"

    case "$var_name" in
        AZURE_SUBSCRIPTION_ID)
            echo "Azure Subscription ID"
            ;;
        AZURE_TENANT_ID)
            echo "Azure Tenant ID"
            ;;
        AZURE_LOCATION)
            echo "Azure Region (e.g., centralus, eastus)"
            ;;
        AZURE_RESOURCE_GROUP)
            echo "Resource Group Name"
            ;;
        STORAGE_ACCOUNT_NAME)
            echo "Storage Account Name (3-24 chars, lowercase alphanumeric)"
            ;;
        NETWORKING_VNET_NAME)
            echo "Virtual Network Name"
            ;;
        HOST_POOL_NAME)
            echo "AVD Host Pool Name"
            ;;
        WORKSPACE_NAME)
            echo "AVD Workspace Name"
            ;;
        *)
            echo ""
            ;;
    esac
}

# Get default suggestion for a variable
get_default_suggestion() {
    local var_name="$1"
    local context="${2:-}"

    # Try standards.yaml defaults first
    local default
    default=$(resolve_from_standards "$var_name" 2>/dev/null)

    if [[ -n "$default" && "$default" != "null" ]]; then
        echo "$default"
        return 0
    fi

    # Try config.yaml
    default=$(resolve_from_config "$var_name" 2>/dev/null)

    if [[ -n "$default" && "$default" != "null" ]]; then
        echo "$default"
        return 0
    fi

    return 1
}

# ==============================================================================
# BATCH RESOLUTION
# ==============================================================================

# Resolve multiple values at once
# Usage: resolve_values "VAR1 VAR2 VAR3" "context"
resolve_values() {
    local var_names="$1"
    local context="${2:-}"
    local context_json="${3:-"{}"}"

    local results=()

    for var_name in $var_names; do
        local value
        value=$(resolve_value "$var_name" "$context" "$context_json" 2>/dev/null) || value=""
        results+=("$var_name=$value")
    done

    printf '%s\n' "${results[@]}"
}

# Export resolved values as environment variables
# Usage: export_resolved_values "VAR1 VAR2 VAR3" "context"
export_resolved_values() {
    local var_names="$1"
    local context="${2:-}"
    local context_json="${3:-"{}"}"

    for var_name in $var_names; do
        local value
        value=$(resolve_value "$var_name" "$context" "$context_json" 2>/dev/null) || value=""

        if [[ -n "$value" ]]; then
            export "$var_name=$value"
            echo "[v] Exported: $var_name" >&2
        fi
    done
}

# ==============================================================================
# LOGGING
# ==============================================================================

# Log resolution result (for debugging/auditing)
log_resolution() {
    local var_name="$1"
    local value="$2"
    local source="$3"

    # Only log in debug mode
    if [[ "${DEBUG:-false}" == "true" ]]; then
        local masked_value="$value"
        # Mask sensitive values
        if [[ "$var_name" == *PASSWORD* || "$var_name" == *SECRET* || "$var_name" == *KEY* ]]; then
            masked_value="********"
        fi
        echo "[DEBUG] Resolved $var_name = '$masked_value' (source: $source)" >&2
    fi
}

# ==============================================================================
# VALIDATION
# ==============================================================================

# Validate that required values are available
# Usage: validate_required_values "VAR1 VAR2 VAR3"
validate_required_values() {
    local var_names="$1"
    local errors=0

    for var_name in $var_names; do
        local value
        value=$(resolve_value "$var_name" "" "{}" 2>/dev/null) || value=""

        if [[ -z "$value" ]]; then
            echo "[x] Required value not available: $var_name" >&2
            ((errors++))
        fi
    done

    if [[ $errors -gt 0 ]]; then
        echo "[x] Validation failed: $errors required values missing" >&2
        return 1
    fi

    echo "[v] All required values available" >&2
    return 0
}

# ==============================================================================
# Export functions
# ==============================================================================
export -f resolve_value
export -f resolve_from_environment
export -f resolve_from_discovery
export -f resolve_from_standards
export -f resolve_from_config
export -f get_cached_value
export -f cache_resolved_value
export -f map_var_to_resource_type
export -f map_var_to_yaml_path
export -f prompt_for_value
export -f resolve_values
export -f export_resolved_values
export -f validate_required_values
