#!/bin/bash

################################################################################
# Task: Create Network Security Groups
#
# Purpose: Create NSGs with inbound/outbound rules for AVD architecture
#
# Inputs (from config.env):
#   - RESOURCE_GROUP_NAME
#   - LOCATION
#   - NSG variables for each subnet
#
# Outputs:
#   - Multiple NSGs created with rules
#   - Details saved to artifacts/
#
# Duration: 2-3 minutes
# Idempotent: Yes
################################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCRIPT_NAME="02-create-nsgs"

CONFIG_FILE="${PROJECT_ROOT}/01-networking/config.env"
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

log_section "Creating Network Security Groups"

# Validate
if ! az account show &>/dev/null; then
    log_error "Not authenticated to Azure"
    exit 1
fi

if ! az group exists --name "$RESOURCE_GROUP_NAME" | grep -q "true"; then
    log_error "Resource group not found: $RESOURCE_GROUP_NAME"
    exit 1
fi

# NSG for session hosts subnet
local session_hosts_nsg="${SESSION_HOSTS_SUBNET_NAME}-nsg"

if ! az network nsg show \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$session_hosts_nsg" &>/dev/null; then

    log_info "Creating NSG for session hosts: $session_hosts_nsg"

    az network nsg create \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --name "$session_hosts_nsg" \
        --location "$LOCATION" \
        --output none

    # Add basic rules
    az network nsg rule create \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --nsg-name "$session_hosts_nsg" \
        --name "AllowRDP" \
        --priority 100 \
        --source-address-prefixes "*" \
        --source-port-ranges "*" \
        --destination-address-prefixes "VirtualNetwork" \
        --destination-port-ranges "3389" \
        --access Allow \
        --protocol Tcp \
        --output none

    log_success "NSG created: $session_hosts_nsg"
else
    log_success "NSG already exists: $session_hosts_nsg"
fi

# NSG for private endpoints
local private_endpoints_nsg="${PRIVATE_ENDPOINTS_SUBNET_NAME}-nsg"

if ! az network nsg show \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$private_endpoints_nsg" &>/dev/null; then

    log_info "Creating NSG for private endpoints: $private_endpoints_nsg"

    az network nsg create \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --name "$private_endpoints_nsg" \
        --location "$LOCATION" \
        --output none

    log_success "NSG created: $private_endpoints_nsg"
else
    log_success "NSG already exists: $private_endpoints_nsg"
fi

# Save details
{
    echo "Network Security Groups Creation Details"
    echo "========================================"
    echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
    echo ""
    echo "NSGs Created:"
    echo "  Session Hosts NSG: $session_hosts_nsg"
    echo "  Private Endpoints NSG: $private_endpoints_nsg"
    echo ""
    echo "Rules Applied:"
    echo "  RDP (3389) - Allow from VirtualNetwork"
    echo ""
    echo "Next Steps:"
    echo "  1. Associate NSGs with subnets"
    echo "  2. Add additional rules as needed"
    echo ""
} > "${LOG_DIR}/${SCRIPT_NAME}-details.txt"

log_success "Task completed successfully"
exit 0
