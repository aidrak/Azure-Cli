#!/bin/bash
# ==============================================================================
# Workflow Engine - Multi-Step Workflow Orchestration
# ==============================================================================
#
# Purpose: Execute multi-step workflows defined in YAML format
#
# Usage:
#   source core/workflow-engine.sh
#   execute_workflow "path/to/workflow.yaml"
#   validate_workflow "path/to/workflow.yaml"
#   get_workflow_status "workflow-id"
#
# Features:
#   - Sequential step execution
#   - Dependency resolution (future enhancement)
#   - Comprehensive logging and state tracking
#   - Error handling and rollback support
#   - Variable substitution from config
#
# Workflow YAML Format:
#   workflow:
#     id: "unique-workflow-id"
#     name: "Workflow Name"
#     description: "Optional description"
#     steps:
#       - name: "Step Name"
#         operation: "operation-file.yaml"
#         parameters:
#           param1: "value1"
#           param2: "value2"
#
# ==============================================================================

set -euo pipefail

# ==============================================================================
# CONFIGURATION
# ==============================================================================

PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
WORKFLOWS_DIR="${PROJECT_ROOT}/workflows"
ARTIFACTS_DIR="${PROJECT_ROOT}/artifacts"
WORKFLOW_STATE_DIR="${ARTIFACTS_DIR}/workflow-state"
WORKFLOW_LOGS_DIR="${ARTIFACTS_DIR}/workflow-logs"

# Ensure directories exist
mkdir -p "$WORKFLOW_STATE_DIR" "$WORKFLOW_LOGS_DIR"

# ==============================================================================
# SOURCE DEPENDENCIES
# ==============================================================================

# Source logger for structured logging
if [[ -f "${PROJECT_ROOT}/core/logger.sh" ]]; then
    source "${PROJECT_ROOT}/core/logger.sh"
else
    echo "[x] ERROR: logger.sh not found" >&2
    exit 1
fi

# Source executor for operation execution
if [[ -f "${PROJECT_ROOT}/core/executor.sh" ]]; then
    source "${PROJECT_ROOT}/core/executor.sh"
else
    echo "[x] ERROR: executor.sh not found" >&2
    exit 1
fi

# Source config manager for variable substitution
if [[ -f "${PROJECT_ROOT}/core/config-manager.sh" ]]; then
    source "${PROJECT_ROOT}/core/config-manager.sh"
else
    echo "[x] ERROR: config-manager.sh not found" >&2
    exit 1
fi

# Source state manager for tracking
if [[ -f "${PROJECT_ROOT}/core/state-manager.sh" ]]; then
    source "${PROJECT_ROOT}/core/state-manager.sh"
else
    echo "[x] ERROR: state-manager.sh not found" >&2
    exit 1
fi

# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

# Generate unique workflow execution ID
generate_workflow_exec_id() {
    local workflow_id="$1"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local random_suffix=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 4)
    echo "wf_${workflow_id}_${timestamp}_${random_suffix}"
}

# Get workflow state file path
get_workflow_state_file() {
    local workflow_exec_id="$1"
    echo "${WORKFLOW_STATE_DIR}/${workflow_exec_id}.json"
}

# Get workflow log file path
get_workflow_log_file() {
    local workflow_exec_id="$1"
    echo "${WORKFLOW_LOGS_DIR}/${workflow_exec_id}.log"
}

# Initialize workflow execution state
init_workflow_state() {
    local workflow_exec_id="$1"
    local workflow_id="$2"
    local workflow_name="$3"
    local step_count="$4"

    local state_file=$(get_workflow_state_file "$workflow_exec_id")

    # Create initial state JSON
    jq -n \
        --arg exec_id "$workflow_exec_id" \
        --arg wf_id "$workflow_id" \
        --arg name "$workflow_name" \
        --arg status "running" \
        --arg start_time "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)" \
        --argjson step_count "$step_count" \
        --argjson completed_steps 0 \
        '{
            execution_id: $exec_id,
            workflow_id: $wf_id,
            workflow_name: $name,
            status: $status,
            start_time: $start_time,
            total_steps: $step_count,
            completed_steps: $completed_steps,
            failed_steps: [],
            skipped_steps: [],
            steps: {}
        }' > "$state_file"

    log_info "Workflow state initialized: $state_file"
}

