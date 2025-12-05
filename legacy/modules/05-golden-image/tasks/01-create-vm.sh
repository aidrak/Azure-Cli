#!/bin/bash

# ============================================================================
# Task 01: Create Temporary VM for Golden Image
# ============================================================================
#
# Purpose: Creates a temporary Windows 11 VM in Azure with necessary configuration
# for golden image creation (TrustedLaunch security, public IP for RDP access).
#
# Dependencies: None (first task in the golden image workflow)
#
# Prerequisites:
# - Azure CLI installed and authenticated
# - Resource group must exist
# - VNet and subnet must exist
# - config.env must be sourced
#
# Inputs from config.env:
# - RESOURCE_GROUP_NAME
# - TEMP_VM_NAME
# - VM_SIZE
# - WINDOWS_IMAGE_SKU
# - LOCATION
# - VNET_NAME
# - SUBNET_NAME
# - ADMIN_USERNAME
# - ADMIN_PASSWORD
# - TAGS
#
# Outputs:
# - VM created in Azure
# - Public IP assigned
# - logs/artifacts/task-01-*.log
#
# Notes:
# - Idempotent: checks if VM exists before creating
# - Uses TrustedLaunch for enhanced security
# - Creates Standard public IP for RDP access
# - Expected runtime: 5-10 minutes
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

TASK_NAME="01-create-vm"
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
# Validation Functions
# ============================================================================

validate_prerequisites() {
    log_section "Validating Prerequisites"

    # Check Azure CLI
    if ! command -v az &> /dev/null; then
        log_error "Azure CLI is not installed"
    fi
    log_success "Azure CLI is installed"

    # Check Azure authentication
    if ! az account show &> /dev/null; then
        log_error "Not logged into Azure. Run 'az login' first"
    fi
    log_success "Logged into Azure"

    # Check required environment variables
    local required_vars=("RESOURCE_GROUP_NAME" "TEMP_VM_NAME" "VM_SIZE" "WINDOWS_IMAGE_SKU" "LOCATION" "VNET_NAME" "SUBNET_NAME" "ADMIN_USERNAME" "ADMIN_PASSWORD")

    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            log_error "Required variable '$var' is not set"
        fi
    done
    log_success "All required variables are set"

    # Check resource group exists
    if ! az group exists -n "$RESOURCE_GROUP_NAME" | grep -q true; then
        log_error "Resource group '$RESOURCE_GROUP_NAME' does not exist"
    fi
    log_success "Resource group '$RESOURCE_GROUP_NAME' exists"

    # Check VNet exists
    if ! az network vnet show -g "$RESOURCE_GROUP_NAME" -n "$VNET_NAME" &> /dev/null; then
        log_error "VNet '$VNET_NAME' not found in resource group '$RESOURCE_GROUP_NAME'"
    fi
    log_success "VNet '$VNET_NAME' exists"

    # Check subnet exists
    if ! az network vnet subnet show -g "$RESOURCE_GROUP_NAME" --vnet-name "$VNET_NAME" -n "$SUBNET_NAME" &> /dev/null; then
        log_error "Subnet '$SUBNET_NAME' not found in VNet '$VNET_NAME'"
    fi
    log_success "Subnet '$SUBNET_NAME' exists"
}

# ============================================================================
# VM Creation
# ============================================================================

check_vm_exists() {
    log_info "Checking if VM '$TEMP_VM_NAME' already exists..."

    if az vm show -g "$RESOURCE_GROUP_NAME" -n "$TEMP_VM_NAME" &> /dev/null; then
        log_warning "VM '$TEMP_VM_NAME' already exists. Skipping creation."
        return 0
    fi
    return 1
}

create_vm() {
    log_section "Creating Virtual Machine"

    log_info "VM Configuration:"
    log_info "  Name: $TEMP_VM_NAME"
    log_info "  Size: $VM_SIZE"
    log_info "  Image: $WINDOWS_IMAGE_SKU"
    log_info "  Location: $LOCATION"
    log_info "  VNet: $VNET_NAME"
    log_info "  Subnet: $SUBNET_NAME"

    az vm create \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --name "$TEMP_VM_NAME" \
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
        --tags $TAGS \
        --output none 2>&1 | tee -a "$LOG_FILE"

    log_success "VM '$TEMP_VM_NAME' created successfully"
}

get_vm_details() {
    log_section "Fetching VM Details"

    # Get public IP
    PUBLIC_IP=$(az vm show -g "$RESOURCE_GROUP_NAME" -n "$TEMP_VM_NAME" -d --query "publicIps" -o tsv)
    if [ -z "$PUBLIC_IP" ] || [ "$PUBLIC_IP" == "None" ]; then
        log_warning "No public IP assigned yet. Waiting 30 seconds and retrying..."
        sleep 30
        PUBLIC_IP=$(az vm show -g "$RESOURCE_GROUP_NAME" -n "$TEMP_VM_NAME" -d --query "publicIps" -o tsv)
    fi

    log_success "VM Public IP: $PUBLIC_IP"

    # Get private IP
    PRIVATE_IP=$(az vm show -g "$RESOURCE_GROUP_NAME" -n "$TEMP_VM_NAME" -d --query "privateIps" -o tsv)
    log_success "VM Private IP: $PRIVATE_IP"

    # Get VM ID
    VM_ID=$(az vm show -g "$RESOURCE_GROUP_NAME" -n "$TEMP_VM_NAME" --query "id" -o tsv)
    log_success "VM ID: $VM_ID"

    # Save VM details to state file
    cat > "${SCRIPT_DIR}/artifacts/${TASK_NAME}_vm-details.txt" << EOF
VM_NAME=$TEMP_VM_NAME
VM_RESOURCE_GROUP=$RESOURCE_GROUP_NAME
VM_ID=$VM_ID
VM_PUBLIC_IP=$PUBLIC_IP
VM_PRIVATE_IP=$PRIVATE_IP
VM_CREATED_AT=$(date -Iseconds)
EOF
    log_success "VM details saved to artifacts"
}

# ============================================================================
# Main Execution
# ============================================================================

log_section "TASK 01: Create Temporary VM"
log_info "Log file: $LOG_FILE"

validate_prerequisites

if check_vm_exists; then
    log_section "VM Already Exists"
    get_vm_details
else
    create_vm
    get_vm_details
fi

log_section "Task Complete"
log_success "VM '$TEMP_VM_NAME' is ready for configuration"
log_info "Next step: Run task 02-validate-vm.sh to wait for VM readiness"

exit 0
