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
#   - Timeout detection
#   - Operation types: FAST, WAIT, HEARTBEAT
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
# Execute Asynchronous Heartbeat Operation
# ==============================================================================
track_heartbeat_operation() {
    local operation_id="$1"
    local command="$2"
    local timeout="$3"
    local log_file="$4"
    local start_time
    start_time=$(date +%s)

    # Execute the command (az vm run-command create)
    # The output of this command is JSON containing the command ID
    local create_output_file="${OUTPUTS_DIR}/${operation_id}_create.json"
    if ! eval "$command" > "$create_output_file"; then
        log_error "Failed to create az vm run-command for $operation_id." "progress-tracker"
        cat "$create_output_file" >> "$log_file"
        return 1
    fi

    local run_command_id
    run_command_id=$(jq -r '.runCommandName' "$create_output_file")
    if [[ -z "$run_command_id" || "$run_command_id" == "null" ]]; then
        log_error "Could not get runCommandName from 'az vm run-command create' output." "progress-tracker"
        cat "$create_output_file" >> "$log_file"
        return 1
    fi

    log_info "Started async operation with command ID: $run_command_id" "progress-tracker"
    echo "[*] Azure Run Command ID: $run_command_id" >> "$log_file"

    local last_progress_time=$start_time
    local progress_interval=60 # Check every 60 seconds
    local last_heartbeat_check_time=$start_time
    local heartbeat_check_interval=180 # Check heartbeat file every 3 minutes
    local heartbeat_stale_threshold=300 # 5 minutes

    while true; do
        local current_time
        current_time=$(date +%s)
        local elapsed=$((current_time - start_time))

        # Check for overall timeout
        if [[ $elapsed -gt $timeout ]]; then
            log_error "TIMEOUT: Operation exceeded ${timeout}s" "progress-tracker"
            # Attempt to cancel the command on the VM
            az vm run-command cancel --resource-group "{{AZURE_RESOURCE_GROUP}}" \
              --name "{{GOLDEN_IMAGE_TEMP_VM_NAME}}" --run-command-name "$run_command_id"
            return 124
        fi

        # --- Tier 1: Check Azure Run Command Status ---
        local status_output_file="${OUTPUTS_DIR}/${operation_id}_status.json"
        az vm run-command show --resource-group "{{AZURE_RESOURCE_GROUP}}" \
          --name "{{GOLDEN_IMAGE_TEMP_VM_NAME}}" --run-command-name "$run_command_id" \
          --instance-view --output json > "$status_output_file"

        local provision_state
        provision_state=$(jq -r '.instanceView.executionState' "$status_output_file")
        local command_stdout
        command_stdout=$(jq -r '.instanceView.output' "$status_output_file")

        # Append stdout to main log file
        echo "$command_stdout" > "${log_file}.latest"
        # This is a basic way to append; more robust solutions could avoid duplicates
        # For now, we just overwrite and show the latest state.
        
        case "$provision_state" in
            Succeeded)
                log_success "Azure Run Command Succeeded." "progress-tracker"
                # Final output capture
                echo "$command_stdout" > "$log_file"
                return 0
                ;;
            Failed)
                log_error "Azure Run Command Failed." "progress-tracker"
                echo "$command_stdout" > "$log_file"
                return 1
                ;;
            Running)
                # It's running, continue to Tier 2 check
                ;;
            *)
                log_error "Unknown Azure Run Command state: $provision_state" "progress-tracker"
                echo "$command_stdout" > "$log_file"
                return 1
                ;;
        esac

        # --- Tier 2: Check In-VM Heartbeat ---
        if [[ $((current_time - last_heartbeat_check_time)) -ge $heartbeat_check_interval ]]; then
            log_info "Checking in-VM heartbeats..." "progress-tracker"
            last_heartbeat_check_time=$current_time
            
            # This is a conceptual implementation. We need a way to list and check heartbeats.
            # We'll assume the script inside the VM manages multiple heartbeats and if any is stale, it will exit.
            # A simpler check here is to see if the main log has recent "[MONITOR]" messages.
            if grep -q "\[MONITOR\]" "${log_file}.latest"; then
                local last_monitor_line
                last_monitor_line=$(grep "\[MONITOR\]" "${log_file}.latest" | tail -1)
                log_info "Latest monitor line: $last_monitor_line" "progress-tracker"
            else
                log_warn "No '[MONITOR]' lines found in latest output." "progress-tracker"
            fi
        fi

        # Show elapsed time at progress intervals
        if [[ $((current_time - last_progress_time)) -ge $progress_interval ]]; then
            echo "[i] ${elapsed}s elapsed... (Azure status: $provision_state)"
            last_progress_time=$current_time
        fi

        sleep 30
    done
}


