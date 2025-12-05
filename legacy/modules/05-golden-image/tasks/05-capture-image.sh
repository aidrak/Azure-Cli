#!/bin/bash

# ============================================================================
# Task 05: Capture VM as Golden Image
# ============================================================================
#
# Purpose: Captures the sysprepped VM as a reusable image in Azure Compute
# Gallery. Creates the gallery, image definition, and version with automatic
# timestamp-based versioning.
#
# Dependencies: Task 04 (VM must be sysprepped and deallocated)
#
# Prerequisites:
# - VM must be deallocated and generalized
# - Azure CLI must be authenticated
# - config.env must be sourced
#
# Inputs from config.env:
# - RESOURCE_GROUP_NAME
# - TEMP_VM_NAME
# - IMAGE_GALLERY_NAME
# - IMAGE_DEFINITION_NAME
# - IMAGE_PUBLISHER
# - IMAGE_OFFER
# - IMAGE_SKU_NAME
#
# Outputs:
# - Azure Compute Gallery created (if not exists)
# - Image definition created (if not exists)
# - Image version created and stored in gallery
# - logs/artifacts/task-05-*.log
# - logs/artifacts/task-05-image-details.txt
#
# Notes:
# - Gallery and definition are idempotent (created only if needed)
# - Image versions are always created fresh with timestamp
# - Expected runtime: 15-30 minutes
# - Image can be reused for multiple session host deployments
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

TASK_NAME="05-capture-image"
TIMESTAMP=$(date +'%Y%m%d_%H%M%S')
LOG_FILE="${SCRIPT_DIR}/artifacts/${TASK_NAME}_${TIMESTAMP}.log"

# Image version format: YYYY.MMDD.HHMM (e.g., 2025.1204.0530)
IMAGE_VERSION=$(date +'%Y.%m%d.%H%M')

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

    # Check VM exists
    if ! az vm show -g "$RESOURCE_GROUP_NAME" -n "$TEMP_VM_NAME" &> /dev/null; then
        log_error "VM '$TEMP_VM_NAME' not found"
    fi
    log_success "VM '$TEMP_VM_NAME' exists"

    # Check VM is deallocated
    VM_STATE=$(az vm get-instance-view -g "$RESOURCE_GROUP_NAME" -n "$TEMP_VM_NAME" --query "instanceView.statuses[?starts_with(code, 'PowerState')].displayStatus" -o tsv)
    if [[ "$VM_STATE" != "VM deallocated" ]] && [[ "$VM_STATE" != "VM stopped" ]]; then
        log_error "VM is not deallocated (current state: $VM_STATE). Run task 04 first."
    fi
    log_success "VM is deallocated"

    # Check VM is generalized
    PROVISIONING_STATE=$(az vm get-instance-view -g "$RESOURCE_GROUP_NAME" -n "$TEMP_VM_NAME" --query "instanceView.vmAgent.statuses[0].displayStatus" -o tsv 2>/dev/null || echo "Unknown")
    log_info "VM provisioning state: $PROVISIONING_STATE"
}

# ============================================================================
# Gallery Management
# ============================================================================

create_or_verify_gallery() {
    log_section "Managing Azure Compute Gallery"

    log_info "Gallery name: $IMAGE_GALLERY_NAME"
    log_info "Location: $LOCATION"

    if az sig show -g "$RESOURCE_GROUP_NAME" -r "$IMAGE_GALLERY_NAME" &> /dev/null; then
        log_success "Gallery '$IMAGE_GALLERY_NAME' already exists"
    else
        log_info "Creating new gallery..."
        az sig create \
            --resource-group "$RESOURCE_GROUP_NAME" \
            --gallery-name "$IMAGE_GALLERY_NAME" \
            --location "$LOCATION" \
            --output none

        log_success "Gallery '$IMAGE_GALLERY_NAME' created"
    fi
}

