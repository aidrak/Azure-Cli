#!/bin/bash
# ==============================================================================
# Template Engine - Parse and Execute Operation YAML Templates
# ==============================================================================
#
# Purpose: Convert YAML operation templates into executable commands
# Usage:
#   source core/template-engine.sh
#   parse_operation_yaml "path/to/operation.yaml"
#   substitute_variables "template-string"
#   execute_operation "path/to/operation.yaml"
#
# ==============================================================================

set -euo pipefail

# Project paths
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

# ==============================================================================
# Parse Operation YAML
# ==============================================================================
parse_operation_yaml() {
    local yaml_file="$1"

    if [[ ! -f "$yaml_file" ]]; then
        echo "[x] ERROR: Operation YAML not found: $yaml_file" >&2
        return 1
    fi

    echo "[*] Parsing operation: $yaml_file" >&2

    # Extract key fields using yq (works for both legacy and capability formats)
    OPERATION_ID=$(yq e '.operation.id' "$yaml_file")
    OPERATION_NAME=$(yq e '.operation.name' "$yaml_file")
    OPERATION_DESCRIPTION=$(yq e '.operation.description // ""' "$yaml_file")
    OPERATION_DURATION_EXPECTED=$(yq e '.operation.duration.expected // 60' "$yaml_file")
    OPERATION_DURATION_TIMEOUT=$(yq e '.operation.duration.timeout // 120' "$yaml_file")
    OPERATION_DURATION_TYPE=$(yq e '.operation.duration.type // "FAST"' "$yaml_file")

    # Validation settings
    VALIDATION_ENABLED=$(yq e '.operation.validation.enabled // false' "$yaml_file")

    # Template command
    TEMPLATE_TYPE=$(yq e '.operation.template.type' "$yaml_file")
    TEMPLATE_COMMAND=$(yq e '.operation.template.command' "$yaml_file")

    # PowerShell script
    POWERSHELL_FILE=$(yq e '.operation.powershell.file // ""' "$yaml_file")
    POWERSHELL_CONTENT=$(yq e '.operation.powershell.content // ""' "$yaml_file")

    # === NEW CAPABILITY SCHEMA FIELDS ===
    # These fields only exist in capability format, defaults to empty for legacy
    OPERATION_CAPABILITY=$(yq e '.operation.capability // ""' "$yaml_file")
    OPERATION_MODE=$(yq e '.operation.operation_mode // ""' "$yaml_file")
    OPERATION_RESOURCE_TYPE=$(yq e '.operation.resource_type // ""' "$yaml_file")

    # Idempotency settings (capability format)
    IDEMPOTENCY_ENABLED=$(yq e '.operation.idempotency.enabled // false' "$yaml_file")
    IDEMPOTENCY_CHECK_COMMAND=$(yq e '.operation.idempotency.check_command // ""' "$yaml_file")
    IDEMPOTENCY_SKIP_IF_EXISTS=$(yq e '.operation.idempotency.skip_if_exists // false' "$yaml_file")

    # Rollback settings (capability format)
    ROLLBACK_ENABLED=$(yq e '.operation.rollback.enabled // false' "$yaml_file")

    # Export for use by other functions
    export OPERATION_ID OPERATION_NAME OPERATION_DESCRIPTION
    export OPERATION_DURATION_EXPECTED OPERATION_DURATION_TIMEOUT OPERATION_DURATION_TYPE
    export VALIDATION_ENABLED
    export TEMPLATE_TYPE TEMPLATE_COMMAND
    export POWERSHELL_FILE POWERSHELL_CONTENT

    # Export capability-specific fields
    export OPERATION_CAPABILITY OPERATION_MODE OPERATION_RESOURCE_TYPE
    export IDEMPOTENCY_ENABLED IDEMPOTENCY_CHECK_COMMAND IDEMPOTENCY_SKIP_IF_EXISTS
    export ROLLBACK_ENABLED

    echo "[v] Parsed operation: $OPERATION_NAME (ID: $OPERATION_ID)" >&2
    if [[ -n "$OPERATION_CAPABILITY" && "$OPERATION_CAPABILITY" != "null" ]]; then
        echo "[v] Capability: $OPERATION_CAPABILITY | Mode: $OPERATION_MODE" >&2
    fi
    return 0
}

