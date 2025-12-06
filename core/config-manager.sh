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

    # Parse YAML and export as environment variables
    # Format: SECTION_KEY="value"

    # Azure section
    AZURE_SUBSCRIPTION_ID=$(yq e '.azure.subscription_id' "$config_file"); export AZURE_SUBSCRIPTION_ID
    AZURE_TENANT_ID=$(yq e '.azure.tenant_id' "$config_file"); export AZURE_TENANT_ID
    AZURE_LOCATION=$(yq e '.azure.location' "$config_file"); export AZURE_LOCATION
    AZURE_RESOURCE_GROUP=$(yq e '.azure.resource_group' "$config_file"); export AZURE_RESOURCE_GROUP

    # Networking section (Module 01 - Advanced Networking)
    NETWORKING_VNET_NAME=$(yq e '.networking.vnet.name' "$config_file"); export NETWORKING_VNET_NAME
    NETWORKING_VNET_ADDRESS_SPACE=$(yq e '.networking.vnet.address_space | join(" ")' "$config_file"); export NETWORKING_VNET_ADDRESS_SPACE
    NETWORKING_VNET_LOCATION=$(yq e '.networking.vnet.location' "$config_file"); export NETWORKING_VNET_LOCATION
    NETWORKING_DNS_ENABLED=$(yq e '.networking.private_dns.enabled' "$config_file"); export NETWORKING_DNS_ENABLED
    NETWORKING_PEERING_ENABLED=$(yq e '.networking.peering.enabled' "$config_file"); export NETWORKING_PEERING_ENABLED
    NETWORKING_ROUTE_TABLES_ENABLED=$(yq e '.networking.route_tables.enabled' "$config_file"); export NETWORKING_ROUTE_TABLES_ENABLED

    # Commonly used subnet names (extracted from array for convenience)
    NETWORKING_SESSION_HOST_SUBNET_NAME=$(yq e '.networking.subnets[] | select(.name == "subnet-session-hosts") | .name' "$config_file"); export NETWORKING_SESSION_HOST_SUBNET_NAME
    NETWORKING_PRIVATE_ENDPOINT_SUBNET_NAME=$(yq e '.networking.subnets[] | select(.name == "subnet-private-endpoints") | .name' "$config_file"); export NETWORKING_PRIVATE_ENDPOINT_SUBNET_NAME
    NETWORKING_MANAGEMENT_SUBNET_NAME=$(yq e '.networking.subnets[] | select(.name == "subnet-management") | .name' "$config_file"); export NETWORKING_MANAGEMENT_SUBNET_NAME

    # Note: Full subnet arrays, NSG rules, DNS zones are parsed dynamically in operations
    # They are too complex for simple environment variables

    # Storage section (Module 02)
    STORAGE_ACCOUNT_NAME=$(yq e '.storage.account_name' "$config_file"); export STORAGE_ACCOUNT_NAME
    STORAGE_SKU=$(yq e '.storage.sku' "$config_file"); export STORAGE_SKU
    STORAGE_KIND=$(yq e '.storage.kind' "$config_file"); export STORAGE_KIND
    STORAGE_FILE_SHARE_NAME=$(yq e '.storage.file_share_name' "$config_file"); export STORAGE_FILE_SHARE_NAME
    STORAGE_QUOTA_GB=$(yq e '.storage.quota_gb' "$config_file"); export STORAGE_QUOTA_GB
    STORAGE_ENABLE_ENTRA_KERBEROS=$(yq e '.storage.enable_entra_kerberos' "$config_file"); export STORAGE_ENABLE_ENTRA_KERBEROS
    STORAGE_ENABLE_SMB_MULTICHANNEL=$(yq e '.storage.enable_smb_multichannel' "$config_file"); export STORAGE_ENABLE_SMB_MULTICHANNEL
    STORAGE_PUBLIC_NETWORK_ACCESS=$(yq e '.storage.public_network_access' "$config_file"); export STORAGE_PUBLIC_NETWORK_ACCESS
    STORAGE_HTTPS_ONLY=$(yq e '.storage.https_only' "$config_file"); export STORAGE_HTTPS_ONLY
    STORAGE_MIN_TLS_VERSION=$(yq e '.storage.min_tls_version' "$config_file"); export STORAGE_MIN_TLS_VERSION

    # Entra ID section (Module 03)
    ENTRA_GROUP_USERS_STANDARD=$(yq e '.entra_id.group_users_standard' "$config_file"); export ENTRA_GROUP_USERS_STANDARD
    ENTRA_GROUP_USERS_STANDARD_DESCRIPTION=$(yq e '.entra_id.group_users_standard_description' "$config_file"); export ENTRA_GROUP_USERS_STANDARD_DESCRIPTION
    ENTRA_GROUP_USERS_ADMINS=$(yq e '.entra_id.group_users_admins' "$config_file"); export ENTRA_GROUP_USERS_ADMINS
    ENTRA_GROUP_USERS_ADMINS_DESCRIPTION=$(yq e '.entra_id.group_users_admins_description' "$config_file"); export ENTRA_GROUP_USERS_ADMINS_DESCRIPTION
    ENTRA_GROUP_DEVICES_SSO=$(yq e '.entra_id.group_devices_sso' "$config_file"); export ENTRA_GROUP_DEVICES_SSO
    ENTRA_GROUP_DEVICES_SSO_DESCRIPTION=$(yq e '.entra_id.group_devices_sso_description' "$config_file"); export ENTRA_GROUP_DEVICES_SSO_DESCRIPTION
    ENTRA_GROUP_DEVICES_FSLOGIX=$(yq e '.entra_id.group_devices_fslogix' "$config_file"); export ENTRA_GROUP_DEVICES_FSLOGIX
    ENTRA_GROUP_DEVICES_FSLOGIX_DESCRIPTION=$(yq e '.entra_id.group_devices_fslogix_description' "$config_file"); export ENTRA_GROUP_DEVICES_FSLOGIX_DESCRIPTION
    ENTRA_GROUP_DEVICES_NETWORK=$(yq e '.entra_id.group_devices_network' "$config_file"); export ENTRA_GROUP_DEVICES_NETWORK
    ENTRA_GROUP_DEVICES_NETWORK_DESCRIPTION=$(yq e '.entra_id.group_devices_network_description' "$config_file"); export ENTRA_GROUP_DEVICES_NETWORK_DESCRIPTION
    ENTRA_GROUP_DEVICES_SECURITY=$(yq e '.entra_id.group_devices_security' "$config_file"); export ENTRA_GROUP_DEVICES_SECURITY
    ENTRA_GROUP_DEVICES_SECURITY_DESCRIPTION=$(yq e '.entra_id.group_devices_security_description' "$config_file"); export ENTRA_GROUP_DEVICES_SECURITY_DESCRIPTION

    # Golden Image section
    GOLDEN_IMAGE_TEMP_VM_NAME=$(yq e '.golden_image.temp_vm_name' "$config_file"); export GOLDEN_IMAGE_TEMP_VM_NAME
    GOLDEN_IMAGE_VM_SIZE=$(yq e '.golden_image.vm_size' "$config_file"); export GOLDEN_IMAGE_VM_SIZE
    GOLDEN_IMAGE_IMAGE_PUBLISHER=$(yq e '.golden_image.image_publisher' "$config_file"); export GOLDEN_IMAGE_IMAGE_PUBLISHER
    GOLDEN_IMAGE_IMAGE_OFFER=$(yq e '.golden_image.image_offer' "$config_file"); export GOLDEN_IMAGE_IMAGE_OFFER
    GOLDEN_IMAGE_IMAGE_SKU=$(yq e '.golden_image.image_sku' "$config_file"); export GOLDEN_IMAGE_IMAGE_SKU
    GOLDEN_IMAGE_IMAGE_VERSION=$(yq e '.golden_image.image_version' "$config_file"); export GOLDEN_IMAGE_IMAGE_VERSION
    GOLDEN_IMAGE_ADMIN_USERNAME=$(yq e '.golden_image.admin_username' "$config_file"); export GOLDEN_IMAGE_ADMIN_USERNAME
    # Preserve environment variable if already set (for security - don't overwrite with empty value)
    if [[ -z "${GOLDEN_IMAGE_ADMIN_PASSWORD:-}" ]]; then
        GOLDEN_IMAGE_ADMIN_PASSWORD=$(yq e '.golden_image.admin_password' "$config_file"); export GOLDEN_IMAGE_ADMIN_PASSWORD
    fi
    GOLDEN_IMAGE_GALLERY_NAME=$(yq e '.golden_image.gallery_name' "$config_file"); export GOLDEN_IMAGE_GALLERY_NAME
    GOLDEN_IMAGE_DEFINITION_NAME=$(yq e '.golden_image.definition_name' "$config_file"); export GOLDEN_IMAGE_DEFINITION_NAME

    # Golden Image Applications - convert array to CSV
    GOLDEN_IMAGE_APPLICATIONS_CSV=$(yq e '.golden_image.applications | join(",")' "$config_file"); export GOLDEN_IMAGE_APPLICATIONS_CSV

    # Load app manifest content
    local app_manifest_file="modules/05-golden-image/app_manifest.yaml"
    if [[ -f "$app_manifest_file" ]]; then
        APP_MANIFEST_CONTENT=$(cat "$app_manifest_file"); export APP_MANIFEST_CONTENT
    else
        APP_MANIFEST_CONTENT=""; export APP_MANIFEST_CONTENT
    fi

    # Session Host section
    SESSION_HOST_VM_COUNT=$(yq e '.session_host.vm_count' "$config_file"); export SESSION_HOST_VM_COUNT
    SESSION_HOST_VM_SIZE=$(yq e '.session_host.vm_size' "$config_file"); export SESSION_HOST_VM_SIZE
    SESSION_HOST_NAME_PREFIX=$(yq e '.session_host.name_prefix' "$config_file"); export SESSION_HOST_NAME_PREFIX

    # Host Pool section
    HOST_POOL_NAME=$(yq e '.host_pool.name' "$config_file"); export HOST_POOL_NAME
    HOST_POOL_TYPE=$(yq e '.host_pool.type' "$config_file"); export HOST_POOL_TYPE
    HOST_POOL_MAX_SESSIONS=$(yq e '.host_pool.max_sessions' "$config_file"); export HOST_POOL_MAX_SESSIONS
    HOST_POOL_LOAD_BALANCER=$(yq e '.host_pool.load_balancer' "$config_file"); export HOST_POOL_LOAD_BALANCER

    # Workspace section
    WORKSPACE_NAME=$(yq e '.workspace.name' "$config_file"); export WORKSPACE_NAME
    WORKSPACE_FRIENDLY_NAME=$(yq e '.workspace.friendly_name' "$config_file"); export WORKSPACE_FRIENDLY_NAME

    # Application Group section
    APP_GROUP_NAME=$(yq e '.app_group.name' "$config_file"); export APP_GROUP_NAME
    APP_GROUP_TYPE=$(yq e '.app_group.type' "$config_file"); export APP_GROUP_TYPE

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

    echo "[v] Configuration loaded successfully"
    return 0
}

