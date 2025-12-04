#!/bin/bash

# Unified logging functions for Bash deployment scripts
#
# Purpose: Provides consistent logging across all AVD deployment steps
# Usage: source ../common/functions/logging-functions.sh
#
# Functions:
#   log_info()    - Log informational message
#   log_success() - Log successful operation
#   log_error()   - Log error message
#   log_warning() - Log warning message
#   log_section() - Log section header
#   save_log()    - Save logs to timestamped file
#
# Colors used:
#   Green   (32m) - Success
#   Red     (31m) - Error
#   Yellow  (33m) - Warning
#   Cyan    (36m) - Header/Info
#   Gray    (37m) - Normal

# Set default log level if not provided
LOG_LEVEL="${LOG_LEVEL:-INFO}"
LOG_FILE="${LOG_FILE:-}"
SCRIPT_NAME="${SCRIPT_NAME:-$(basename "$0")}"

# Color codes
COLOR_GREEN="\033[32m"
COLOR_RED="\033[31m"
COLOR_YELLOW="\033[33m"
COLOR_CYAN="\033[36m"
COLOR_GRAY="\033[37m"
COLOR_RESET="\033[0m"

# ============================================================================
# Core Logging Functions
# ============================================================================

# Print timestamp in ISO 8601 format
_get_timestamp() {
    date -u "+%Y-%m-%dT%H:%M:%SZ"
}

# Initialize log file with header
_init_log_file() {
    if [[ -z "$LOG_FILE" ]]; then
        return
    fi

    # Create directory if needed
    local log_dir
    log_dir=$(dirname "$LOG_FILE")
    if [[ ! -d "$log_dir" ]]; then
        mkdir -p "$log_dir"
    fi

    # Write header
    {
        echo "================================================================================"
        echo "Deployment Log: $SCRIPT_NAME"
        echo "Started: $(_get_timestamp)"
        echo "================================================================================"
        echo ""
    } >> "$LOG_FILE"
}

# Write to log file (if configured)
_write_log() {
    if [[ -z "$LOG_FILE" ]]; then
        return
    fi
    echo "[$(_get_timestamp)] $1" >> "$LOG_FILE"
}

# Log informational message
log_info() {
    local message="$1"
    echo -e "${COLOR_CYAN}ℹ${COLOR_RESET} ${message}"
    _write_log "INFO: $message"
}

# Log successful operation
log_success() {
    local message="$1"
    echo -e "${COLOR_GREEN}✓${COLOR_RESET} ${message}"
    _write_log "SUCCESS: $message"
}

# Log error message
log_error() {
    local message="$1"
    echo -e "${COLOR_RED}✗${COLOR_RESET} ${message}" >&2
    _write_log "ERROR: $message"
}

# Log warning message
log_warning() {
    local message="$1"
    echo -e "${COLOR_YELLOW}⚠${COLOR_RESET} ${message}"
    _write_log "WARNING: $message"
}

# Log section header
log_section() {
    local message="$1"
    echo ""
    echo -e "${COLOR_CYAN}=== ${message} ===${COLOR_RESET}"
    echo ""
    _write_log "SECTION: $message"
}

# Log debug message (only if DEBUG mode enabled)
log_debug() {
    local message="$1"
    if [[ "${DEBUG:-0}" == "1" ]] || [[ "$LOG_LEVEL" == "DEBUG" ]]; then
        echo -e "${COLOR_GRAY}[DEBUG] ${message}${COLOR_RESET}"
        _write_log "DEBUG: $message"
    fi
}

# ============================================================================
# Log File Management
# ============================================================================

