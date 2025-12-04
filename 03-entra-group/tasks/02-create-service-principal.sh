#!/bin/bash

################################################################################
# Task: Create Service Principal for Automation
#
# Purpose: Create service principal for unattended deployment automation
#
# Inputs (from config.env):
#   - AUTOMATION_SP_NAME
#   - AUTOMATION_SP_DESCRIPTION
#   - TENANT_ID
#   - SUBSCRIPTION_ID
#
# Outputs:
#   - Service principal created
#   - Client credentials generated
#   - Details saved to artifacts/
#
# Duration: 1-2 minutes
# Idempotent: Yes (checks if SP exists)
#
# WARNING: This creates credentials that must be stored securely
################################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCRIPT_NAME="02-create-service-principal"

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
    log_warning() { echo "⚠ $*"; }
}

log_section() { echo ""; echo "=== $1 ==="; echo ""; }

log_section "Creating Service Principal for Automation"

# Validate Azure CLI authentication
if ! az account show &>/dev/null; then
    log_error "Not authenticated to Azure"
    exit 1
fi

# Check if service principal already exists
log_info "Checking if service principal exists: $AUTOMATION_SP_NAME"

local sp_id
sp_id=$(az ad sp list \
    --filter "displayName eq '${AUTOMATION_SP_NAME}'" \
    --query "[0].id" -o tsv 2>/dev/null || echo "")

if [[ -n "$sp_id" && "$sp_id" != "None" ]]; then
    log_success "Service principal already exists: $AUTOMATION_SP_NAME"
    log_warning "Cannot regenerate credentials. Use 'az ad app credential reset' if needed."
    exit 0
fi

# Create service principal
log_info "Creating service principal: $AUTOMATION_SP_NAME"

local sp_output
sp_output=$(az ad sp create-for-rbac \
    --name "$AUTOMATION_SP_NAME" \
    --description "$AUTOMATION_SP_DESCRIPTION" \
    --role Contributor \
    --scopes "/subscriptions/${SUBSCRIPTION_ID}" \
    --output json 2>&1)

if [[ $? -ne 0 ]]; then
    log_error "Failed to create service principal"
    exit 1
fi

log_success "Service principal created: $AUTOMATION_SP_NAME"

# Extract credentials
local app_id
local password
local tenant_id

app_id=$(echo "$sp_output" | jq -r '.appId')
password=$(echo "$sp_output" | jq -r '.password')
tenant_id=$(echo "$sp_output" | jq -r '.tenant')

# Get service principal details
local sp_object_id
sp_object_id=$(az ad sp show \
    --id "$app_id" \
    --query id -o tsv)

# Save secure details to artifacts (with warning about security)
local creds_file="${LOG_DIR}/${SCRIPT_NAME}-credentials.txt"

{
    echo "Service Principal Credentials"
    echo "============================="
    echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
    echo ""
    echo "WARNING: Store this file securely. It contains sensitive credentials."
    echo "File permissions: 600 (read-write owner only)"
    echo ""
    echo "Service Principal Details:"
    echo "  Display Name: $AUTOMATION_SP_NAME"
    echo "  Application ID: $app_id"
    echo "  Object ID: $sp_object_id"
    echo "  Tenant ID: $tenant_id"
    echo "  Subscription ID: $SUBSCRIPTION_ID"
    echo ""
    echo "Credentials:"
    echo "  Password: $password"
    echo ""
    echo "Usage (Bash):"
    echo "  az login --service-principal -u $app_id -p '$password' --tenant $tenant_id"
    echo ""
    echo "Usage (PowerShell):"
    echo "  \$securePassword = ConvertTo-SecureString '$password' -AsPlainText -Force"
    echo "  \$credential = New-Object System.Management.Automation.PSCredential('$app_id', \$securePassword)"
    echo "  Connect-AzAccount -ServicePrincipal -Credential \$credential -Tenant $tenant_id"
    echo ""
    echo "Important:"
    echo "  - Keep these credentials secure"
    echo "  - Rotate credentials regularly"
    echo "  - Do not commit to version control"
    echo "  - Use Azure Key Vault to store secrets"
    echo ""
} > "$creds_file"

# Set restrictive permissions
chmod 600 "$creds_file"

log_success "Credentials saved to: $creds_file"
log_warning "IMPORTANT: Secure this file. Credentials will not be retrievable after this script completes."

# Save public details
{
    echo "Service Principal Creation Details"
    echo "=================================="
    echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
    echo ""
    echo "Service Principal:"
    echo "  Display Name: $AUTOMATION_SP_NAME"
    echo "  Application ID: $app_id"
    echo "  Object ID: $sp_object_id"
    echo "  Tenant ID: $tenant_id"
    echo ""
    echo "Permissions:"
    echo "  Role: Contributor"
    echo "  Scope: /subscriptions/${SUBSCRIPTION_ID}"
    echo ""
    echo "Status:"
    echo "  Created: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
    echo "  Credentials File: ${SCRIPT_NAME}-credentials.txt"
    echo ""
    echo "Next Steps:"
    echo "  1. Save credentials to secure location (Azure Key Vault recommended)"
    echo "  2. Update deployment scripts with credentials"
    echo "  3. Test authentication with 'az login' using service principal"
    echo ""
} > "${LOG_DIR}/${SCRIPT_NAME}-details.txt"

log_success "Task completed successfully"
exit 0
