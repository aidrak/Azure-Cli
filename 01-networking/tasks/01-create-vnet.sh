#!/bin/bash

################################################################################
# Task: Create Virtual Network
#
# Purpose: Create Azure Virtual Network with subnets for AVD deployment
#
# Inputs (from config.env):
#   - RESOURCE_GROUP_NAME: Resource group for VNet
#   - LOCATION: Azure region
#   - VNET_NAME: Virtual network name
#   - VNET_CIDR: VNet address space (e.g., 10.0.0.0/16)
#   - SESSION_HOSTS_SUBNET_NAME: Session hosts subnet name
#   - SESSION_HOSTS_SUBNET_CIDR: Session hosts subnet CIDR
#   - PRIVATE_ENDPOINTS_SUBNET_NAME: Private endpoints subnet name
#   - PRIVATE_ENDPOINTS_SUBNET_CIDR: Private endpoints subnet CIDR
#   - FILE_SERVER_SUBNET_NAME: File server subnet name
#   - FILE_SERVER_SUBNET_CIDR: File server subnet CIDR
#
# Outputs:
#   - VNet created with all subnets
#   - Details saved to: artifacts/01-create-vnet-details.txt
#
# Duration: 2-3 minutes
#
# Idempotent: Yes (skips if VNet already exists)
################################################################################

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCRIPT_NAME="01-create-vnet"

# Load configuration
CONFIG_FILE="${PROJECT_ROOT}/01-networking/config.env"
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "ERROR: Configuration file not found: $CONFIG_FILE"
    exit 1
fi

source "$CONFIG_FILE" || { echo "ERROR: Failed to load config"; exit 1; }

# Initialize logging
ENABLE_LOGGING=1
LOG_DIR="${ARTIFACTS_DIR}"
mkdir -p "$LOG_DIR"

# Load logging functions
LOGGING_FUNCS="${PROJECT_ROOT}/common/functions/logging-functions.sh"
[[ -f "$LOGGING_FUNCS" ]] && source "$LOGGING_FUNCS" || {
    log_info() { echo "ℹ $*"; }
    log_success() { echo "✓ $*"; }
    log_error() { echo "✗ $*" >&2; }
    log_warning() { echo "⚠ $*"; }
    log_section() { echo ""; echo "=== $* ==="; echo ""; }
    save_log() { echo "$LOG_DIR/${1}_$(date +%Y%m%d_%H%M%S).log"; }
}

LOG_FILE=$(save_log "$SCRIPT_NAME" "$LOG_DIR")

log_section "Task: Create Virtual Network"
log_info "Execution started at $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
log_info "Log file: $LOG_FILE"

# ============================================================================
# VALIDATION
# ============================================================================

validate_prerequisites() {
    log_section "Validating Prerequisites"

    # Check Azure CLI
    if ! command -v az &>/dev/null; then
        log_error "Azure CLI not installed"
        return 1
    fi
    log_success "Azure CLI installed"

    # Check Azure authentication
    if ! az account show &>/dev/null; then
        log_error "Not authenticated to Azure"
        return 1
    fi
    log_success "Azure authentication verified"

    # Check resource group exists
    if ! az group exists --name "$RESOURCE_GROUP_NAME" | grep -q "true"; then
        log_error "Resource group not found: $RESOURCE_GROUP_NAME"
        return 1
    fi
    log_success "Resource group exists: $RESOURCE_GROUP_NAME"

    # Validate required configuration
    local required_vars=(
        "RESOURCE_GROUP_NAME"
        "LOCATION"
        "VNET_NAME"
        "VNET_CIDR"
        "SESSION_HOSTS_SUBNET_NAME"
        "SESSION_HOSTS_SUBNET_CIDR"
    )

    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            log_error "Required configuration missing: $var"
            return 1
        fi
        log_info "$var=${!var}"
    done

    log_success "All prerequisites validated"
    return 0
}

# ============================================================================
# MAIN TASK
# ============================================================================

create_vnet() {
    log_section "Creating Virtual Network"

    # Check if VNet already exists
    if az network vnet show \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --name "$VNET_NAME" &>/dev/null; then

        log_warning "VNet already exists: $VNET_NAME"
        return 0
    fi

    log_info "Creating VNet: $VNET_NAME"
    log_info "  Address space: $VNET_CIDR"
    log_info "  Location: $LOCATION"

    if ! az network vnet create \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --name "$VNET_NAME" \
        --address-prefix "$VNET_CIDR" \
        --location "$LOCATION" \
        --output json >"${LOG_DIR}/${SCRIPT_NAME}-vnet-create.json" 2>&1; then

        log_error "Failed to create VNet"
        return 1
    fi

    log_success "VNet created: $VNET_NAME"
}

