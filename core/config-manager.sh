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

        # =====================================================================
        # Service Principal Credentials (for Claude Code automation)
        # =====================================================================
        local sp_client_id sp_client_secret sp_cert_thumbprint sp_cert_path

        sp_client_id=$(yq e '.service_principal.client_id' "$SECRETS_FILE" 2>/dev/null)
        if [[ -n "$sp_client_id" && "$sp_client_id" != "null" ]]; then
            AZURE_CLIENT_ID="$sp_client_id"
            export AZURE_CLIENT_ID
            echo "[v] Service principal client_id loaded"
        fi

        sp_client_secret=$(yq e '.service_principal.client_secret' "$SECRETS_FILE" 2>/dev/null)
        if [[ -n "$sp_client_secret" && "$sp_client_secret" != "null" ]]; then
            AZURE_CLIENT_SECRET="$sp_client_secret"
            export AZURE_CLIENT_SECRET
            echo "[v] Service principal client_secret loaded"
        fi

        sp_cert_thumbprint=$(yq e '.service_principal.certificate_thumbprint' "$SECRETS_FILE" 2>/dev/null)
        if [[ -n "$sp_cert_thumbprint" && "$sp_cert_thumbprint" != "null" ]]; then
            AZURE_CERTIFICATE_THUMBPRINT="$sp_cert_thumbprint"
            export AZURE_CERTIFICATE_THUMBPRINT
            echo "[v] Service principal certificate_thumbprint loaded"
        fi

        sp_cert_path=$(yq e '.service_principal.certificate_path' "$SECRETS_FILE" 2>/dev/null)
        if [[ -n "$sp_cert_path" && "$sp_cert_path" != "null" ]]; then
            AZURE_CERTIFICATE_PATH="$sp_cert_path"
            export AZURE_CERTIFICATE_PATH
            echo "[v] Service principal certificate_path loaded"
        fi
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
# Validate Operation Configuration
# ==============================================================================
# Validates all variables required for a specific operation BEFORE execution
# Usage: validate_operation_config "vnet-create"
# Returns: 0 if all variables validated, 1 if errors found
validate_operation_config() {
    local operation_id="$1"

    echo "[*] Validating configuration for operation: $operation_id"

    # Find operation YAML file
    local operation_file
    operation_file=$(find "${PROJECT_ROOT}/capabilities" -name "${operation_id}.yaml" 2>/dev/null | head -1)

    if [[ -z "$operation_file" ]]; then
        echo "[x] ERROR: Operation not found: $operation_id"
        echo "[i] Run './core/engine.sh list' to see available operations"
        return 1
    fi

    echo "[*] Found operation file: $operation_file"

    local errors=0
    local warnings=0

    # Extract required parameters from operation YAML
    local required_params
    required_params=$(yq e '.operation.parameters.required // []' "$operation_file" 2>/dev/null)

    if [[ "$required_params" != "[]" && "$required_params" != "null" ]]; then
        local param_count
        param_count=$(yq e '.operation.parameters.required | length' "$operation_file" 2>/dev/null)

        echo "[*] Checking $param_count required parameters..."

        local i=0
        while [[ $i -lt $param_count ]]; do
            local param_name param_default param_var
            param_name=$(yq e ".operation.parameters.required[$i].name" "$operation_file" 2>/dev/null)
            param_default=$(yq e ".operation.parameters.required[$i].default" "$operation_file" 2>/dev/null)

            # Extract variable name from template (e.g., {{NETWORKING_VNET_NAME}})
            if [[ "$param_default" =~ \{\{([A-Z_]+)\}\} ]]; then
                param_var="${BASH_REMATCH[1]}"

                # Check if variable is set
                if [[ -z "${!param_var:-}" ]]; then
                    echo "[x] ERROR: Required variable not set: $param_var (for parameter: $param_name)"
                    echo "    [i] Remediation:"
                    echo "        1. Check config.yaml for the value"
                    echo "        2. Or set: export $param_var='<value>'"
                    echo "        3. Or run: ./core/engine.sh run config/prompt-config"
                    ((errors++))
                else
                    echo "[v] $param_var = ${!param_var}"
                fi
            fi

            ((i++))
        done
    fi

    # Validate bootstrap variables (always required)
    echo "[*] Validating bootstrap variables..."

    local bootstrap_vars=("AZURE_SUBSCRIPTION_ID" "AZURE_TENANT_ID" "AZURE_LOCATION" "AZURE_RESOURCE_GROUP")
    for var in "${bootstrap_vars[@]}"; do
        if [[ -z "${!var:-}" || "${!var}" == "null" ]]; then
            echo "[x] ERROR: Bootstrap variable not set: $var"
            ((errors++))
        else
            echo "[v] $var is set"
        fi
    done

    # Check Azure CLI availability
    echo "[*] Checking Azure CLI availability..."
    if ! command -v az &> /dev/null; then
        echo "[x] ERROR: Azure CLI (az) not found in PATH"
        echo "    [i] Remediation: Install Azure CLI from https://docs.microsoft.com/cli/azure/"
        ((errors++))
    else
        echo "[v] Azure CLI is available"
    fi

    # Report results
    echo ""
    if [[ $errors -eq 0 ]]; then
        echo "[v] Configuration validation passed"
        if [[ $warnings -gt 0 ]]; then
            echo "[!] Warnings: $warnings"
        fi
        return 0
    else
        echo "[x] Configuration validation FAILED: $errors error(s)"
        return 1
    fi
}

