#!/bin/bash
# ==============================================================================
# Logger - Structured JSON Logging
# ==============================================================================
#
# Purpose: Provide structured logging for operations and artifacts
# Usage:
#   source core/logger.sh
#   log_info "Message"
#   log_error "Error message"
#   log_operation_start "operation-id"
#   log_operation_complete "operation-id" duration exit_code
#
# ==============================================================================

set -euo pipefail

# Project paths
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
ARTIFACTS_DIR="${PROJECT_ROOT}/artifacts"
LOGS_DIR="${ARTIFACTS_DIR}/logs"

# Ensure log directory exists
mkdir -p "$LOGS_DIR"

# Log file for structured logs
STRUCTURED_LOG="${LOGS_DIR}/deployment_$(date +%Y%m%d).jsonl"

# ==============================================================================
# Log Levels
# ==============================================================================
LOG_LEVEL_DEBUG=0
LOG_LEVEL_INFO=1
LOG_LEVEL_WARN=2

CURRENT_LOG_LEVEL=${CURRENT_LOG_LEVEL:-$LOG_LEVEL_INFO}

# ==============================================================================
# Write Structured Log Entry
# ==============================================================================
log_structured() {
    local level="$1"
    local message="$2"
    local operation_id="${3:-}"
    local metadata="${4:-{}}"

    # Ensure metadata is valid JSON
    if [[ -z "$metadata" ]] || [[ "$metadata" == "null" ]]; then
        metadata="{}"
    fi

    local timestamp
    timestamp=$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)

    local log_entry
    log_entry=$(jq -cn \
        --arg ts "$timestamp" \
        --arg lvl "$level" \
        --arg msg "$message" \
        --arg op_id "$operation_id" \
        --argjson meta "$metadata" \
        '{
            timestamp: $ts,
            level: $lvl,
            message: $msg,
            operation_id: $op_id,
            metadata: $meta
        }' 2>/dev/null)

    # Only write if log entry was generated successfully
    if [[ -n "$log_entry" ]]; then
        echo "$log_entry" >> "$STRUCTURED_LOG"
    fi
}

# ==============================================================================
# Console + Structured Logging Functions
# ==============================================================================
log_debug() {
    local message="$1"
    local operation_id="${2:-}"

    if [[ $CURRENT_LOG_LEVEL -le $LOG_LEVEL_DEBUG ]]; then
        echo "[DEBUG] $message"
        log_structured "DEBUG" "$message" "$operation_id"
    fi
}

log_info() {
    local message="$1"
    local operation_id="${2:-}"

    if [[ $CURRENT_LOG_LEVEL -le $LOG_LEVEL_INFO ]]; then
        echo "[*] $message"
        log_structured "INFO" "$message" "$operation_id"
    fi
}

log_warn() {
    local message="$1"
    local operation_id="${2:-}"

    if [[ $CURRENT_LOG_LEVEL -le $LOG_LEVEL_WARN ]]; then
        echo "[!] WARNING: $message"
        log_structured "WARN" "$message" "$operation_id"
    fi
}

log_error() {
    local message="$1"
    local operation_id="${2:-}"
    local error_code="${3:-1}"

    echo "[x] ERROR: $message" >&2
    log_structured "ERROR" "$message" "$operation_id" "{\"error_code\": $error_code}"
}

log_success() {
    local message="$1"
    local operation_id="${2:-}"

    echo "[v] $message"
    log_structured "SUCCESS" "$message" "$operation_id"
}

# ==============================================================================
# Operation Lifecycle Logging
# ==============================================================================
log_operation_start() {
    local operation_id="$1"
    local operation_name="${2:-$operation_id}"
    local expected_duration="${3:-60}"

    local metadata
    metadata=$(jq -n \
        --arg name "$operation_name" \
        --argjson duration "$expected_duration" \
        '{
            operation_name: $name,
            expected_duration: $duration,
            start_time: now
        }')

    log_structured "OPERATION_START" "Starting operation: $operation_name" "$operation_id" "$metadata"
    echo ""
    echo "========================================================================"
    echo "  Operation: $operation_name"
    echo "  ID: $operation_id"
    echo "  Expected Duration: ${expected_duration}s"
    echo "========================================================================"
    echo ""
}

log_operation_progress() {
    local operation_id="$1"
    local progress_message="$2"
    local elapsed="${3:-0}"

    local metadata
    metadata=$(jq -n \
        --argjson elapsed "$elapsed" \
        '{
            elapsed_seconds: $elapsed
        }')

    log_structured "OPERATION_PROGRESS" "$progress_message" "$operation_id" "$metadata"
}

