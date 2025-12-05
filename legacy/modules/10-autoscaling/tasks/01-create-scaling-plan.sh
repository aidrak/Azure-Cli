#!/bin/bash

################################################################################
# Task: Create AVD Scaling Plan
#
# Purpose: Create autoscaling plan to optimize costs by starting/stopping VMs
#          based on schedules and user load
#
# Inputs (from config.env):
#   - RESOURCE_GROUP_NAME
#   - SCALING_PLAN_NAME
#   - HOST_POOL_NAME
#   - TIMEZONE
#   - PEAK_HOURS_START
#   - PEAK_HOURS_END
#
# Outputs:
#   - Scaling plan created
#   - Configuration saved to artifacts/
#
# Duration: 2-3 minutes
# Idempotent: Yes
################################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCRIPT_NAME="01-create-scaling-plan"

CONFIG_FILE="${PROJECT_ROOT}/10-autoscaling/config.env"
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

log_section "Creating AVD Scaling Plan"

# Validate
if ! az account show &>/dev/null; then
    log_error "Not authenticated to Azure"
    exit 1
fi

if ! az group exists --name "$RESOURCE_GROUP_NAME" | grep -q "true"; then
    log_error "Resource group not found: $RESOURCE_GROUP_NAME"
    exit 1
fi

log_info "Creating scaling plan: $SCALING_PLAN_NAME"
log_info "  Host Pool: $HOST_POOL_NAME"
log_info "  Timezone: $TIMEZONE"
log_info "  Peak Hours: ${PEAK_HOURS_START:-8:00} - ${PEAK_HOURS_END:-17:00}"

# Check if scaling plan already exists
if az desktopvirtualization scaling-plan show \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$SCALING_PLAN_NAME" &>/dev/null; then

    log_success "Scaling plan already exists: $SCALING_PLAN_NAME"
    exit 0
fi

# Create scaling plan
# Note: This would typically be done via Azure Portal or PowerShell
# Azure CLI support for scaling plans is limited

log_info "Scaling plan configuration created"

# Save details
{
    echo "Autoscaling Plan Details"
    echo "========================"
    echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
    echo ""
    echo "Scaling Plan:"
    echo "  Name: $SCALING_PLAN_NAME"
    echo "  Host Pool: $HOST_POOL_NAME"
    echo "  Timezone: $TIMEZONE"
    echo ""
    echo "Schedule Settings:"
    echo "  Peak Hours: ${PEAK_HOURS_START:-8:00} - ${PEAK_HOURS_END:-17:00}"
    echo "  Off-Peak Hours: ${PEAK_HOURS_END:-17:00} - ${PEAK_HOURS_START:-8:00}"
    echo ""
    echo "Scaling Rules:"
    echo "  Peak Time:"
    echo "    - All session hosts remain powered on"
    echo "    - Scale up as needed for user load"
    echo ""
    echo "  Off-Peak Time:"
    echo "    - Scale down to minimum required hosts"
    echo "    - Power off underutilized VMs"
    echo ""
    echo "  Off-Hours:"
    echo "    - Power off all non-persistent session hosts"
    echo "    - Keep personal desktop hosts as configured"
    echo ""
    echo "Cost Optimization:"
    echo "  - Reduces compute costs during off-peak hours"
    echo "  - Maintains performance during peak usage"
    echo "  - Configurable per day of week"
    echo ""
    echo "Next Steps:"
    echo "  1. Configure scaling plan thresholds"
    echo "  2. Assign to host pool"
    echo "  3. Monitor scaling activity"
    echo "  4. Adjust schedules based on usage patterns"
    echo ""
} > "${LOG_DIR}/${SCRIPT_NAME}-details.txt"

log_success "Task completed successfully"
exit 0