# ==============================================================================
# Substitute Variables in Template
# ==============================================================================
substitute_variables() {
    local template="$1"
    local result="$template"

    # Replace {{VAR}} with environment variable value
    # Common variables from config.yaml (loaded by config-manager.sh):

    # Azure variables
    result="${result//\{\{AZURE_SUBSCRIPTION_ID\}\}/$AZURE_SUBSCRIPTION_ID}"
    result="${result//\{\{AZURE_TENANT_ID\}\}/$AZURE_TENANT_ID}"
    result="${result//\{\{AZURE_LOCATION\}\}/$AZURE_LOCATION}"
    result="${result//\{\{AZURE_RESOURCE_GROUP\}\}/$AZURE_RESOURCE_GROUP}"

    # Networking variables
    result="${result//\{\{NETWORKING_VNET_NAME\}\}/${NETWORKING_VNET_NAME:-}}"
    result="${result//\{\{NETWORKING_VNET_CIDR\}\}/${NETWORKING_VNET_CIDR:-}}"
    result="${result//\{\{NETWORKING_SUBNET_NAME\}\}/${NETWORKING_SUBNET_NAME:-}}"
    result="${result//\{\{NETWORKING_SUBNET_CIDR\}\}/${NETWORKING_SUBNET_CIDR:-}}"
    result="${result//\{\{NETWORKING_NSG_NAME\}\}/${NETWORKING_NSG_NAME:-}}"
    result="${result//\{\{NETWORKING_SESSION_HOST_SUBNET_NAME\}\}/${NETWORKING_SESSION_HOST_SUBNET_NAME:-}}"
    result="${result//\{\{NETWORKING_PRIVATE_ENDPOINT_SUBNET_NAME\}\}/${NETWORKING_PRIVATE_ENDPOINT_SUBNET_NAME:-}}"
    result="${result//\{\{NETWORKING_MANAGEMENT_SUBNET_NAME\}\}/${NETWORKING_MANAGEMENT_SUBNET_NAME:-}}"

    # Storage variables
    result="${result//\{\{STORAGE_ACCOUNT_NAME\}\}/${STORAGE_ACCOUNT_NAME:-}}"
    result="${result//\{\{STORAGE_SHARE_NAME\}\}/${STORAGE_SHARE_NAME:-}}"
    result="${result//\{\{STORAGE_FILE_SHARE_NAME\}\}/${STORAGE_FILE_SHARE_NAME:-}}"
    result="${result//\{\{STORAGE_QUOTA_GB\}\}/${STORAGE_QUOTA_GB:-}}"
    result="${result//\{\{STORAGE_SKU\}\}/${STORAGE_SKU:-}}"
    result="${result//\{\{STORAGE_KIND\}\}/${STORAGE_KIND:-}}"
    result="${result//\{\{STORAGE_ENABLE_ENTRA_KERBEROS\}\}/${STORAGE_ENABLE_ENTRA_KERBEROS:-}}"
    result="${result//\{\{STORAGE_ENABLE_SMB_MULTICHANNEL\}\}/${STORAGE_ENABLE_SMB_MULTICHANNEL:-}}"
    result="${result//\{\{STORAGE_PUBLIC_NETWORK_ACCESS\}\}/${STORAGE_PUBLIC_NETWORK_ACCESS:-}}"
    result="${result//\{\{STORAGE_HTTPS_ONLY\}\}/${STORAGE_HTTPS_ONLY:-}}"
    result="${result//\{\{STORAGE_MIN_TLS_VERSION\}\}/${STORAGE_MIN_TLS_VERSION:-}}"

    # Entra ID variables
    result="${result//\{\{ENTRA_GROUP_USERS_STANDARD\}\}/${ENTRA_GROUP_USERS_STANDARD:-}}"
    result="${result//\{\{ENTRA_GROUP_USERS_STANDARD_DESCRIPTION\}\}/${ENTRA_GROUP_USERS_STANDARD_DESCRIPTION:-}}"
    result="${result//\{\{ENTRA_GROUP_USERS_ADMINS\}\}/${ENTRA_GROUP_USERS_ADMINS:-}}"
    result="${result//\{\{ENTRA_GROUP_USERS_ADMINS_DESCRIPTION\}\}/${ENTRA_GROUP_USERS_ADMINS_DESCRIPTION:-}}"
    result="${result//\{\{ENTRA_GROUP_DEVICES_SSO\}\}/${ENTRA_GROUP_DEVICES_SSO:-}}"
    result="${result//\{\{ENTRA_GROUP_DEVICES_SSO_DESCRIPTION\}\}/${ENTRA_GROUP_DEVICES_SSO_DESCRIPTION:-}}"
    result="${result//\{\{ENTRA_GROUP_DEVICES_FSLOGIX\}\}/${ENTRA_GROUP_DEVICES_FSLOGIX:-}}"
    result="${result//\{\{ENTRA_GROUP_DEVICES_FSLOGIX_DESCRIPTION\}\}/${ENTRA_GROUP_DEVICES_FSLOGIX_DESCRIPTION:-}}"
    result="${result//\{\{ENTRA_GROUP_DEVICES_NETWORK\}\}/${ENTRA_GROUP_DEVICES_NETWORK:-}}"
    result="${result//\{\{ENTRA_GROUP_DEVICES_NETWORK_DESCRIPTION\}\}/${ENTRA_GROUP_DEVICES_NETWORK_DESCRIPTION:-}}"
    result="${result//\{\{ENTRA_GROUP_DEVICES_SECURITY\}\}/${ENTRA_GROUP_DEVICES_SECURITY:-}}"
    result="${result//\{\{ENTRA_GROUP_DEVICES_SECURITY_DESCRIPTION\}\}/${ENTRA_GROUP_DEVICES_SECURITY_DESCRIPTION:-}}"

    # Golden Image variables
    result="${result//\{\{GOLDEN_IMAGE_TEMP_VM_NAME\}\}/${GOLDEN_IMAGE_TEMP_VM_NAME:-}}"
    result="${result//\{\{GOLDEN_IMAGE_VM_SIZE\}\}/${GOLDEN_IMAGE_VM_SIZE:-}}"
    result="${result//\{\{GOLDEN_IMAGE_IMAGE_PUBLISHER\}\}/${GOLDEN_IMAGE_IMAGE_PUBLISHER:-}}"
    result="${result//\{\{GOLDEN_IMAGE_IMAGE_OFFER\}\}/${GOLDEN_IMAGE_IMAGE_OFFER:-}}"
    result="${result//\{\{GOLDEN_IMAGE_IMAGE_SKU\}\}/${GOLDEN_IMAGE_IMAGE_SKU:-}}"
    result="${result//\{\{GOLDEN_IMAGE_IMAGE_VERSION\}\}/${GOLDEN_IMAGE_IMAGE_VERSION:-}}"
    result="${result//\{\{GOLDEN_IMAGE_ADMIN_USERNAME\}\}/${GOLDEN_IMAGE_ADMIN_USERNAME:-}}"
    result="${result//\{\{GOLDEN_IMAGE_ADMIN_PASSWORD\}\}/${GOLDEN_IMAGE_ADMIN_PASSWORD:-}}"
    result="${result//\{\{GOLDEN_IMAGE_GALLERY_NAME\}\}/${GOLDEN_IMAGE_GALLERY_NAME:-}}"
    result="${result//\{\{GOLDEN_IMAGE_DEFINITION_NAME\}\}/${GOLDEN_IMAGE_DEFINITION_NAME:-}}"
    result="${result//\{\{GOLDEN_IMAGE_APPLICATIONS_CSV\}\}/${GOLDEN_IMAGE_APPLICATIONS_CSV:-}}"
    result="${result//\{\{APP_MANIFEST_CONTENT\}\}/${APP_MANIFEST_CONTENT:-}}"
    result="${result//\{\{APP_MANIFEST_B64\}\}/${APP_MANIFEST_B64:-}}"

    # Host Pool variables
    result="${result//\{\{HOST_POOL_NAME\}\}/${HOST_POOL_NAME:-}}"
    result="${result//\{\{HOST_POOL_TYPE\}\}/${HOST_POOL_TYPE:-}}"
    result="${result//\{\{HOST_POOL_MAX_SESSIONS\}\}/${HOST_POOL_MAX_SESSIONS:-}}"
    result="${result//\{\{HOST_POOL_LOAD_BALANCER\}\}/${HOST_POOL_LOAD_BALANCER:-}}"

    # Workspace variables
    result="${result//\{\{WORKSPACE_NAME\}\}/${WORKSPACE_NAME:-}}"
    result="${result//\{\{WORKSPACE_FRIENDLY_NAME\}\}/${WORKSPACE_FRIENDLY_NAME:-}}"

    # App Group variables
    result="${result//\{\{APP_GROUP_NAME\}\}/${APP_GROUP_NAME:-}}"
    result="${result//\{\{APP_GROUP_TYPE\}\}/${APP_GROUP_TYPE:-}}"

    # Session Host variables
    result="${result//\{\{SESSION_HOST_VM_COUNT\}\}/${SESSION_HOST_VM_COUNT:-}}"
    result="${result//\{\{SESSION_HOST_VM_SIZE\}\}/${SESSION_HOST_VM_SIZE:-}}"
    result="${result//\{\{SESSION_HOST_NAME_PREFIX\}\}/${SESSION_HOST_NAME_PREFIX:-}}"

    # Project paths
    result="${result//\{\{PROJECT_ROOT\}\}/$PROJECT_ROOT}"

    # PowerShell content (for powershell-vm-command template type)
    # Replace {{POWERSHELL_CONTENT}} with the actual PowerShell script from YAML
    if [[ -n "${POWERSHELL_CONTENT:-}" && "${POWERSHELL_CONTENT:-}" != "null" ]]; then
        # Use a temporary marker to avoid issues with special characters
        local ps_marker="___POWERSHELL_CONTENT___"
        result="${result//\{\{POWERSHELL_CONTENT\}\}/$ps_marker}"

        # Create temp file with PowerShell content
        local temp_ps_file=$(mktemp)
        echo "${POWERSHELL_CONTENT:-}" > "$temp_ps_file"

        # Read it back and substitute
        local ps_content
        ps_content=$(<"$temp_ps_file")
        rm -f "$temp_ps_file"

        # Replace marker with actual content (using printf to handle special characters)
        result="${result//$ps_marker/$ps_content}"
    fi

    echo "$result"
}