log_operation_complete() {
    local operation_id="$1"
    local duration="$2"
    local exit_code="${3:-0}"
    local expected_duration="${4:-60}"

    local status
    if [[ $exit_code -eq 0 ]]; then
        status="completed"
    elif [[ $exit_code -eq 124 ]]; then
        status="timeout"
    else
        status="failed"
    fi

    local metadata
    metadata=$(jq -n \
        --argjson duration "$duration" \
        --argjson expected "$expected_duration" \
        --argjson exit_code "$exit_code" \
        --arg status "$status" \
        '{
            duration_seconds: $duration,
            expected_duration: $expected,
            exit_code: $exit_code,
            status: $status,
            end_time: now
        }')

    log_structured "OPERATION_COMPLETE" "Operation $status: $operation_id" "$operation_id" "$metadata"

    echo ""
    echo "========================================================================"
    echo "  Operation Complete: $operation_id"
    echo "  Status: $status"
    echo "  Duration: ${duration}s (expected: ${expected_duration}s)"
    echo "  Exit Code: $exit_code"
    echo "========================================================================"
    echo ""
}

log_operation_error() {
    local operation_id="$1"
    local error_message="$2"
    local error_code="${3:-1}"
    local elapsed="${4:-0}"

    local metadata
    metadata=$(jq -n \
        --arg error "$error_message" \
        --argjson code "$error_code" \
        --argjson elapsed "$elapsed" \
        '{
            error_message: $error,
            error_code: $code,
            elapsed_seconds: $elapsed
        }')

    log_structured "OPERATION_ERROR" "Operation error: $error_message" "$operation_id" "$metadata"
}

# ==============================================================================
# Artifact Management
# ==============================================================================
log_artifact_created() {
    local artifact_type="$1"  # log, output, checkpoint, script
    local artifact_path="$2"
    local operation_id="${3:-}"

    local metadata
    metadata=$(jq -n \
        --arg type "$artifact_type" \
        --arg path "$artifact_path" \
        '{
            artifact_type: $type,
            artifact_path: $path,
            created_at: now
        }')

    log_structured "ARTIFACT_CREATED" "Created $artifact_type: $artifact_path" "$operation_id" "$metadata"
}

# ==============================================================================
# Query Structured Logs
# ==============================================================================
query_logs() {
    local operation_id="${1:-}"
    local level="${2:-}"

    if [[ ! -f "$STRUCTURED_LOG" ]]; then
        echo "[!] No structured log file found: $STRUCTURED_LOG"
        return 1
    fi

    echo "[*] Querying structured logs..."
    echo "  Log file: $STRUCTURED_LOG"
    echo "  Operation ID: ${operation_id:-all}"
    echo "  Level: ${level:-all}"
    echo ""

    # Build jq filter
    local filter="."

    if [[ -n "$operation_id" ]]; then
        filter="$filter | select(.operation_id == \"$operation_id\")"
    fi

    if [[ -n "$level" ]]; then
        filter="$filter | select(.level == \"$level\")"
    fi

    # Execute query
    jq -r "$filter" "$STRUCTURED_LOG" 2>/dev/null || echo "(No matching logs found)"
}

get_operation_summary() {
    local operation_id="$1"

    if [[ ! -f "$STRUCTURED_LOG" ]]; then
        echo "[!] No structured log file found"
        return 1
    fi

    echo "[*] Operation Summary: $operation_id"
    echo ""

    # Get start and end entries
    local start_entry
    start_entry=$(jq -r "select(.operation_id == \"$operation_id\" and .level == \"OPERATION_START\")" "$STRUCTURED_LOG" 2>/dev/null | head -n 1)
    local end_entry
    end_entry=$(jq -r "select(.operation_id == \"$operation_id\" and .level == \"OPERATION_COMPLETE\")" "$STRUCTURED_LOG" 2>/dev/null | head -n 1)

    if [[ -z "$start_entry" ]]; then
        echo "[!] No start entry found for operation: $operation_id"
        return 1
    fi

    echo "Start Time: $(echo "$start_entry" | jq -r '.timestamp')"
    echo "Operation Name: $(echo "$start_entry" | jq -r '.metadata.operation_name')"
    echo "Expected Duration: $(echo "$start_entry" | jq -r '.metadata.expected_duration')s"
    echo ""

    if [[ -n "$end_entry" ]]; then
        echo "End Time: $(echo "$end_entry" | jq -r '.timestamp')"
        echo "Status: $(echo "$end_entry" | jq -r '.metadata.status')"
        echo "Actual Duration: $(echo "$end_entry" | jq -r '.metadata.duration_seconds')s"
        echo "Exit Code: $(echo "$end_entry" | jq -r '.metadata.exit_code')"
    else
        echo "[!] Operation not yet complete"
    fi

    echo ""
}

# ==============================================================================
# Export functions
# ==============================================================================
export -f log_structured
export -f log_debug log_info log_warn log_error log_success
export -f log_operation_start log_operation_progress log_operation_complete log_operation_error
export -f log_artifact_created
export -f query_logs get_operation_summary
