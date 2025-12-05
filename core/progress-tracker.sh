#!/bin/bash
# ==============================================================================
# Progress Tracker - Real-Time Operation Monitoring
# ==============================================================================
#
# Purpose: Execute operations with real-time progress visibility and fail-fast
# Usage:
#   source core/progress-tracker.sh
#   track_operation "operation-id" "command" expected_duration timeout type
#
# Features:
#   - Real-time output streaming
#   - Progress marker parsing ([START], [PROGRESS], [VALIDATE], [SUCCESS], [ERROR])
#   - Timeout detection (2x expected duration)
#   - FAST vs WAIT operation types
#   - Checkpoint creation
#
# ==============================================================================

set -euo pipefail

# Project paths
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
ARTIFACTS_DIR="${PROJECT_ROOT}/artifacts"
LOGS_DIR="${ARTIFACTS_DIR}/logs"
OUTPUTS_DIR="${ARTIFACTS_DIR}/outputs"

# Ensure directories exist
mkdir -p "$LOGS_DIR" "$OUTPUTS_DIR"

# ==============================================================================
# Execute Operation with Progress Tracking
# ==============================================================================
track_operation() {
    local operation_id="$1"
    local command="$2"
    local expected_duration="${3:-60}"
    local timeout="${4:-120}"
    local operation_type="${5:-FAST}"

    local log_file="${LOGS_DIR}/${operation_id}_$(date +%Y%m%d_%H%M%S).log"
    local output_file="${OUTPUTS_DIR}/${operation_id}.json"
    local start_time=$(date +%s)

    echo ""
    echo "========================================================================"
    echo "  Operation: $operation_id"
    echo "========================================================================"
    echo "Expected Duration: ${expected_duration}s"
    echo "Timeout: ${timeout}s"
    echo "Type: $operation_type"
    echo "Log: $log_file"
    echo ""

    # Determine progress update frequency based on operation type
    local progress_interval
    if [[ "$operation_type" == "FAST" ]]; then
        progress_interval=10  # Update every 10s for fast operations
    else
        progress_interval=60  # Update every 60s for wait operations
    fi

    # Check if command is a multi-line bash script
    local script_file=""
    if [[ "$command" =~ ^#!/bin/bash || "$command" =~ $'\n' ]]; then
        # Write script to temp file and execute with bash
        script_file="${LOGS_DIR}/${operation_id}_$(date +%Y%m%d_%H%M%S).sh"
        echo "$command" > "$script_file"
        chmod +x "$script_file"
        echo "[*] Executing script: $script_file"

        # Execute script in background
        {
            bash "$script_file" 2>&1 | tee "$log_file"
        } &
    else
        # Execute command directly with eval
        {
            eval "$command" 2>&1 | tee "$log_file"
        } &
    fi

    local cmd_pid=$!

    echo "[*] Operation started (PID: $cmd_pid)"
    echo ""

    # Monitor progress
    local last_progress_time=$start_time
    local last_output_check=$start_time
    local has_started=false
    local has_error=false

    while kill -0 "$cmd_pid" 2>/dev/null; do
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))

        # Check for timeout
        if [[ $elapsed -gt $timeout ]]; then
            echo ""
            echo "[x] TIMEOUT: Operation exceeded ${timeout}s (${elapsed}s elapsed)"
            kill -9 "$cmd_pid" 2>/dev/null || true
            return 124  # Timeout exit code
        fi

        # Show elapsed time at progress intervals
        if [[ $((current_time - last_progress_time)) -ge $progress_interval ]]; then
            echo "[i] ${elapsed}s elapsed..."
            last_progress_time=$current_time
        fi

        # Check log file for markers every 2 seconds
        if [[ -f "$log_file" && $((current_time - last_output_check)) -ge 2 ]]; then
            # Check for [START] marker
            if ! $has_started && grep -q "\[START\]" "$log_file"; then
                has_started=true
                echo "[v] Operation started on remote system"
            fi

            # Check for [ERROR] marker
            if ! $has_error && grep -q "\[ERROR\]" "$log_file"; then
                has_error=true
                echo "[!] Error detected in operation output"
            fi

            last_output_check=$current_time
        fi

        sleep 2
    done

    # Get exit code
    wait "$cmd_pid"
    local exit_code=$?

    local end_time=$(date +%s)
    local total_duration=$((end_time - start_time))

    echo ""
    echo "========================================================================"
    echo "  Operation Complete"
    echo "========================================================================"
    echo "Duration: ${total_duration}s (expected: ${expected_duration}s)"
    echo "Exit Code: $exit_code"
    echo ""

    # Analyze results
    if [[ $exit_code -eq 0 ]]; then
        echo "[v] Operation completed successfully"

        # Check if [SUCCESS] marker present
        if [[ -f "$log_file" ]] && grep -q "\[SUCCESS\]" "$log_file"; then
            echo "[v] Success marker found in output"
        else
            echo "[!] WARNING: No [SUCCESS] marker found (operation may be incomplete)"
        fi

    else
        echo "[x] Operation failed (exit code: $exit_code)"

        # Show last 20 lines of log for context
        if [[ -f "$log_file" ]]; then
            echo ""
            echo "=== Last 20 lines of output ==="
            tail -n 20 "$log_file"
            echo "==============================="
        fi

        return $exit_code
    fi

    # Check for warnings
    if [[ $total_duration -gt $expected_duration ]]; then
        local overage=$((total_duration - expected_duration))
        echo "[!] WARNING: Operation took ${overage}s longer than expected"
        echo "[!] Consider updating expected duration in operation YAML"
    fi

    return 0
}

