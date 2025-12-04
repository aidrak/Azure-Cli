#!/bin/bash

# ============================================================================
# Task 06: Clean Up Temporary Resources
# ============================================================================
#
# Purpose: Deletes temporary resources created during golden image creation
# (temporary VM, network interfaces, disks). Keeps the final image in the gallery.
#
# Dependencies: Task 05 (Image must be captured)
#
# Prerequisites:
# - Image must already be captured in gallery
# - Azure CLI must be authenticated
# - config.env must be sourced
#
# Inputs from config.env:
# - RESOURCE_GROUP_NAME
# - TEMP_VM_NAME
#
# Outputs:
# - Temporary VM deleted
# - Associated disks deleted
# - Network interfaces deleted
# - logs/artifacts/task-06-*.log
#
# Notes:
# - Idempotent: checks if resources exist before deleting
# - Only deletes VM and associated infrastructure, NOT the gallery
# - Expected runtime: 5-10 minutes
# - Safe to run after image capture is complete
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

TASK_NAME="06-cleanup"
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
# Resource Cleanup
# ============================================================================

delete_vm() {
    log_section "Deleting Temporary VM"

    if ! az vm show -g "$RESOURCE_GROUP_NAME" -n "$TEMP_VM_NAME" &> /dev/null; then
        log_warning "VM '$TEMP_VM_NAME' does not exist, skipping deletion"
        return 0
    fi

    log_info "VM found: $TEMP_VM_NAME"
    log_warning "Deleting VM (this will also remove associated resources)..."

    az vm delete \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --name "$TEMP_VM_NAME" \
        --yes \
        --no-wait \
        --output none

    log_success "VM deletion initiated"
    log_info "Waiting for VM deletion to complete..."

    # Wait for deletion (with timeout)
    local attempt=0
    while [ $attempt -lt 120 ]; do
        if ! az vm show -g "$RESOURCE_GROUP_NAME" -n "$TEMP_VM_NAME" &> /dev/null; then
            log_success "VM '$TEMP_VM_NAME' has been deleted"
            return 0
        fi

        attempt=$((attempt + 1))
        echo -n "."
        sleep 5
    done

    log_warning "VM deletion timeout, continuing with other cleanup tasks..."
}

cleanup_disks() {
    log_section "Cleaning Up Associated Disks"

    log_info "Looking for unattached disks..."

    # Find disks with the VM name in their name
    local disks=$(az disk list -g "$RESOURCE_GROUP_NAME" --query "[?contains(name, '${TEMP_VM_NAME}')].name" -o tsv)

    if [ -z "$disks" ]; then
        log_info "No associated disks found"
        return 0
    fi

    for disk in $disks; do
        log_info "Found disk: $disk"

        # Check if disk is attached
        local attached=$(az disk show -g "$RESOURCE_GROUP_NAME" -n "$disk" --query "managedBy" -o tsv)

        if [ -z "$attached" ] || [ "$attached" == "null" ]; then
            log_info "Disk is unattached, deleting..."
            az disk delete \
                --resource-group "$RESOURCE_GROUP_NAME" \
                --name "$disk" \
                --yes \
                --no-wait \
                --output none

            log_success "Disk '$disk' deletion initiated"
        else
            log_warning "Disk '$disk' is still attached, cannot delete"
        fi
    done
}

cleanup_network_interfaces() {
    log_section "Cleaning Up Network Interfaces"

    log_info "Looking for unused network interfaces..."

    # Find network interfaces that are not attached and have the VM name in their name
    local nics=$(az network nic list -g "$RESOURCE_GROUP_NAME" --query "[?contains(name, '${TEMP_VM_NAME}')].name" -o tsv)

    if [ -z "$nics" ]; then
        log_info "No associated network interfaces found"
        return 0
    fi

    for nic in $nics; do
        log_info "Found NIC: $nic"

        # Check if NIC is attached
        local attached=$(az network nic show -g "$RESOURCE_GROUP_NAME" -n "$nic" --query "virtualMachine" -o tsv)

        if [ -z "$attached" ] || [ "$attached" == "null" ]; then
            log_info "NIC is unattached, deleting..."
            az network nic delete \
                --resource-group "$RESOURCE_GROUP_NAME" \
                --name "$nic" \
                --no-wait \
                --output none

            log_success "NIC '$nic' deletion initiated"
        else
            log_warning "NIC '$nic' is still attached, cannot delete"
        fi
    done
}

cleanup_public_ips() {
    log_section "Cleaning Up Public IPs"

    log_info "Looking for unused public IPs..."

    # Find public IPs with the VM name in their name
    local ips=$(az network public-ip list -g "$RESOURCE_GROUP_NAME" --query "[?contains(name, '${TEMP_VM_NAME}')].name" -o tsv)

    if [ -z "$ips" ]; then
        log_info "No associated public IPs found"
        return 0
    fi

    for ip in $ips; do
        log_info "Found public IP: $ip"

        # Check if IP is associated
        local associated=$(az network public-ip show -g "$RESOURCE_GROUP_NAME" -n "$ip" --query "ipConfiguration" -o tsv)

        if [ -z "$associated" ] || [ "$associated" == "null" ]; then
            log_info "Public IP is unassociated, deleting..."
            az network public-ip delete \
                --resource-group "$RESOURCE_GROUP_NAME" \
                --name "$ip" \
                --no-wait \
                --output none

            log_success "Public IP '$ip' deletion initiated"
        else
            log_warning "Public IP '$ip' is still associated, skipping"
        fi
    done
}

# ============================================================================
# Summary
# ============================================================================

generate_summary() {
    log_section "Cleanup Summary"

    # Save cleanup summary
    cat > "${SCRIPT_DIR}/artifacts/${TASK_NAME}_summary.txt" << EOF
Cleanup performed at: $(date)
Resource Group: $RESOURCE_GROUP_NAME
Temporary VM deleted: $TEMP_VM_NAME

Golden Image Resources (NOT deleted):
- Image Gallery: $IMAGE_GALLERY_NAME
- Image Definition: $IMAGE_DEFINITION_NAME
- Image Versions: Available for deployment

Next Steps:
1. Verify image in Azure Compute Gallery
2. Deploy session hosts using the golden image
3. Optional: Delete image when no longer needed

Log file: $LOG_FILE
EOF

    log_success "Cleanup summary saved"
}

# ============================================================================
# Main Execution
# ============================================================================

log_section "TASK 06: Clean Up Temporary Resources"
log_info "Log file: $LOG_FILE"

log_warning "This will delete the temporary VM and associated infrastructure"
log_info "The captured golden image in the gallery will NOT be deleted"

delete_vm
cleanup_disks
cleanup_network_interfaces
cleanup_public_ips
generate_summary

log_section "Task Complete"
log_success "Temporary resources have been cleaned up"
log_info ""
log_success "Golden image creation workflow is complete!"
log_success "Image available at: /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP_NAME/providers/Microsoft.Compute/galleries/$IMAGE_GALLERY_NAME/images/$IMAGE_DEFINITION_NAME"
log_info ""
log_info "To deploy session hosts from this image, use the image ID in step 06-session-host-deployment"

exit 0
