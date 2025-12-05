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

    # Parse YAML and export as environment variables
    # Format: SECTION_KEY="value"

    # Azure section
    export AZURE_SUBSCRIPTION_ID=$(yq e '.azure.subscription_id' "$config_file")
    export AZURE_TENANT_ID=$(yq e '.azure.tenant_id' "$config_file")
    export AZURE_LOCATION=$(yq e '.azure.location' "$config_file")
    export AZURE_RESOURCE_GROUP=$(yq e '.azure.resource_group' "$config_file")

    # Networking section (Module 01 - Advanced Networking)
    export NETWORKING_VNET_NAME=$(yq e '.networking.vnet.name' "$config_file")
    export NETWORKING_VNET_ADDRESS_SPACE=$(yq e '.networking.vnet.address_space | join(" ")' "$config_file")
    export NETWORKING_VNET_LOCATION=$(yq e '.networking.vnet.location' "$config_file")
    export NETWORKING_DNS_ENABLED=$(yq e '.networking.private_dns.enabled' "$config_file")
    export NETWORKING_PEERING_ENABLED=$(yq e '.networking.peering.enabled' "$config_file")
    export NETWORKING_ROUTE_TABLES_ENABLED=$(yq e '.networking.route_tables.enabled' "$config_file")

    # Commonly used subnet names (extracted from array for convenience)
    export NETWORKING_SESSION_HOST_SUBNET_NAME=$(yq e '.networking.subnets[] | select(.name == "subnet-session-hosts") | .name' "$config_file")
    export NETWORKING_PRIVATE_ENDPOINT_SUBNET_NAME=$(yq e '.networking.subnets[] | select(.name == "subnet-private-endpoints") | .name' "$config_file")
    export NETWORKING_MANAGEMENT_SUBNET_NAME=$(yq e '.networking.subnets[] | select(.name == "subnet-management") | .name' "$config_file")

    # Note: Full subnet arrays, NSG rules, DNS zones are parsed dynamically in operations
    # They are too complex for simple environment variables

    # Storage section (Module 02)
    export STORAGE_ACCOUNT_NAME=$(yq e '.storage.account_name' "$config_file")
    export STORAGE_SKU=$(yq e '.storage.sku' "$config_file")
    export STORAGE_KIND=$(yq e '.storage.kind' "$config_file")
    export STORAGE_FILE_SHARE_NAME=$(yq e '.storage.file_share_name' "$config_file")
    export STORAGE_QUOTA_GB=$(yq e '.storage.quota_gb' "$config_file")
    export STORAGE_ENABLE_ENTRA_KERBEROS=$(yq e '.storage.enable_entra_kerberos' "$config_file")
    export STORAGE_ENABLE_SMB_MULTICHANNEL=$(yq e '.storage.enable_smb_multichannel' "$config_file")
    export STORAGE_PUBLIC_NETWORK_ACCESS=$(yq e '.storage.public_network_access' "$config_file")
    export STORAGE_HTTPS_ONLY=$(yq e '.storage.https_only' "$config_file")
    export STORAGE_MIN_TLS_VERSION=$(yq e '.storage.min_tls_version' "$config_file")

    # Golden Image section
    export GOLDEN_IMAGE_TEMP_VM_NAME=$(yq e '.golden_image.temp_vm_name' "$config_file")
    export GOLDEN_IMAGE_VM_SIZE=$(yq e '.golden_image.vm_size' "$config_file")
    export GOLDEN_IMAGE_IMAGE_PUBLISHER=$(yq e '.golden_image.image_publisher' "$config_file")
    export GOLDEN_IMAGE_IMAGE_OFFER=$(yq e '.golden_image.image_offer' "$config_file")
    export GOLDEN_IMAGE_IMAGE_SKU=$(yq e '.golden_image.image_sku' "$config_file")
    export GOLDEN_IMAGE_IMAGE_VERSION=$(yq e '.golden_image.image_version' "$config_file")
    export GOLDEN_IMAGE_ADMIN_USERNAME=$(yq e '.golden_image.admin_username' "$config_file")
    export GOLDEN_IMAGE_ADMIN_PASSWORD=$(yq e '.golden_image.admin_password' "$config_file")
    export GOLDEN_IMAGE_GALLERY_NAME=$(yq e '.golden_image.gallery_name' "$config_file")
    export GOLDEN_IMAGE_DEFINITION_NAME=$(yq e '.golden_image.definition_name' "$config_file")

    # Session Host section
    export SESSION_HOST_VM_COUNT=$(yq e '.session_host.vm_count' "$config_file")
    export SESSION_HOST_VM_SIZE=$(yq e '.session_host.vm_size' "$config_file")
    export SESSION_HOST_NAME_PREFIX=$(yq e '.session_host.name_prefix' "$config_file")

    # Host Pool section
    export HOST_POOL_NAME=$(yq e '.host_pool.name' "$config_file")
    export HOST_POOL_TYPE=$(yq e '.host_pool.type' "$config_file")
    export HOST_POOL_MAX_SESSIONS=$(yq e '.host_pool.max_sessions' "$config_file")
    export HOST_POOL_LOAD_BALANCER=$(yq e '.host_pool.load_balancer' "$config_file")

    # Workspace section
    export WORKSPACE_NAME=$(yq e '.workspace.name' "$config_file")
    export WORKSPACE_FRIENDLY_NAME=$(yq e '.workspace.friendly_name' "$config_file")

    # Application Group section
    export APP_GROUP_NAME=$(yq e '.app_group.name' "$config_file")
    export APP_GROUP_TYPE=$(yq e '.app_group.type' "$config_file")

    echo "[v] Configuration loaded successfully"
    return 0
}