# ==============================================================================
# Parse Progress Markers from Log
# ==============================================================================
parse_progress_markers() {
    local log_file="$1"

    if [[ ! -f "$log_file" ]]; then
        echo "[x] ERROR: Log file not found: $log_file"
        return 1
    fi

    echo ""
    echo "=== Progress Markers ==="

    # Extract all markers with timestamps
    grep -E "\[(START|PROGRESS|VALIDATE|SUCCESS|ERROR)\]" "$log_file" || echo "(No markers found)"

    echo "========================"
    echo ""

    # Summary
    local start_count=$(grep -c "\[START\]" "$log_file" || echo "0")
    local progress_count=$(grep -c "\[PROGRESS\]" "$log_file" || echo "0")
    local validate_count=$(grep -c "\[VALIDATE\]" "$log_file" || echo "0")
    local success_count=$(grep -c "\[SUCCESS\]" "$log_file" || echo "0")
    local error_count=$(grep -c "\[ERROR\]" "$log_file" || echo "0")

    echo "Marker Summary:"
    echo "  [START]: $start_count"
    echo "  [PROGRESS]: $progress_count"
    echo "  [VALIDATE]: $validate_count"
    echo "  [SUCCESS]: $success_count"
    echo "  [ERROR]: $error_count"
    echo ""

    # Validation
    if [[ $start_count -eq 0 ]]; then
        echo "[!] WARNING: No [START] marker found"
    fi

    if [[ $success_count -eq 0 && $error_count -eq 0 ]]; then
        echo "[!] WARNING: No completion marker ([SUCCESS] or [ERROR]) found"
    fi

    return 0
}

# ==============================================================================
# Check Operation Health
# ==============================================================================
check_operation_health() {
    local log_file="$1"

    if [[ ! -f "$log_file" ]]; then
        echo "[x] ERROR: Log file not found: $log_file"
        return 1
    fi

    echo "[*] Checking operation health..."

    local issues=0

    # Check for [START] marker
    if ! grep -q "\[START\]" "$log_file"; then
        echo "[!] Issue: Missing [START] marker"
        ((issues++))
    fi

    # Check for completion marker
    if ! grep -q "\[SUCCESS\]" "$log_file" && ! grep -q "\[ERROR\]" "$log_file"; then
        echo "[!] Issue: Missing completion marker ([SUCCESS] or [ERROR])"
        ((issues++))
    fi

    # Check for errors
    if grep -q "\[ERROR\]" "$log_file"; then
        echo "[!] Issue: [ERROR] marker found in output"
        ((issues++))
    fi

    # Check for PowerShell errors
    if grep -qi "exception\|failed\|error:" "$log_file"; then
        echo "[!] Issue: Error keywords found in output"
        ((issues++))
    fi

    if [[ $issues -eq 0 ]]; then
        echo "[v] Operation health: GOOD"
        return 0
    else
        echo "[x] Operation health: ISSUES ($issues found)"
        return 1
    fi
}

# ==============================================================================
# Create Checkpoint
# ==============================================================================
create_checkpoint() {
    local operation_id="$1"
    local status="$2"  # completed, failed, timeout
    local duration="$3"
    local log_file="$4"

    local checkpoint_file="${ARTIFACTS_DIR}/checkpoint_${operation_id}.json"

    cat > "$checkpoint_file" <<EOF
{
  "operation_id": "$operation_id",
  "status": "$status",
  "duration_seconds": $duration,
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "log_file": "$log_file"
}
EOF

    echo "[v] Checkpoint created: $checkpoint_file"
}

# ==============================================================================
# Resume from Checkpoint
# ==============================================================================
resume_from_checkpoint() {
    local operation_id="$1"

    local checkpoint_file="${ARTIFACTS_DIR}/checkpoint_${operation_id}.json"

    if [[ ! -f "$checkpoint_file" ]]; then
        echo "[!] No checkpoint found for: $operation_id"
        return 1
    fi

    echo "[*] Found checkpoint: $checkpoint_file"

    local status=$(jq -r '.status' "$checkpoint_file")
    local duration=$(jq -r '.duration_seconds' "$checkpoint_file")
    local timestamp=$(jq -r '.timestamp' "$checkpoint_file")

    echo "  Status: $status"
    echo "  Duration: ${duration}s"
    echo "  Timestamp: $timestamp"

    if [[ "$status" == "completed" ]]; then
        echo "[v] Operation already completed, skipping"
        return 0
    else
        echo "[!] Operation incomplete, will retry"
        return 1
    fi
}

# ==============================================================================
# Export functions for use by other scripts
# ==============================================================================
export -f track_operation
export -f parse_progress_markers
export -f check_operation_health
export -f create_checkpoint
export -f resume_from_checkpoint
