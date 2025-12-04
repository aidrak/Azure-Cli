#!/bin/bash

# Automates Golden Image VM Creation for Azure Virtual Desktop (AVD)
#
# Purpose: Creates a temporary Windows VM with public IP that will be configured
# as a golden image template for session hosts.
#
# Prerequisites:
# - Azure CLI installed and authenticated (az login)
# - VNet with subnet must exist
# - Required permissions: Virtual Machine Contributor, Network Contributor
# - Windows 11 AVD image must be available in your region
#
# Permissions Required:
# - Microsoft.Compute/virtualMachines/write
# - Microsoft.Network/publicIPAddresses/write
# - Microsoft.Network/networkInterfaces/write
#
# Usage:
# chmod +x ./05-Golden-Image-VM-Create.sh
# ./05-Golden-Image-VM-Create.sh
#
# Example with custom parameters:
# RESOURCE_GROUP="RG-Azure-VDI-01" VM_NAME="avd-gold-custom" ./05-Golden-Image-VM-Create.sh
#
# Environment Variables (with defaults):
# - RESOURCE_GROUP: Name of resource group (default: RG-Azure-VDI-01)
# - LOCATION: Azure region (default: centralus)
# - VM_NAME: Name for golden image VM (default: avd-gold-pool)
# - VNET_NAME: Virtual network name (default: vnet-avd-prod)
# - SUBNET_NAME: Subnet name for VM (default: subnet-session-hosts)
# - VM_SIZE: Azure VM size (default: Standard_D4s_v6)
# - ADMIN_USERNAME: Admin username (default: entra-admin)
# - ADMIN_PASSWORD: Admin password (OPTIONAL - will be prompted if not provided)
#
# Notes:
# - This script creates a VM with a public IP for RDP access
# - The public IP is temporary and should be removed after configuration
# - Expected runtime: 5-10 minutes
# - The VM must be configured via RDP with the next script

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration with defaults
RESOURCE_GROUP="${RESOURCE_GROUP:-RG-Azure-VDI-01}"
LOCATION="${LOCATION:-centralus}"
VM_NAME="${VM_NAME:-avd-gold-pool}"
VNET_NAME="${VNET_NAME:-vnet-avd-prod}"
SUBNET_NAME="${SUBNET_NAME:-subnet-session-hosts}"
VM_SIZE="${VM_SIZE:-Standard_D4s_v6}"
ADMIN_USERNAME="${ADMIN_USERNAME:-entra-admin}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-}"

# Image reference
IMAGE_PUBLISHER="MicrosoftWindowsDesktop"
IMAGE_OFFER="windows-11"
IMAGE_SKU="win11-25h2-avd"
IMAGE_VERSION="latest"

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

    # Check if VNet exists
    if ! az network vnet show -g "$RESOURCE_GROUP" -n "$VNET_NAME" &> /dev/null; then
        log_error "VNet '$VNET_NAME' not found"
        exit 1
    fi
    log_success "VNet '$VNET_NAME' exists"

    # Check if subnet exists
    if ! az network vnet subnet show -g "$RESOURCE_GROUP" --vnet-name "$VNET_NAME" -n "$SUBNET_NAME" &> /dev/null; then
        log_error "Subnet '$SUBNET_NAME' not found"
        exit 1
    fi
    log_success "Subnet '$SUBNET_NAME' exists"

    # Prompt for password if not provided
    if [[ -z "$ADMIN_PASSWORD" ]]; then
        log_info "Enter admin password for VM (will not be displayed):"
        read -sp "Password: " ADMIN_PASSWORD
        echo ""
        if [[ -z "$ADMIN_PASSWORD" ]]; then
            log_error "Password cannot be empty"
            exit 1
        fi
    fi
}

# ============================================================================
# VM Creation
# ============================================================================

create_virtual_machine() {
    log_section "Creating Virtual Machine"

    # Check if VM already exists
    if az vm show -g "$RESOURCE_GROUP" -n "$VM_NAME" &> /dev/null; then
        log_warning "VM '$VM_NAME' already exists"
        return 0
    fi

    log_info "Creating VM '$VM_NAME' (Size: $VM_SIZE)"
    log_info "Image: $IMAGE_PUBLISHER:$IMAGE_OFFER:$IMAGE_SKU:$IMAGE_VERSION"

    az vm create \
        --resource-group "$RESOURCE_GROUP" \
        --name "$VM_NAME" \
        --image "${IMAGE_PUBLISHER}:${IMAGE_OFFER}:${IMAGE_SKU}:${IMAGE_VERSION}" \
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
        --output none

    log_success "VM '$VM_NAME' created"
}

# ============================================================================
# Network Configuration
# ============================================================================

get_public_ip() {
    log_section "Retrieving Public IP for RDP"

    PUBLIC_IP=$(az vm show -g "$RESOURCE_GROUP" -n "$VM_NAME" -d --query publicIps -o tsv)

    if [[ -z "$PUBLIC_IP" ]] || [[ "$PUBLIC_IP" == "null" ]]; then
        log_warning "Public IP not yet assigned, waiting..."
        sleep 10
        PUBLIC_IP=$(az vm show -g "$RESOURCE_GROUP" -n "$VM_NAME" -d --query publicIps -o tsv)
    fi

    if [[ -z "$PUBLIC_IP" ]] || [[ "$PUBLIC_IP" == "null" ]]; then
        log_error "Could not retrieve public IP"
        return 1
    fi

    log_success "Public IP retrieved: $PUBLIC_IP"
}

# ============================================================================
# Verification
# ============================================================================

verify_vm_creation() {
    log_section "Verifying VM Creation"

    if az vm show -g "$RESOURCE_GROUP" -n "$VM_NAME" &> /dev/null; then
        log_success "VM '$VM_NAME' verified"
    else
        log_error "VM '$VM_NAME' not found"
        return 1
    fi

    # Check VM status
    VM_STATUS=$(az vm get-instance-view -g "$RESOURCE_GROUP" -n "$VM_NAME" --query "instanceView.statuses[?starts_with(code, 'ProvisioningState')].displayStatus" -o tsv)
    log_info "Provisioning Status: $VM_STATUS"

    log_success "VM creation verified"
}

# ============================================================================
# Main Execution
# ============================================================================

main() {
    log_section "AVD Golden Image VM Creation"

    validate_prerequisites
    create_virtual_machine
    verify_vm_creation
    get_public_ip

    echo ""
    log_success "VM Creation Complete!"
    echo ""
    log_info "Summary:"
    echo "  Resource Group: $RESOURCE_GROUP"
    echo "  VM Name: $VM_NAME"
    echo "  VM Size: $VM_SIZE"
    echo "  Image: $IMAGE_SKU"
    echo "  Public IP: $PUBLIC_IP"
    echo "  Admin Username: $ADMIN_USERNAME"
    echo ""
    log_info "Next steps:"
    echo "  1. Connect to VM via RDP: $PUBLIC_IP (Port 3389)"
    echo "  2. Login with username '$ADMIN_USERNAME'"
    echo "  3. Once logged in, run the VM configuration script (05-Golden-Image-VM-Configure.ps1)"
    echo "  4. Save the password securely for later use"
    echo ""
}

main "$@"
