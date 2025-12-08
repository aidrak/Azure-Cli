#!/bin/bash
# ==============================================================================
# Main Engine - Orchestrates Capability Operation Execution
# ==============================================================================
#
# Purpose: Main entry point for executing capability operations
# Usage:
#   ./core/engine.sh run <operation-id>
#   ./core/engine.sh resume
#   ./core/engine.sh status
#   ./core/engine.sh list
#
# Examples:
#   ./core/engine.sh run golden-image-install-apps           # Run golden image app installation
#   ./core/engine.sh run vnet-create                         # Run VNet creation operation
#   ./core/engine.sh run storage-account-create              # Run storage account creation
#   ./core/engine.sh resume                                  # Resume from failure
#   ./core/engine.sh status                                  # Show current state
#   ./core/engine.sh list                                    # List all capability operations
#
# ==============================================================================

set -euo pipefail

# Project paths
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PROJECT_ROOT

STATE_FILE="${PROJECT_ROOT}/state.json"
CAPABILITIES_DIR="${PROJECT_ROOT}/capabilities"
LOGS_DIR="${PROJECT_ROOT}/artifacts/logs"

# Source core components
source "${PROJECT_ROOT}/core/config-manager.sh"
source "${PROJECT_ROOT}/core/template-engine.sh"
source "${PROJECT_ROOT}/core/progress-tracker.sh"
source "${PROJECT_ROOT}/core/error-handler.sh"
source "${PROJECT_ROOT}/core/logger.sh"
source "${PROJECT_ROOT}/core/executor.sh"  # Include the executor for command tracking helpers

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
# Find Operation YAML File (Legacy)
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
# Find Capability Operation YAML File (New Format)
# ==============================================================================
# Searches for operation across all capability directories
find_capability_operation() {
    local operation_id="$1"

    if [[ ! -d "$CAPABILITIES_DIR" ]]; then
        return 1
    fi

    # Search through all capability directories
    for capability_dir in "${CAPABILITIES_DIR}"/*; do
        if [[ -d "$capability_dir" ]]; then
            local operations_dir="${capability_dir}/operations"

            if [[ ! -d "$operations_dir" ]]; then
                continue
            fi

            # Search for YAML file matching operation ID
            # Optimized: try direct filename match first if convention followed
            if [[ -f "${operations_dir}/${operation_id}.yaml" ]]; then
                echo "${operations_dir}/${operation_id}.yaml"
                return 0
            fi

            # Fallback: Search inside files
            for file in "${operations_dir}"/*.yaml; do
                if [[ -f "$file" ]]; then
                    local op_id
                    op_id=$(yq e '.operation.id' "$file" 2>/dev/null)
                    if [[ "$op_id" == "$operation_id" ]]; then
                        echo "$file"
                        return 0
                    fi
                fi
            done
        fi
    done

    return 1
}

# ==============================================================================
# Detect Operation Schema Format
# ==============================================================================
detect_operation_format() {
    local yaml_file="$1"

    if [[ ! -f "$yaml_file" ]]; then
        echo "unknown"
        return 1
    fi

    # Check if capability field exists (new format)
    local capability
    capability=$(yq e '.operation.capability // ""' "$yaml_file" 2>/dev/null)

    if [[ -n "$capability" && "$capability" != "null" ]]; then
        echo "capability"
    else
        echo "legacy"
    fi
}

# ==============================================================================
# Find Operation YAML (Dual-Mode: Legacy + Capability)
# ==============================================================================
find_operation_yaml_dual() {
    local module_dir="$1"
    local operation_id="$2"

    # Try legacy format first (if module_dir provided)
    if [[ -n "$module_dir" && -d "$module_dir" ]]; then
        local legacy_yaml
        legacy_yaml=$(find_operation_yaml "$module_dir" "$operation_id" 2>/dev/null) && {
            echo "$legacy_yaml"
            return 0
        }
    fi

    # Try capability format
    local capability_yaml
    capability_yaml=$(find_capability_operation "$operation_id") && {
        echo "$capability_yaml"
        return 0
    }

    # Not found in either location
    log_error "Operation YAML not found for: $operation_id (tried legacy and capability)" "engine"
    return 1
}

# ==============================================================================
# Create Checkpoint (Placeholder for future expansion)
# ==============================================================================
create_checkpoint() {
    local operation_id="$1"
    local status="$2"
    local duration="$3"
    local log_file="$4"
    log_debug "Checkpoint created for operation: $operation_id (status: $status, duration: ${duration}s)" "engine"
}

# ==============================================================================
# Execute Single Operation
# ==============================================================================
execute_single_operation() {
    local module_dir="$1"
    local operation_id="$2"

    log_info "Executing operation: $operation_id" "engine"

    # Find operation YAML (dual-mode: legacy + capability)
    local yaml_file
    yaml_file=$(find_operation_yaml_dual "$module_dir" "$operation_id") || return 1

    # Detect format and log
    local operation_format
    operation_format=$(detect_operation_format "$yaml_file")
    log_info "Found operation file: $yaml_file (format: $operation_format)" "engine"

    # If Capability Format, use the new Executor directly if possible
    if [[ "$operation_format" == "capability" ]]; then
        # Use the new Executor logic (imported from core/executor.sh)
        # But we need to wrap it to match the engine's state tracking
        
        update_state "current_operation" "$operation_id"
        update_state "status" "running"
        
        local start_time=$(date +%s)
        
        # Call execute_operation from core/executor.sh
        if execute_operation "$yaml_file" "false"; then
             local duration=$(($(date +%s) - start_time))
             update_operation_state "$operation_id" "completed" "$duration"
             create_checkpoint "$operation_id" "completed" "$duration" ""
             return 0
        else
             local duration=$(($(date +%s) - start_time))
             update_operation_state "$operation_id" "failed" "$duration"
             create_checkpoint "$operation_id" "failed" "$duration" ""
             return 1
        fi
    fi

    # --- LEGACY EXECUTION PATH ---

    # Parse operation to get metadata
    parse_operation_yaml "$yaml_file" || return 1

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
        return 0
    else
        local exit_code=$?
        local end_time
        end_time=$(date +%s)
        local duration=$((end_time - start_time))

        log_operation_error "$operation_id" "Operation failed" "$exit_code" "$duration"
        update_operation_state "$operation_id" "failed" "$duration"
        return $exit_code
    fi
}

# ==============================================================================
# Execute Operations in Parallel Group
# ==============================================================================
execute_parallel_group() {
    local module_dir="$1"
    shift
    local operations=($@)
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

    if [[ $failed -eq 1 ]]; then
        echo "[x] Parallel group failed"
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

    # Get operations list from module.yaml
    local module_yaml="${module_dir}/module.yaml"
    local total_ops
    total_ops=$(yq e '.module.operations | length' "$module_yaml")
    local current_op=0

    # Group operations by parallel_group to support parallel execution
    local op_index=0
    while [[ $op_index -lt $total_ops ]]; do
        # Get operation at this index
        local op_id
        op_id=$(yq e ".module.operations[$op_index].id" "$module_yaml")

        # Get parallel group for this operation (if any)
        local parallel_group
        parallel_group=$(yq e ".module.operations[$op_index].parallel_group // \"\"" "$module_yaml")

        # Collect all operations in this group
        local group_ops=($op_id)
        local next_index=$((op_index + 1))

        if [[ -n "$parallel_group" && "$parallel_group" != "null" ]]; then
            while [[ $next_index -lt $total_ops ]]; do
                local next_group
                next_group=$(yq e ".module.operations[$next_index].parallel_group // \"\"" "$module_yaml")
                if [[ "$next_group" == "$parallel_group" ]]; then
                    local next_op_id
                    next_op_id=$(yq e ".module.operations[$next_index].id" "$module_yaml")
                    group_ops+=("$next_op_id")
                    next_index=$((next_index + 1))
                else
                    break
                fi
            done
            op_index=$next_index
        else
            op_index=$((op_index + 1))
        fi

        current_op=$((current_op + ${#group_ops[@]}))

        # Execute operations
        if [[ ${#group_ops[@]} -gt 1 ]]; then
            if ! execute_parallel_group "$module_dir" "${group_ops[@]}"; then
                log_error "Module failed at parallel group: $parallel_group" "engine"
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
    done

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
        echo "Resume failed operation: $failed_operation?"
        read -p "Retry? (y/n): " -n 1 -r
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

    local status
    status=$(jq -r '.status // "unknown"' "$STATE_FILE")
    local current_module
    current_module=$(jq -r '.current_module // "none"' "$STATE_FILE")

    echo "Status: $status"
    echo "Current Module: $current_module"
    
    echo "Operations:"
    jq -r '.operations | to_entries[] | "  - " + .key + ": " + .value.status' "$STATE_FILE"
}

# ==============================================================================
# List Modules and Capabilities
# ==============================================================================
list_modules() {
    echo "Available Capabilities:"
    echo ""
    if [[ -d "$CAPABILITIES_DIR" ]]; then
        for d in "${CAPABILITIES_DIR}"/*; do
            if [[ -d "$d" ]]; then
                local capability_name=$(basename "$d")
                echo "[$capability_name]"
                for op in "$d"/operations/*.yaml; do
                    if [[ -f "$op" ]]; then
                        local op_id=$(yq e '.operation.id' "$op" 2>/dev/null || echo "unknown")
                        local op_name=$(yq e '.operation.name' "$op" 2>/dev/null || echo "Unknown Operation")
                        echo "  - $op_id: $op_name"
                    fi
                done
                echo ""
            fi
        done
    else
        echo "Error: Capabilities directory not found at $CAPABILITIES_DIR"
        return 1
    fi
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
                echo "ERROR: Module name or operation ID required"
                echo "Usage: $0 run <module> [operation]"
                echo "   OR: $0 run <operation-id>"
                echo "   OR: $0 run <capability>/<operation>"
                exit 1
            fi

            # Load configuration
            log_info "Loading configuration" "engine"
            load_config || exit 1

            # Initialize state
            init_state

            # NEW: Check for capability/operation syntax (e.g., compute/vm-create)
            if [[ "$module_name" == */* && -z "$operation_id" ]]; then
                local capability="${module_name%/*}"
                local op_id="${module_name#*/}"
                local capability_yaml="${CAPABILITIES_DIR}/${capability}/operations/${op_id}.yaml"

                if [[ -f "$capability_yaml" ]]; then
                    log_info "Executing capability operation: ${capability}/${op_id}" "engine"
                    execute_single_operation "" "$op_id"
                else
                    log_error "Operation not found: ${capability}/${op_id}" "engine"
                    log_error "Expected file: $capability_yaml" "engine"
                    exit 1
                fi
            # Check if module_name is actually a capability operation ID
            else
                local capability_yaml
                capability_yaml=$(find_capability_operation "$module_name" 2>/dev/null)

                if [[ -n "$capability_yaml" && -z "$operation_id" ]]; then
                    # Direct capability operation execution
                    log_info "Executing capability operation: $module_name" "engine"
                    execute_single_operation "" "$module_name"
                elif [[ -n "$operation_id" ]]; then
                    # Traditional: module + operation
                    validate_config "$module_name" || exit 1
                    execute_single_operation "${MODULES_DIR}/${module_name}" "$operation_id"
                else
                    # Execute entire module
                    validate_config "$module_name" || exit 1
                    execute_module "$module_name"
                fi
            fi
            ;;

        workflow)
            local workflow_arg="${2:-}"

            if [[ -z "$workflow_arg" ]]; then
                echo "ERROR: Workflow file or ID required"
                echo "Usage: $0 workflow <workflow.yaml>"
                echo "   OR: $0 workflow <workflow-id>"
                exit 1
            fi

            # Load configuration
            log_info "Loading configuration" "engine"
            load_config || exit 1

            # Initialize state
            init_state

            # Source workflow engine
            source "${PROJECT_ROOT}/core/workflow-engine.sh"

            # Check if it's a file path or workflow ID
            if [[ -f "$workflow_arg" ]]; then
                execute_workflow "$workflow_arg"
            elif [[ -f "${PROJECT_ROOT}/workflows/${workflow_arg}.yaml" ]]; then
                execute_workflow "${PROJECT_ROOT}/workflows/${workflow_arg}.yaml"
            else
                log_error "Workflow not found: $workflow_arg" "engine"
                exit 1
            fi
            ;;

        resume)
            load_config || exit 1
            resume_execution
            ;;

        status)
            show_status
            ;;

        list)
            list_modules
            ;;

        *)
            echo "Usage: $0 {run|workflow|resume|status|list} ..."
            exit 1
            ;;
    esac
}

# Execute main
main "$@"