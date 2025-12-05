#!/bin/bash
# ==============================================================================
# Main Engine - Orchestrates Module and Operation Execution
# ==============================================================================
#
# Purpose: Main entry point for executing modules and operations
# Usage:
#   ./core/engine.sh run <module> [operation]
#   ./core/engine.sh resume
#   ./core/engine.sh status
#   ./core/engine.sh list
#
# Examples:
#   ./core/engine.sh run 05-golden-image                    # Run entire module
#   ./core/engine.sh run 05-golden-image 02-install-fslogix # Run single operation
#   ./core/engine.sh resume                                 # Resume from failure
#   ./core/engine.sh status                                 # Show current state
#   ./core/engine.sh list                                   # List all modules/operations
#
# ==============================================================================

set -euo pipefail

# Project paths
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PROJECT_ROOT

STATE_FILE="${PROJECT_ROOT}/state.json"
MODULES_DIR="${PROJECT_ROOT}/modules"

# Source core components
source "${PROJECT_ROOT}/core/config-manager.sh"
source "${PROJECT_ROOT}/core/template-engine.sh"
source "${PROJECT_ROOT}/core/progress-tracker.sh"
source "${PROJECT_ROOT}/core/error-handler.sh"
source "${PROJECT_ROOT}/core/logger.sh"

# ==============================================================================
# Initialize State File
# ==============================================================================
init_state() {
    if [[ ! -f "$STATE_FILE" ]]; then
        log_info "Initializing state file" "engine"
        cat > "$STATE_FILE" <<EOF
{
  "version": "1.0",
  "started_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "current_module": null,
  "current_operation": null,
  "status": "initialized",
  "modules": {},
  "operations": {}
}
EOF
    fi
}

# ==============================================================================
# Update State
# ==============================================================================
update_state() {
    local field="$1"
    local value="$2"

    jq --arg field "$field" --arg value "$value" \
       '.[$field] = $value | .updated_at = (now | strftime("%Y-%m-%dT%H:%M:%SZ"))' \
       "$STATE_FILE" > "${STATE_FILE}.tmp"

    mv "${STATE_FILE}.tmp" "$STATE_FILE"
}

update_operation_state() {
    local operation_id="$1"
    local status="$2"
    local duration="${3:-0}"

    jq --arg op_id "$operation_id" \
       --arg status "$status" \
       --arg duration "$duration" \
       --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
       '.operations[$op_id] = {
          "status": $status,
          "duration": ($duration | tonumber),
          "timestamp": $timestamp
        }' \
       "$STATE_FILE" > "${STATE_FILE}.tmp"

    mv "${STATE_FILE}.tmp" "$STATE_FILE"
}

update_module_state() {
    local module_id="$1"
    local status="$2"

    jq --arg mod_id "$module_id" \
       --arg status "$status" \
       --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
       '.modules[$mod_id] = {
          "status": $status,
          "timestamp": $timestamp
        }' \
       "$STATE_FILE" > "${STATE_FILE}.tmp"

    mv "${STATE_FILE}.tmp" "$STATE_FILE"
}

# ==============================================================================
# Get Module Operations
# ==============================================================================
get_module_operations() {
    local module_dir="$1"
    local module_yaml="${module_dir}/module.yaml"

    if [[ ! -f "$module_yaml" ]]; then
        log_error "Module definition not found: $module_yaml" "engine"
        return 1
    fi

    # Get list of operation IDs from module.yaml
    yq e '.module.operations[].id' "$module_yaml"
}

