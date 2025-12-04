#!/bin/bash

################################################################################
# Validate Prerequisites for Golden Image Creation
################################################################################
# Lightweight validator - checks essential requirements before running tasks
################################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VALIDATOR_LOG_FILE="${SCRIPT_DIR}/artifacts/validate-prereqs-$(date +'%Y%m%d_%H%M%S').log"
CONFIG_FILE="${SCRIPT_DIR}/config.env"

mkdir -p "${SCRIPT_DIR}/artifacts"

# ============================================================================
# Colors
# ============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ============================================================================
# Logging
# ============================================================================
log_section() {
    echo -e "\n${BLUE}=== $1 ===${NC}" | tee -a "$VALIDATOR_LOG_FILE"
}

log_success() {
    echo -e "${GREEN}✓ $1${NC}" | tee -a "$VALIDATOR_LOG_FILE"
}

log_error() {
    echo -e "${RED}✗ $1${NC}" | tee -a "$VALIDATOR_LOG_FILE"
    exit 1
}

log_warning() {
    echo -e "${YELLOW}⚠ $1${NC}" | tee -a "$VALIDATOR_LOG_FILE"
}

log_info() {
    echo -e "${YELLOW}ℹ $1${NC}" | tee -a "$VALIDATOR_LOG_FILE"
}

# ============================================================================
# Quick Checks
# ============================================================================

log_section "GOLDEN IMAGE PREREQUISITES VALIDATION"
log_info "Log file: $VALIDATOR_LOG_FILE"
log_info "Timestamp: $(date)"

# Check 1: Azure CLI
if ! command -v az &> /dev/null; then
    log_error "Azure CLI is not installed"
fi
log_success "Azure CLI installed"

# Check 2: Azure Authentication (with timeout)
if ! timeout 10 az account show &> /dev/null 2>&1; then
    log_error "Not authenticated to Azure. Run 'az login' first."
fi
log_success "Authenticated to Azure"

# Check 3: Load config
if [ ! -f "$CONFIG_FILE" ]; then
    log_error "Configuration file not found: $CONFIG_FILE"
fi
source "$CONFIG_FILE" 2>/dev/null || log_error "Failed to load config.env"
log_success "Configuration file loaded"

# Check 4: Resource Group
if ! timeout 10 az group exists -n "$RESOURCE_GROUP_NAME" | grep -q true 2>/dev/null; then
    log_error "Resource group '$RESOURCE_GROUP_NAME' does not exist"
fi
log_success "Resource group '$RESOURCE_GROUP_NAME' exists"

# Check 5: VNet
if ! timeout 10 az network vnet show -g "$RESOURCE_GROUP_NAME" -n "$VNET_NAME" &> /dev/null 2>&1; then
    log_error "VNet '$VNET_NAME' not found"
fi
log_success "VNet '$VNET_NAME' exists"

# Check 6: Subnet
if ! timeout 10 az network vnet subnet show -g "$RESOURCE_GROUP_NAME" --vnet-name "$VNET_NAME" -n "$SUBNET_NAME" &> /dev/null 2>&1; then
    log_error "Subnet '$SUBNET_NAME' not found"
fi
log_success "Subnet '$SUBNET_NAME' exists"

# ============================================================================
# Summary
# ============================================================================

log_section "Validation Summary"
log_success "All prerequisite checks passed!"
log_info "You can now run the golden image creation workflow:"
log_info "  ./tasks/01-create-vm.sh"

exit 0