# ==============================================================================
# Dry-Run Operation (Preview Mode)
# ==============================================================================
# Simulates operation execution without making any changes to Azure resources
# Usage: dry_run_operation "vnet-create"
# Returns: 0 if preview successful, 1 if errors
dry_run_operation() {
    local operation_id="$1"

    echo ""
    echo "===================================================================="
    echo "  DRY-RUN MODE - No changes will be made"
    echo "===================================================================="
    echo ""

    # Validate operation config first
    if ! validate_operation_config "$operation_id"; then
        echo "[x] Dry-run validation failed"
        return 1
    fi

    # Find operation YAML file
    local operation_file
    operation_file=$(find "${PROJECT_ROOT}/capabilities" -name "${operation_id}.yaml" 2>/dev/null | head -1)

    if [[ -z "$operation_file" ]]; then
        echo "[x] Operation not found: $operation_id"
        return 1
    fi

    echo "[*] Analyzing operation: $operation_id"
    echo "[*] Operation file: $operation_file"
    echo ""

    # Extract operation metadata
    local op_name op_description op_type resource_type
    op_name=$(yq e '.operation.name // "N/A"' "$operation_file" 2>/dev/null)
    op_description=$(yq e '.operation.description // "N/A"' "$operation_file" 2>/dev/null)
    op_type=$(yq e '.operation.operation_mode // "N/A"' "$operation_file" 2>/dev/null)
    resource_type=$(yq e '.operation.resource_type // "N/A"' "$operation_file" 2>/dev/null)

    echo "Operation Details:"
    echo "  ID: $operation_id"
    echo "  Name: $op_name"
    echo "  Description: $op_description"
    echo "  Type: $op_type"
    echo "  Resource Type: $resource_type"
    echo ""

    # Extract duration expectations
    local expected_duration timeout_duration
    expected_duration=$(yq e '.operation.duration.expected // "unknown"' "$operation_file" 2>/dev/null)
    timeout_duration=$(yq e '.operation.duration.timeout // "unknown"' "$operation_file" 2>/dev/null)

    echo "Execution Expectations:"
    echo "  Expected duration: ${expected_duration}s"
    echo "  Timeout: ${timeout_duration}s"
    echo ""

    # Check idempotency
    local idempotent_enabled skip_if_exists
    idempotent_enabled=$(yq e '.operation.idempotency.enabled // false' "$operation_file" 2>/dev/null)
    skip_if_exists=$(yq e '.operation.idempotency.skip_if_exists // false' "$operation_file" 2>/dev/null)

    echo "Idempotency:"
    echo "  Enabled: $idempotent_enabled"
    echo "  Skip if exists: $skip_if_exists"
    echo ""

    # Show validation checks
    local validation_enabled validation_checks
    validation_enabled=$(yq e '.operation.validation.enabled // false' "$operation_file" 2>/dev/null)
    validation_checks=$(yq e '.operation.validation.checks | length' "$operation_file" 2>/dev/null)

    echo "Post-Execution Validation:"
    echo "  Enabled: $validation_enabled"
    if [[ "$validation_enabled" == "true" && "$validation_checks" != "null" ]]; then
        echo "  Checks: $validation_checks"
        local i=0
        while [[ $i -lt $validation_checks ]]; do
            local check_desc
            check_desc=$(yq e ".operation.validation.checks[$i].description // 'N/A'" "$operation_file" 2>/dev/null)
            echo "    - $check_desc"
            ((i++))
        done
    fi
    echo ""

    # Show rollback information
    local rollback_enabled rollback_steps
    rollback_enabled=$(yq e '.operation.rollback.enabled // false' "$operation_file" 2>/dev/null)
    rollback_steps=$(yq e '.operation.rollback.steps | length' "$operation_file" 2>/dev/null)

    echo "Rollback Configuration:"
    echo "  Enabled: $rollback_enabled"
    if [[ "$rollback_enabled" == "true" && "$rollback_steps" != "null" ]]; then
        echo "  Rollback steps: $rollback_steps"
        local i=0
        while [[ $i -lt $rollback_steps ]]; do
            local step_name
            step_name=$(yq e ".operation.rollback.steps[$i].name // 'N/A'" "$operation_file" 2>/dev/null)
            echo "    - $step_name"
            ((i++))
        done
    fi
    echo ""

    # Extract and display PowerShell/template preview
    local powershell_content
    powershell_content=$(yq e '.operation.powershell.content // ""' "$operation_file" 2>/dev/null)

    if [[ -n "$powershell_content" && "$powershell_content" != "null" ]]; then
        echo "Preview of Operation Script (first 20 lines):"
        echo "----"
        echo "$powershell_content" | head -20
        if [[ $(echo "$powershell_content" | wc -l) -gt 20 ]]; then
            echo "[... script continues ...]"
        fi
        echo "----"
        echo ""
    fi

    echo "===================================================================="
    echo "  DRY-RUN COMPLETE - Operation validated but NOT executed"
    echo "===================================================================="
    echo ""
    echo "To execute this operation, run:"
    echo "  ./core/engine.sh run $operation_id"
    echo ""

    return 0
}

