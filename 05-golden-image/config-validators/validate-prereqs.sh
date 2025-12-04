#!/bin/bash

# ============================================================================
# Validate Prerequisites for Golden Image Creation
# ============================================================================
#
# Purpose: Checks that all required tools and permissions are available
# before starting the golden image creation workflow.
#
# Prerequisites: None
#
# Outputs:
# - Validation report to console and log file
# - Exit code 0 if all checks pass, 1 if any check fails
#
# Notes:
# - Run this before starting any tasks
# - Can be run independently at any time
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
LOG_FILE="${SCRIPT_DIR}/artifacts/validate-prereqs-$(date +'%Y%m%d_%H%M%S').log"

mkdir -p "${SCRIPT_DIR}/artifacts"

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

CHECKS_PASSED=0
CHECKS_FAILED=0

check_tool_installed() {
    local tool_name=$1
    local command=$2

    if command -v "$command" &> /dev/null; then
        local version=$($command --version 2>&1 | head -1)
        log_success "$tool_name is installed ($version)"
        ((CHECKS_PASSED++))
    else
        log_error "$tool_name is not installed. Install it before proceeding."
        ((CHECKS_FAILED++))
    fi
}

check_azure_cli() {
    log_section "Checking Azure CLI"
    check_tool_installed "Azure CLI" "az"
}

check_azure_authentication() {
    log_section "Checking Azure Authentication"

    if az account show &> /dev/null; then
        CURRENT_ACCOUNT=$(az account show --query "user.name" -o tsv)
        CURRENT_SUBSCRIPTION=$(az account show --query "name" -o tsv)
        log_success "Authenticated to Azure as: $CURRENT_ACCOUNT"
        log_info "Current subscription: $CURRENT_SUBSCRIPTION"
        ((CHECKS_PASSED++))
    else
        log_error "Not authenticated to Azure. Run 'az login' first."
        ((CHECKS_FAILED++))
    fi
}

check_resource_group() {
    log_section "Checking Resource Group"

    if [ -f "${SCRIPT_DIR}/config.env" ]; then
        source "${SCRIPT_DIR}/config.env"
    fi

    if [ -z "$RESOURCE_GROUP_NAME" ]; then
        log_warning "RESOURCE_GROUP_NAME not set in config.env"
        ((CHECKS_FAILED++))
        return
    fi

    if az group exists -n "$RESOURCE_GROUP_NAME" | grep -q true; then
        RG_LOCATION=$(az group show -n "$RESOURCE_GROUP_NAME" --query "location" -o tsv)
        log_success "Resource group '$RESOURCE_GROUP_NAME' exists (location: $RG_LOCATION)"
        ((CHECKS_PASSED++))
    else
        log_error "Resource group '$RESOURCE_GROUP_NAME' does not exist"
        ((CHECKS_FAILED++))
    fi
}

check_vnet() {
    log_section "Checking Virtual Network"

    if [ -z "$VNET_NAME" ] || [ -z "$RESOURCE_GROUP_NAME" ]; then
        log_warning "VNET_NAME or RESOURCE_GROUP_NAME not set"
        ((CHECKS_FAILED++))
        return
    fi

    if az network vnet show -g "$RESOURCE_GROUP_NAME" -n "$VNET_NAME" &> /dev/null; then
        VPC_PREFIX=$(az network vnet show -g "$RESOURCE_GROUP_NAME" -n "$VNET_NAME" --query "addressSpace.addressPrefixes[0]" -o tsv)
        log_success "VNet '$VNET_NAME' exists (prefix: $VPC_PREFIX)"
        ((CHECKS_PASSED++))
    else
        log_error "VNet '$VNET_NAME' not found in resource group '$RESOURCE_GROUP_NAME'"
        ((CHECKS_FAILED++))
    fi
}

check_subnet() {
    log_section "Checking Subnet"

    if [ -z "$SUBNET_NAME" ] || [ -z "$VNET_NAME" ] || [ -z "$RESOURCE_GROUP_NAME" ]; then
        log_warning "SUBNET_NAME, VNET_NAME, or RESOURCE_GROUP_NAME not set"
        ((CHECKS_FAILED++))
        return
    fi

    if az network vnet subnet show -g "$RESOURCE_GROUP_NAME" --vnet-name "$VNET_NAME" -n "$SUBNET_NAME" &> /dev/null; then
        SUBNET_PREFIX=$(az network vnet subnet show -g "$RESOURCE_GROUP_NAME" --vnet-name "$VNET_NAME" -n "$SUBNET_NAME" --query "addressPrefix" -o tsv)
        log_success "Subnet '$SUBNET_NAME' exists (prefix: $SUBNET_PREFIX)"
        ((CHECKS_PASSED++))
    else
        log_error "Subnet '$SUBNET_NAME' not found in VNet '$VNET_NAME'"
        ((CHECKS_FAILED++))
    fi
}

check_azure_permissions() {
    log_section "Checking Azure Permissions"

    # Check if user has sufficient permissions to create VMs, galleries, etc.
    # This is a basic check - actual permissions required are more granular

    if az role assignment list --query "[].roleDefinitionName" -o tsv | grep -q "Contributor\|Owner"; then
        log_success "User has sufficient Azure permissions (Contributor or Owner role)"
        ((CHECKS_PASSED++))
    else
        log_warning "User may not have sufficient permissions. Verify before proceeding."
        log_info "Required permissions: Virtual Machine Contributor, Gallery Contributor, Network Contributor"
        ((CHECKS_FAILED++))
    fi
}

check_configuration_file() {
    log_section "Checking Configuration File"

    if [ ! -f "${SCRIPT_DIR}/config.env" ]; then
        log_error "Configuration file 'config.env' not found"
        ((CHECKS_FAILED++))
        return
    fi

    log_success "Configuration file 'config.env' exists"

    # Check for required variables
    REQUIRED_VARS=("RESOURCE_GROUP_NAME" "LOCATION" "TEMP_VM_NAME" "VM_SIZE" "WINDOWS_IMAGE_SKU" "VNET_NAME" "SUBNET_NAME")

    for var in "${REQUIRED_VARS[@]}"; do
        if grep -q "^export $var=" "${SCRIPT_DIR}/config.env"; then
            log_success "  Variable '$var' is defined in config.env"
            ((CHECKS_PASSED++))
        else
            log_warning "  Variable '$var' is NOT defined in config.env"
            ((CHECKS_FAILED++))
        fi
    done
}

# ============================================================================
# Main Execution
# ============================================================================

log_section "GOLDEN IMAGE PREREQUISITES VALIDATION"
log_info "Log file: $LOG_FILE"
log_info "Timestamp: $(date)"

check_azure_cli
check_azure_authentication
check_resource_group
check_vnet
check_subnet
check_azure_permissions
check_configuration_file

# ============================================================================
# Summary
# ============================================================================

log_section "Validation Summary"
log_info "Checks passed: $CHECKS_PASSED"
log_info "Checks failed: $CHECKS_FAILED"

if [ $CHECKS_FAILED -eq 0 ]; then
    log_success "All prerequisite checks passed!"
    log_info "You can now start the golden image creation workflow:"
    log_info "  ./tasks/01-create-vm.sh"
    exit 0
else
    log_error "Some prerequisite checks failed. Please address the issues above and try again."
    exit 1
fi