# Update workflow step state
update_step_state() {
    local workflow_exec_id="$1"
    local step_index="$2"
    local step_name="$3"
    local step_status="$4"
    local step_output="${5:-}"

    local state_file=$(get_workflow_state_file "$workflow_exec_id")

    if [[ ! -f "$state_file" ]]; then
        log_error "Workflow state file not found: $state_file"
        return 1
    fi

    local step_key="step_${step_index}"
    local end_time="$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)"

    # Update state with step information
    jq --arg key "$step_key" \
       --arg idx "$step_index" \
       --arg name "$step_name" \
       --arg status "$step_status" \
       --arg output "$step_output" \
       --arg end_time "$end_time" \
       '.steps[$key] = {
           index: ($idx | tonumber),
           name: $name,
           status: $status,
           output: $output,
           completed_at: $end_time
       }' "$state_file" > "${state_file}.tmp" && mv "${state_file}.tmp" "$state_file"

    # Update completed steps count
    local completed=$(jq '.steps | map(select(.status == "completed")) | length' "$state_file")
    jq ".completed_steps = $completed" "$state_file" > "${state_file}.tmp" && mv "${state_file}.tmp" "$state_file"
}

# Update overall workflow status
update_workflow_status() {
    local workflow_exec_id="$1"
    local status="$2"  # running, completed, failed

    local state_file=$(get_workflow_state_file "$workflow_exec_id")

    if [[ ! -f "$state_file" ]]; then
        log_error "Workflow state file not found: $state_file"
        return 1
    fi

    local end_time=""
    if [[ "$status" != "running" ]]; then
        end_time="$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)"
    fi

    if [[ -n "$end_time" ]]; then
        jq --arg status "$status" --arg end_time "$end_time" \
           '.status = $status | .end_time = $end_time' "$state_file" \
           > "${state_file}.tmp" && mv "${state_file}.tmp" "$state_file"
    else
        jq --arg status "$status" '.status = $status' "$state_file" \
           > "${state_file}.tmp" && mv "${state_file}.tmp" "$state_file"
    fi
}

# ==============================================================================
# WORKFLOW VALIDATION
# ==============================================================================

validate_workflow() {
    local workflow_file="$1"

    if [[ ! -f "$workflow_file" ]]; then
        log_error "Workflow file not found: $workflow_file"
        return 1
    fi

    log_info "Validating workflow: $workflow_file"

    # Check YAML is valid
    if ! yq e '.' "$workflow_file" >/dev/null 2>&1; then
        log_error "Invalid YAML in workflow file"
        return 1
    fi

    # Check required fields
    local workflow_id=$(yq e '.workflow.id' "$workflow_file" 2>/dev/null)
    if [[ -z "$workflow_id" ]] || [[ "$workflow_id" == "null" ]]; then
        log_error "Workflow missing required field: .workflow.id"
        return 1
    fi

    local workflow_name=$(yq e '.workflow.name' "$workflow_file" 2>/dev/null)
    if [[ -z "$workflow_name" ]] || [[ "$workflow_name" == "null" ]]; then
        log_error "Workflow missing required field: .workflow.name"
        return 1
    fi

    # Check steps exist
    local step_count=$(yq e '.workflow.steps | length' "$workflow_file" 2>/dev/null)
    if [[ -z "$step_count" ]] || [[ "$step_count" == "0" ]] || [[ "$step_count" == "null" ]]; then
        log_error "Workflow has no steps defined"
        return 1
    fi

    # Validate each step
    local i=0
    while [[ $i -lt $step_count ]]; do
        local step_name=$(yq e ".workflow.steps[$i].name" "$workflow_file" 2>/dev/null)
        local step_operation=$(yq e ".workflow.steps[$i].operation" "$workflow_file" 2>/dev/null)

        if [[ -z "$step_name" ]] || [[ "$step_name" == "null" ]]; then
            log_error "Step $((i+1)) missing required field: name"
            return 1
        fi

        if [[ -z "$step_operation" ]] || [[ "$step_operation" == "null" ]]; then
            log_error "Step $((i+1)) ($step_name) missing required field: operation"
            return 1
        fi

        ((i++))
    done

    log_success "Workflow validation passed: $workflow_id ($step_count steps)"
    return 0
}

# ==============================================================================
# WORKFLOW EXECUTION
# ==============================================================================

