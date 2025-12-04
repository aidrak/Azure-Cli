#!/bin/bash

################################################################################
# Task: Create AVD Host Pool
#
# Purpose: Create host pool for session host deployment
#
# Inputs (from config.env):
#   - RESOURCE_GROUP_NAME
#   - LOCATION
#   - HOST_POOL_NAME
#   - HOST_POOL_TYPE (Pooled or Personal)
#   - LOAD_BALANCER_TYPE
#   - MAX_SESSION_LIMIT
#
# Outputs:
#   - Host pool created
#   - Details saved to artifacts/
#
# Duration: 1-2 minutes
# Idempotent: Yes
################################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCRIPT_NAME="01-create-host-pool"

CONFIG_FILE="${PROJECT_ROOT}/04-host-pool-workspace/config.env"
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

log_section "Creating AVD Host Pool"

# Validate
if ! az account show &>/dev/null; then
    log_error "Not authenticated to Azure"
    exit 1
fi

if ! az group exists --name "$RESOURCE_GROUP_NAME" | grep -q "true"; then
    log_error "Resource group not found: $RESOURCE_GROUP_NAME"
    exit 1
fi

# Check if host pool already exists
if az desktopvirtualization hostpool show \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$HOST_POOL_NAME" &>/dev/null; then

    log_success "Host pool already exists: $HOST_POOL_NAME"
    exit 0
fi

# Create host pool
log_info "Creating host pool: $HOST_POOL_NAME"
log_info "  Type: $HOST_POOL_TYPE"
log_info "  Load Balancer: $LOAD_BALANCER_TYPE"
log_info "  Max Sessions: $MAX_SESSION_LIMIT"

if ! az desktopvirtualization hostpool create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$HOST_POOL_NAME" \
    --location "$LOCATION" \
    --host-pool-type "$HOST_POOL_TYPE" \
    --load-balancer-type "$LOAD_BALANCER_TYPE" \
    --max-session-limit "$MAX_SESSION_LIMIT" \
    --personal-desktop-assignment-type Automatic \
    --preferred-app-group-type Desktop \
    --output json >"${LOG_DIR}/${SCRIPT_NAME}-create.json" 2>&1; then

    log_error "Failed to create host pool"
    exit 1
fi

log_success "Host pool created: $HOST_POOL_NAME"

# Get host pool details
local hp_id
hp_id=$(az desktopvirtualization hostpool show \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$HOST_POOL_NAME" \
    --query id -o tsv)

# Save details
{
    echo "Host Pool Creation Details"
    echo "=========================="
    echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
    echo ""
    echo "Host Pool:"
    echo "  Name: $HOST_POOL_NAME"
    echo "  Resource Group: $RESOURCE_GROUP_NAME"
    echo "  Location: $LOCATION"
    echo "  ID: $hp_id"
    echo ""
    echo "Configuration:"
    echo "  Type: $HOST_POOL_TYPE"
    echo "  Load Balancer: $LOAD_BALANCER_TYPE"
    echo "  Max Sessions: $MAX_SESSION_LIMIT"
    echo ""
    echo "Next Steps:"
    echo "  1. Create application groups"
    echo "  2. Create workspace"
    echo "  3. Register session hosts to this pool"
    echo ""
} > "${LOG_DIR}/${SCRIPT_NAME}-details.txt"

log_success "Task completed successfully"
exit 0