# ==============================================================================
# Extract and Save PowerShell Script
# ==============================================================================
extract_powershell_script() {
    local yaml_file="$1"
    local module_dir
    module_dir="$(dirname "$yaml_file")"
    local output_dir="${PROJECT_ROOT}/artifacts/scripts"

    mkdir -p "$output_dir"

    # Check if PowerShell content exists in YAML
    if [[ -n "$POWERSHELL_CONTENT" && "$POWERSHELL_CONTENT" != "null" ]]; then
        # Extract PowerShell content from YAML
        local ps_file="${output_dir}/${OPERATION_ID}.ps1"
        yq e '.operation.powershell.content' "$yaml_file" > "$ps_file"

        echo "[v] PowerShell script extracted to: $ps_file" >&2
        echo "$ps_file"
        return 0
    elif [[ -n "$POWERSHELL_FILE" && "$POWERSHELL_FILE" != "null" ]]; then
        # Reference existing PowerShell file
        local ps_file="${module_dir}/${POWERSHELL_FILE}"

        if [[ ! -f "$ps_file" ]]; then
            echo "[x] ERROR: PowerShell file not found: $ps_file" >&2
            return 1
        fi

        echo "[v] Using PowerShell script: $ps_file" >&2
        echo "$ps_file"
        return 0
    else
        echo "[!] WARNING: No PowerShell script defined" >&2
        echo ""  # Return empty string for bash-only operations
        return 0  # Success - not all operations need PowerShell
    fi
}