# ==============================================================================
# Validate Configuration
# ==============================================================================
# Usage: validate_config [module_id]
# If module_id provided, only validates sections required for that module
# If no module_id, validates all required sections (full validation)
validate_config() {
    local module_id="${1:-}"

    if [[ -n "$module_id" ]]; then
        echo "[*] Validating configuration for module: $module_id"
    else
        echo "[*] Validating full configuration..."
    fi

    local errors=0

    # Always validate Azure global fields (required by all modules)
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

    # Module-specific validation
    case "$module_id" in
        "01-networking")
            # Networking module requires VNet configuration
            if [[ -z "$NETWORKING_VNET_NAME" || "$NETWORKING_VNET_NAME" == "null" ]]; then
                echo "[x] ERROR: networking.vnet.name is required"
                ((errors++))
            fi
            ;;

        "02-storage")
            # Storage module - account_name is optional (auto-generated if empty)
            # Validate other critical storage settings
            if [[ -z "$STORAGE_SKU" || "$STORAGE_SKU" == "null" ]]; then
                echo "[x] ERROR: storage.sku is required"
                ((errors++))
            fi
            ;;

        "03-entra-group")
            # Entra ID module requires group configuration
            if [[ -z "$ENTRA_GROUP_USERS_STANDARD" || "$ENTRA_GROUP_USERS_STANDARD" == "null" ]]; then
                echo "[x] ERROR: entra_id.group_users_standard is required"
                ((errors++))
            fi
            ;;

        "04-host-pool-workspace"|"05-golden-image"|"06-session-host-deployment")
            # These modules require golden image configuration
            if [[ -z "$GOLDEN_IMAGE_TEMP_VM_NAME" || "$GOLDEN_IMAGE_TEMP_VM_NAME" == "null" ]]; then
                echo "[x] ERROR: golden_image.temp_vm_name is required"
                ((errors++))
            fi

            # Admin password only required for golden image module
            if [[ "$module_id" == "05-golden-image" ]]; then
                if [[ -z "$GOLDEN_IMAGE_ADMIN_PASSWORD" || "$GOLDEN_IMAGE_ADMIN_PASSWORD" == "null" || "$GOLDEN_IMAGE_ADMIN_PASSWORD" == "" ]]; then
                    echo "[x] ERROR: golden_image.admin_password is required for Module 05"
                    echo "[!] Provide via environment variable:"
                    echo "[!]   export GOLDEN_IMAGE_ADMIN_PASSWORD='your-secure-password'"
                    ((errors++))
                fi
            fi
            ;;

        "")
            # Full validation (no module specified)
            # Check for admin password (security requirement)
            if [[ -z "$GOLDEN_IMAGE_ADMIN_PASSWORD" || "$GOLDEN_IMAGE_ADMIN_PASSWORD" == "null" || "$GOLDEN_IMAGE_ADMIN_PASSWORD" == "" ]]; then
                echo "[!] WARNING: golden_image.admin_password not set"
                echo "[!] You will need to provide it via environment variable for Module 05:"
                echo "[!]   export GOLDEN_IMAGE_ADMIN_PASSWORD='your-secure-password'"
                # Not an error - can be provided later when needed
            fi
            ;;

        *)
            # Unknown module - skip module-specific validation
            echo "[i] No specific validation rules for module: $module_id"
            ;;
    esac

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
    read -r -p "Subscription ID [$AZURE_SUBSCRIPTION_ID]: " input
    AZURE_SUBSCRIPTION_ID="${input:-$AZURE_SUBSCRIPTION_ID}"

    read -r -p "Tenant ID [$AZURE_TENANT_ID]: " input
    AZURE_TENANT_ID="${input:-$AZURE_TENANT_ID}"

    read -r -p "Location [$AZURE_LOCATION]: " input
    AZURE_LOCATION="${input:-$AZURE_LOCATION}"

    read -r -p "Resource Group [$AZURE_RESOURCE_GROUP]: " input
    AZURE_RESOURCE_GROUP="${input:-$AZURE_RESOURCE_GROUP}"

    echo ""
    echo "--- Golden Image VM ---"
    read -r -p "Temp VM Name [$GOLDEN_IMAGE_TEMP_VM_NAME]: " input
    GOLDEN_IMAGE_TEMP_VM_NAME="${input:-$GOLDEN_IMAGE_TEMP_VM_NAME}"

    read -r -p "VM Size [$GOLDEN_IMAGE_VM_SIZE]: " input
    GOLDEN_IMAGE_VM_SIZE="${input:-$GOLDEN_IMAGE_VM_SIZE}"

    read -r -p "Admin Username [$GOLDEN_IMAGE_ADMIN_USERNAME]: " input
    GOLDEN_IMAGE_ADMIN_USERNAME="${input:-$GOLDEN_IMAGE_ADMIN_USERNAME}"

    # Admin password (secure input)
    if [[ -z "$GOLDEN_IMAGE_ADMIN_PASSWORD" || "$GOLDEN_IMAGE_ADMIN_PASSWORD" == "null" ]]; then
        read -r -sp "Admin Password (hidden): " GOLDEN_IMAGE_ADMIN_PASSWORD
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
