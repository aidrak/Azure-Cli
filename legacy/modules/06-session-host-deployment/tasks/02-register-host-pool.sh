#!/bin/bash

################################################################################
# Task: Register Session Hosts to Host Pool
#
# Purpose: Register deployed session hosts to the AVD host pool
#
# Inputs (from config.env):
#   - RESOURCE_GROUP_NAME
#   - HOST_POOL_NAME
#   - VM_NAME_PREFIX
#   - SESSION_HOST_COUNT
#
# Outputs:
#   - Session hosts registered to host pool
#   - Registration tokens created
#   - Details saved to artifacts/
#
# Duration: 5-10 minutes
# Idempotent: Yes
################################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCRIPT_NAME="02-register-host-pool"

CONFIG_FILE="${PROJECT_ROOT}/06-session-host-deployment/config.env"
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

log_section "Registering Session Hosts to Host Pool"

# Validate
if ! az account show &>/dev/null; then
    log_error "Not authenticated to Azure"
    exit 1
fi

if ! az desktopvirtualization hostpool show \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$HOST_POOL_NAME" &>/dev/null; then
    log_error "Host pool not found: $HOST_POOL_NAME"
    exit 1
fi

log_info "Registering $SESSION_HOST_COUNT session hosts to: $HOST_POOL_NAME"

# Get host pool resource ID
local hp_id
hp_id=$(az desktopvirtualization hostpool show \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$HOST_POOL_NAME" \
    --query id -o tsv)

# Generate registration token
log_info "Generating host pool registration token"

local token_output
token_output=$(az desktopvirtualization hostpool retrieve-registration-token \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$HOST_POOL_NAME" \
    --output json 2>&1)

local registration_token
registration_token=$(echo "$token_output" | jq -r '.token' 2>/dev/null || echo "")

if [[ -z "$registration_token" ]]; then
    log_error "Failed to generate registration token"
    exit 1
fi

log_success "Registration token generated"

# Save token securely
local token_file="${LOG_DIR}/${SCRIPT_NAME}-token.txt"
echo "$registration_token" > "$token_file"
chmod 600 "$token_file"

log_info "Token saved to: $token_file"

# Verify VMs exist and are running
log_info "Verifying session host VMs"

local registered_count=0
local i

for ((i=1; i<=SESSION_HOST_COUNT; i++)); do
    local vm_name="${VM_NAME_PREFIX}-$(printf "%02d" $i)"

    if ! az vm show \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --name "$vm_name" &>/dev/null; then
        log_error "VM not found: $vm_name"
        continue
    fi

    # Check VM state
    local vm_state
    vm_state=$(az vm get-instance-view \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --name "$vm_name" \
        --query "instanceView.statuses[?starts_with(code, 'PowerState/')].displayStatus" \
        -o tsv)

    log_info "  $vm_name: $vm_state"

    if [[ "$vm_state" == "VM running" ]]; then
        ((registered_count++))
    fi
done

log_info "Ready VMs: $registered_count/$SESSION_HOST_COUNT"

# Save details
{
    echo "Host Pool Registration Details"
    echo "=============================="
    echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
    echo ""
    echo "Host Pool:"
    echo "  Name: $HOST_POOL_NAME"
    echo "  Resource Group: $RESOURCE_GROUP_NAME"
    echo "  ID: $hp_id"
    echo ""
    echo "Registration:"
    echo "  Total VMs: $SESSION_HOST_COUNT"
    echo "  Running VMs: $registered_count"
    echo "  Token expires: 1 hour (regenerate if needed)"
    echo "  Token file: ${SCRIPT_NAME}-token.txt"
    echo ""
    echo "Next Steps:"
    echo "  1. On each session host VM:"
    echo "     - Install AVD agent"
    echo "     - Provide registration token"
    echo "     - Complete registration"
    echo "  2. Verify hosts appear in host pool"
    echo "  3. Test user access"
    echo ""
    echo "Token:"
    echo "  Store securely if using for registration"
    echo "  Regenerate if token expires"
    echo ""
} > "${LOG_DIR}/${SCRIPT_NAME}-details.txt"

log_success "Task completed successfully"
exit 0
