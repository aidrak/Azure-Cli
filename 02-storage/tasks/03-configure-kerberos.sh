#!/bin/bash

################################################################################
# Task: Configure Kerberos Authentication
#
# Purpose: Enable Entra ID Kerberos authentication on Premium Files for seamless
#          FSLogix mounting with domain credentials
#
# Inputs (from config.env):
#   - STORAGE_ACCOUNT_NAME
#   - RESOURCE_GROUP_NAME
#   - ENABLE_ENTRA_KERBEROS
#   - ENABLE_SMB_MULTICHANNEL
#
# Outputs:
#   - Kerberos enabled on storage account
#   - SMB Multichannel enabled (optional)
#   - Details saved to artifacts/
#
# Duration: 1-2 minutes
# Idempotent: Yes
################################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCRIPT_NAME="03-configure-kerberos"

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

log_section "Configuring Kerberos Authentication"

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

# Check if Kerberos is already enabled
log_info "Checking current Kerberos configuration"

local current_config
current_config=$(az storage account show \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$STORAGE_ACCOUNT_NAME" \
    --query "azureFilesIdentityBasedAuth.directoryServiceOptions" \
    -o tsv 2>/dev/null || echo "None")

if [[ "$current_config" == "AADKERB" ]]; then
    log_success "Kerberos authentication already enabled"
else
    # Enable Kerberos
    log_info "Enabling Kerberos authentication (AADKERB)"

    if ! az storage account update \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --name "$STORAGE_ACCOUNT_NAME" \
        --enable-files-aadkerb true \
        --output json >"${LOG_DIR}/${SCRIPT_NAME}-kerberos.json" 2>&1; then

        log_error "Failed to enable Kerberos"
        exit 1
    fi

    log_success "Kerberos authentication enabled"
fi

# Enable SMB Multichannel if configured
if [[ "${ENABLE_SMB_MULTICHANNEL:-false}" == "true" ]]; then
    log_info "Enabling SMB Multichannel for performance"

    if ! az storage account update \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --name "$STORAGE_ACCOUNT_NAME" \
        --enable-smb-multichannel true \
        --output json >"${LOG_DIR}/${SCRIPT_NAME}-multichannel.json" 2>&1; then

        log_error "Failed to enable SMB Multichannel (non-critical)"
    else
        log_success "SMB Multichannel enabled"
    fi
fi

# Get updated storage account details
log_info "Retrieving updated storage configuration"

local storage_id auth_method
storage_id=$(az storage account show \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$STORAGE_ACCOUNT_NAME" \
    --query id -o tsv)

auth_method=$(az storage account show \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$STORAGE_ACCOUNT_NAME" \
    --query "azureFilesIdentityBasedAuth.directoryServiceOptions" \
    -o tsv)

# Save details
{
    echo "Kerberos Configuration Details"
    echo "=============================="
    echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
    echo ""
    echo "Storage Account:"
    echo "  Name: $STORAGE_ACCOUNT_NAME"
    echo "  Resource Group: $RESOURCE_GROUP_NAME"
    echo "  ID: $storage_id"
    echo ""
    echo "Authentication:"
    echo "  Method: $auth_method (Entra ID Kerberos)"
    echo "  SMB Multichannel: ${ENABLE_SMB_MULTICHANNEL:-false}"
    echo ""
    echo "FSLogix Integration:"
    echo "  Users can now mount shares with domain credentials"
    echo "  No additional authentication required"
    echo "  Seamless Kerberos-based access"
    echo ""
} > "${LOG_DIR}/${SCRIPT_NAME}-details.txt"

log_success "Task completed successfully"
exit 0