# ==============================================================================
# Validate Configuration
# ==============================================================================
validate_config() {
    echo "[*] Validating configuration..."

    local errors=0

    # Required Azure fields
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

    # Check for admin password (security requirement)
    if [[ -z "$GOLDEN_IMAGE_ADMIN_PASSWORD" || "$GOLDEN_IMAGE_ADMIN_PASSWORD" == "null" || "$GOLDEN_IMAGE_ADMIN_PASSWORD" == "" ]]; then
        echo "[!] WARNING: golden_image.admin_password not set"
        echo "[!] You will need to provide it via environment variable:"
        echo "[!]   export GOLDEN_IMAGE_ADMIN_PASSWORD='your-secure-password'"
        # Not an error - can be provided via environment
    fi

    if [[ $errors -gt 0 ]]; then
        echo "[x] Configuration validation failed with $errors errors"
        return 1
    fi

    echo "[v] Configuration validation passed"
    return 0
}

# ==============================================================================
# Prompt User for Configuration
# ==============================================================================
prompt_user_for_config() {
    echo ""
    echo "===================================================================="
    echo "  Azure VDI Deployment - Configuration"
    echo "===================================================================="
    echo ""
    echo "Press ENTER to accept default values shown in [brackets]"
    echo ""

    # Azure configuration
    echo "--- Azure Configuration ---"
    read -p "Subscription ID [$AZURE_SUBSCRIPTION_ID]: " input
    AZURE_SUBSCRIPTION_ID="${input:-$AZURE_SUBSCRIPTION_ID}"

    read -p "Tenant ID [$AZURE_TENANT_ID]: " input
    AZURE_TENANT_ID="${input:-$AZURE_TENANT_ID}"

    read -p "Location [$AZURE_LOCATION]: " input
    AZURE_LOCATION="${input:-$AZURE_LOCATION}"

    read -p "Resource Group [$AZURE_RESOURCE_GROUP]: " input
    AZURE_RESOURCE_GROUP="${input:-$AZURE_RESOURCE_GROUP}"

    echo ""
    echo "--- Golden Image VM ---"
    read -p "Temp VM Name [$GOLDEN_IMAGE_TEMP_VM_NAME]: " input
    GOLDEN_IMAGE_TEMP_VM_NAME="${input:-$GOLDEN_IMAGE_TEMP_VM_NAME}"

    read -p "VM Size [$GOLDEN_IMAGE_VM_SIZE]: " input
    GOLDEN_IMAGE_VM_SIZE="${input:-$GOLDEN_IMAGE_VM_SIZE}"

    read -p "Admin Username [$GOLDEN_IMAGE_ADMIN_USERNAME]: " input
    GOLDEN_IMAGE_ADMIN_USERNAME="${input:-$GOLDEN_IMAGE_ADMIN_USERNAME}"

    # Admin password (secure input)
    if [[ -z "$GOLDEN_IMAGE_ADMIN_PASSWORD" || "$GOLDEN_IMAGE_ADMIN_PASSWORD" == "null" ]]; then
        read -sp "Admin Password (hidden): " GOLDEN_IMAGE_ADMIN_PASSWORD
        echo ""
    else
        echo "Admin Password: [already set - not prompting]"
    fi

    echo ""
    echo "[v] Configuration complete"
    echo ""
}

