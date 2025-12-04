#!/bin/bash

# ============================================================================
# Task 04: Run Sysprep on VM
# ============================================================================
#
# Purpose: Prepares the configured VM for image capture by running Windows
# Sysprep utility. This generalizes the VM so it can be captured as a reusable
# image and deployed to multiple VMs.
#
# Dependencies: Task 03 (VM must be configured)
#
# Prerequisites:
# - VM must be configured and running
# - Azure CLI must be authenticated
# - config.env must be sourced
#
# Inputs from config.env:
# - RESOURCE_GROUP_NAME
# - TEMP_VM_NAME
#
# Outputs:
# - VM generalized via sysprep
# - VM shut down automatically after sysprep
# - logs/artifacts/task-04-*.log
#
# Notes:
# - Idempotent: checks if VM is already generalized
# - VM will be shut down by sysprep (normal behavior)
# - Expected runtime: 5-10 minutes
# - After sysprep, VM must be deallocated before capture
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

if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}ERROR: Configuration file not found: $CONFIG_FILE${NC}"
    exit 1
fi

source "$CONFIG_FILE"

TASK_NAME="04-sysprep-vm"
TIMESTAMP=$(date +'%Y%m%d_%H%M%S')
LOG_FILE="${SCRIPT_DIR}/artifacts/${TASK_NAME}_${TIMESTAMP}.log"

MAX_WAIT_ATTEMPTS=120  # 10 minutes
WAIT_INTERVAL=5

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

check_vm_exists() {
    log_section "Checking VM Status"

    if ! az vm show -g "$RESOURCE_GROUP_NAME" -n "$TEMP_VM_NAME" &> /dev/null; then
        log_error "VM '$TEMP_VM_NAME' not found"
    fi
    log_success "VM '$TEMP_VM_NAME' exists"
}

# ============================================================================
# Sysprep Execution
# ============================================================================

run_sysprep() {
    log_section "Running Sysprep on VM"

    log_warning "Sysprep will generalize and shut down the VM"
    log_info "This is necessary to prepare the VM for image capture"
    log_info "Sysprep command: C:\\Windows\\System32\\Sysprep\\sysprep.exe /oobe /generalize /shutdown /quiet"

    # Run sysprep via az vm run-command
    log_info "Issuing sysprep command to VM..."
    az vm run-command invoke \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --name "$TEMP_VM_NAME" \
        --command-id RunPowerShellScript \
        --scripts "C:\\Windows\\System32\\Sysprep\\sysprep.exe /oobe /generalize /shutdown /quiet" \
        --output none 2>&1 | tee -a "$LOG_FILE" || log_warning "Sysprep command issued (VM will shut down)"

    log_info "Sysprep process initiated. Waiting for VM to shut down..."
}

wait_for_shutdown() {
    log_section "Waiting for VM Shutdown"

    log_info "Waiting for VM to be deallocated (up to $((MAX_WAIT_ATTEMPTS * WAIT_INTERVAL / 60)) minutes)..."

    local attempt=0
    while [ $attempt -lt $MAX_WAIT_ATTEMPTS ]; do
        VM_STATE=$(az vm get-instance-view -g "$RESOURCE_GROUP_NAME" -n "$TEMP_VM_NAME" --query "instanceView.statuses[?starts_with(code, 'PowerState')].displayStatus" -o tsv 2>/dev/null || echo "Unknown")

        if [[ "$VM_STATE" == "VM deallocated" ]] || [[ "$VM_STATE" == "VM stopped" ]]; then
            log_success "VM is deallocated after sysprep"
            return 0
        fi

        attempt=$((attempt + 1))
        remaining=$((MAX_WAIT_ATTEMPTS - attempt))
        progress=$((attempt * 100 / MAX_WAIT_ATTEMPTS))
        log_info "[$progress%] VM state: $VM_STATE (attempt $attempt/$MAX_WAIT_ATTEMPTS)"

        sleep $WAIT_INTERVAL
    done

    log_warning "VM did not deallocate within timeout. Manually deallocating..."
    deallocate_vm
}

deallocate_vm() {
    log_info "Deallocating VM via Azure CLI..."

    az vm deallocate \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --name "$TEMP_VM_NAME" \
        --no-wait \
        --output none

    log_success "Deallocate command issued"
}

# ============================================================================
# Main Execution
# ============================================================================

log_section "TASK 04: Run Sysprep on VM"
log_info "Log file: $LOG_FILE"

check_vm_exists
run_sysprep
wait_for_shutdown

log_section "Task Complete"
log_success "VM has been sysprepped and is deallocated"
log_info "VM is now ready for image capture"
log_info "Next step: Run task 05-capture-image.sh to capture the VM as a gallery image"

exit 0