# ==============================================================================
# Render Executable Command
# ==============================================================================
render_command() {
    local yaml_file="$1"

    # Parse operation
    parse_operation_yaml "$yaml_file" || return 1

    # Handle powershell-direct template type
    if [[ "$TEMPLATE_TYPE" == "powershell-direct" ]]; then
        # Create temp file with PowerShell content
        local temp_ps_file="/tmp/powershell-direct-${OPERATION_ID}-$(date +%s).ps1"

        # Extract and substitute variables in PowerShell content
        if [[ -n "$POWERSHELL_CONTENT" && "$POWERSHELL_CONTENT" != "null" ]]; then
            local ps_content
            ps_content=$(substitute_variables "$POWERSHELL_CONTENT")
            echo "$ps_content" > "$temp_ps_file"
        else
            echo "[x] ERROR: powershell-direct requires powershell.content" >&2
            return 1
        fi

        # Return command to execute PowerShell and cleanup
        echo "pwsh -NoProfile -NonInteractive -File \"$temp_ps_file\"; _exit_code=\$?; rm -f \"$temp_ps_file\"; exit \$_exit_code"
        return 0
    fi

    # Handle powershell-vm-command template type
    if [[ "$TEMPLATE_TYPE" == "powershell-vm-command" ]]; then
        # Substitute variables in template command
        local command
        command=$(substitute_variables "$TEMPLATE_COMMAND")
        echo "$command"
        return 0
    fi

    # Extract PowerShell script (if exists) for other template types
    local ps_script
    ps_script=$(extract_powershell_script "$yaml_file")  # Don't fail if no PowerShell
    local ps_script_status=$?

    # Substitute variables in template command
    local command
    command=$(substitute_variables "$TEMPLATE_COMMAND")

    # Replace @script.ps1 placeholder with actual path (only if PowerShell script exists)
    # Handle both "@filename.ps1" and "@modules/.../filename.ps1" patterns
    if [[ $ps_script_status -eq 0 && -n "$ps_script" && -n "$POWERSHELL_FILE" && "$POWERSHELL_FILE" != "null" ]]; then
        # Replace any path ending with the PowerShell filename using bash pattern substitution
        # Match "@" followed by any characters, ending with the PowerShell filename
        if [[ "$command" =~ @[^[:space:]]*${POWERSHELL_FILE} ]]; then
            local full_match="${BASH_REMATCH[0]}"
            command="${command//${full_match}/@${ps_script}}"
        fi
    fi

    echo "$command"
    return 0
}

