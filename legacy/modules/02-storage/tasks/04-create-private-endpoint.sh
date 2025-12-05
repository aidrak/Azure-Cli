#!/bin/bash

################################################################################
# Task: Create Private Endpoint for Storage Account
#
# Purpose: Create private endpoint for secure, non-internet-routable access
#          to FSLogix storage
#
# Inputs (from config.env):
#   - STORAGE_ACCOUNT_NAME
#   - RESOURCE_GROUP_NAME
#   - LOCATION
#   - VNET_NAME
#   - PRIVATE_ENDPOINT_SUBNET_NAME
#   - PRIVATE_DNS_ZONE_NAME
#
# Outputs:
#   - Private endpoint created
#   - DNS zone link created
#   - A record configured
#   - Details saved to artifacts/
#
# Duration: 2-3 minutes
# Idempotent: Yes
################################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCRIPT_NAME="04-create-private-endpoint"

CONFIG_FILE="${PROJECT_ROOT}/02-storage/config.env"
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

log_section "Creating Private Endpoint for Storage"

# Validate
if ! az account show &>/dev/null; then
    log_error "Not authenticated to Azure"
    exit 1
fi

if ! az storage account show \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$STORAGE_ACCOUNT_NAME" &>/dev/null; then
    log_error "Storage account not found: $STORAGE_ACCOUNT_NAME"
    exit 1
fi

if ! az network vnet show \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$VNET_NAME" &>/dev/null; then
    log_error "VNet not found: $VNET_NAME"
    exit 1
fi

# Generate private endpoint name
local pe_name="${STORAGE_ACCOUNT_NAME}-file-pep"

# Check if private endpoint already exists
if az network private-endpoint show \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$pe_name" &>/dev/null; then

    log_success "Private endpoint already exists: $pe_name"
    exit 0
fi

# Get subnet ID
log_info "Getting subnet ID for private endpoint"

local subnet_id
subnet_id=$(az network vnet subnet show \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --vnet-name "$VNET_NAME" \
    --name "$PRIVATE_ENDPOINT_SUBNET_NAME" \
    --query id -o tsv)

if [[ -z "$subnet_id" ]]; then
    log_error "Subnet not found: $PRIVATE_ENDPOINT_SUBNET_NAME"
    exit 1
fi

# Get storage account resource ID
local storage_id
storage_id=$(az storage account show \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$STORAGE_ACCOUNT_NAME" \
    --query id -o tsv)

# Create private endpoint
log_info "Creating private endpoint: $pe_name"

if ! az network private-endpoint create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$pe_name" \
    --vnet-name "$VNET_NAME" \
    --subnet "$PRIVATE_ENDPOINT_SUBNET_NAME" \
    --private-connection-resource-id "$storage_id" \
    --group-ids file \
    --connection-name "${STORAGE_ACCOUNT_NAME}-connection" \
    --output json >"${LOG_DIR}/${SCRIPT_NAME}-create.json" 2>&1; then

    log_error "Failed to create private endpoint"
    exit 1
fi

log_success "Private endpoint created: $pe_name"

# Get private endpoint details
log_info "Retrieving private endpoint details"

local pe_id nic_id private_ip
pe_id=$(az network private-endpoint show \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$pe_name" \
    --query id -o tsv)

nic_id=$(az network private-endpoint show \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$pe_name" \
    --query "networkInterfaces[0].id" -o tsv)

private_ip=$(az network nic show \
    --ids "$nic_id" \
    --query "ipConfigurations[0].privateIpAddress" -o tsv)

# Create or update private DNS zone record
log_info "Configuring private DNS zone"

# Check if private DNS zone exists
if ! az network private-dns zone show \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$PRIVATE_DNS_ZONE_NAME" &>/dev/null; then

    log_info "Creating private DNS zone: $PRIVATE_DNS_ZONE_NAME"

    az network private-dns zone create \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --name "$PRIVATE_DNS_ZONE_NAME" \
        --output none

    # Link DNS zone to VNet
    log_info "Linking DNS zone to VNet"

    az network private-dns link vnet create \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --zone-name "$PRIVATE_DNS_ZONE_NAME" \
        --name "${VNET_NAME}-link" \
        --virtual-network "$VNET_NAME" \
        --registration-enabled false \
        --output none
fi

# Create A record for private endpoint
log_info "Creating DNS A record for private endpoint"

az network private-dns record-set a create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --zone-name "$PRIVATE_DNS_ZONE_NAME" \
    --name "$STORAGE_ACCOUNT_NAME" \
    --output none 2>/dev/null || true

az network private-dns record-set a add-record \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --zone-name "$PRIVATE_DNS_ZONE_NAME" \
    --record-set-name "$STORAGE_ACCOUNT_NAME" \
    --ipv4-address "$private_ip" \
    --output none

log_success "DNS A record created"

# Save details
{
    echo "Private Endpoint Configuration Details"
    echo "======================================"
    echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
    echo ""
    echo "Private Endpoint:"
    echo "  Name: $pe_name"
    echo "  Resource Group: $RESOURCE_GROUP_NAME"
    echo "  ID: $pe_id"
    echo "  VNet: $VNET_NAME"
    echo "  Subnet: $PRIVATE_ENDPOINT_SUBNET_NAME"
    echo ""
    echo "Network Interface:"
    echo "  NIC ID: $nic_id"
    echo "  Private IP: $private_ip"
    echo ""
    echo "DNS Configuration:"
    echo "  DNS Zone: $PRIVATE_DNS_ZONE_NAME"
    echo "  Record: ${STORAGE_ACCOUNT_NAME}.${PRIVATE_DNS_ZONE_NAME}"
    echo "  IP Address: $private_ip"
    echo ""
    echo "Access:"
    echo "  Internal VNet access only (no public internet routing)"
    echo "  Accessible via private IP: $private_ip"
    echo ""
} > "${LOG_DIR}/${SCRIPT_NAME}-details.txt"

log_success "Task completed successfully"
exit 0