# ==============================================================================
# Execute Operation with Progress Tracking
# ==============================================================================
track_operation() {
    local operation_id="$1"
    local command="$2"
    local expected_duration="${3:-60}"
    local timeout="${4:-120}"
    local operation_type="${5:-FAST}"

    local log_file
    log_file="${LOGS_DIR}/${operation_id}_$(date +%Y%m%d_%H%M%S).log"
    local start_time
    start_time=$(date +%s)

    echo ""
    echo "========================================================================"
    echo "  Operation: $operation_id"
    echo "========================================================================"
    echo "Expected Duration: ${expected_duration}s"
    echo "Timeout: ${timeout}s"
    echo "Type: $operation_type"
    echo "Log: $log_file"
    echo ""
    
    # Handle HEARTBEAT type separately
    if [[ "$operation_type" == "HEARTBEAT" ]]; then
        track_heartbeat_operation "$operation_id" "$command" "$timeout" "$log_file"
        local exit_code=$?
        # Post-processing for heartbeat would go here
        local end_time
        end_time=$(date +%s)
        local total_duration=$((end_time - start_time))

        echo ""
        echo "========================================================================"
        echo "  Operation Complete"
        echo "========================================================================"
        echo "Duration: ${total_duration}s (expected: ${expected_duration}s)"
        echo "Exit Code: $exit_code"
        echo ""
        return $exit_code
    fi

    # --- Existing logic for FAST and WAIT types ---

    local progress_interval
    if [[ "$operation_type" == "FAST" ]]; then
        progress_interval=10
    else
        progress_interval=60
    fi

    local script_file=""
    if [[ "$command" =~ ^#!/bin/bash || "$command" =~ $'
' ]]; then
        script_file="${LOGS_DIR}/${operation_id}_$(date +%Y%m%d_%H%M%S).sh"
        echo "$command" > "$script_file"
        chmod +x "$script_file"
        echo "[*] Executing script: $script_file"
        { bash "$script_file" 2>&1 | tee "$log_file"; } &
    else
        { eval "$command" 2>&1 | tee "$log_file"; } &
    fi

    local cmd_pid=$!
    echo "[*] Operation started (PID: $cmd_pid)"
    echo ""

    local last_progress_time=$start_time
    while kill -0 "$cmd_pid" 2>/dev/null; do
        local current_time
        current_time=$(date +%s)
        local elapsed=$((current_time - start_time))

        if [[ $elapsed -gt $timeout ]]; then
            echo ""
            echo "[x] TIMEOUT: Operation exceeded ${timeout}s (${elapsed}s elapsed)"
            kill -9 "$cmd_pid" 2>/dev/null || true
            return 124
        fi

        if [[ $((current_time - last_progress_time)) -ge $progress_interval ]]; then
            echo "[i] ${elapsed}s elapsed..."
            last_progress_time=$current_time
        fi
        sleep 2
    done

    wait "$cmd_pid"
    local exit_code=$?
    local end_time
    end_time=$(date +%s)
    local total_duration=$((end_time - start_time))

    echo ""
    echo "========================================================================"
    echo "  Operation Complete"
    echo "========================================================================"
    echo "Duration: ${total_duration}s (expected: ${expected_duration}s)"
    echo "Exit Code: $exit_code"
    echo ""

    if [[ $exit_code -eq 0 ]]; then
        echo "[v] Operation completed successfully"
    else
        echo "[x] Operation failed (exit code: $exit_code)"
        if [[ -f "$log_file" ]]; then
            echo ""
            echo "=== Last 20 lines of output ==="
            tail -n 20 "$log_file"
            echo "==============================="
        fi
        return $exit_code
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
    grep -E "\[(START|PROGRESS|VALIDATE|SUCCESS|ERROR|MONITOR)\]" "$log_file" || echo "(No markers found)"
    echo "========================"
}