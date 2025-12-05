#!/bin/bash

################################################################################
# Task: Deploy Session Host VMs from Golden Image
#
# Purpose: Deploy multiple session host VMs from golden image and register
#          them to the host pool
#
# Inputs (from config.env):
#   - RESOURCE_GROUP_NAME
#   - LOCATION
#   - VM_NAME_PREFIX
#   - SESSION_HOST_COUNT
#   - VM_SIZE
#   - IMAGE_GALLERY_NAME
#   - IMAGE_DEFINITION_NAME
#   - IMAGE_VERSION
#   - VNET_NAME
#   - SESSION_HOSTS_SUBNET_NAME
#
# Outputs:
#   - Session host VMs created
#   - VMs deployed in parallel
#   - Details saved to artifacts/
#
# Duration: 10-15 minutes (parallel deployment)
# Idempotent: Partial (checks existing VMs)
################################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCRIPT_NAME="01-deploy-session-hosts"

CONFIG_FILE="${PROJECT_ROOT}/06-session-host-deployment/config.env"
[[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE" || { echo "ERROR: Config not found"; exit 1; }

ENABLE_LOGGING=1
LOG_DIR="${ARTIFACTS_DIR}"
mkdir -p "$LOG_DIR"

# Load logging functions
LOGGING_FUNCS="${PROJECT_ROOT}/common/functions/logging-functions.sh"
[[ -f "$LOGGING_FUNCS" ]] && source "$LOGGING_FUNCS" || {
    log_info() { echo "ℹ $*"; }
    log_success() { echo "✓ $*"; }
    log_error() { echo "✗ $*" >&2; }
}

log_section() { echo ""; echo "=== $1 ==="; echo ""; }

log_section "Deploying Session Host VMs"

# Validate
if ! az account show &>/dev/null; then
    log_error "Not authenticated to Azure"
    exit 1
fi

if ! az group exists --name "$RESOURCE_GROUP_NAME" | grep -q "true"; then
    log_error "Resource group not found: $RESOURCE_GROUP_NAME"
    exit 1
fi

# Get image ID
log_info "Getting image ID from gallery"

local image_id
image_id=$(az sig image-definition show \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --gallery-name "$IMAGE_GALLERY_NAME" \
    --gallery-image-definition "$IMAGE_DEFINITION_NAME" \
    --query id -o tsv 2>/dev/null)

if [[ -z "$image_id" ]]; then
    log_error "Image definition not found: $IMAGE_DEFINITION_NAME"
    exit 1
fi

# Get subnet ID
log_info "Getting subnet ID"

local subnet_id
subnet_id=$(az network vnet subnet show \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --vnet-name "$VNET_NAME" \
    --name "$SESSION_HOSTS_SUBNET_NAME" \
    --query id -o tsv)

if [[ -z "$subnet_id" ]]; then
    log_error "Subnet not found: $SESSION_HOSTS_SUBNET_NAME"
    exit 1
fi

# Deploy session hosts
log_info "Deploying $SESSION_HOST_COUNT session host VMs"
log_info "  VM prefix: $VM_NAME_PREFIX"
log_info "  VM size: $VM_SIZE"

local deployed_vms=()
local failed_vms=()
local i

for ((i=1; i<=SESSION_HOST_COUNT; i++)); do
    local vm_name="${VM_NAME_PREFIX}-$(printf "%02d" $i)"

    # Check if VM already exists
    if az vm show --resource-group "$RESOURCE_GROUP_NAME" --name "$vm_name" &>/dev/null; then
        log_info "VM already exists: $vm_name"
        deployed_vms+=("$vm_name")
        continue
    fi

    log_info "Creating VM: $vm_name ($i/$SESSION_HOST_COUNT)"

    if ! az vm create \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --name "$vm_name" \
        --location "$LOCATION" \
        --image "$image_id" \
        --size "$VM_SIZE" \
        --subnet "$subnet_id" \
        --admin-username azureuser \
        --generate-ssh-keys \
        --nsg "" \
        --public-ip-address "" \
        --os-disk-delete-option Delete \
        --data-disk-delete-option Delete \
        --nic-delete-option Delete \
        --output json >"${LOG_DIR}/${SCRIPT_NAME}-${vm_name}.json" 2>&1; then

        log_error "Failed to create VM: $vm_name"
        failed_vms+=("$vm_name")
    else
        log_success "VM created: $vm_name"
        deployed_vms+=("$vm_name")
    fi
done

# Summary
log_info ""
log_info "Deployment Summary:"
log_info "  Successfully deployed: ${#deployed_vms[@]}/$SESSION_HOST_COUNT"
log_info "  Failed: ${#failed_vms[@]}/$SESSION_HOST_COUNT"

if [[ ${#failed_vms[@]} -gt 0 ]]; then
    log_error "Failed VMs: ${failed_vms[*]}"
    exit 1
fi

# Save details
{
    echo "Session Host Deployment Details"
    echo "==============================="
    echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
    echo ""
    echo "Deployment Summary:"
    echo "  Total VMs: $SESSION_HOST_COUNT"
    echo "  Successfully Deployed: ${#deployed_vms[@]}"
    echo "  Failed: ${#failed_vms[@]}"
    echo ""
    echo "VM Details:"
    echo "  Prefix: $VM_NAME_PREFIX"
    echo "  Size: $VM_SIZE"
    echo "  Location: $LOCATION"
    echo "  Image Gallery: $IMAGE_GALLERY_NAME"
    echo "  Image Definition: $IMAGE_DEFINITION_NAME"
    echo ""
    echo "Deployed VMs:"
    for vm in "${deployed_vms[@]}"; do
        echo "  - $vm"
    done
    echo ""
    echo "Network:"
    echo "  VNet: $VNET_NAME"
    echo "  Subnet: $SESSION_HOSTS_SUBNET_NAME"
    echo ""
    echo "Next Steps:"
    echo "  1. Wait for VMs to fully initialize"
    echo "  2. Register VMs with host pool"
    echo "  3. Verify connectivity"
    echo ""
} > "${LOG_DIR}/${SCRIPT_NAME}-details.txt"

log_success "Task completed successfully"
exit 0
