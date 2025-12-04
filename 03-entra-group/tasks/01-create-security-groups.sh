#!/bin/bash

################################################################################
# Task: Create Entra ID Security Groups
#
# Purpose: Create security groups for AVD users and administrators
#
# Inputs (from config.env):
#   - AVD_USERS_GROUP_NAME
#   - AVD_USERS_GROUP_DESCRIPTION
#   - AVD_ADMINS_GROUP_NAME
#   - AVD_ADMINS_GROUP_DESCRIPTION
#   - TENANT_ID
#
# Outputs:
#   - Two security groups created
#   - Group IDs saved
#   - Details saved to artifacts/
#
# Duration: 1-2 minutes
# Idempotent: Yes (checks if groups exist)
################################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCRIPT_NAME="01-create-security-groups"

CONFIG_FILE="${PROJECT_ROOT}/03-entra-group/config.env"
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

log_section "Creating Entra ID Security Groups"

# Validate Azure CLI authentication
if ! az account show &>/dev/null; then
    log_error "Not authenticated to Azure"
    exit 1
fi

# Create AVD Users Group
log_info "Creating AVD Users security group"

local users_group_id
users_group_id=$(az ad group list \
    --filter "displayName eq '${AVD_USERS_GROUP_NAME}'" \
    --query "[0].id" -o tsv 2>/dev/null || echo "")

if [[ -n "$users_group_id" && "$users_group_id" != "None" ]]; then
    log_success "AVD Users group already exists"
else
    log_info "  Name: $AVD_USERS_GROUP_NAME"
    log_info "  Description: $AVD_USERS_GROUP_DESCRIPTION"

    if ! users_group_id=$(az ad group create \
        --display-name "$AVD_USERS_GROUP_NAME" \
        --mail-nickname "$(echo $AVD_USERS_GROUP_NAME | tr ' ' '-' | tr '[:upper:]' '[:lower:]')" \
        --description "$AVD_USERS_GROUP_DESCRIPTION" \
        --query id -o tsv 2>&1); then

        log_error "Failed to create AVD Users group"
        log_error "$users_group_id"
        exit 1
    fi

    log_success "AVD Users group created: $AVD_USERS_GROUP_NAME"
fi

# Create AVD Admins Group
log_info "Creating AVD Admins security group"

local admins_group_id
admins_group_id=$(az ad group list \
    --filter "displayName eq '${AVD_ADMINS_GROUP_NAME}'" \
    --query "[0].id" -o tsv 2>/dev/null || echo "")

if [[ -n "$admins_group_id" && "$admins_group_id" != "None" ]]; then
    log_success "AVD Admins group already exists"
else
    log_info "  Name: $AVD_ADMINS_GROUP_NAME"
    log_info "  Description: $AVD_ADMINS_GROUP_DESCRIPTION"

    if ! admins_group_id=$(az ad group create \
        --display-name "$AVD_ADMINS_GROUP_NAME" \
        --mail-nickname "$(echo $AVD_ADMINS_GROUP_NAME | tr ' ' '-' | tr '[:upper:]' '[:lower:]')" \
        --description "$AVD_ADMINS_GROUP_DESCRIPTION" \
        --query id -o tsv 2>&1); then

        log_error "Failed to create AVD Admins group"
        log_error "$admins_group_id"
        exit 1
    fi

    log_success "AVD Admins group created: $AVD_ADMINS_GROUP_NAME"
fi

# Get final group IDs for verification
users_group_id=$(az ad group list \
    --filter "displayName eq '${AVD_USERS_GROUP_NAME}'" \
    --query "[0].id" -o tsv)

admins_group_id=$(az ad group list \
    --filter "displayName eq '${AVD_ADMINS_GROUP_NAME}'" \
    --query "[0].id" -o tsv)

# Save details
{
    echo "Security Groups Creation Details"
    echo "================================"
    echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
    echo ""
    echo "AVD Users Group:"
    echo "  Name: $AVD_USERS_GROUP_NAME"
    echo "  ID: $users_group_id"
    echo "  Purpose: End users accessing AVD resources"
    echo ""
    echo "AVD Admins Group:"
    echo "  Name: $AVD_ADMINS_GROUP_NAME"
    echo "  ID: $admins_group_id"
    echo "  Purpose: Administrative access to AVD infrastructure"
    echo ""
    echo "Next Steps:"
    echo "  1. Add users to the appropriate groups"
    echo "  2. Use these groups for RBAC assignments"
    echo "  3. Use these groups for application group assignments"
    echo ""
} > "${LOG_DIR}/${SCRIPT_NAME}-details.txt"

log_success "Task completed successfully"
exit 0
