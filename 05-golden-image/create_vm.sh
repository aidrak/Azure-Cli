#!/bin/bash
set -e

# Helper Functions (embedded as common_functions.sh is not found)
validate_az_cli() {
    if ! command -v az &> /dev/null; then
        log_error "Azure CLI is not installed. Please install it to proceed."
    fi
    log_success "Azure CLI is installed."
}

validate_variable() {
    local var_name="$1"
    local var_value="${!var_name}"
    if [ -z "$var_value" ]; then
        log_error "Required environment variable '$var_name' is not set. Please check config.env."
    fi
    log_info "Variable '$var_name' is set."
}

source "$(dirname "$0")/config.env"

# --- Validation ---
log_section "Validating VM Creation Prerequisites"
validate_az_cli
validate_variable "RESOURCE_GROUP_NAME"
validate_variable "LOCATION"
validate_variable "VM_NAME"
validate_variable "VM_SIZE"
validate_variable "WINDOWS_IMAGE_SKU"
validate_variable "ADMIN_USERNAME"
validate_variable "ADMIN_PASSWORD"
validate_variable "VNET_NAME"
validate_variable "SUBNET_NAME"
log_success "All prerequisites validated."

# --- Main Logic ---
log_section "Virtual Machine Creation"

if az vm show -g "$RESOURCE_GROUP_NAME" -n "$VM_NAME" --query "name" -o tsv &> /dev/null; then
    log_warning "VM '$VM_NAME' in resource group '$RESOURCE_GROUP_NAME' already exists. Skipping creation."
    exit 0
fi

log_info "Creating VM '$VM_NAME'வதற்காக..."
log_info "Size: $VM_SIZE, Image: $WINDOWS_IMAGE_SKU, Location: $LOCATION"

az vm create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$VM_NAME" \
    --image "$WINDOWS_IMAGE_SKU" \
    --size "$VM_SIZE" \
    --admin-username "$ADMIN_USERNAME" \
    --admin-password "$ADMIN_PASSWORD" \
    --vnet-name "$VNET_NAME" \
    --subnet "$SUBNET_NAME" \
    --public-ip-sku Standard \
    --security-type TrustedLaunch \
    --enable-secure-boot true \
    --enable-vtpm true \
    --location "$LOCATION" \
    --tags "source=golden-image-script" \
    --output none

log_success "VM '$VM_NAME' created successfully."

log_info "Fetching VM Details..."
ip_address=$(az vm show -g "$RESOURCE_GROUP_NAME" -n "$VM_NAME" -d --query "publicIps" -o tsv)
log_success "VM IP Address: $ip_address"
