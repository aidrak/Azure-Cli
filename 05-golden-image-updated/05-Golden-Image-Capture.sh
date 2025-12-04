#!/bin/bash

# Automates Golden Image Capture for Azure Virtual Desktop (AVD)
#
# Purpose: Runs sysprep on the golden image VM, then captures it as a reusable
# image version in Azure Compute Gallery.
#
# Prerequisites:
# - Golden image VM must be fully configured and running
# - VM must be in resource group and accessible
# - Azure Compute Gallery will be created if it doesn't exist
# - Required permissions: Compute Gallery Contributor, VM Contributor
# - VM must be accessible via Azure CLI (not via RDP)
#
# Permissions Required:
# - Microsoft.Compute/galleries/write
# - Microsoft.Compute/galleries/images/write
# - Microsoft.Compute/galleries/images/versions/write
# - Microsoft.Compute/virtualMachines/write
#
# Usage:
# chmod +x ./05-Golden-Image-Capture.sh
# ./05-Golden-Image-Capture.sh
#
# Example with custom parameters:
# RESOURCE_GROUP="RG-Azure-VDI-01" VM_NAME="avd-gold-pool" ./05-Golden-Image-Capture.sh
#
# Environment Variables (with defaults):
# - RESOURCE_GROUP: Name of resource group (default: RG-Azure-VDI-01)
# - VM_NAME: Name of golden image VM (default: avd-gold-pool)
# - GALLERY_NAME: Compute gallery name (default: AVD_Image_Gallery)
# - IMAGE_DEF_NAME: Image definition name (default: Win11-AVD-Pooled)
# - IMAGE_VERSION: Image version to create (default: 1.0.0)
# - LOCATION: Azure region (default: centralus)
#
# Notes:
# - This script is idempotent for gallery/definition creation
# - Image versions are always created fresh with new timestamps
# - Expected runtime: 10-30 minutes
# - The VM will be deallocated and generalized
# - After capture, the temporary VM can be deleted

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration with defaults
RESOURCE_GROUP="${RESOURCE_GROUP:-RG-Azure-VDI-01}"
VM_NAME="${VM_NAME:-avd-gold-pool}"
GALLERY_NAME="${GALLERY_NAME:-AVD_Image_Gallery}"
IMAGE_DEF_NAME="${IMAGE_DEF_NAME:-Win11-AVD-Pooled}"
IMAGE_VERSION="${IMAGE_VERSION:-1.0.0}"
LOCATION="${LOCATION:-centralus}"

# Image configuration
IMAGE_PUBLISHER="YourCompany"
IMAGE_OFFER="AVD"
IMAGE_SKU="Win11-Pooled-FSLogix"

# ============================================================================
# Helper Functions
# ============================================================================

log_section() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
}

log_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

