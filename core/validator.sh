#!/bin/bash
# ==============================================================================
# Validator - Operation Result Validation Framework
# ==============================================================================
#
# Purpose: Validate operation results (files, registry keys, services, Azure resources)
# Usage:
#   source core/validator.sh
#   validate_file_exists "C:\\Program Files\\FSLogix\\Apps\\frx.exe" "gm-temp-vm"
#   validate_registry_key "HKLM:\\SOFTWARE\\FSLogix" "gm-temp-vm"
#   validate_azure_resource "vm" "gm-temp-vm"
#
# ==============================================================================

set -euo pipefail

# Project paths
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

# ==============================================================================
# Validate File Exists on Remote VM
# ==============================================================================
validate_file_exists() {
    local file_path="$1"
    local vm_name="$2"
    local resource_group="${3:-$AZURE_RESOURCE_GROUP}"

    echo "[*] Validating file exists: $file_path"

    # Create PowerShell validation script
    local validation_script="
    if (Test-Path '$file_path') {
        Write-Host '[VALIDATE_SUCCESS] File exists: $file_path'
        exit 0
    } else {
        Write-Host '[VALIDATE_FAILURE] File not found: $file_path'
        exit 1
    }
    "

    # Execute via az vm run-command
    local result
    result=$(az vm run-command invoke \
        --resource-group "$resource_group" \
        --name "$vm_name" \
        --command-id RunPowerShellScript \
        --scripts "$validation_script" \
        --output json 2>&1)

    if echo "$result" | grep -q "\[VALIDATE_SUCCESS\]"; then
        echo "[v] File validation passed: $file_path"
        return 0
    else
        echo "[x] File validation failed: $file_path"
        echo "$result"
        return 1
    fi
}

# ==============================================================================
# Validate Registry Key Exists on Remote VM
# ==============================================================================
validate_registry_key() {
    local registry_path="$1"
    local vm_name="$2"
    local resource_group="${3:-$AZURE_RESOURCE_GROUP}"

    echo "[*] Validating registry key: $registry_path"

    # Create PowerShell validation script
    local validation_script="
    if (Test-Path '$registry_path') {
        Write-Host '[VALIDATE_SUCCESS] Registry key exists: $registry_path'
        exit 0
    } else {
        Write-Host '[VALIDATE_FAILURE] Registry key not found: $registry_path'
        exit 1
    }
    "

    # Execute via az vm run-command
    local result
    result=$(az vm run-command invoke \
        --resource-group "$resource_group" \
        --name "$vm_name" \
        --command-id RunPowerShellScript \
        --scripts "$validation_script" \
        --output json 2>&1)

    if echo "$result" | grep -q "\[VALIDATE_SUCCESS\]"; then
        echo "[v] Registry validation passed: $registry_path"
        return 0
    else
        echo "[x] Registry validation failed: $registry_path"
        echo "$result"
        return 1
    fi
}

# ==============================================================================
# Validate Registry Value on Remote VM
# ==============================================================================
validate_registry_value() {
    local registry_path="$1"
    local value_name="$2"
    local expected_value="$3"
    local vm_name="$4"
    local resource_group="${5:-$AZURE_RESOURCE_GROUP}"

    echo "[*] Validating registry value: $registry_path\\$value_name = $expected_value"

    # Create PowerShell validation script
    local validation_script="
    try {
        \$value = Get-ItemPropertyValue -Path '$registry_path' -Name '$value_name' -ErrorAction Stop
        if (\$value -eq '$expected_value') {
            Write-Host '[VALIDATE_SUCCESS] Registry value matches: $value_name = $expected_value'
            exit 0
        } else {
            Write-Host '[VALIDATE_FAILURE] Registry value mismatch: $value_name = ' \$value ' (expected: $expected_value)'
            exit 1
        }
    } catch {
        Write-Host '[VALIDATE_FAILURE] Registry value not found: $value_name'
        exit 1
    }
    "

    # Execute via az vm run-command
    local result
    result=$(az vm run-command invoke \
        --resource-group "$resource_group" \
        --name "$vm_name" \
        --command-id RunPowerShellScript \
        --scripts "$validation_script" \
        --output json 2>&1)

    if echo "$result" | grep -q "\[VALIDATE_SUCCESS\]"; then
        echo "[v] Registry value validation passed"
        return 0
    else
        echo "[x] Registry value validation failed"
        echo "$result"
        return 1
    fi
}

# ==============================================================================
# Validate Service Status on Remote VM
# ==============================================================================
validate_service_status() {
    local service_name="$1"
    local expected_status="$2"  # Running, Stopped, etc.
    local vm_name="$3"
    local resource_group="${4:-$AZURE_RESOURCE_GROUP}"

    echo "[*] Validating service: $service_name (expected: $expected_status)"

    # Create PowerShell validation script
    local validation_script="
    try {
        \$service = Get-Service -Name '$service_name' -ErrorAction Stop
        if (\$service.Status -eq '$expected_status') {
            Write-Host '[VALIDATE_SUCCESS] Service status correct: $service_name = ' \$service.Status
            exit 0
        } else {
            Write-Host '[VALIDATE_FAILURE] Service status incorrect: $service_name = ' \$service.Status ' (expected: $expected_status)'
            exit 1
        }
    } catch {
        Write-Host '[VALIDATE_FAILURE] Service not found: $service_name'
        exit 1
    }
    "

    # Execute via az vm run-command
    local result
    result=$(az vm run-command invoke \
        --resource-group "$resource_group" \
        --name "$vm_name" \
        --command-id RunPowerShellScript \
        --scripts "$validation_script" \
        --output json 2>&1)

    if echo "$result" | grep -q "\[VALIDATE_SUCCESS\]"; then
        echo "[v] Service validation passed"
        return 0
    else
        echo "[x] Service validation failed"
        echo "$result"
        return 1
    fi
}