execute_workflow() {
    local workflow_file="$1"
    local force_mode="${2:-false}"

    # Validate workflow first
    if ! validate_workflow "$workflow_file"; then
        log_error "Workflow validation failed"
        return 1
    fi

    # Extract workflow metadata
    local workflow_id=$(yq e '.workflow.id' "$workflow_file")
    local workflow_name=$(yq e '.workflow.name' "$workflow_file")
    local workflow_description=$(yq e '.workflow.description // ""' "$workflow_file")
    local step_count=$(yq e '.workflow.steps | length' "$workflow_file")

    # Generate unique execution ID
    local workflow_exec_id=$(generate_workflow_exec_id "$workflow_id")
    local log_file=$(get_workflow_log_file "$workflow_exec_id")

    # Start operation logging
    log_operation_start "$workflow_exec_id" "$workflow_name" $((step_count * 60))

    # Initialize workflow state
    init_workflow_state "$workflow_exec_id" "$workflow_id" "$workflow_name" "$step_count"

    # Initialize state database if needed
    if ! init_state_db 2>/dev/null; then
        log_warn "Could not initialize state database (may already exist)" "$workflow_exec_id"
    fi

    log_info "Executing workflow: $workflow_name (ID: $workflow_id)" "$workflow_exec_id"
    log_info "Total steps: $step_count" "$workflow_exec_id"

    if [[ -n "$workflow_description" ]] && [[ "$workflow_description" != "null" ]]; then
        log_info "Description: $workflow_description" "$workflow_exec_id"
    fi

    # Execute each step sequentially
    local step_index=0
    local failed_steps=0
    local start_time=$(date +%s)

    while [[ $step_index -lt $step_count ]]; do
        local step_name=$(yq e ".workflow.steps[$step_index].name" "$workflow_file")
        local step_operation=$(yq e ".workflow.steps[$step_index].operation" "$workflow_file")
        local step_continue_on_error=$(yq e ".workflow.steps[$step_index].continue_on_error // false" "$workflow_file")

        log_info "Step $((step_index + 1))/$step_count: $step_name" "$workflow_exec_id"
        log_info "  Operation: $step_operation" "$workflow_exec_id"

        # Get step parameters (if any)
        local step_params=$(yq e ".workflow.steps[$step_index].parameters // {}" "$workflow_file" -o=json 2>/dev/null)

        # Resolve operation file path
        local operation_file="$step_operation"
        if [[ ! -f "$operation_file" ]]; then
            # Try relative to project root
            operation_file="${PROJECT_ROOT}/${step_operation}"
        fi
        if [[ ! -f "$operation_file" ]]; then
            # Try relative to workflow directory
            operation_file="${WORKFLOWS_DIR}/${step_operation}"
        fi

        if [[ ! -f "$operation_file" ]]; then
            log_error "Operation file not found: $step_operation" "$workflow_exec_id"
            ((failed_steps++))
            update_step_state "$workflow_exec_id" "$step_index" "$step_name" "failed" "Operation file not found"

            if [[ "$step_continue_on_error" != "true" ]]; then
                log_error "Workflow execution failed at step $((step_index + 1))" "$workflow_exec_id"
                update_workflow_status "$workflow_exec_id" "failed"
                log_operation_complete "$workflow_exec_id" $(($(date +%s) - start_time)) 1
                return 1
            else
                log_warn "Continuing despite error (continue_on_error=true)" "$workflow_exec_id"
                update_step_state "$workflow_exec_id" "$step_index" "$step_name" "skipped" "Operation file not found"
            fi
        else
            # Execute operation
            if execute_operation "$operation_file" "$force_mode"; then
                log_success "Step completed: $step_name" "$workflow_exec_id"
                update_step_state "$workflow_exec_id" "$step_index" "$step_name" "completed"
            else
                log_error "Step failed: $step_name" "$workflow_exec_id"
                ((failed_steps++))
                update_step_state "$workflow_exec_id" "$step_index" "$step_name" "failed"

                if [[ "$step_continue_on_error" != "true" ]]; then
                    log_error "Workflow execution failed at step $((step_index + 1))" "$workflow_exec_id"
                    update_workflow_status "$workflow_exec_id" "failed"
                    log_operation_complete "$workflow_exec_id" $(($(date +%s) - start_time)) 1
                    return 1
                else
                    log_warn "Continuing despite error (continue_on_error=true)" "$workflow_exec_id"
                fi
            fi
        fi

        ((step_index++))
    done

    # Workflow completed successfully
    update_workflow_status "$workflow_exec_id" "completed"
    log_operation_complete "$workflow_exec_id" $(($(date +%s) - start_time)) 0
    log_success "Workflow completed: $workflow_name" "$workflow_exec_id"

    # Output execution ID for reference
    echo "$workflow_exec_id"
    return 0
}

# ==============================================================================
# WORKFLOW STATUS AND QUERY
# ==============================================================================

get_workflow_status() {
    local workflow_exec_id="$1"
    local state_file=$(get_workflow_state_file "$workflow_exec_id")

    if [[ ! -f "$state_file" ]]; then
        log_error "Workflow state not found: $workflow_exec_id"
        return 1
    fi

    log_info "Workflow Status: $workflow_exec_id"
    echo ""

    # Pretty print JSON state
    jq '.' "$state_file" | sed 's/^/  /'
    echo ""
}

