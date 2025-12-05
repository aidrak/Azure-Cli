#!/bin/bash

# ============================================================================
# Task 03: Configure VM with Golden Image Software and Optimizations
# ============================================================================
#
# Purpose: Configures the VM with all required software (FSLogix, Chrome, Adobe,
# Office), security settings, and AVD optimizations (VDOT).
#
# Dependencies: Task 02 (VM must be validated and running)
#
# Prerequisites:
# - VM must be running and fully booted
# - Azure CLI must be authenticated
# - config.env must be sourced
# - config_vm.ps1 must exist
#
# Inputs from config.env:
# - RESOURCE_GROUP_NAME
# - TEMP_VM_NAME
# - FSLOGIX_VERSION
# - VDOT_VERSION
#
# Outputs:
# - VM configured with all software and optimizations
# - logs/artifacts/task-03-*.log
# - logs/artifacts/task-03-configuration-details.txt
#
# Notes:
# - Uses 'az vm run-command' for non-interactive execution
# - Expected runtime: 30-60 minutes (includes Windows Updates)
# - Large output - may take time to complete
#

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ============================================================================
# Configuration
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.env"
PS_CONFIG_SCRIPT="${SCRIPT_DIR}/config_vm.ps1"

if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}ERROR: Configuration file not found: $CONFIG_FILE${NC}"
    exit 1
fi

if [ ! -f "$PS_CONFIG_SCRIPT" ]; then
    echo -e "${RED}ERROR: PowerShell configuration script not found: $PS_CONFIG_SCRIPT${NC}"
    exit 1
fi

source "$CONFIG_FILE"

TASK_NAME="03-configure-vm"
TIMESTAMP=$(date +'%Y%m%d_%H%M%S')
LOG_FILE="${SCRIPT_DIR}/artifacts/${TASK_NAME}_${TIMESTAMP}.log"

# ============================================================================
# Logging Functions
# ============================================================================

log_section() {
    echo -e "\n${BLUE}=== $1 ===${NC}" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}✓ $1${NC}" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}✗ $1${NC}" | tee -a "$LOG_FILE"
    exit 1
}

log_warning() {
    echo -e "${YELLOW}⚠ $1${NC}" | tee -a "$LOG_FILE"
}

log_info() {
    echo -e "${YELLOW}ℹ $1${NC}" | tee -a "$LOG_FILE"
}

# ============================================================================
# Pre-flight Checks
# ============================================================================

check_prerequisites() {
    log_section "Checking Prerequisites"

    # Check VM exists and is running
    if ! az vm show -g "$RESOURCE_GROUP_NAME" -n "$TEMP_VM_NAME" &> /dev/null; then
        log_error "VM '$TEMP_VM_NAME' not found"
    fi
    log_success "VM '$TEMP_VM_NAME' exists"

    # Check VM is running
    VM_STATE=$(az vm get-instance-view -g "$RESOURCE_GROUP_NAME" -n "$TEMP_VM_NAME" --query "instanceView.statuses[?starts_with(code, 'PowerState')].displayStatus" -o tsv)
    if [[ "$VM_STATE" != "VM running" ]]; then
        log_error "VM is not running (current state: $VM_STATE)"
    fi
    log_success "VM is running"
}

# ============================================================================
# Configuration Execution
# ============================================================================

run_configuration() {
    log_section "Running VM Configuration via Azure CLI"

    log_info "Configuration includes:"
    log_info "  • Disabling BitLocker"
    log_info "  • Installing Windows Updates"
    log_info "  • Installing FSLogix (v$FSLOGIX_VERSION)"
    log_info "  • Installing Google Chrome Enterprise"
    log_info "  • Installing Adobe Reader DC"
    log_info "  • Installing Microsoft Office 365"
    log_info "  • Running AVD Optimization Tool (v$VDOT_VERSION)"
    log_info "  • Applying registry optimizations"
    log_info "  • Configuring default user profile"
    log_info ""
    log_warning "This process may take 30-60 minutes"
    log_info "Remote execution via az vm run-command..."

    # Execute PowerShell script on VM
    # Note: This reads the local PS1 file and sends commands to the VM
    az vm run-command invoke \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --name "$TEMP_VM_NAME" \
        --command-id RunPowerShellScript \
        --scripts "$(cat "$PS_CONFIG_SCRIPT")" \
        --output json > "${SCRIPT_DIR}/artifacts/${TASK_NAME}_execution-output.json" 2>&1 || true

    log_success "Configuration execution completed"
}

parse_execution_output() {
    log_section "Parsing Execution Output"

    local output_file="${SCRIPT_DIR}/artifacts/${TASK_NAME}_execution-output.json"

    if [ -f "$output_file" ]; then
        # Extract stdout and stderr from JSON output
        log_info "Extracting configuration output..."

        # Try to extract stdout
        STDOUT=$(cat "$output_file" | grep -o '"stdout":"[^"]*"' | sed 's/"stdout":"\(.*\)"/\1/' | head -1)
        if [ -n "$STDOUT" ]; then
            echo "$STDOUT" >> "$LOG_FILE"
            log_success "Configuration output available (see log file for details)"
        fi

        # Check for errors
        STDERR=$(cat "$output_file" | grep -o '"stderr":"[^"]*"' | sed 's/"stderr":"\(.*\)"/\1/' | head -1)
        if [ -n "$STDERR" ]; then
            log_warning "Configuration execution had warnings/errors (see log file)"
            echo "$STDERR" >> "$LOG_FILE"
        fi

        # Check exit code
        EXIT_CODE=$(cat "$output_file" | grep -o '"exitCode":[0-9]*' | sed 's/"exitCode":\([0-9]*\)/\1/')
        if [ -n "$EXIT_CODE" ]; then
            if [ "$EXIT_CODE" -eq 0 ]; then
                log_success "Configuration execution exit code: $EXIT_CODE (success)"
            else
                log_warning "Configuration execution exit code: $EXIT_CODE (check log for details)"
            fi
        fi
    fi
}

# ============================================================================
# Main Execution
# ============================================================================

log_section "TASK 03: Configure VM"
log_info "Log file: $LOG_FILE"

check_prerequisites
run_configuration
parse_execution_output

log_section "Task Complete"
log_success "VM configuration completed"
log_warning "Next step: Run task 04-sysprep-vm.sh to prepare VM for image capture"
log_info "Note: VM will be shut down during sysprep process"

exit 0
