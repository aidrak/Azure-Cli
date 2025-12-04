#!/bin/bash

################################################################################
# Task: Create File Share for FSLogix
#
# Purpose: Create Azure Premium Files share for FSLogix profile containers
#
# Inputs (from config.env):
#   - RESOURCE_GROUP_NAME
#   - STORAGE_ACCOUNT_NAME
#   - FILE_SHARE_NAME
#   - FILE_SHARE_QUOTA_GB
#
# Outputs:
#   - File share created
#   - Quota set
#   - Details saved to artifacts/
#
# Duration: 1-2 minutes
# Idempotent: Yes
################################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCRIPT_NAME="02-create-file-share"

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

log_section "Creating File Share for FSLogix"

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

# Check if file share exists
if az storage share exists \
    --account-name "$STORAGE_ACCOUNT_NAME" \
    --name "$FILE_SHARE_NAME" \
    --query exists -o tsv | grep -q "true"; then

    log_success "File share already exists: $FILE_SHARE_NAME"
    exit 0
fi

# Create file share
log_info "Creating file share: $FILE_SHARE_NAME"
log_info "  Quota: ${FILE_SHARE_QUOTA_GB}GB"

if ! az storage share create \
    --account-name "$STORAGE_ACCOUNT_NAME" \
    --name "$FILE_SHARE_NAME" \
    --quota "$FILE_SHARE_QUOTA_GB" \
    --output json >"${LOG_DIR}/${SCRIPT_NAME}-create.json" 2>&1; then

    log_error "Failed to create file share"
    exit 1
fi

log_success "File share created: $FILE_SHARE_NAME"

# Get file share details
log_info "Retrieving file share details"

local share_id
share_id=$(az storage share show \
    --account-name "$STORAGE_ACCOUNT_NAME" \
    --name "$FILE_SHARE_NAME" \
    --query id -o tsv)

# Save details
{
    echo "File Share Creation Details"
    echo "==========================="
    echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
    echo ""
    echo "File Share:"
    echo "  Name: $FILE_SHARE_NAME"
    echo "  Storage Account: $STORAGE_ACCOUNT_NAME"
    echo "  Resource Group: $RESOURCE_GROUP_NAME"
    echo "  ID: $share_id"
    echo "  Quota: ${FILE_SHARE_QUOTA_GB}GB"
    echo ""
    echo "FSLogix Configuration:"
    echo "  Path: \\\\${STORAGE_ACCOUNT_NAME}.file.core.windows.net\\${FILE_SHARE_NAME}"
    echo "  Mount Type: SMB3.1.1 with Kerberos"
    echo ""
} > "${LOG_DIR}/${SCRIPT_NAME}-details.txt"

log_success "Task completed successfully"
exit 0