log_error() {
    echo -e "${RED}✗ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

log_info() {
    echo -e "${YELLOW}ℹ $1${NC}"
}

# ============================================================================
# Validation Functions
# ============================================================================

validate_prerequisites() {
    log_section "Validating Prerequisites"

    if ! command -v az &> /dev/null; then
        log_error "Azure CLI is not installed"
        exit 1
    fi
    log_success "Azure CLI installed"

    # Check if logged in
    if ! az account show &> /dev/null; then
        log_error "Not logged into Azure. Run 'az login' first"
        exit 1
    fi
    log_success "Logged into Azure"

    # Check if resource group exists
    if ! az group exists -n "$RESOURCE_GROUP" | grep -q true; then
        log_error "Resource group '$RESOURCE_GROUP' does not exist"
        exit 1
    fi
    log_success "Resource group '$RESOURCE_GROUP' exists"

    # Check if VM exists
    if ! az vm show -g "$RESOURCE_GROUP" -n "$VM_NAME" &> /dev/null; then
        log_error "VM '$VM_NAME' not found"
        exit 1
    fi
    log_success "VM '$VM_NAME' exists"
}

# ============================================================================
# Sysprep Preparation
# ============================================================================

run_sysprep_on_vm() {
    log_section "Running Sysprep on VM"

    log_warning "This will generalize the VM for image capture"
    log_info "Confirming VM name: $VM_NAME"

    log_info "Starting sysprep process on VM (this may take 5-10 minutes)"
    try {
        # Run sysprep via az vm run-command
        az vm run-command invoke \
            --resource-group "$RESOURCE_GROUP" \
            --name "$VM_NAME" \
            --command-id RunPowerShellScript \
            --scripts "C:\Windows\System32\Sysprep\sysprep.exe /oobe /generalize /shutdown /quiet" \
            --output none
    } catch {
        log_warning "Sysprep command may still be running in background"
    }

    log_info "Waiting for VM to shutdown after sysprep (30 seconds)..."
    sleep 30

    # Wait for VM to stop
    log_info "Waiting for VM to be deallocated..."
    for i in {1..120}; do
        VM_STATE=$(az vm get-instance-view -g "$RESOURCE_GROUP" -n "$VM_NAME" --query "instanceView.statuses[?starts_with(code, 'PowerState')].displayStatus" -o tsv)

        if [[ "$VM_STATE" == "VM deallocated" ]] || [[ "$VM_STATE" == "VM stopped" ]]; then
            log_success "VM is deallocated"
            break
        fi

        if [[ $i -eq 120 ]]; then
            log_warning "VM did not deallocate automatically, proceeding to deallocate manually"
        fi

        sleep 5
    done

    log_success "Sysprep completed"
}

# ============================================================================
# VM Deallocation and Generalization
# ============================================================================

deallocate_and_generalize_vm() {
    log_section "Deallocating and Generalizing VM"

    log_info "Deallocating VM '$VM_NAME'"
    az vm deallocate \
        --resource-group "$RESOURCE_GROUP" \
        --name "$VM_NAME" \
        --output none

    log_success "VM deallocated"

    log_info "Generalizing VM '$VM_NAME'"
    az vm generalize \
        --resource-group "$RESOURCE_GROUP" \
        --name "$VM_NAME" \
        --output none

    log_success "VM generalized"
}

# ============================================================================
# Compute Gallery Creation
# ============================================================================

create_compute_gallery() {
    log_section "Creating/Verifying Compute Gallery"

    log_info "Checking if gallery '$GALLERY_NAME' exists"
    if az sig show -g "$RESOURCE_GROUP" --gallery-name "$GALLERY_NAME" &> /dev/null; then
        log_warning "Compute Gallery '$GALLERY_NAME' already exists"
        return 0
    fi

    log_info "Creating Compute Gallery '$GALLERY_NAME'"
    az sig create \
        -g "$RESOURCE_GROUP" \
        --gallery-name "$GALLERY_NAME" \
        --location "$LOCATION" \
        --output none

    log_success "Compute Gallery '$GALLERY_NAME' created"
}

# ============================================================================
# Image Definition Creation
# ============================================================================

create_image_definition() {
    log_section "Creating/Verifying Image Definition"

    log_info "Checking if image definition '$IMAGE_DEF_NAME' exists"
    if az sig image-definition show \
        -g "$RESOURCE_GROUP" \
        --gallery-name "$GALLERY_NAME" \
        --gallery-image-definition "$IMAGE_DEF_NAME" &> /dev/null; then
        log_warning "Image definition '$IMAGE_DEF_NAME' already exists"
        return 0
    fi

    log_info "Creating image definition '$IMAGE_DEF_NAME'"
    az sig image-definition create \
        -g "$RESOURCE_GROUP" \
        --gallery-name "$GALLERY_NAME" \
        --gallery-image-definition "$IMAGE_DEF_NAME" \
        --publisher "$IMAGE_PUBLISHER" \
        --offer "$IMAGE_OFFER" \
        --sku "$IMAGE_SKU" \
        --os-type Windows \
        --os-state Generalized \
        --hyper-v-generation V2 \
        --features SecurityType=TrustedLaunch \
        --location "$LOCATION" \
        --output none

    log_success "Image definition '$IMAGE_DEF_NAME' created"
}

# ============================================================================
# Image Version Creation
# ============================================================================

create_image_version() {
    log_section "Creating Image Version"

    # Get VM ID
    VM_ID=$(az vm show \
        -g "$RESOURCE_GROUP" \
        -n "$VM_NAME" \
        --query id \
        -o tsv)

    if [[ -z "$VM_ID" ]]; then
        log_error "Could not retrieve VM ID"
        return 1
    fi

    log_info "Retrieved VM ID: $VM_ID"

    log_info "Creating image version '$IMAGE_VERSION' from VM '$VM_NAME'"
    az sig image-version create \
        -g "$RESOURCE_GROUP" \
        --gallery-name "$GALLERY_NAME" \
        --gallery-image-definition "$IMAGE_DEF_NAME" \
        --gallery-image-version "$IMAGE_VERSION" \
        --managed-image "$VM_ID" \
        --location "$LOCATION" \
        --output none

    log_success "Image version '$IMAGE_VERSION' created"
}

# ============================================================================
# Cleanup
# ============================================================================

cleanup_resources() {
    log_section "Cleanup Options"

    log_warning "The temporary VM can now be deleted to save costs"
    log_info "To delete the VM and associated resources, run:"
    echo ""
    echo "  az vm delete -g $RESOURCE_GROUP -n $VM_NAME --yes"
    echo "  az network nic delete -g $RESOURCE_GROUP -n \"${VM_NAME}VMNic\""
    echo "  az network public-ip delete -g $RESOURCE_GROUP -n \"${VM_NAME}PublicIP\""
    echo "  az disk delete -g $RESOURCE_GROUP -n \"${VM_NAME}_OsDisk_*\" --yes"
    echo ""
}

# ============================================================================
# Verification
# ============================================================================

verify_image_capture() {
    log_section "Verifying Image Capture"

    log_info "Verifying image version exists"
    if az sig image-version show \
        -g "$RESOURCE_GROUP" \
        --gallery-name "$GALLERY_NAME" \
        --gallery-image-definition "$IMAGE_DEF_NAME" \
        --gallery-image-version "$IMAGE_VERSION" &> /dev/null; then
        log_success "Image version verified"
    else
        log_error "Image version not found"
        return 1
    fi

    log_success "Image capture verified"
}

# ============================================================================
# Main Execution
# ============================================================================

main() {
    log_section "AVD Golden Image Capture"

    validate_prerequisites
    run_sysprep_on_vm
    deallocate_and_generalize_vm
    create_compute_gallery
    create_image_definition
    create_image_version
    verify_image_capture
    cleanup_resources

    echo ""
    log_success "Image Capture Complete!"
    echo ""
    log_info "Summary:"
    echo "  Resource Group: $RESOURCE_GROUP"
    echo "  VM Name: $VM_NAME"
    echo "  Gallery: $GALLERY_NAME"
    echo "  Image Definition: $IMAGE_DEF_NAME"
    echo "  Image Version: $IMAGE_VERSION"
    echo "  Image ID: /subscriptions/$(az account show --query id -o tsv)/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.Compute/galleries/${GALLERY_NAME}/images/${IMAGE_DEF_NAME}/versions/${IMAGE_VERSION}"
    echo ""
    log_info "Next steps:"
    echo "  1. Delete the temporary VM to save costs (see cleanup options above)"
    echo "  2. Deploy session hosts using this image (Step 06)"
    echo "  3. Assign users to the host pool (Step 08)"
    echo ""
}

main "$@"