list_workflow_executions() {
    log_info "Workflow Executions:"
    echo ""

    if [[ ! -d "$WORKFLOW_STATE_DIR" ]] || [[ -z "$(ls -A "$WORKFLOW_STATE_DIR")" ]]; then
        log_info "No workflow executions found"
        return 0
    fi

    # List all state files
    for state_file in "$WORKFLOW_STATE_DIR"/*.json; do
        if [[ -f "$state_file" ]]; then
            local exec_id=$(jq -r '.execution_id' "$state_file")
            local workflow_id=$(jq -r '.workflow_id' "$state_file")
            local status=$(jq -r '.status' "$state_file")
            local start_time=$(jq -r '.start_time' "$state_file")

            printf "  %-40s %-30s %-10s %s\n" "$exec_id" "$workflow_id" "$status" "$start_time"
        fi
    done
    echo ""
}

# ==============================================================================
# DRY RUN / PREVIEW
# ==============================================================================

preview_workflow() {
    local workflow_file="$1"

    if ! validate_workflow "$workflow_file"; then
        log_error "Workflow validation failed"
        return 1
    fi

    # Extract workflow metadata
    local workflow_id=$(yq e '.workflow.id' "$workflow_file")
    local workflow_name=$(yq e '.workflow.name' "$workflow_file")
    local workflow_description=$(yq e '.workflow.description // "No description"' "$workflow_file")
    local step_count=$(yq e '.workflow.steps | length' "$workflow_file")

    echo ""
    echo "=========================================================================="
    echo "Workflow Preview: $workflow_name"
    echo "=========================================================================="
    echo ""
    echo "ID: $workflow_id"
    echo "Description: $workflow_description"
    echo "Total Steps: $step_count"
    echo ""
    echo "Steps:"
    echo ""

    local i=0
    while [[ $i -lt $step_count ]]; do
        local step_name=$(yq e ".workflow.steps[$i].name" "$workflow_file")
        local step_operation=$(yq e ".workflow.steps[$i].operation" "$workflow_file")
        local step_params=$(yq e ".workflow.steps[$i].parameters // {}" "$workflow_file" -o=json 2>/dev/null)

        echo "  Step $((i+1)): $step_name"
        echo "    Operation: $step_operation"

        if [[ "$step_params" != "{}" ]]; then
            echo "    Parameters: $(echo "$step_params" | jq -c '.')"
        fi
        echo ""

        ((i++))
    done

    echo "=========================================================================="
    echo ""
}

# ==============================================================================
# EXPORT FUNCTIONS
# ==============================================================================

export -f execute_workflow validate_workflow
export -f get_workflow_status list_workflow_executions
export -f preview_workflow
export -f init_workflow_state update_step_state update_workflow_status

# ==============================================================================
# CLI INTERFACE (if called directly)
# ==============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ $# -lt 1 ]]; then
        echo "Usage: $0 <command> [args...]"
        echo ""
        echo "Commands:"
        echo "  execute <workflow.yaml> [--force]   Execute workflow"
        echo "  validate <workflow.yaml>            Validate workflow YAML"
        echo "  preview <workflow.yaml>             Preview workflow steps"
        echo "  status <workflow-exec-id>           Get workflow execution status"
        echo "  list                                List all workflow executions"
        echo ""
        exit 1
    fi

    command="$1"
    shift

    case "$command" in
        execute)
            workflow_file="${1:-}"
            force_mode="${2:-}"
            if [[ -z "$workflow_file" ]]; then
                log_error "Workflow file required"
                exit 1
            fi
            execute_workflow "$workflow_file" "$force_mode"
            ;;
        validate)
            workflow_file="${1:-}"
            if [[ -z "$workflow_file" ]]; then
                log_error "Workflow file required"
                exit 1
            fi
            validate_workflow "$workflow_file"
            ;;
        preview)
            workflow_file="${1:-}"
            if [[ -z "$workflow_file" ]]; then
                log_error "Workflow file required"
                exit 1
            fi
            preview_workflow "$workflow_file"
            ;;
        status)
            workflow_exec_id="${1:-}"
            if [[ -z "$workflow_exec_id" ]]; then
                log_error "Workflow execution ID required"
                exit 1
            fi
            get_workflow_status "$workflow_exec_id"
            ;;
        list)
            list_workflow_executions
            ;;
        *)
            log_error "Unknown command: $command"
            exit 1
            ;;
    esac
fi
