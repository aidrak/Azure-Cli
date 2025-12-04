#!/bin/bash

################################################################################
# TASK TEMPLATE: [Replace with task name]
#
# Purpose: [Explain what this task does in one sentence]
#
# Usage:
#   ./[task-name].sh
#
# Prerequisites:
#   - Azure CLI installed and authenticated
#   - config.env properly configured
#   - [List any other prerequisites]
#
# Environment Variables (from config.env):
#   - RESOURCE_GROUP_NAME       Resource group for deployment
#   - LOCATION                  Azure region
#   - [Other required variables]
#
# Outputs:
#   - Logs saved to: artifacts/[task-name]_TIMESTAMP.log
#   - Details saved to: artifacts/[task-name]-details.txt
#
# Exit Codes:
#   0 - Success
#   1 - Failure
#
# Author: Generated from task template
# Version: 1.0
################################################################################

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

# Script metadata
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_NAME="$(basename "$0")"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Load configuration
CONFIG_FILE="${PROJECT_ROOT}/config.env"
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "ERROR: Configuration file not found: $CONFIG_FILE"
    exit 1
fi

# Source centralized config and local config
source "$CONFIG_FILE" || { echo "ERROR: Failed to load config"; exit 1; }

# Initialize logging
ENABLE_LOGGING=1
LOG_DIR="${PROJECT_ROOT}/artifacts"
mkdir -p "$LOG_DIR"

# ============================================================================
# LOAD FUNCTION LIBRARIES
# ============================================================================

# Load logging functions
LOGGING_FUNCS="${PROJECT_ROOT}/common/functions/logging-functions.sh"
if [[ -f "$LOGGING_FUNCS" ]]; then
    source "$LOGGING_FUNCS"
else
    # Fallback logging if functions not available
    log_info() { echo "ℹ $*"; }
    log_success() { echo "✓ $*"; }
    log_error() { echo "✗ $*" >&2; }
    log_warning() { echo "⚠ $*"; }
    log_section() { echo ""; echo "=== $* ==="; echo ""; }
    save_log() { echo "$LOG_DIR/${SCRIPT_NAME%.*}_$(date +%Y%m%d_%H%M%S).log"; }
fi

# Load additional function libraries as needed
# CONFIG_FUNCS="${PROJECT_ROOT}/common/functions/config-functions.sh"
# [[ -f "$CONFIG_FUNCS" ]] && source "$CONFIG_FUNCS"
#
# AZURE_FUNCS="${PROJECT_ROOT}/common/functions/azure-functions.sh"
# [[ -f "$AZURE_FUNCS" ]] && source "$AZURE_FUNCS"

# ============================================================================
# INITIALIZE LOGGING
# ============================================================================

LOG_FILE=$(save_log "${SCRIPT_NAME%.*}" "$LOG_DIR")

log_section "Starting: $SCRIPT_NAME"
log_info "Execution started at $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
log_info "Log file: $LOG_FILE"

# ============================================================================
# VALIDATION
# ============================================================================

# Validate prerequisites
validate_prerequisites() {
    log_section "Validating Prerequisites"

    # Check Azure CLI
    if ! command -v az &>/dev/null; then
        log_error "Azure CLI not installed"
        return 1
    fi
    log_success "Azure CLI installed"

    # Check Azure authentication
    if ! az account show &>/dev/null; then
        log_error "Not authenticated to Azure. Run: az login"
        return 1
    fi
    log_success "Azure authentication verified"

    # Validate required configuration variables
    local required_vars=(
        "RESOURCE_GROUP_NAME"
        "LOCATION"
        # Add other required variables here
    )

    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            log_error "Required variable not set: $var"
            return 1
        fi
        log_info "$var = ${!var}"
    done

    log_success "All prerequisites validated"
    return 0
}

# ============================================================================
# MAIN TASK LOGIC
# ============================================================================

# TODO: Replace with actual task logic
main_task() {
    log_section "Main Task: [Replace with task name]"

    # Step 1: Describe what this step does
    log_info "Step 1: [Replace with actual step]"
    # TODO: Implement step 1 logic
    # if ! [command]; then
    #     log_error "Step 1 failed"
    #     return 1
    # fi
    # log_success "Step 1 completed"

    # Step 2: Describe what this step does
    log_info "Step 2: [Replace with actual step]"
    # TODO: Implement step 2 logic
    # if ! [command]; then
    #     log_error "Step 2 failed"
    #     return 1
    # fi
    # log_success "Step 2 completed"

    log_success "Main task completed"
    return 0
}

# ============================================================================
# SAVE ARTIFACTS
# ============================================================================

save_artifacts() {
    log_section "Saving Artifacts"

    local details_file="${LOG_DIR}/${SCRIPT_NAME%.*}-details.txt"

    {
        echo "Task Details: $SCRIPT_NAME"
        echo "Executed: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
        echo "Status: Success"
        echo ""
        echo "Configuration:"
        echo "  Resource Group: $RESOURCE_GROUP_NAME"
        echo "  Location: $LOCATION"
        echo ""
        echo "Log file: $LOG_FILE"
        # TODO: Add task-specific outputs here
        echo ""
        echo "Outputs:"
        echo "  [Add outputs here]"
    } > "$details_file"

    log_success "Details saved to: $details_file"
}

# ============================================================================
# ERROR HANDLING
# ============================================================================

trap 'handle_error' ERR

handle_error() {
    local line_number=$1
    log_error "Script failed at line $line_number"
    log_error "See full log: $LOG_FILE"
    exit 1
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    log_section "Execution Plan"
    log_info "1. Validate prerequisites"
    log_info "2. Execute main task"
    log_info "3. Save artifacts"

    # Validate
    if ! validate_prerequisites; then
        log_error "Prerequisites validation failed"
        exit 1
    fi

    # Execute main task
    if ! main_task; then
        log_error "Main task failed"
        exit 1
    fi

    # Save artifacts
    if ! save_artifacts; then
        log_error "Failed to save artifacts"
        exit 1
    fi

    # Success
    log_section "Completion"
    log_success "Task completed successfully"
    log_info "Execution completed at $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
    log_info "Log file: $LOG_FILE"

    return 0
}

# Run main function
main "$@"
exit $?