# ==============================================================================
# Validate Operation Prerequisites
# ==============================================================================
validate_prerequisites() {
    local yaml_file="$1"

    echo "[*] Validating prerequisites..."

    # Check if requires section exists
    local requires_count
    requires_count=$(yq e '.operation.requires | length' "$yaml_file")

    if [[ "$requires_count" == "0" || "$requires_count" == "null" ]]; then
        echo "[v] No prerequisites defined"
        return 0
    fi

    # Check each prerequisite
    local i=0
    while [[ $i -lt $requires_count ]]; do
        local required_operation
        local required_status
        local is_optional="false"

        # Check if requires entry is a string or an object
        local entry_type
        entry_type=$(yq e ".operation.requires[$i] | type" "$yaml_file")

        if [[ "$entry_type" == "!!str" ]]; then
            # Simple string format: just operation ID
            required_operation=$(yq e ".operation.requires[$i]" "$yaml_file")
            required_status="completed"  # Default to completed
        else
            # Object format: operation and status fields
            required_operation=$(yq e ".operation.requires[$i].operation" "$yaml_file")
            required_status=$(yq e ".operation.requires[$i].status" "$yaml_file")
            is_optional=$(yq e ".operation.requires[$i].optional // false" "$yaml_file")
        fi

        echo "[*] Checking prerequisite: $required_operation (expected status: $required_status)"

        # Check state file for prerequisite completion
        local state_file="${PROJECT_ROOT}/state.json"
        if [[ -f "$state_file" ]]; then
            local actual_status
            actual_status=$(jq -r ".operations[\"$required_operation\"].status // \"not_found\"" "$state_file")

            if [[ "$actual_status" != "$required_status" ]]; then
                if [[ "$is_optional" == "true" ]]; then
                    echo "[!] WARNING: Optional prerequisite not met: $required_operation (skipping)"
                else
                    echo "[x] ERROR: Prerequisite not met: $required_operation"
                    echo "[x] Expected status: $required_status, Actual: $actual_status"
                    return 1
                fi
            fi
        else
            echo "[!] WARNING: No state file found, skipping prerequisite checks"
        fi

        ((i++))
    done

    echo "[v] All prerequisites validated"
    return 0
}

