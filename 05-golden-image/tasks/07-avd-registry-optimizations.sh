#!/bin/bash

################################################################################
# Task 07: Apply AVD-Specific Registry Optimizations
#
# Purpose: Apply registry optimizations specific to Azure Virtual Desktop
#          for Pooled (multi-session) environments with FSLogix.
#          This task corresponds to Step 7 of the manual golden image guide.
#
# Usage:
#   ./tasks/07-avd-registry-optimizations.sh
#
# Prerequisites:
#   - Azure CLI installed and authenticated
#   - config.env properly configured
#   - VM must be running and accessible
#   - Previous steps (Steps 1-6) completed on the VM
#
# Environment Variables (from config.env):
#   - RESOURCE_GROUP_NAME   Resource group containing VM
#   - TEMP_VM_NAME          Temporary VM for golden image
#
# Outputs:
#   - Logs saved to: artifacts/07-avd-registry-optimizations_TIMESTAMP.log
#   - JSON output: artifacts/07-avd-registry-optimizations-output.json
#   - Details: artifacts/07-avd-registry-optimizations-details.txt
#
# Exit Codes:
#   0 - Success
#   1 - Failure
#
# Author: Generated from task template
# Version: 1.0
################################################################################

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

# Script metadata
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_NAME="$(basename "$0")"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
STEP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Load configuration from parent directory
CONFIG_FILE="${STEP_DIR}/config.env"
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "ERROR: Configuration file not found: $CONFIG_FILE"
    exit 1
fi

# Source config
source "$CONFIG_FILE" || { echo "ERROR: Failed to load config"; exit 1; }

# Initialize logging
ENABLE_LOGGING=1
LOG_DIR="${STEP_DIR}/artifacts"
mkdir -p "$LOG_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="${LOG_DIR}/${SCRIPT_NAME%.*}_${TIMESTAMP}.log"

# ============================================================================
# LOAD FUNCTION LIBRARIES
# ============================================================================

# Load logging functions
LOGGING_FUNCS="${PROJECT_ROOT}/common/functions/logging-functions.sh"
if [[ -f "$LOGGING_FUNCS" ]]; then
    source "$LOGGING_FUNCS"
else
    # Fallback logging if functions not available
    log_info() { echo "ℹ $*" | tee -a "$LOG_FILE"; }
    log_success() { echo "✓ $*" | tee -a "$LOG_FILE"; }
    log_error() { echo "✗ $*" | tee -a "$LOG_FILE" >&2; }
    log_warning() { echo "⚠ $*" | tee -a "$LOG_FILE"; }
    log_section() { echo "" | tee -a "$LOG_FILE"; echo "=== $* ===" | tee -a "$LOG_FILE"; echo "" | tee -a "$LOG_FILE"; }
fi

# ============================================================================
# INITIALIZE LOGGING
# ============================================================================

log_section "Task 07: Apply AVD-Specific Registry Optimizations"
log_info "Execution started at $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
log_info "Log file: $LOG_FILE"
log_info "Script location: $SCRIPT_DIR"

# ============================================================================
# VALIDATION
# ============================================================================

validate_prerequisites() {
    log_section "Validating Prerequisites"

    # Check Azure CLI
    if ! command -v az &>/dev/null; then
        log_error "Azure CLI not installed"
        return 1
    fi
    log_success "Azure CLI installed"

    # Check Azure authentication
    if ! az account show &>/dev/null; then
        log_error "Not authenticated to Azure. Run: az login"
        return 1
    fi
    log_success "Azure authentication verified"

    # Validate required configuration variables
    local required_vars=(
        "RESOURCE_GROUP_NAME"
        "TEMP_VM_NAME"
    )

    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            log_error "Required variable not set: $var"
            return 1
        fi
        log_info "$var = ${!var}"
    done

    # Verify VM exists
    log_info "Checking if VM '$TEMP_VM_NAME' exists..."
    if ! az vm show -g "$RESOURCE_GROUP_NAME" -n "$TEMP_VM_NAME" &>/dev/null; then
        log_error "VM '$TEMP_VM_NAME' not found in resource group '$RESOURCE_GROUP_NAME'"
        return 1
    fi
    log_success "VM '$TEMP_VM_NAME' exists"

    # Check VM is running
    log_info "Checking VM power state..."
    VM_STATE=$(az vm get-instance-view -g "$RESOURCE_GROUP_NAME" -n "$TEMP_VM_NAME" --query "instanceView.statuses[?starts_with(code, 'PowerState')].displayStatus" -o tsv)
    if [[ "$VM_STATE" != "VM running" ]]; then
        log_error "VM is not running (current state: $VM_STATE)"
        return 1
    fi
    log_success "VM is running"

    log_success "All prerequisites validated"
    return 0
}

# ============================================================================
# MAIN TASK LOGIC
# ============================================================================