# ==============================================================================
# Find Operation YAML File
# ==============================================================================
find_operation_yaml() {
    local module_dir="$1"
    local operation_id="$2"

    # Search for operation YAML in operations directory
    local operations_dir="${module_dir}/operations"

    if [[ ! -d "$operations_dir" ]]; then
        log_error "Operations directory not found: $operations_dir" "engine"
        return 1
    fi

    # Find YAML file that matches the operation ID
    local yaml_file
    for file in "${operations_dir}"/*.yaml; do
        if [[ -f "$file" ]]; then
            local op_id
            op_id=$(yq e '.operation.id' "$file")
            if [[ "$op_id" == "$operation_id" ]]; then
                echo "$file"
                return 0
            fi
        fi
    done

    log_error "Operation YAML not found for: $operation_id" "engine"
    return 1
}

# ==============================================================================
# Execute Single Operation
# ==============================================================================
execute_single_operation() {
    local module_dir="$1"
    local operation_id="$2"

    log_info "Executing operation: $operation_id" "engine"

    # Find operation YAML
    local yaml_file
    yaml_file=$(find_operation_yaml "$module_dir" "$operation_id") || return 1

    log_info "Found operation file: $yaml_file" "engine"

    # Parse operation to get metadata
    parse_operation_yaml "$yaml_file" || return 1

    # Update state
    update_state "current_operation" "$operation_id"
    update_state "status" "running"

    # Validate prerequisites
    log_info "Validating prerequisites..." "engine"
    if ! validate_prerequisites "$yaml_file"; then
        log_error "Prerequisites not met for: $operation_id" "engine"
        update_operation_state "$operation_id" "blocked" 0
        return 1
    fi

    # Render executable command
    log_info "Rendering command template..." "engine"
    local command
    command=$(render_command "$yaml_file") || return 1

    # Execute with progress tracking
    log_operation_start "$operation_id" "$OPERATION_NAME" "$OPERATION_DURATION_EXPECTED"

    local start_time
    start_time=$(date +%s)

    if track_operation \
        "$operation_id" \
        "$command" \
        "$OPERATION_DURATION_EXPECTED" \
        "$OPERATION_DURATION_TIMEOUT" \
        "$OPERATION_DURATION_TYPE"; then

        local end_time
        end_time=$(date +%s)
        local duration=$((end_time - start_time))

        log_operation_complete "$operation_id" "$duration" "0" "$OPERATION_DURATION_EXPECTED"
        update_operation_state "$operation_id" "completed" "$duration"
        reset_retry_counter "$operation_id"

        # Create checkpoint
        local log_file
        log_file=$(find "$LOGS_DIR" -name "${operation_id}_*.log" -printf '%T@ %p\n' | sort -nr | head -n1 | cut -d' ' -f2-)
        create_checkpoint "$operation_id" "completed" "$duration" "$log_file"

        return 0
    else
        local exit_code=$?
        local end_time
        end_time=$(date +%s)
        local duration=$((end_time - start_time))

        log_operation_error "$operation_id" "Operation failed" "$exit_code" "$duration"
        update_operation_state "$operation_id" "failed" "$duration"

        # Find log file for error analysis
        local log_file
        log_file=$(find "$LOGS_DIR" -name "${operation_id}_*.log" -printf '%T@ %p\n' | sort -nr | head -n1 | cut -d' ' -f2-)

        if [[ -n "$log_file" ]]; then
            create_checkpoint "$operation_id" "failed" "$duration" "$log_file"

            # Trigger error handler
            echo ""
            echo "========================================================================"
            echo "  Error Handler"
            echo "========================================================================"
            handle_operation_error "$operation_id" "$log_file" "$exit_code" "$yaml_file" "false"
        fi

        return $exit_code
    fi
}

# ==============================================================================
# Execute Operations in Parallel Group
# ==============================================================================
execute_parallel_group() {
    local module_dir="$1"
    shift
    local operations=("$@")
    local pids=()
    local results=()
    local op_count=${#operations[@]}

    echo ""
    echo "========================================================================"
    echo "  Parallel Group: ${op_count} operations"
    echo "========================================================================"
    for op_id in "${operations[@]}"; do
        echo "  - $op_id"
    done
    echo ""

    # Launch all operations in background
    for operation_id in "${operations[@]}"; do
        (
            execute_single_operation "$module_dir" "$operation_id"
            exit $?
        ) &
        pids+=("$!")
        echo "[*] Started $operation_id (PID: ${pids[-1]})"
    done

    echo ""
    echo "[*] Waiting for ${op_count} parallel operations to complete..."
    echo ""

    # Wait for all operations and collect results
    local idx=0
    local failed=0
    for pid in "${pids[@]}"; do
        wait "$pid"
        local exit_code=$?
        results+=("$exit_code")

        if [[ $exit_code -ne 0 ]]; then
            echo "[x] Operation ${operations[$idx]} failed (exit code: $exit_code)"
            failed=1
        else
            echo "[v] Operation ${operations[$idx]} completed successfully"
        fi
        idx=$((idx + 1))
    done

    echo ""
    if [[ $failed -eq 1 ]]; then
        echo "[x] Parallel group failed - one or more operations failed"
        return 1
    else
        echo "[v] All parallel operations completed successfully"
        return 0
    fi
}

# ==============================================================================
# Execute Module
# ==============================================================================
execute_module() {
    local module_name="$1"
    local module_dir="${MODULES_DIR}/${module_name}"

    if [[ ! -d "$module_dir" ]]; then
        log_error "Module directory not found: $module_dir" "engine"
        return 1
    fi

    log_info "Executing module: $module_name" "engine"

    # Update state
    update_state "current_module" "$module_name"
    update_module_state "$module_name" "running"

    # Get operations list with parallel groups
    local module_yaml="${module_dir}/module.yaml"
    local total_ops
    total_ops=$(yq e '.module.operations | length' "$module_yaml")
    local current_op=0

    echo ""
    echo "========================================================================"
    echo "  Module: $module_name"
    echo "========================================================================"
    echo "Operations: $total_ops"
    echo ""

    # Group operations by parallel_group
    # Get list of unique parallel groups (empty string for operations without group)
    local groups
    groups=$(yq e '.module.operations[] | .parallel_group // "seq_" + (.id | sub("^.*-", ""))' "$module_yaml" | sort -u)

    # Execute each group
    while IFS= read -r group_id; do
        # Get operations in this group
        local group_ops=()
        if [[ "$group_id" == seq_* ]]; then
            # Sequential operation (no parallel_group defined)
            local op_id="${group_id#seq_}"
            # Find the actual operation ID
            op_id=$(yq e ".module.operations[] | select(.parallel_group == null) | select(.id | test(\"${op_id}$\")) | .id" "$module_yaml")
            group_ops=("$op_id")
        else
            # Parallel group - get all operations with this group number
            while IFS= read -r op_id; do
                [[ -n "$op_id" ]] && group_ops+=("$op_id")
            done < <(yq e ".module.operations[] | select(.parallel_group == ${group_id}) | .id" "$module_yaml")
        fi

        # Skip if no operations in group
        [[ ${#group_ops[@]} -eq 0 ]] && continue

        current_op=$((current_op + ${#group_ops[@]}))

        echo ""
        echo "========================================================================"
        echo "  Operations $((current_op - ${#group_ops[@]} + 1)) to $current_op of $total_ops"
        if [[ ${#group_ops[@]} -gt 1 ]]; then
            echo "  Parallel Group: $group_id"
        fi
        echo "========================================================================"
        echo ""

        # Execute operations in parallel if more than one, otherwise sequential
        if [[ ${#group_ops[@]} -gt 1 ]]; then
            if ! execute_parallel_group "$module_dir" "${group_ops[@]}"; then
                log_error "Module failed at parallel group: $group_id" "engine"
                update_module_state "$module_name" "failed"
                update_state "status" "failed"
                return 1
            fi
        else
            if ! execute_single_operation "$module_dir" "${group_ops[0]}"; then
                log_error "Module failed at operation: ${group_ops[0]}" "engine"
                update_module_state "$module_name" "failed"
                update_state "status" "failed"
                return 1
            fi
        fi

    done <<< "$groups"

    # Module completed successfully
    log_success "Module completed: $module_name" "engine"
    update_module_state "$module_name" "completed"
    update_state "current_module" "null"
    update_state "status" "completed"

    return 0
}

# ==============================================================================
# Resume from Failure
# ==============================================================================
resume_execution() {
    log_info "Resuming from previous state" "engine"

    if [[ ! -f "$STATE_FILE" ]]; then
        log_error "No state file found - nothing to resume" "engine"
        return 1
    fi

    local current_module
    current_module=$(jq -r '.current_module // "null"' "$STATE_FILE")
    local current_status
    current_status=$(jq -r '.status // "unknown"' "$STATE_FILE")

    if [[ "$current_module" == "null" ]]; then
        log_info "No module in progress" "engine"
        return 0
    fi

    if [[ "$current_status" != "failed" ]]; then
        log_info "Last execution completed successfully" "engine"
        return 0
    fi

    log_info "Resuming module: $current_module" "engine"

    # Find the failed operation
    local failed_operation
    failed_operation=$(jq -r '.operations | to_entries[] | select(.value.status == "failed") | .key' "$STATE_FILE" | head -1)

    if [[ -n "$failed_operation" ]]; then
        echo ""
        echo "========================================================================"
        echo "  Resuming from Failed Operation"
        echo "========================================================================"
        echo "Module: $current_module"
        echo "Operation: $failed_operation"
        echo ""
        echo "Previous error information:"
        get_error_history "$failed_operation"
        echo ""

        read -p "Retry this operation? (y/n): " -n 1 -r
        echo ""

        if [[ $REPLY =~ ^[Yy]$ ]]; then
            execute_single_operation "${MODULES_DIR}/${current_module}" "$failed_operation"
            return $?
        else
            log_info "Resume cancelled by user" "engine"
            return 1
        fi
    else
        log_error "Could not determine failed operation" "engine"
        return 1
    fi
}

# ==============================================================================
# Show Current Status
# ==============================================================================
show_status() {
    if [[ ! -f "$STATE_FILE" ]]; then
        echo "No deployment in progress"
        return 0
    fi

    echo ""
    echo "========================================================================"
    echo "  Deployment Status"
    echo "========================================================================"
    echo ""

    local status
    status=$(jq -r '.status // "unknown"' "$STATE_FILE")
    local current_module
    current_module=$(jq -r '.current_module // "none"' "$STATE_FILE")
    local started_at
    started_at=$(jq -r '.started_at // "unknown"' "$STATE_FILE")

    echo "Status: $status"
    echo "Current Module: $current_module"
    echo "Started: $started_at"
    echo ""

    # Show completed operations
    local completed_ops
    completed_ops=$(jq -r '.operations | to_entries[] | select(.value.status == "completed") | .key' "$STATE_FILE" | wc -l)
    local failed_ops
    failed_ops=$(jq -r '.operations | to_entries[] | select(.value.status == "failed") | .key' "$STATE_FILE" | wc -l)

    echo "Operations:"
    echo "  Completed: $completed_ops"
    echo "  Failed: $failed_ops"
    echo ""

    if [[ $failed_ops -gt 0 ]]; then
        echo "Failed Operations:"
        jq -r '.operations | to_entries[] | select(.value.status == "failed") | "  - " + .key' "$STATE_FILE"
        echo ""
    fi

    echo "========================================================================"
}

# ==============================================================================
# List Available Modules and Operations
# ==============================================================================
list_modules() {
    echo ""
    echo "========================================================================"
    echo "  Available Modules"
    echo "========================================================================"
    echo ""

    for module_dir in "${MODULES_DIR}"/*; do
        if [[ -d "$module_dir" ]]; then
            local module_name
            module_name=$(basename "$module_dir")
            local module_yaml="${module_dir}/module.yaml"

            if [[ -f "$module_yaml" ]]; then
                local module_title
                module_title=$(yq e '.module.name // "Unknown"' "$module_yaml")
                local module_desc
                module_desc=$(yq e '.module.description // ""' "$module_yaml")

                echo "Module: $module_name"
                echo "  Name: $module_title"
                if [[ -n "$module_desc" ]]; then
                    echo "  Description: $module_desc"
                fi

                # List operations
                echo "  Operations:"
                local ops
                ops=$(get_module_operations "$module_dir" 2>/dev/null)
                if [[ -n "$ops" ]]; then
                    while IFS= read -r op_id; do
                        local op_yaml
                        op_yaml=$(find_operation_yaml "$module_dir" "$op_id" 2>/dev/null)
                        if [[ -n "$op_yaml" ]]; then
                            local op_name
                            op_name=$(yq e '.operation.name // "Unknown"' "$op_yaml")
                            echo "    - $op_id: $op_name"
                        fi
                    done <<< "$ops"
                fi
                echo ""
            fi
        fi
    done

    echo "========================================================================"
}

# ==============================================================================
# Main Command Handler
# ==============================================================================
main() {
    local command="${1:-}"

    case "$command" in
        run)
            local module_name="${2:-}"
            local operation_id="${3:-}"

            if [[ -z "$module_name" ]]; then
                echo "ERROR: Module name required"
                echo "Usage: $0 run <module> [operation]"
                exit 1
            fi

            # Load configuration
            log_info "Loading configuration" "engine"
            load_config || exit 1

            # Validate configuration for specific module
            validate_config "$module_name" || exit 1

            # Initialize state
            init_state

            if [[ -n "$operation_id" ]]; then
                # Execute single operation
                execute_single_operation "${MODULES_DIR}/${module_name}" "$operation_id"
            else
                # Execute entire module
                execute_module "$module_name"
            fi
            ;;

        resume)
            # Load configuration
            load_config || exit 1

            # For resume, get current module from state and validate for that module
            local current_module
            current_module=$(jq -r '.current_module // ""' "$STATE_FILE" 2>/dev/null)
            if [[ -n "$current_module" ]]; then
                validate_config "$current_module" || exit 1
            else
                # If no current module in state, do full validation
                validate_config || exit 1
            fi

            resume_execution
            ;;

        status)
            show_status
            ;;

        list)
            list_modules
            ;;

        *)
            echo "Azure VDI Deployment Engine"
            echo ""
            echo "Usage:"
            echo "  $0 run <module> [operation]  Execute module or single operation"
            echo "  $0 resume                    Resume from failed operation"
            echo "  $0 status                    Show deployment status"
            echo "  $0 list                      List available modules"
            echo ""
            echo "Examples:"
            echo "  $0 run 05-golden-image"
            echo "  $0 run 05-golden-image 02-install-fslogix"
            echo "  $0 resume"
            echo ""
            exit 1
            ;;
    esac
}

# Execute main
main "$@"
