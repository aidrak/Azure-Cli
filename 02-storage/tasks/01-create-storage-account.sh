#!/bin/bash

################################################################################
# Task: Create Storage Account
#
# Purpose: Create Azure Premium Files storage account for FSLogix
#
# Inputs (from config.env):
#   - RESOURCE_GROUP_NAME
#   - LOCATION
#   - STORAGE_ACCOUNT_NAME
#   - STORAGE_ACCOUNT_SKU (Premium_LRS)
#   - STORAGE_ACCOUNT_KIND (FileStorage)
#
# Outputs:
#   - Storage account created
#   - Details saved to artifacts/
#
# Duration: 1-2 minutes
# Idempotent: Yes
################################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCRIPT_NAME="01-create-storage-account"

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
    save_log() { echo "$LOG_DIR/${1}_$(date +%Y%m%d_%H%M%S).log"; }
}

LOG_FILE=$(save_log "$SCRIPT_NAME" "$LOG_DIR")

log_section() { echo ""; echo "=== $1 ==="; echo ""; }

log_section "Creating Storage Account"

# Validate
if ! az account show &>/dev/null; then
    log_error "Not authenticated to Azure"
    exit 1
fi

if ! az group exists --name "$RESOURCE_GROUP_NAME" | grep -q "true"; then
    log_error "Resource group not found: $RESOURCE_GROUP_NAME"
    exit 1
fi

# Check if storage account exists
if az storage account show \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$STORAGE_ACCOUNT_NAME" &>/dev/null; then

    log_success "Storage account already exists: $STORAGE_ACCOUNT_NAME"
    exit 0
fi

# Create storage account
log_info "Creating storage account: $STORAGE_ACCOUNT_NAME"
log_info "  SKU: $STORAGE_ACCOUNT_SKU"
log_info "  Kind: $STORAGE_ACCOUNT_KIND"

if ! az storage account create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$STORAGE_ACCOUNT_NAME" \
    --location "$LOCATION" \
    --sku "$STORAGE_ACCOUNT_SKU" \
    --kind "$STORAGE_ACCOUNT_KIND" \
    --access-tier Premium \
    --https-only true \
    --output json >"${LOG_DIR}/${SCRIPT_NAME}-create.json" 2>&1; then

    log_error "Failed to create storage account"
    exit 1
fi

log_success "Storage account created: $STORAGE_ACCOUNT_NAME"

# Get storage account details
local storage_id
storage_id=$(az storage account show \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$STORAGE_ACCOUNT_NAME" \
    --query id -o tsv)

log_info "Storage Account ID: $storage_id"

# Save details
{
    echo "Storage Account Creation Details"
    echo "================================="
    echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
    echo ""
    echo "Storage Account:"
    echo "  Name: $STORAGE_ACCOUNT_NAME"
    echo "  Resource Group: $RESOURCE_GROUP_NAME"
    echo "  Location: $LOCATION"
    echo "  ID: $storage_id"
    echo "  SKU: $STORAGE_ACCOUNT_SKU"
    echo ""
    echo "Log file: $LOG_FILE"
} > "${LOG_DIR}/${SCRIPT_NAME}-details.txt"

log_success "Task completed successfully"
exit 0