# ==============================================================================
# Validate Operation Results
# ==============================================================================
validate_results() {
    local yaml_file="$1"

    if [[ "$VALIDATION_ENABLED" != "true" ]]; then
        echo "[i] Validation disabled"
        return 0
    fi

    echo "[*] Validating results..."

    # Check if validation checks exist
    local checks_count
    checks_count=$(yq e '.operation.validation.checks | length' "$yaml_file")

    if [[ "$checks_count" == "0" || "$checks_count" == "null" ]]; then
        echo "[v] No validation checks defined"
        return 0
    fi

    # Run each validation check
    local i=0
    local failures=0

    while [[ $i -lt $checks_count ]]; do
        local check_type
        check_type=$(yq e ".operation.validation.checks[$i].type" "$yaml_file")

        case "$check_type" in
            "file_exists")
                local path
                path=$(yq e ".operation.validation.checks[$i].path" "$yaml_file")
                echo "[*] Checking file exists: $path"
                # This would be checked on the remote VM via az vm run-command
                echo "[i] File check: $path (requires remote validation)"
                ;;

            "registry_key")
                local key
                key=$(yq e ".operation.validation.checks[$i].path" "$yaml_file")
                echo "[*] Checking registry key: $key"
                # This would be checked on the remote VM via az vm run-command
                echo "[i] Registry check: $key (requires remote validation)"
                ;;

            "azure_resource")
                local resource_type
                resource_type=$(yq e ".operation.validation.checks[$i].resource_type" "$yaml_file")
                local resource_name
                resource_name=$(yq e ".operation.validation.checks[$i].resource_name" "$yaml_file")
                echo "[*] Checking Azure resource: $resource_type / $resource_name"
                # Check via Azure CLI
                ;;

            *)
                echo "[!] WARNING: Unknown validation check type: $check_type"
                ;;
        esac

        ((i++))
    done

    if [[ $failures -gt 0 ]]; then
        echo "[x] Validation failed with $failures failures"
        return 1
    fi

    echo "[v] All validations passed"
    return 0
}

# ==============================================================================
# Execute Operation
# ==============================================================================
execute_operation() {
    local yaml_file="$1"

    echo ""
    echo "===================================================================="
    echo "  Executing Operation"
    echo "===================================================================="

    # Parse operation
    parse_operation_yaml "$yaml_file" || return 1

    echo ""
    echo "Operation: $OPERATION_NAME"
    echo "ID: $OPERATION_ID"
    echo "Expected Duration: ${OPERATION_DURATION_EXPECTED}s (Type: $OPERATION_DURATION_TYPE)"
    echo "Timeout: ${OPERATION_DURATION_TIMEOUT}s"
    echo ""

    # Validate prerequisites
    validate_prerequisites "$yaml_file" || return 1

    # Render executable command
    local command
    command=$(render_command "$yaml_file") || return 1

    echo "[*] Executing command..."
    echo ""

    # Execute the command
    # Note: In Phase 2, this will be replaced with progress-tracker.sh
    eval "$command"
    local exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        echo ""
        echo "[x] Operation failed (exit code: $exit_code)"
        return $exit_code
    fi

    echo ""
    echo "[v] Operation completed successfully"

    # Validate results
    validate_results "$yaml_file" || return 1

    echo ""
    echo "===================================================================="
    return 0
}

# ==============================================================================
# Edit PowerShell Content in Template
# ==============================================================================
edit_powershell_in_template() {
    local yaml_file="$1"
    local new_powershell_content="$2"

    if [[ ! -f "$yaml_file" ]]; then
        echo "[x] Template file not found: $yaml_file"
        return 1
    fi

    echo "[*] Updating PowerShell content in template"

    # Create temporary file with new content
    local temp_file
    temp_file=$(mktemp)
    echo "$new_powershell_content" > "$temp_file"

    # Use yq to update the powershell.content field
    yq e -i ".operation.powershell.content = load_str(\"$temp_file\")" "$yaml_file"

    rm -f "$temp_file"

    echo "[v] PowerShell content updated in: $yaml_file"
    return 0
}

# ==============================================================================
# Add Fix to Template
# ==============================================================================
add_fix_to_template() {
    local yaml_file="$1"
    local issue="$2"
    local fix_description="$3"
    local fix_date="${4:-$(date +%Y-%m-%d)}"

    if [[ ! -f "$yaml_file" ]]; then
        echo "[x] Template file not found: $yaml_file"
        return 1
    fi

    echo "[*] Adding fix record to template"

    # Check if fixes section exists
    local has_fixes
    has_fixes=$(yq e '.operation.fixes' "$yaml_file")

    if [[ "$has_fixes" == "null" ]]; then
        # Initialize fixes array
        yq e -i '.operation.fixes = []' "$yaml_file"
    fi

    # Get current number of fixes
    local fix_count
    fix_count=$(yq e '.operation.fixes | length' "$yaml_file")

    # Add new fix entry
    yq e -i ".operation.fixes[$fix_count].issue = \"$issue\"" "$yaml_file"
    yq e -i ".operation.fixes[$fix_count].detected = \"$fix_date\"" "$yaml_file"
    yq e -i ".operation.fixes[$fix_count].fix = \"$fix_description\"" "$yaml_file"
    yq e -i ".operation.fixes[$fix_count].applied_to_template = true" "$yaml_file"

    echo "[v] Fix record added to template"
    return 0
}