# ==============================================================================
# Pre-Flight Checks
# ==============================================================================
# Comprehensive pre-execution validation covering Azure connectivity,
# configuration, and operation YAML syntax
# Usage: preflight_check [operation_id]
# Returns: 0 if all checks pass, 1 if any check fails
preflight_check() {
    local operation_id="${1:-}"

    echo ""
    echo "===================================================================="
    echo "  PRE-FLIGHT CHECKS"
    echo "===================================================================="
    echo ""

    local errors=0
    local warnings=0

    # Check 1: Bootstrap configuration
    echo "[*] Check 1/5: Bootstrap Configuration"
    echo "    Validating essential configuration..."

    local bootstrap_vars=("AZURE_SUBSCRIPTION_ID" "AZURE_TENANT_ID" "AZURE_LOCATION" "AZURE_RESOURCE_GROUP")
    for var in "${bootstrap_vars[@]}"; do
        if [[ -z "${!var:-}" || "${!var}" == "null" ]]; then
            echo "[x]   ERROR: $var not set"
            ((errors++))
        fi
    done

    if [[ $errors -eq 0 ]]; then
        echo "[v]   Bootstrap configuration OK"
        echo "      Subscription: ${AZURE_SUBSCRIPTION_ID:0:20}..."
        echo "      Tenant: ${AZURE_TENANT_ID:0:20}..."
        echo "      Location: $AZURE_LOCATION"
        echo "      Resource Group: $AZURE_RESOURCE_GROUP"
    fi
    echo ""

    # Check 2: Required tools
    echo "[*] Check 2/5: Required Tools"

    local required_tools=("az" "yq" "jq")
    local missing_tools=0

    for tool in "${required_tools[@]}"; do
        if command -v "$tool" &> /dev/null; then
            local version
            version=$("$tool" --version 2>/dev/null | head -1)
            echo "[v]   $tool: $version"
        else
            echo "[x]   $tool: NOT FOUND"
            ((missing_tools++))
            ((errors++))
        fi
    done

    if [[ $missing_tools -eq 0 ]]; then
        echo "[v]   All required tools available"
    fi
    echo ""

    # Check 3: Azure CLI authentication
    echo "[*] Check 3/5: Azure CLI Authentication"

    # Check if we can access Azure
    if az account show &>/dev/null; then
        local current_account
        current_account=$(az account show --query "name" -o tsv 2>/dev/null)
        echo "[v]   Authenticated to Azure"
        echo "      Current account: $current_account"
    else
        echo "[!]   Not authenticated to Azure"
        echo "      Remediation:"
        echo "        1. Run: ./core/engine.sh run identity/az-login-service-principal"
        echo "        2. Or manually: az login"
        ((warnings++))
    fi
    echo ""

    # Check 4: Resource Group accessibility
    echo "[*] Check 4/5: Azure Resource Accessibility"

    if [[ -z "${AZURE_RESOURCE_GROUP:-}" || "${AZURE_RESOURCE_GROUP}" == "null" ]]; then
        echo "[x]   Resource group not configured"
        ((errors++))
    elif az group show --name "$AZURE_RESOURCE_GROUP" &>/dev/null; then
        echo "[v]   Resource group exists: $AZURE_RESOURCE_GROUP"
    else
        echo "[x]   Resource group not found: $AZURE_RESOURCE_GROUP"
        echo "      Remediation:"
        echo "        1. Create the resource group: az group create --name $AZURE_RESOURCE_GROUP --location $AZURE_LOCATION"
        echo "        2. Or run: ./core/engine.sh run management/resource-group-create"
        ((errors++))
    fi
    echo ""

    # Check 5: Operation-specific validation (if operation_id provided)
    echo "[*] Check 5/5: Operation-Specific Validation"

    if [[ -n "$operation_id" ]]; then
        echo "    Validating operation: $operation_id"

        # Find operation YAML
        local operation_file
        operation_file=$(find "${PROJECT_ROOT}/capabilities" -name "${operation_id}.yaml" 2>/dev/null | head -1)

        if [[ -z "$operation_file" ]]; then
            echo "[x]   Operation not found: $operation_id"
            ((errors++))
        else
            echo "[v]   Operation file found: $operation_file"

            # Validate YAML syntax
            if yq e '.' "$operation_file" &>/dev/null; then
                echo "[v]   YAML syntax valid"
            else
                echo "[x]   YAML syntax error in: $operation_file"
                ((errors++))
            fi

            # Validate operation has required sections
            local op_id
            op_id=$(yq e '.operation.id // ""' "$operation_file" 2>/dev/null)

            if [[ -z "$op_id" ]]; then
                echo "[!]   WARNING: operation.id not defined in YAML"
                ((warnings++))
            fi

            # Check for PowerShell content or template command
            local has_powershell has_template
            has_powershell=$(yq e '.operation.powershell.content // ""' "$operation_file" 2>/dev/null | wc -c)
            has_template=$(yq e '.operation.template // ""' "$operation_file" 2>/dev/null | wc -c)

            if [[ $has_powershell -gt 1 ]] || [[ $has_template -gt 1 ]]; then
                echo "[v]   Operation has executable content"
            else
                echo "[!]   WARNING: No PowerShell or template content found"
                ((warnings++))
            fi
        fi
    else
        echo "    Skipping operation validation (no operation_id provided)"
    fi
    echo ""

    # Summary
    echo "===================================================================="
    echo "  PRE-FLIGHT CHECK SUMMARY"
    echo "===================================================================="

    if [[ $errors -eq 0 ]]; then
        echo "[v] All checks passed"
        if [[ $warnings -gt 0 ]]; then
            echo "[!] Warnings: $warnings (review above)"
        fi
        echo ""
        if [[ -n "$operation_id" ]]; then
            echo "Ready to execute: ./core/engine.sh run $operation_id"
        else
            echo "System ready for operations"
        fi
        echo ""
        return 0
    else
        echo "[x] FAILED: $errors error(s) detected"
        echo "[!] Please resolve errors above before proceeding"
        echo ""
        return 1
    fi
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
export -f validate_operation_config
export -f dry_run_operation
export -f preflight_check