# ==============================================================================
# Check Pipeline State
# ==============================================================================
check_pipeline_state() {
    if [[ -f "$STATE_FILE" ]]; then
        echo "[i] Found existing state file: $STATE_FILE"

        # Extract current module and operation
        local current_module=$(jq -r '.current_module // "none"' "$STATE_FILE")
        local current_operation=$(jq -r '.current_operation // "none"' "$STATE_FILE")
        local status=$(jq -r '.status // "unknown"' "$STATE_FILE")

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

    # Update YAML file with current environment variables
    yq e -i ".azure.subscription_id = \"$AZURE_SUBSCRIPTION_ID\"" "$config_file"
    yq e -i ".azure.tenant_id = \"$AZURE_TENANT_ID\"" "$config_file"
    yq e -i ".azure.location = \"$AZURE_LOCATION\"" "$config_file"
    yq e -i ".azure.resource_group = \"$AZURE_RESOURCE_GROUP\"" "$config_file"

    yq e -i ".golden_image.temp_vm_name = \"$GOLDEN_IMAGE_TEMP_VM_NAME\"" "$config_file"
    yq e -i ".golden_image.vm_size = \"$GOLDEN_IMAGE_VM_SIZE\"" "$config_file"
    yq e -i ".golden_image.admin_username = \"$GOLDEN_IMAGE_ADMIN_USERNAME\"" "$config_file"
    # Note: Never save password to config file (security)

    echo "[v] Configuration saved"
    return 0
}

# ==============================================================================
# Display Configuration
# ==============================================================================
display_config() {
    echo ""
    echo "===================================================================="
    echo "  Current Configuration"
    echo "===================================================================="
    echo ""
    echo "Azure:"
    echo "  Subscription ID: $AZURE_SUBSCRIPTION_ID"
    echo "  Tenant ID: $AZURE_TENANT_ID"
    echo "  Location: $AZURE_LOCATION"
    echo "  Resource Group: $AZURE_RESOURCE_GROUP"
    echo ""
    echo "Networking:"
    echo "  VNet: $NETWORKING_VNET_NAME ($NETWORKING_VNET_CIDR)"
    echo "  Subnet: $NETWORKING_SUBNET_NAME ($NETWORKING_SUBNET_CIDR)"
    echo "  NSG: $NETWORKING_NSG_NAME"
    echo ""
    echo "Golden Image:"
    echo "  Temp VM: $GOLDEN_IMAGE_TEMP_VM_NAME"
    echo "  VM Size: $GOLDEN_IMAGE_VM_SIZE"
    echo "  Admin: $GOLDEN_IMAGE_ADMIN_USERNAME"
    echo "  Gallery: $GOLDEN_IMAGE_GALLERY_NAME"
    echo ""
    echo "Host Pool:"
    echo "  Name: $HOST_POOL_NAME"
    echo "  Type: $HOST_POOL_TYPE"
    echo "  Max Sessions: $HOST_POOL_MAX_SESSIONS"
    echo ""
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