create_subnets() {
    log_section "Creating Subnets"

    # Subnet array: (name CIDR)
    local subnets=(
        "$SESSION_HOSTS_SUBNET_NAME" "$SESSION_HOSTS_SUBNET_CIDR"
        "$PRIVATE_ENDPOINTS_SUBNET_NAME" "$PRIVATE_ENDPOINTS_SUBNET_CIDR"
        "$FILE_SERVER_SUBNET_NAME" "$FILE_SERVER_SUBNET_CIDR"
    )

    local i=0
    while [[ $i -lt ${#subnets[@]} ]]; do
        local subnet_name="${subnets[$i]}"
        local subnet_cidr="${subnets[$((i+1))]}"
        ((i += 2))

        # Skip if not configured
        if [[ -z "$subnet_name" ]] || [[ -z "$subnet_cidr" ]]; then
            log_warning "Skipping unconfigured subnet"
            continue
        fi

        # Check if subnet exists
        if az network vnet subnet show \
            --resource-group "$RESOURCE_GROUP_NAME" \
            --vnet-name "$VNET_NAME" \
            --name "$subnet_name" &>/dev/null; then

            log_warning "Subnet already exists: $subnet_name"
            continue
        fi

        log_info "Creating subnet: $subnet_name ($subnet_cidr)"

        if ! az network vnet subnet create \
            --resource-group "$RESOURCE_GROUP_NAME" \
            --vnet-name "$VNET_NAME" \
            --name "$subnet_name" \
            --address-prefix "$subnet_cidr" \
            --output json >"${LOG_DIR}/${SCRIPT_NAME}-subnet-${subnet_name}.json" 2>&1; then

            log_error "Failed to create subnet: $subnet_name"
            return 1
        fi

        log_success "Subnet created: $subnet_name"
    done

    log_success "All subnets created"
}

# ============================================================================
# SAVE ARTIFACTS
# ============================================================================

save_artifacts() {
    log_section "Saving Artifacts"

    local details_file="${LOG_DIR}/${SCRIPT_NAME}-details.txt"

    # Get VNet details
    local vnet_id
    vnet_id=$(az network vnet show \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --name "$VNET_NAME" \
        --query id -o tsv)

    local vnet_provisioning_state
    vnet_provisioning_state=$(az network vnet show \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --name "$VNET_NAME" \
        --query "provisioningState" -o tsv)

    {
        echo "Virtual Network Creation Details"
        echo "=================================="
        echo ""
        echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
        echo ""
        echo "Virtual Network:"
        echo "  Name: $VNET_NAME"
        echo "  Resource Group: $RESOURCE_GROUP_NAME"
        echo "  Location: $LOCATION"
        echo "  Address Space: $VNET_CIDR"
        echo "  ID: $vnet_id"
        echo "  Provisioning State: $vnet_provisioning_state"
        echo ""
        echo "Subnets:"
        echo "  1. $SESSION_HOSTS_SUBNET_NAME ($SESSION_HOSTS_SUBNET_CIDR)"
        echo "  2. $PRIVATE_ENDPOINTS_SUBNET_NAME ($PRIVATE_ENDPOINTS_SUBNET_CIDR)"
        echo "  3. $FILE_SERVER_SUBNET_NAME ($FILE_SERVER_SUBNET_CIDR)"
        echo ""
        echo "Log file: $LOG_FILE"
    } > "$details_file"

    log_success "Details saved to: $details_file"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    log_section "Execution Plan"
    log_info "1. Validate prerequisites"
    log_info "2. Create VNet"
    log_info "3. Create subnets"
    log_info "4. Save artifacts"

    # Validate
    if ! validate_prerequisites; then
        log_error "Prerequisites validation failed"
        exit 1
    fi

    # Create VNet
    if ! create_vnet; then
        log_error "VNet creation failed"
        exit 1
    fi

    # Create subnets
    if ! create_subnets; then
        log_error "Subnet creation failed"
        exit 1
    fi

    # Save artifacts
    if ! save_artifacts; then
        log_warning "Failed to save artifacts (non-fatal)"
    fi

    # Success
    log_section "Completion"
    log_success "Task completed successfully"
    log_info "Execution completed at $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
    log_info "Next task: 02-create-nsgs.sh"

    return 0
}

main "$@"
exit $?
