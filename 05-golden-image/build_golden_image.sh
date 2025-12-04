#!/bin/bash

# Master orchestration script for creating an Azure Virtual Desktop (AVD) golden image.
# This script automates the entire process: VM creation, configuration, sysprep,
# and image capture into an Azure Compute Gallery.
#
# Usage:
# chmod +x ./build_golden_image.sh
# ./build_golden_image.sh
#
# Prerequisites:
# - Azure CLI installed and authenticated (az login)
# - config.env file configured with all necessary environment variables
#
# The script will perform the following steps:
# 1. Clean up any existing temporary VM from a previous run (idempotency).
# 2. Create a new Azure VM.
# 3. Run a PowerShell configuration script on the VM (installs software, optimizes).
# 4. Run sysprep on the VM and generalize it.
# 5. Capture the generalized VM as an image version in an Azure Compute Gallery.
# 6. Clean up the temporary VM and its associated resources.

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Source configuration variables
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
CONFIG_FILE="$SCRIPT_DIR/config.env"
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}Error: config.env not found in $SCRIPT_DIR. Please create it.${NC}"
    exit 1
fi
source "$CONFIG_FILE"

# ============================================================================
# Helper Functions (re-using log functions from sub-scripts)
# ============================================================================

log_section() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
}

log_success() {
    echo -e "${GREEN}[v] $1${NC}"
}

log_error() {
    echo -e "${RED}[x] $1${NC}"
    exit 1
}

log_warning() {
    echo -e "${YELLOW}[!] $1${NC}"
}

log_info() {
    echo -e "${YELLOW}[i] $1${NC}"
}

# ============================================================================
# Main Orchestration
# ============================================================================

main() {
    log_section "Starting AVD Golden Image Creation Process"

    # --- 0. Pre-flight Check and Cleanup (ensure clean state) ---
    log_section "Pre-flight Check and Cleanup"
    if az vm show -g "$RESOURCE_GROUP_NAME" -n "$VM_NAME" --query "name" -o tsv &> /dev/null; then
        log_warning "Temporary VM '$VM_NAME' already exists. Deleting it for a clean run..."
        az vm delete --resource-group "$RESOURCE_GROUP_NAME" --name "$VM_NAME" --yes
        log_success "VM deleted."
    fi

    # Cleanup associated network resources if they exist
    if az network nic show -g "$RESOURCE_GROUP_NAME" -n "${VM_NAME}VMNic" &> /dev/null; then
        log_info "Deleting existing NIC: ${VM_NAME}VMNic"
        az network nic delete -g "$RESOURCE_GROUP_NAME" -n "${VM_NAME}VMNic" --no-wait
    fi
    if az network public-ip show -g "$RESOURCE_GROUP_NAME" -n "${VM_NAME}PublicIP" &> /dev/null; then
        log_info "Deleting existing Public IP: ${VM_NAME}PublicIP"
        az network public-ip delete -g "$RESOURCE_GROUP_NAME" -n "${VM_NAME}PublicIP" --no-wait
    fi
    DISK_ID=$(az disk list -g "$RESOURCE_GROUP_NAME" --query "[?starts_with(name, '$VM_NAME')].id" -o tsv)
    if [ -n "$DISK_ID" ]; then
        log_info "Deleting existing OS Disk: $DISK_ID"
        az disk delete --ids "$DISK_ID" --yes --no-wait
    fi

    # Wait for deletion to complete if --no-wait was used
    log_info "Waiting for any previous deletions to complete..."
    sleep 30 # Give Azure some time to process deletions

    log_success "Pre-flight cleanup complete."

    # --- 1. Create the temporary VM ---
    log_section "Step 1: Creating temporary VM"
    . "$SCRIPT_DIR/create_vm.sh" # Source to run in current shell, inheriting variables
    log_success "Temporary VM created."

    # --- 2. Run PowerShell Configuration Script on the VM ---
    log_section "Step 2: Running VM Configuration Script"
    log_info "Waiting for VM Agent to be ready..."
    az vm wait -g "$RESOURCE_GROUP_NAME" -n "$VM_NAME" --created # Wait for VM to be provisioned (and agent to be ready)
    sleep 30 # Give agent a little more time to settle

    log_info "Executing configuration script 'config_vm.ps1' on VM..."
    run_output=$(az vm run-command invoke \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --name "$VM_NAME" \
        --command-id RunPowerShellScript \
        --scripts "@$SCRIPT_DIR/config_vm.ps1" 2>&1)

    # Check for script errors - look for PowerShell 'ERROR:' output
    if echo "$run_output" | grep -q "ERROR:"; then
        log_error "The PowerShell configuration script failed. Output:"
        echo "$run_output"
    fi
    log_success "VM Configuration script executed successfully."

    # --- 3. Capture the image (Sysprep, Deallocate, Generalize, Create Image Version) ---
    log_section "Step 3: Capturing Golden Image"
    . "$SCRIPT_DIR/capture_image.sh" # Source to run in current shell, inheriting variables
    log_success "Golden Image captured."

    # --- 4. Final Cleanup (Delete the temporary VM and its resources) ---
    log_section "Step 4: Final Cleanup"
    log_info "Deleting temporary VM '$VM_NAME' and associated resources..."

    # Ensure VM is deallocated before attempting to delete resources
    az vm deallocate -g "$RESOURCE_GROUP_NAME" -n "$VM_NAME" --output none || true # Ignore error if already deallocated

    az vm delete -g "$RESOURCE_GROUP_NAME" -n "$VM_NAME" --yes
    log_success "VM '$VM_NAME' deleted."

    # Delete associated resources (NIC, Public IP, OS Disk)
    log_info "Deleting associated network interfaces and public IPs..."
    az network nic delete -g "$RESOURCE_GROUP_NAME" -n "${VM_NAME}VMNic" || true # Ignore error if already deleted
    az network public-ip delete -g "$RESOURCE_GROUP_NAME" -n "${VM_NAME}PublicIP" || true # Ignore error if already deleted

    DISK_ID=$(az disk list -g "$RESOURCE_GROUP_NAME" --query "[?starts_with(name, '$VM_NAME')].id" -o tsv)
    if [ -n "$DISK_ID" ]; then
        log_info "Deleting OS Disk: $DISK_ID"
        az disk delete --ids "$DISK_ID" --yes || true # Ignore error if already deleted
    fi
    log_success "Associated resources cleaned up."

    log_section "AVD Golden Image Creation Process Complete!"
    log_success "A new golden image version '$IMAGE_VERSION' has been created in gallery '$IMAGE_GALLERY_NAME'."
    log_info "You can find it under: /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP_NAME/providers/Microsoft.Compute/galleries/$IMAGE_GALLERY_NAME/images/$IMAGE_DEFINITION_NAME/versions/$IMAGE_VERSION"
}

main "$@"