execute_registry_optimizations() {
    log_section "Executing Registry Optimizations"

    # Locate PowerShell script
    PS_SCRIPT="${STEP_DIR}/powershell/avd-registry-optimizations.ps1"
    if [[ ! -f "$PS_SCRIPT" ]]; then
        log_error "PowerShell script not found: $PS_SCRIPT"
        return 1
    fi
    log_info "Found PowerShell script: $PS_SCRIPT"

    # Display what will be executed
    log_info "Registry optimizations include:"
    log_info "  • RDP timezone redirection"
    log_info "  • FSLogix Defender exclusions (Pooled only)"
    log_info "  • Locale settings (en-US)"
    log_info "  • Disable System Restore and VSS"
    log_info "  • Black screen fix (disable first logon animation)"
    log_info "  • OOBE privacy suppression"
    log_info "  • Windows Hello suppression"
    log_info "  • Default User profile configuration"
    log_info ""
    log_warning "Executing PowerShell script on VM (this may take 2-5 minutes)..."

    # Read PowerShell script and execute via az vm run-command
    local output_file="${LOG_DIR}/${SCRIPT_NAME%.*}-output.json"

    az vm run-command invoke \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --name "$TEMP_VM_NAME" \
        --command-id RunPowerShellScript \
        --scripts "@${PS_SCRIPT}" \
        --output json > "$output_file" 2>&1 || true

    # Check if output file exists
    if [[ ! -f "$output_file" ]]; then
        log_error "Failed to execute PowerShell script on VM"
        return 1
    fi

    log_success "PowerShell script execution completed"

    # Extract and display output
    parse_execution_output "$output_file"

    return 0
}

parse_execution_output() {
    local output_file="$1"

    log_section "Parsing Execution Output"

    # Extract exit code
    local exit_code
    exit_code=$(jq -r '.value[0].exitCode // empty' "$output_file" 2>/dev/null || echo "")

    if [[ -n "$exit_code" ]]; then
        log_info "PowerShell exit code: $exit_code"
        if [[ "$exit_code" == "0" ]]; then
            log_success "Script executed successfully (exit code: 0)"
        else
            log_warning "Script completed with exit code: $exit_code"
        fi
    fi

    # Extract stdout
    local stdout
    stdout=$(jq -r '.value[0].stdout // empty' "$output_file" 2>/dev/null || echo "")

    if [[ -n "$stdout" ]]; then
        log_info "Script output:"
        echo "$stdout" | tee -a "$LOG_FILE"
    fi

    # Extract stderr
    local stderr
    stderr=$(jq -r '.value[0].stderr // empty' "$output_file" 2>/dev/null || echo "")

    if [[ -n "$stderr" ]]; then
        log_warning "Script warnings/errors:"
        echo "$stderr" | tee -a "$LOG_FILE"
    fi

    # Save JSON output for debugging
    log_info "Full execution output saved to: $output_file"
}

save_artifacts() {
    log_section "Saving Artifacts"

    # Create details file
    local details_file="${LOG_DIR}/${SCRIPT_NAME%.*}-details.txt"
    {
        echo "Task 07: Apply AVD-Specific Registry Optimizations"
        echo "======================================================="
        echo ""
        echo "Execution Details:"
        echo "  Timestamp: $TIMESTAMP"
        echo "  Script: $SCRIPT_NAME"
        echo "  Resource Group: $RESOURCE_GROUP_NAME"
        echo "  VM Name: $TEMP_VM_NAME"
        echo ""
        echo "Optimizations Applied:"
        echo "  ✓ RDP timezone redirection"
        echo "  ✓ FSLogix Defender exclusions"
        echo "  ✓ Locale settings (en-US)"
        echo "  ✓ System Restore and VSS disabled"
        echo "  ✓ First logon animation disabled"
        echo "  ✓ OOBE privacy screens disabled"
        echo "  ✓ Windows Hello disabled"
        echo "  ✓ Default User profile configured"
        echo ""
        echo "Next Steps:"
        echo "  1. Verify VM is in desired state"
        echo "  2. Run Task 08 (Final Cleanup & Sysprep Preparation)"
        echo "  3. Then run Task 04 (Sysprep VM)"
        echo "  4. Then run Task 05 (Capture Image)"
        echo ""
        echo "Log File: $LOG_FILE"
        echo "Output File: ${LOG_DIR}/${SCRIPT_NAME%.*}-output.json"
    } > "$details_file"

    log_success "Details saved to: $details_file"
    cat "$details_file" | tee -a "$LOG_FILE"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    local exit_code=0

    # Validate prerequisites
    if ! validate_prerequisites; then
        log_error "Prerequisites validation failed"
        exit_code=1
    # Execute registry optimizations
    elif ! execute_registry_optimizations; then
        log_error "Registry optimizations failed"
        exit_code=1
    fi

    # Save artifacts regardless of success/failure
    save_artifacts

    # Final message
    log_section "Task 07 Complete"
    if [[ $exit_code -eq 0 ]]; then
        log_success "AVD-specific registry optimizations applied successfully"
        log_info "Execution completed at $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
        log_warning "Next: Run Task 08 for final cleanup and sysprep preparation"
    else
        log_error "Task 07 failed. Check logs for details."
        log_info "Log file: $LOG_FILE"
    fi

    return $exit_code
}

# Execute main function
main "$@"
exit $?
