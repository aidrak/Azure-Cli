#!/bin/bash

################################################################################
# Task: Assign RBAC Roles for AVD Access
#
# Purpose: Assign RBAC roles to security groups for AVD resource access
#
# Inputs (from config.env):
#   - RESOURCE_GROUP_NAME
#   - AVD_USERS_GROUP_NAME
#   - AVD_ADMINS_GROUP_NAME
#   - USER_ROLE
#   - ADMIN_ROLE
#
# Outputs:
#   - RBAC assignments created
#   - Role assignments saved to artifacts/
#
# Duration: 2-3 minutes
# Idempotent: Yes
################################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCRIPT_NAME="01-assign-rbac-roles"

CONFIG_FILE="${PROJECT_ROOT}/08-rbac/config.env"
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

log_section "Assigning RBAC Roles"

# Validate
if ! az account show &>/dev/null; then
    log_error "Not authenticated to Azure"
    exit 1
fi

if ! az group exists --name "$RESOURCE_GROUP_NAME" | grep -q "true"; then
    log_error "Resource group not found: $RESOURCE_GROUP_NAME"
    exit 1
fi

# Get resource group ID
local rg_id
rg_id=$(az group show \
    --name "$RESOURCE_GROUP_NAME" \
    --query id -o tsv)

log_info "Resource Group ID: $rg_id"

# Assign role to AVD Users group
log_info "Assigning role to AVD Users group: $AVD_USERS_GROUP_NAME"

local users_group_id
users_group_id=$(az ad group list \
    --filter "displayName eq '${AVD_USERS_GROUP_NAME}'" \
    --query "[0].id" -o tsv)

if [[ -n "$users_group_id" && "$users_group_id" != "None" ]]; then
    log_info "  Group ID: $users_group_id"
    log_info "  Role: $USER_ROLE"

    if az role assignment create \
        --assignee "$users_group_id" \
        --role "$USER_ROLE" \
        --scope "$rg_id" \
        --output none 2>/dev/null; then

        log_success "Role assigned to AVD Users group"
    else
        log_info "Role assignment already exists (or user lacks permissions)"
    fi
else
    log_error "AVD Users group not found"
    exit 1
fi

# Assign role to AVD Admins group
log_info "Assigning role to AVD Admins group: $AVD_ADMINS_GROUP_NAME"

local admins_group_id
admins_group_id=$(az ad group list \
    --filter "displayName eq '${AVD_ADMINS_GROUP_NAME}'" \
    --query "[0].id" -o tsv)

if [[ -n "$admins_group_id" && "$admins_group_id" != "None" ]]; then
    log_info "  Group ID: $admins_group_id"
    log_info "  Role: $ADMIN_ROLE"

    if az role assignment create \
        --assignee "$admins_group_id" \
        --role "$ADMIN_ROLE" \
        --scope "$rg_id" \
        --output none 2>/dev/null; then

        log_success "Role assigned to AVD Admins group"
    else
        log_info "Role assignment already exists (or user lacks permissions)"
    fi
else
    log_error "AVD Admins group not found"
    exit 1
fi

# Get all assignments
log_info "Verifying role assignments"

local assignments_json
assignments_json=$(az role assignment list \
    --scope "$rg_id" \
    --query "[?principalName.contains(@, 'AVD')].{principalName: principalName, roleDefinitionName: roleDefinitionName, scope: scope}" \
    --output json)

# Save details
{
    echo "RBAC Role Assignment Details"
    echo "============================="
    echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
    echo ""
    echo "Resource Group:"
    echo "  Name: $RESOURCE_GROUP_NAME"
    echo "  ID: $rg_id"
    echo ""
    echo "Assignments:"
    echo "  AVD Users Group:"
    echo "    Group ID: $users_group_id"
    echo "    Role: $USER_ROLE"
    echo ""
    echo "  AVD Admins Group:"
    echo "    Group ID: $admins_group_id"
    echo "    Role: $ADMIN_ROLE"
    echo ""
    echo "Scope: Resource Group ($RESOURCE_GROUP_NAME)"
    echo ""
    echo "Next Steps:"
    echo "  1. Add users to appropriate security groups"
    echo "  2. Verify role assignments in Azure Portal"
    echo "  3. Test user access to resources"
    echo ""
} > "${LOG_DIR}/${SCRIPT_NAME}-details.txt"

# Save JSON output
echo "$assignments_json" > "${LOG_DIR}/${SCRIPT_NAME}-assignments.json"

log_success "Task completed successfully"
exit 0