# Save logs to timestamped file
save_log() {
    local output_file="${1:-}"
    local log_dir="${2:-artifacts}"
    local timestamp

    timestamp=$(date +%Y%m%d_%H%M%S)

    # Create output directory if needed
    if [[ ! -d "$log_dir" ]]; then
        mkdir -p "$log_dir"
    fi

    # If no filename specified, use script name with timestamp
    if [[ -z "$output_file" ]]; then
        output_file="${log_dir}/${SCRIPT_NAME%.*}_${timestamp}.log"
    else
        output_file="${log_dir}/${output_file}_${timestamp}.log"
    fi

    # Set global log file for subsequent calls
    LOG_FILE="$output_file"
    _init_log_file

    log_success "Logging to: $output_file"
    echo "$output_file"
}

# Append to existing log
append_to_log() {
    local message="$1"
    local file="${2:-$LOG_FILE}"

    if [[ -z "$file" ]]; then
        log_error "No log file specified"
        return 1
    fi

    echo "[$(_get_timestamp)] $message" >> "$file"
}

# Get log file path
get_log_file() {
    echo "$LOG_FILE"
}

# ============================================================================
# Structured Output
# ============================================================================

# Print a key-value pair (useful for artifacts)
log_key_value() {
    local key="$1"
    local value="$2"
    printf "%-30s: %s\n" "$key" "$value"
    _write_log "  $key: $value"
}

# Start a data block (JSON, YAML, etc.)
log_data_block() {
    local label="$1"
    local format="${2:-}"
    echo ""
    echo -e "${COLOR_CYAN}--- ${label} ${format:+(${format})} ---${COLOR_RESET}"
    _write_log "DATA BLOCK: $label $format"
}

# End a data block
log_data_end() {
    echo -e "${COLOR_CYAN}---${COLOR_RESET}"
    echo ""
    _write_log "END DATA BLOCK"
}

# ============================================================================
# Status Tracking
# ============================================================================

# Initialize counters
OPERATIONS_ATTEMPTED=0
OPERATIONS_SUCCEEDED=0
OPERATIONS_FAILED=0

# Track operation attempt
track_operation() {
    ((OPERATIONS_ATTEMPTED++))
}

# Track operation success
track_success() {
    ((OPERATIONS_SUCCEEDED++))
}

# Track operation failure
track_failure() {
    ((OPERATIONS_FAILED++))
}

# Print operation summary
log_summary() {
    local section="${1:-Operations}"

    echo ""
    echo -e "${COLOR_CYAN}=== ${section} Summary ===${COLOR_RESET}"
    echo -e "${COLOR_GREEN}✓ Succeeded: ${OPERATIONS_SUCCEEDED}${COLOR_RESET}"

    if [[ $OPERATIONS_FAILED -gt 0 ]]; then
        echo -e "${COLOR_RED}✗ Failed: ${OPERATIONS_FAILED}${COLOR_RESET}"
    fi

    if [[ $OPERATIONS_ATTEMPTED -gt 0 ]]; then
        local success_rate=$((OPERATIONS_SUCCEEDED * 100 / OPERATIONS_ATTEMPTED))
        echo -e "${COLOR_CYAN}Success rate: ${success_rate}%${COLOR_RESET}"
    fi

    echo ""
}

# ============================================================================
# Error Handling Integration
# ============================================================================

# Log and exit on error
die() {
    local message="$1"
    local exit_code="${2:-1}"

    log_error "$message"
    log_error "Script failed. See log for details: $LOG_FILE"

    exit "$exit_code"
}

# Log and continue with warning
warn_continue() {
    local message="$1"
    log_warning "$message"
    log_warning "Continuing anyway..."
}

# ============================================================================
# Initialization
# ============================================================================

# Auto-initialize if ENABLE_LOGGING is set
if [[ "${ENABLE_LOGGING:-0}" == "1" ]]; then
    save_log
fi

# Export functions for use in subshells
export -f log_info
export -f log_success
export -f log_error
export -f log_warning
export -f log_section
export -f log_debug
export -f save_log
export -f append_to_log
export -f get_log_file
export -f log_key_value
export -f log_data_block
export -f log_data_end
export -f track_operation
export -f track_success
export -f track_failure
export -f log_summary
export -f die
export -f warn_continue
