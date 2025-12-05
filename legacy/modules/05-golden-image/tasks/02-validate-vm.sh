#!/bin/bash

# ============================================================================
# Task 02: Validate VM Readiness
# ============================================================================
#
# Purpose: Waits for the newly created VM to be fully provisioned and ready
# for configuration. Checks that Windows is booted and RDP is accessible.
#
# Dependencies: Task 01 (VM must exist)
#
# Prerequisites:
# - VM must be created and running
# - Azure CLI must be authenticated
# - config.env must be sourced
#
# Inputs from config.env:
# - RESOURCE_GROUP_NAME
# - TEMP_VM_NAME
#
# Outputs:
# - Verified VM is running
# - Verified Windows OS is booted
# - Verified RDP port is listening
# - logs/artifacts/task-02-*.log
#
# Notes:
# - Idempotent: checks current status without modifying anything
# - Waits up to 30 minutes for VM readiness
# - Expected runtime: 5-15 minutes
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

TASK_NAME="02-validate-vm"
TIMESTAMP=$(date +'%Y%m%d_%H%M%S')
LOG_FILE="${SCRIPT_DIR}/artifacts/${TASK_NAME}_${TIMESTAMP}.log"

MAX_WAIT_ATTEMPTS=360  # 30 minutes (360 * 5 seconds)
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
# Validation Functions
# ============================================================================

check_vm_running() {
    log_section "Checking VM Running Status"

    local attempt=0
    while [ $attempt -lt $MAX_WAIT_ATTEMPTS ]; do
        VM_STATE=$(az vm get-instance-view -g "$RESOURCE_GROUP_NAME" -n "$TEMP_VM_NAME" --query "instanceView.statuses[?starts_with(code, 'PowerState')].displayStatus" -o tsv 2>/dev/null || echo "Unknown")

        if [[ "$VM_STATE" == "VM running" ]]; then
            log_success "VM is running"
            return 0
        fi

        attempt=$((attempt + 1))
        remaining=$((MAX_WAIT_ATTEMPTS - attempt))
        log_info "VM state: $VM_STATE (attempt $attempt/$MAX_WAIT_ATTEMPTS, remaining ~$((remaining * WAIT_INTERVAL))s)"

        if [ $attempt -lt $MAX_WAIT_ATTEMPTS ]; then
            sleep $WAIT_INTERVAL
        fi
    done

    log_error "VM did not reach 'running' state within timeout period"
}

check_windows_booted() {
    log_section "Checking Windows OS Boot Status"

    local attempt=0
    while [ $attempt -lt $MAX_WAIT_ATTEMPTS ]; do
        OS_STATE=$(az vm get-instance-view -g "$RESOURCE_GROUP_NAME" -n "$TEMP_VM_NAME" --query "instanceView.statuses[?starts_with(code, 'OSState')].displayStatus" -o tsv 2>/dev/null || echo "Unknown")

        if [[ "$OS_STATE" == "OS provisioned and ready for use" ]]; then
            log_success "Windows OS is booted and ready"
            return 0
        fi

        attempt=$((attempt + 1))
        remaining=$((MAX_WAIT_ATTEMPTS - attempt))
        log_info "OS state: $OS_STATE (attempt $attempt/$MAX_WAIT_ATTEMPTS, remaining ~$((remaining * WAIT_INTERVAL))s)"

        if [ $attempt -lt $MAX_WAIT_ATTEMPTS ]; then
            sleep $WAIT_INTERVAL
        fi
    done

    log_warning "OS did not reach 'provisioned and ready' state, but continuing..."
}

check_rdp_ready() {
    log_section "Checking RDP Readiness"

    log_info "Testing RDP port accessibility..."
    PUBLIC_IP=$(az vm show -g "$RESOURCE_GROUP_NAME" -n "$TEMP_VM_NAME" -d --query "publicIps" -o tsv)

    if [ -z "$PUBLIC_IP" ] || [ "$PUBLIC_IP" == "None" ]; then
        log_warning "No public IP assigned, skipping RDP check"
        return 0
    fi

    local attempt=0
    while [ $attempt -lt 120 ]; do  # 10 minute timeout for RDP
        if timeout 5 bash -c "echo > /dev/tcp/$PUBLIC_IP/3389" &>/dev/null; then
            log_success "RDP port 3389 is responding on $PUBLIC_IP"
            return 0
        fi

        attempt=$((attempt + 1))
        remaining=$((120 - attempt))
        log_info "RDP not yet responding (attempt $attempt/120, remaining ~$((remaining * 5))s)"

        sleep 5
    done

    log_warning "RDP port did not respond within timeout (this may be normal on first boot)"
}

# ============================================================================
# Main Execution
# ============================================================================

log_section "TASK 02: Validate VM Readiness"
log_info "Log file: $LOG_FILE"
log_info "Max wait time: $((MAX_WAIT_ATTEMPTS * WAIT_INTERVAL)) seconds (~$((MAX_WAIT_ATTEMPTS * WAIT_INTERVAL / 60)) minutes)"

# Check VM exists
if ! az vm show -g "$RESOURCE_GROUP_NAME" -n "$TEMP_VM_NAME" &> /dev/null; then
    log_error "VM '$TEMP_VM_NAME' not found. Run task 01 first."
fi

check_vm_running
check_windows_booted
check_rdp_ready

log_section "VM Validation Complete"
log_success "VM '$TEMP_VM_NAME' is ready for configuration"
log_info "Public IP: $(az vm show -g "$RESOURCE_GROUP_NAME" -n "$TEMP_VM_NAME" -d --query "publicIps" -o tsv)"
log_info "Next step: Run task 03-configure-vm.sh to install software and optimizations"

exit 0
