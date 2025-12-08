#!/bin/bash
# ==============================================================================
# Config Manager - Central Configuration System
# ==============================================================================
#
# Purpose: Load, validate, and manage YAML configuration
# Usage:
#   source core/config-manager.sh
#   load_config                    # Load config.yaml into environment
#   validate_config                # Validate required variables
#   prompt_user_for_config         # Interactive prompting with defaults
#   check_pipeline_state           # Check if resuming mid-pipeline
#
# ==============================================================================

set -euo pipefail

# Project paths
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
CONFIG_FILE="${PROJECT_ROOT}/config.yaml"
SECRETS_FILE="${PROJECT_ROOT}/secrets.yaml"
STATE_FILE="${PROJECT_ROOT}/state.json"

# ==============================================================================
# Load Configuration from YAML
# ==============================================================================
load_config() {
    local config_file="${1:-$CONFIG_FILE}"

    if [[ ! -f "$config_file" ]]; then
        echo "ERROR: Configuration file not found: $config_file"
        return 1
    fi

    echo "[*] Loading configuration from: $config_file"

    # ===========================================================================
    # Bootstrap Configuration (minimal required to start the engine)
    # All other variables are resolved on-demand via value-resolver.sh
    # ===========================================================================
    AZURE_SUBSCRIPTION_ID=$(yq e '.azure.subscription_id' "$config_file"); export AZURE_SUBSCRIPTION_ID
    AZURE_TENANT_ID=$(yq e '.azure.tenant_id' "$config_file"); export AZURE_TENANT_ID
    AZURE_LOCATION=$(yq e '.azure.location' "$config_file"); export AZURE_LOCATION
    AZURE_RESOURCE_GROUP=$(yq e '.azure.resource_group' "$config_file"); export AZURE_RESOURCE_GROUP

    # ===========================================================================
    # Load Value Resolver for on-demand variable resolution
    # ===========================================================================
    if [[ -f "${PROJECT_ROOT}/core/value-resolver.sh" ]]; then
        source "${PROJECT_ROOT}/core/value-resolver.sh"
        echo "[v] Value resolver loaded for on-demand configuration"
    fi

    # ===========================================================================
    # Load Secrets (if secrets.yaml exists, merge with config.yaml)
    # Secrets take precedence over config.yaml values
    # ===========================================================================
    if [[ -f "$SECRETS_FILE" ]]; then
        echo "[*] Loading secrets from: $SECRETS_FILE"

        # Override golden image admin password if set in secrets
        local secret_password
        secret_password=$(yq e '.golden_image.admin_password' "$SECRETS_FILE" 2>/dev/null)
        if [[ -n "$secret_password" && "$secret_password" != "null" ]]; then
            GOLDEN_IMAGE_ADMIN_PASSWORD="$secret_password"
            export GOLDEN_IMAGE_ADMIN_PASSWORD
            echo "[v] Golden image admin password loaded from secrets"
        fi

        # Add more secret overrides here as needed
        # Example:
        # local secret_api_key
        # secret_api_key=$(yq e '.api.key' "$SECRETS_FILE" 2>/dev/null)
        # if [[ -n "$secret_api_key" && "$secret_api_key" != "null" ]]; then
        #     API_KEY="$secret_api_key"
        #     export API_KEY
        # fi
    fi

    echo "[v] Configuration loaded successfully (bootstrap variables only)"
    return 0
}

# ==============================================================================
# Validate Configuration
# ==============================================================================
# Validates bootstrap variables only (all others resolved on-demand)
validate_config() {
    echo "[*] Validating bootstrap configuration..."

    local errors=0

    # Validate Azure bootstrap variables (required to start the engine)
    if [[ -z "$AZURE_SUBSCRIPTION_ID" || "$AZURE_SUBSCRIPTION_ID" == "null" ]]; then
        echo "[x] ERROR: azure.subscription_id is required"
        ((errors++))
    fi

    if [[ -z "$AZURE_TENANT_ID" || "$AZURE_TENANT_ID" == "null" ]]; then
        echo "[x] ERROR: azure.tenant_id is required"
        ((errors++))
    fi

    if [[ -z "$AZURE_LOCATION" || "$AZURE_LOCATION" == "null" ]]; then
        echo "[x] ERROR: azure.location is required"
        ((errors++))
    fi

    if [[ -z "$AZURE_RESOURCE_GROUP" || "$AZURE_RESOURCE_GROUP" == "null" ]]; then
        echo "[x] ERROR: azure.resource_group is required"
        ((errors++))
    fi

    if [[ $errors -gt 0 ]]; then
        echo "[x] Bootstrap validation failed with $errors errors"
        return 1
    fi

    echo "[v] Bootstrap validation passed"
    echo "[i] Operation-specific variables will be validated on-demand"
    return 0
}