# ==============================================================================
# Validate Azure Resource Exists
# ==============================================================================
validate_azure_resource() {
    local resource_type="$1"  # vm, vnet, nsg, storage-account, etc.
    local resource_name="$2"
    local resource_group="${3:-$AZURE_RESOURCE_GROUP}"

    echo "[*] Validating Azure resource: $resource_type/$resource_name"

    local result
    case "$resource_type" in
        "vm")
            result=$(az vm show \
                --resource-group "$resource_group" \
                --name "$resource_name" \
                --query "provisioningState" \
                --output tsv 2>&1)
            ;;

        "vnet")
            result=$(az network vnet show \
                --resource-group "$resource_group" \
                --name "$resource_name" \
                --query "provisioningState" \
                --output tsv 2>&1)
            ;;

        "nsg")
            result=$(az network nsg show \
                --resource-group "$resource_group" \
                --name "$resource_name" \
                --query "provisioningState" \
                --output tsv 2>&1)
            ;;

        "storage-account")
            result=$(az storage account show \
                --resource-group "$resource_group" \
                --name "$resource_name" \
                --query "provisioningState" \
                --output tsv 2>&1)
            ;;

        "host-pool")
            result=$(az desktopvirtualization hostpool show \
                --resource-group "$resource_group" \
                --name "$resource_name" \
                --query "provisioningState" \
                --output tsv 2>&1)
            ;;

        *)
            echo "[x] Unknown resource type: $resource_type"
            return 1
            ;;
    esac

    if [[ "$result" == "Succeeded" ]]; then
        echo "[v] Azure resource validation passed: $resource_type/$resource_name"
        return 0
    else
        echo "[x] Azure resource validation failed: $resource_type/$resource_name"
        echo "  Provisioning state: $result"
        return 1
    fi
}

# ==============================================================================
# Validate Multiple Checks from YAML
# ==============================================================================
validate_from_yaml() {
    local yaml_file="$1"
    local vm_name="${2:-$GOLDEN_IMAGE_TEMP_VM_NAME}"

    echo "[*] Running validations from: $yaml_file"

    # Check if validation enabled
    local validation_enabled
    validation_enabled=$(yq e '.operation.validation.enabled // false' "$yaml_file")

    if [[ "$validation_enabled" != "true" ]]; then
        echo "[i] Validation disabled for this operation"
        return 0
    fi

    # Get number of checks
    local checks_count
    checks_count=$(yq e '.operation.validation.checks | length' "$yaml_file")

    if [[ "$checks_count" == "0" || "$checks_count" == "null" ]]; then
        echo "[i] No validation checks defined"
        return 0
    fi

    echo "[*] Running $checks_count validation checks..."
    echo ""

    local failures=0
    local i=0

    while [[ $i -lt $checks_count ]]; do
        local check_type
        check_type=$(yq e ".operation.validation.checks[$i].type" "$yaml_file")

        case "$check_type" in
            "file_exists")
                local path
                path=$(yq e ".operation.validation.checks[$i].path" "$yaml_file")
                validate_file_exists "$path" "$vm_name" || ((failures++))
                ;;

            "registry_key")
                local path
                path=$(yq e ".operation.validation.checks[$i].path" "$yaml_file")
                validate_registry_key "$path" "$vm_name" || ((failures++))
                ;;

            "registry_value")
                local path value_name expected_value
                path=$(yq e ".operation.validation.checks[$i].path" "$yaml_file")
                value_name=$(yq e ".operation.validation.checks[$i].value_name" "$yaml_file")
                expected_value=$(yq e ".operation.validation.checks[$i].expected_value" "$yaml_file")
                validate_registry_value "$path" "$value_name" "$expected_value" "$vm_name" || ((failures++))
                ;;

            "service_status")
                local service_name expected_status
                service_name=$(yq e ".operation.validation.checks[$i].service_name" "$yaml_file")
                expected_status=$(yq e ".operation.validation.checks[$i].expected_status" "$yaml_file")
                validate_service_status "$service_name" "$expected_status" "$vm_name" || ((failures++))
                ;;

            "azure_resource")
                local resource_type resource_name
                resource_type=$(yq e ".operation.validation.checks[$i].resource_type" "$yaml_file")
                resource_name=$(yq e ".operation.validation.checks[$i].resource_name" "$yaml_file")
                validate_azure_resource "$resource_type" "$resource_name" || ((failures++))
                ;;

            *)
                echo "[!] Unknown validation type: $check_type"
                ((failures++))
                ;;
        esac

        echo ""
        ((i++))
    done

    if [[ $failures -eq 0 ]]; then
        echo "[v] All validations passed ($checks_count checks)"
        return 0
    else
        echo "[x] Validation failed: $failures of $checks_count checks failed"
        return 1
    fi
}

# ==============================================================================
# Export functions
# ==============================================================================
export -f validate_file_exists
export -f validate_registry_key
export -f validate_registry_value
export -f validate_service_status
export -f validate_azure_resource
export -f validate_from_yaml