# ==============================================================================
# Get Fixes from Template
# ==============================================================================
get_template_fixes() {
    local yaml_file="$1"

    if [[ ! -f "$yaml_file" ]]; then
        echo "Template not found: $yaml_file"
        return 1
    fi

    local fixes
    fixes=$(yq e '.operation.fixes' "$yaml_file")

    if [[ "$fixes" == "null" || "$fixes" == "[]" ]]; then
        echo "No fixes recorded in template"
        return 0
    fi

    echo "Fixes applied to this template:"
    yq e '.operation.fixes[] | "  [" + .detected + "] " + .issue + "\n    Fix: " + .fix' "$yaml_file"
}

# ==============================================================================
# Update Operation Duration
# ==============================================================================
update_operation_duration() {
    local yaml_file="$1"
    local expected="$2"
    local timeout="$3"

    if [[ ! -f "$yaml_file" ]]; then
        echo "[x] Template file not found: $yaml_file"
        return 1
    fi

    echo "[*] Updating operation duration"

    yq e -i ".operation.duration.expected = $expected" "$yaml_file"
    yq e -i ".operation.duration.timeout = $timeout" "$yaml_file"

    echo "[v] Duration updated: expected=${expected}s, timeout=${timeout}s"
    return 0
}

# ==============================================================================
# Add Validation Check to Template
# ==============================================================================
add_validation_check() {
    local yaml_file="$1"
    local check_type="$2"
    shift 2
    local -a check_params=("$@")

    if [[ ! -f "$yaml_file" ]]; then
        echo "[x] Template file not found: $yaml_file"
        return 1
    fi

    echo "[*] Adding validation check: $check_type"

    # Ensure validation is enabled
    yq e -i '.operation.validation.enabled = true' "$yaml_file"

    # Check if checks array exists
    local has_checks
    has_checks=$(yq e '.operation.validation.checks' "$yaml_file")

    if [[ "$has_checks" == "null" ]]; then
        yq e -i '.operation.validation.checks = []' "$yaml_file"
    fi

    # Get current number of checks
    local check_count
    check_count=$(yq e '.operation.validation.checks | length' "$yaml_file")

    # Add check based on type
    case "$check_type" in
        "file_exists")
            yq e -i ".operation.validation.checks[$check_count].type = \"file_exists\"" "$yaml_file"
            yq e -i ".operation.validation.checks[$check_count].path = \"${check_params[0]}\"" "$yaml_file"
            ;;
        "registry_key")
            yq e -i ".operation.validation.checks[$check_count].type = \"registry_key\"" "$yaml_file"
            yq e -i ".operation.validation.checks[$check_count].path = \"${check_params[0]}\"" "$yaml_file"
            ;;
        "service_status")
            yq e -i ".operation.validation.checks[$check_count].type = \"service_status\"" "$yaml_file"
            yq e -i ".operation.validation.checks[$check_count].service_name = \"${check_params[0]}\"" "$yaml_file"
            yq e -i ".operation.validation.checks[$check_count].expected_status = \"${check_params[1]}\"" "$yaml_file"
            ;;
        *)
            echo "[x] Unknown validation check type: $check_type"
            return 1
            ;;
    esac

    echo "[v] Validation check added"
    return 0
}

# ==============================================================================
# Export functions for use by other scripts
# ==============================================================================
export -f parse_operation_yaml
export -f substitute_variables
export -f extract_powershell_script
export -f render_command
export -f validate_prerequisites
export -f validate_results
export -f execute_operation
export -f edit_powershell_in_template
export -f add_fix_to_template
export -f get_template_fixes
export -f update_operation_duration
export -f add_validation_check