# ==============================================================================
# Prompt User for Configuration
# ==============================================================================
prompt_user_for_config() {
    echo ""
    echo "===================================================================="
    echo "  Azure VDI Deployment - Bootstrap Configuration"
    echo "===================================================================="
    echo ""
    echo "Press ENTER to accept default values shown in [brackets]"
    echo ""

    # Azure configuration (bootstrap variables only)
    echo "--- Azure Configuration ---"
    read -r -p "Subscription ID [$AZURE_SUBSCRIPTION_ID]: " input
    AZURE_SUBSCRIPTION_ID="${input:-$AZURE_SUBSCRIPTION_ID}"

    read -r -p "Tenant ID [$AZURE_TENANT_ID]: " input
    AZURE_TENANT_ID="${input:-$AZURE_TENANT_ID}"

    read -r -p "Location [$AZURE_LOCATION]: " input
    AZURE_LOCATION="${input:-$AZURE_LOCATION}"

    read -r -p "Resource Group [$AZURE_RESOURCE_GROUP]: " input
    AZURE_RESOURCE_GROUP="${input:-$AZURE_RESOURCE_GROUP}"

    echo ""
    echo "[v] Bootstrap configuration complete"
    echo "[i] Other variables will be resolved on-demand via value-resolver.sh"
    echo ""
}

# ==============================================================================
# Check Pipeline State
# ==============================================================================
check_pipeline_state() {
    if [[ -f "$STATE_FILE" ]]; then
        echo "[i] Found existing state file: $STATE_FILE"

        # Extract current module and operation
        local current_module
        current_module=$(jq -r '.current_module // "none"' "$STATE_FILE")
        local current_operation
        current_operation=$(jq -r '.current_operation // "none"' "$STATE_FILE")
        local status
        status=$(jq -r '.status // "unknown"' "$STATE_FILE")

        echo "[i] Current module: $current_module"
        echo "[i] Current operation: $current_operation"
        echo "[i] Status: $status"

        if [[ "$status" == "failed" ]]; then
            echo "[!] Previous execution failed"
            echo "[!] You can resume from the failure point"
        fi

        return 0
    else
        echo "[i] No existing state found (fresh start)"
        return 1
    fi
}

# ==============================================================================
# Save Configuration Updates
# ==============================================================================
save_config() {
    local config_file="${1:-$CONFIG_FILE}"

    echo "[*] Saving configuration to: $config_file"

    # Update YAML file with bootstrap variables only
    yq e -i ".azure.subscription_id = \"$AZURE_SUBSCRIPTION_ID\"" "$config_file"
    yq e -i ".azure.tenant_id = \"$AZURE_TENANT_ID\"" "$config_file"
    yq e -i ".azure.location = \"$AZURE_LOCATION\"" "$config_file"
    yq e -i ".azure.resource_group = \"$AZURE_RESOURCE_GROUP\"" "$config_file"

    echo "[v] Configuration saved (bootstrap variables only)"
    return 0
}

# ==============================================================================
# Display Configuration
# ==============================================================================
display_config() {
    echo ""
    echo "===================================================================="
    echo "  Bootstrap Configuration"
    echo "===================================================================="
    echo ""
    echo "Azure:"
    echo "  Subscription ID: ${AZURE_SUBSCRIPTION_ID:-<not set>}"
    echo "  Tenant ID: ${AZURE_TENANT_ID:-<not set>}"
    echo "  Location: ${AZURE_LOCATION:-<not set>}"
    echo "  Resource Group: ${AZURE_RESOURCE_GROUP:-<not set>}"
    echo ""
    echo "Note: All other variables are resolved on-demand via value-resolver.sh"
    echo "===================================================================="
    echo ""
}

# ==============================================================================
# Export functions for use by other scripts
# ==============================================================================
export -f load_config
export -f validate_config
export -f prompt_user_for_config
export -f check_pipeline_state
export -f save_config
export -f display_config