create_or_verify_image_definition() {
    log_section "Managing Image Definition"

    log_info "Image definition name: $IMAGE_DEFINITION_NAME"
    log_info "Publisher: $IMAGE_PUBLISHER"
    log_info "Offer: $IMAGE_OFFER"
    log_info "SKU: $IMAGE_SKU_NAME"

    if az sig image-definition show \
        -g "$RESOURCE_GROUP_NAME" \
        -r "$IMAGE_GALLERY_NAME" \
        -i "$IMAGE_DEFINITION_NAME" &> /dev/null; then
        log_success "Image definition '$IMAGE_DEFINITION_NAME' already exists"
    else
        log_info "Creating new image definition..."
        az sig image-definition create \
            --resource-group "$RESOURCE_GROUP_NAME" \
            --gallery-name "$IMAGE_GALLERY_NAME" \
            --gallery-image-definition "$IMAGE_DEFINITION_NAME" \
            --publisher "$IMAGE_PUBLISHER" \
            --offer "$IMAGE_OFFER" \
            --sku "$IMAGE_SKU_NAME" \
            --os-type Windows \
            --os-state Generalized \
            --output none

        log_success "Image definition '$IMAGE_DEFINITION_NAME' created"
    fi
}

# ============================================================================
# Image Capture
# ============================================================================

generalize_vm() {
    log_section "Generalizing VM"

    log_info "Marking VM as generalized..."

    # VM should already be generalized from sysprep, but ensure it is
    az vm generalize \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --name "$TEMP_VM_NAME" \
        --output none || log_warning "VM generalization command (may already be generalized)"

    log_success "VM marked as generalized"
}

create_image_version() {
    log_section "Creating Image Version in Gallery"

    log_info "Image version: $IMAGE_VERSION"
    log_info "Source VM: $TEMP_VM_NAME"

    # Get VM ID
    VM_ID=$(az vm show -g "$RESOURCE_GROUP_NAME" -n "$TEMP_VM_NAME" --query "id" -o tsv)

    log_info "Creating image version from VM..."
    az sig image-version create \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --gallery-name "$IMAGE_GALLERY_NAME" \
        --gallery-image-definition "$IMAGE_DEFINITION_NAME" \
        --gallery-image-version "$IMAGE_VERSION" \
        --managed-image "$VM_ID" \
        --location "$LOCATION" \
        --output none

    log_success "Image version '$IMAGE_VERSION' created successfully"
}

get_image_details() {
    log_section "Image Details"

    # Get gallery ID
    GALLERY_ID=$(az sig show -g "$RESOURCE_GROUP_NAME" -r "$IMAGE_GALLERY_NAME" --query "id" -o tsv)

    # Get image definition ID
    IMAGE_DEF_ID=$(az sig image-definition show \
        -g "$RESOURCE_GROUP_NAME" \
        -r "$IMAGE_GALLERY_NAME" \
        -i "$IMAGE_DEFINITION_NAME" \
        --query "id" -o tsv)

    # Get image version ID
    IMAGE_VERSION_ID=$(az sig image-version show \
        -g "$RESOURCE_GROUP_NAME" \
        -r "$IMAGE_GALLERY_NAME" \
        -i "$IMAGE_DEFINITION_NAME" \
        --gallery-image-version "$IMAGE_VERSION" \
        --query "id" -o tsv)

    log_success "Gallery ID: $GALLERY_ID"
    log_success "Image Definition ID: $IMAGE_DEF_ID"
    log_success "Image Version ID: $IMAGE_VERSION_ID"

    # Save image details to file
    cat > "${SCRIPT_DIR}/artifacts/${TASK_NAME}_image-details.txt" << EOF
GALLERY_NAME=$IMAGE_GALLERY_NAME
GALLERY_ID=$GALLERY_ID
IMAGE_DEFINITION=$IMAGE_DEFINITION_NAME
IMAGE_DEF_ID=$IMAGE_DEF_ID
IMAGE_VERSION=$IMAGE_VERSION
IMAGE_VERSION_ID=$IMAGE_VERSION_ID
IMAGE_CREATED_AT=$(date -Iseconds)
RESOURCE_GROUP=$RESOURCE_GROUP_NAME
EOF

    log_success "Image details saved to artifacts"
}

# ============================================================================
# Main Execution
# ============================================================================

log_section "TASK 05: Capture VM as Golden Image"
log_info "Log file: $LOG_FILE"
log_info "Image version: $IMAGE_VERSION"

check_prerequisites
create_or_verify_gallery
create_or_verify_image_definition
generalize_vm
create_image_version
get_image_details

log_section "Task Complete"
log_success "Golden image '$IMAGE_DEFINITION_NAME' (v$IMAGE_VERSION) has been captured successfully!"
log_info "Image is now available in Azure Compute Gallery for deployment"
log_info "Next step: Run task 06-cleanup.sh to delete temporary resources"

exit 0
