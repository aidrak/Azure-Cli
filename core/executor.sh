#!/bin/bash
# ==============================================================================
# Operation Executor - Phase 3 Execution Engine
# ==============================================================================
#
# Purpose: Execute operations with validation, rollback, and state tracking
#
# Usage:
#   source core/executor.sh
#   execute_operation "path/to/operation.yaml"
#   dry_run "path/to/operation.yaml"
#   execute_with_rollback "path/to/operation.yaml"
#
# Features:
#   - Prerequisite validation using query engine
#   - State tracking in SQLite database
#   - Automatic rollback on failure
#   - Comprehensive error handling
#   - Dry-run mode for preview
#   - Variable substitution from config
#   - Progress tracking and metrics
#
# ==============================================================================

set -euo pipefail

# ==============================================================================
# CONFIGURATION
# ==============================================================================

PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
OPERATIONS_DIR="${PROJECT_ROOT}/operations"
ARTIFACTS_DIR="${PROJECT_ROOT}/artifacts"
ROLLBACK_SCRIPTS_DIR="${ARTIFACTS_DIR}/rollback"

# Ensure rollback directory exists
mkdir -p "$ROLLBACK_SCRIPTS_DIR"

# Operation execution modes
EXECUTION_MODE="${EXECUTION_MODE:-normal}"  # normal, dry-run, force

# ==============================================================================
# SOURCE DEPENDENCIES
# ==============================================================================

if [[ -f "${PROJECT_ROOT}/core/state-manager.sh" ]]; then
    source "${PROJECT_ROOT}/core/state-manager.sh"
else
    echo "[x] ERROR: state-manager.sh not found" >&2
    exit 1
fi

if [[ -f "${PROJECT_ROOT}/core/query.sh" ]]; then
    source "${PROJECT_ROOT}/core/query.sh"
else
    echo "[x] ERROR: query.sh not found" >&2
    exit 1
fi

if [[ -f "${PROJECT_ROOT}/core/logger.sh" ]]; then
    source "${PROJECT_ROOT}/core/logger.sh"
else
    echo "[x] ERROR: logger.sh not found" >&2
    exit 1
fi

if [[ -f "${PROJECT_ROOT}/core/config-manager.sh" ]]; then
    source "${PROJECT_ROOT}/core/config-manager.sh"
else
    echo "[x] ERROR: config-manager.sh not found" >&2
    exit 1
fi

if [[ -f "${PROJECT_ROOT}/core/template-engine.sh" ]]; then
    source "${PROJECT_ROOT}/core/template-engine.sh"
else
    echo "[x] ERROR: template-engine.sh not found" >&2
    exit 1
fi

# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

# Generate unique operation execution ID
generate_operation_id() {
    local operation_name="$1"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local random_suffix=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 4)
    echo "${operation_name}_${timestamp}_${random_suffix}"
}

# Parse operation YAML file
parse_operation_file() {
    local yaml_file="$1"

    if [[ ! -f "$yaml_file" ]]; then
        log_error "Operation file not found: $yaml_file"
        return 1
    fi

    # Validate YAML structure
    if ! yq eval '.' "$yaml_file" &>/dev/null; then
        log_error "Invalid YAML syntax in: $yaml_file"
        return 1
    fi

    # Check required fields
    local operation_id=$(yq eval '.operation.id' "$yaml_file")
    local operation_name=$(yq eval '.operation.name' "$yaml_file")

    if [[ -z "$operation_id" ]] || [[ "$operation_id" == "null" ]]; then
        log_error "Missing required field: operation.id"
        return 1
    fi

    if [[ -z "$operation_name" ]] || [[ "$operation_name" == "null" ]]; then
        log_error "Missing required field: operation.name"
        return 1
    fi

    log_info "Parsed operation: $operation_name (ID: $operation_id)"
    return 0
}

# Extract prerequisites from operation YAML
get_prerequisites() {
    local yaml_file="$1"

    # Try root level prerequisites (Legacy/Executor Schema)
    local prereq_count=$(yq eval '.prerequisites | length' "$yaml_file")

    if [[ "$prereq_count" != "0" ]] && [[ "$prereq_count" != "null" ]]; then
        yq eval -o=json '.prerequisites' "$yaml_file"
        return 0
    fi

    # Try operation level prerequisites (Capability Schema)
    prereq_count=$(yq eval '.operation.prerequisites | length' "$yaml_file")
    if [[ "$prereq_count" != "0" ]] && [[ "$prereq_count" != "null" ]]; then
        yq eval -o=json '.operation.prerequisites' "$yaml_file"
        return 0
    fi

    echo "[]"
    return 0
}

# Extract steps from operation YAML
get_steps() {
    local yaml_file="$1"

    # Try explicit steps (Legacy/Executor Schema)
    local step_count=$(yq eval '.steps | length' "$yaml_file")

    if [[ "$step_count" != "0" ]] && [[ "$step_count" != "null" ]]; then
        yq eval -o=json '.steps' "$yaml_file"
        return 0
    fi

    # Try template command (Capability Schema)
    local template_command=$(yq eval '.operation.template.command' "$yaml_file")

    if [[ -n "$template_command" ]] && [[ "$template_command" != "null" ]]; then
        # Construct a synthetic step
        # escape double quotes for JSON
        local escaped_command=$(echo "$template_command" | jq -Rs .)
        echo "[{\"name\": \"Execute Operation Template\", \"command\": $escaped_command}]"
        return 0
    fi

    log_error "No steps or template defined in operation"
    return 1
}

# Extract rollback steps from operation YAML
get_rollback_steps() {
    local yaml_file="$1"

    # Try root level rollback (Legacy/Executor Schema)
    local rollback_count=$(yq eval '.rollback | length' "$yaml_file")

    if [[ "$rollback_count" != "0" ]] && [[ "$rollback_count" != "null" ]]; then
        yq eval -o=json '.rollback' "$yaml_file"
        return 0
    fi

    # Try operation level rollback steps (Capability Schema)
    # Schema: operation.rollback.steps
    rollback_count=$(yq eval '.operation.rollback.steps | length' "$yaml_file")

    if [[ "$rollback_count" != "0" ]] && [[ "$rollback_count" != "null" ]]; then
        yq eval -o=json '.operation.rollback.steps' "$yaml_file"
        return 0
    fi

    echo "[]"
    return 0
}

# ==============================================================================
# PREREQUISITE VALIDATION
# ==============================================================================

validate_prerequisites() {
    local yaml_file="$1"
    local operation_exec_id="$2"

    log_info "Validating prerequisites..." "$operation_exec_id"

    local prerequisites=$(get_prerequisites "$yaml_file")

    # Check for operation prerequisites
    local operation_prereqs=$(echo "$prerequisites" | jq -r '.operations // []')
    local op_prereq_count=$(echo "$operation_prereqs" | jq 'length')

    # Check for resource prerequisites
    local resource_prereqs=$(echo "$prerequisites" | jq -r '.resources // []')
    local res_prereq_count=$(echo "$resource_prereqs" | jq 'length')

    if [[ "$op_prereq_count" == "0" ]] && [[ "$res_prereq_count" == "0" ]]; then
        log_info "No prerequisites to validate" "$operation_exec_id"
        return 0
    fi

    local failed_count=0

    # Validate operation prerequisites
    if [[ "$op_prereq_count" != "0" ]] && [[ "$op_prereq_count" != "null" ]]; then
        log_info "Validating $op_prereq_count operation prerequisite(s)..." "$operation_exec_id"
        local i=0
        while [[ $i -lt $op_prereq_count ]]; do
            local required_op=$(echo "$operation_prereqs" | jq -r ".[$i]")

            # Check if operation completed in state.json
            local op_status=$(jq -r ".operations[\"$required_op\"].status // \"not_found\"" "$STATE_FILE")

            if [[ "$op_status" == "completed" ]]; then
                log_success "Operation prerequisite met: $required_op" "$operation_exec_id"
            else
                log_error "Operation prerequisite not met: $required_op (status: $op_status)" "$operation_exec_id"
                ((failed_count++))
            fi
            ((i++))
        done
    fi

    # Validate resource prerequisites
    if [[ "$res_prereq_count" != "0" ]] && [[ "$res_prereq_count" != "null" ]]; then
        log_info "Validating $res_prereq_count resource prerequisite(s)..." "$operation_exec_id"
        local i=0
        while [[ $i -lt $res_prereq_count ]]; do
            local prereq=$(echo "$resource_prereqs" | jq -r ".[$i]")
            local resource_type=$(echo "$prereq" | jq -r '.type // .resource_type')
            local name_from_config=$(echo "$prereq" | jq -r '.name_from_config // empty')
            local resource_name=$(echo "$prereq" | jq -r '.name // empty')
            local resource_group=$(echo "$prereq" | jq -r '.resource_group // empty')

            # If name_from_config is specified, resolve it from environment
            if [[ -n "$name_from_config" ]]; then
                resource_name="${!name_from_config:-}"
                if [[ -z "$resource_name" ]]; then
                    log_error "Config variable not found: $name_from_config" "$operation_exec_id"
                    ((failed_count++))
                    ((i++))
                    continue
                fi
            fi

            # Default to AZURE_RESOURCE_GROUP if not specified
            if [[ -z "$resource_group" ]]; then
                resource_group="${AZURE_RESOURCE_GROUP:-}"
            fi

            if [[ -z "$resource_name" ]]; then
                log_error "Resource prerequisite $((i+1)): Missing resource name" "$operation_exec_id"
                ((failed_count++))
                ((i++))
                continue
            fi

            log_info "Validating resource prerequisite $((i+1))/$res_prereq_count: $resource_name ($resource_type)" "$operation_exec_id"

            # Check if resource exists using query engine
            if check_resource_exists "$resource_type" "$resource_name" "$resource_group"; then
                log_success "Resource prerequisite validated: $resource_name" "$operation_exec_id"
            else
                log_error "Resource prerequisite not found: $resource_name" "$operation_exec_id"
                ((failed_count++))
            fi

            ((i++))
        done
    fi

    if [[ $failed_count -gt 0 ]]; then
        log_error "Prerequisite validation failed: $failed_count prerequisite(s) not met" "$operation_exec_id"
        return 1
    fi

    log_success "All prerequisites validated successfully" "$operation_exec_id"
    return 0
}

# Check if a resource exists (cache-first, then Azure query)
check_resource_exists() {
    local resource_type="$1"
    local resource_name="$2"
    local resource_group="$3"

    # Try cache first via state-manager
    if get_resource "$resource_type" "$resource_name" "$resource_group" &>/dev/null; then
        return 0
    fi

    # Resource not found
    return 1
}

# ==============================================================================
# OPERATION EXECUTION
# ==============================================================================

execute_operation() {
    local yaml_file="$1"
    local force_mode="${2:-false}"

    # Parse and validate operation file
    if ! parse_operation_file "$yaml_file"; then
        log_error "Failed to parse operation file"
        return 1
    fi

    # Extract operation metadata
    local operation_id=$(yq eval '.operation.id' "$yaml_file")
    local operation_name=$(yq eval '.operation.name' "$yaml_file")
    local operation_type=$(yq eval '.operation.type' "$yaml_file")
    local resource_type=$(yq eval '.operation.resource_type // ""' "$yaml_file")

    # Generate unique execution ID
    local operation_exec_id=$(generate_operation_id "$operation_id")

    # Log operation start
    log_operation_start "$operation_exec_id" "$operation_name"

    # Initialize state database if needed
    init_state_db || {
        log_error "Failed to initialize state database" "$operation_exec_id"
        return 1
    }

    # Create operation record in database
    create_operation "$operation_exec_id" "executor" "$operation_name" "$operation_type" "" || {
        log_error "Failed to create operation record" "$operation_exec_id"
        return 1
    }

    # Update status to running
    update_operation_status "$operation_exec_id" "running"

    # Track start time
    local start_time=$(date +%s)

    # Validate prerequisites (unless force mode)
    if [[ "$force_mode" != "true" ]]; then
        if ! validate_prerequisites "$yaml_file" "$operation_exec_id"; then
            update_operation_status "$operation_exec_id" "failed" "Prerequisite validation failed"
            log_operation_complete "$operation_exec_id" $(($(date +%s) - start_time)) 1
            return 1
        fi
    else
        log_warn "Force mode enabled - skipping prerequisite validation" "$operation_exec_id"
    fi

    # Execute steps
    local steps=$(get_steps "$yaml_file")
    local step_count=$(echo "$steps" | jq 'length')
    local step_index=0
    local execution_success=true

    log_info "Executing $step_count steps..." "$operation_exec_id"

    while [[ $step_index -lt $step_count ]]; do
        local step=$(echo "$steps" | jq -r ".[$step_index]")
        local step_name=$(echo "$step" | jq -r '.name')
        local step_command=$(echo "$step" | jq -r '.command')
        local continue_on_error=$(echo "$step" | jq -r '.continue_on_error // false')

        # Update progress
        update_operation_progress "$operation_exec_id" $((step_index + 1)) "$step_count" "$step_name"

        log_info "Step $((step_index + 1))/$step_count: $step_name" "$operation_exec_id"

        # Substitute variables in command
        local resolved_command=$(substitute_variables "$step_command")

        # Execute step
        if ! execute_step "$operation_exec_id" "$step_name" "$resolved_command" "$step_index"; then
            if [[ "$continue_on_error" == "true" ]]; then
                log_warn "Step failed but continuing due to continue_on_error flag" "$operation_exec_id"
            else
                log_error "Step execution failed, initiating rollback" "$operation_exec_id"
                execution_success=false
                break
            fi
        fi

        ((step_index++))
    done

    # Calculate duration
    local duration=$(($(date +%s) - start_time))

    # Handle execution result
    if [[ "$execution_success" == "true" ]]; then
        # Query Azure to get final resource state
        local resource_name=$(yq eval '.operation.resource_name // ""' "$yaml_file")
        if [[ -n "$resource_name" ]] && [[ -n "$resource_type" ]]; then
            local resource_name_resolved=$(substitute_variables "$resource_name")
            query_and_store_resource "$resource_type" "$resource_name_resolved" "${AZURE_RESOURCE_GROUP:-}"
        fi

        update_operation_status "$operation_exec_id" "completed"
        log_operation_complete "$operation_exec_id" "$duration" 0
        log_success "Operation completed successfully: $operation_name" "$operation_exec_id"
        return 0
    else
        # Execute rollback
        execute_rollback "$yaml_file" "$operation_exec_id" "$step_index"

        update_operation_status "$operation_exec_id" "failed" "Step execution failed at step $((step_index + 1))"
        log_operation_complete "$operation_exec_id" "$duration" 1
        log_error "Operation failed: $operation_name" "$operation_exec_id"
        return 1
    fi
}

# Execute a single step
execute_step() {
    local operation_exec_id="$1"
    local step_name="$2"
    local command="$3"
    local step_index="$4"

    log_info "Executing: $command" "$operation_exec_id"

    # Create step log file
    local step_log="${ARTIFACTS_DIR}/logs/step_${operation_exec_id}_${step_index}.log"
    mkdir -p "$(dirname "$step_log")"

    # Execute command and capture output
    local exit_code=0
    local output=""

    if [[ "${EXECUTION_MODE}" == "dry-run" ]]; then
        log_info "[DRY-RUN] Would execute: $command" "$operation_exec_id"
        echo "[DRY-RUN] Would execute: $command" > "$step_log"
        return 0
    fi

    output=$(eval "$command" 2>&1) || exit_code=$?

    # Save output to log file
    echo "$output" > "$step_log"

    if [[ $exit_code -eq 0 ]]; then
        log_success "Step completed successfully: $step_name" "$operation_exec_id"
        log_info "Output saved to: $step_log" "$operation_exec_id"

        # Log to operation logs in database
        log_operation "$operation_exec_id" "INFO" "Step completed: $step_name" "{\"log_file\": \"$step_log\"}"

        return 0
    else
        log_error "Step failed with exit code $exit_code: $step_name" "$operation_exec_id"
        log_error "Command: $command" "$operation_exec_id"
        log_error "Output: $output" "$operation_exec_id"

        # Log error to operation logs
        log_operation "$operation_exec_id" "ERROR" "Step failed: $step_name" "{\"exit_code\": $exit_code, \"command\": \"$command\", \"log_file\": \"$step_log\"}"

        return 1
    fi
}

# Query Azure and store resource in database
query_and_store_resource() {
    local resource_type="$1"
    local resource_name="$2"
    local resource_group="$3"

    log_info "Querying Azure for resource: $resource_name"

    # Use query engine to get resource
    local resource_json=$(query_azure_resource "$resource_type" "$resource_name" "$resource_group")

    if [[ -n "$resource_json" ]] && [[ "$resource_json" != "null" ]]; then
        # Store in database
        store_resource "$resource_json"
        log_success "Resource stored in state database: $resource_name"
        return 0
    else
        log_warn "Failed to query resource from Azure: $resource_name"
        return 1
    fi
}

# ==============================================================================
# ROLLBACK EXECUTION
# ==============================================================================

execute_rollback() {
    local yaml_file="$1"
    local operation_exec_id="$2"
    local failed_step_index="$3"

    log_warn "Initiating rollback for operation: $operation_exec_id" "$operation_exec_id"

    local rollback_steps=$(get_rollback_steps "$yaml_file")
    local rollback_count=$(echo "$rollback_steps" | jq 'length')

    if [[ "$rollback_count" == "0" ]]; then
        log_warn "No rollback steps defined" "$operation_exec_id"
        return 0
    fi

    log_info "Executing $rollback_count rollback steps in reverse order..." "$operation_exec_id"

    # Execute rollback steps in reverse order
    local i=$((rollback_count - 1))
    while [[ $i -ge 0 ]]; do
        local step=$(echo "$rollback_steps" | jq -r ".[$i]")
        local step_name=$(echo "$step" | jq -r '.name')
        local step_command=$(echo "$step" | jq -r '.command')

        log_info "Rollback step $((rollback_count - i))/$rollback_count: $step_name" "$operation_exec_id"

        # Substitute variables
        local resolved_command=$(substitute_variables "$step_command")

        # Execute rollback step (best effort - don't fail rollback on error)
        local exit_code=0
        local output=""
        output=$(eval "$resolved_command" 2>&1) || exit_code=$?

        if [[ $exit_code -eq 0 ]]; then
            log_success "Rollback step completed: $step_name" "$operation_exec_id"
        else
            log_warn "Rollback step failed (non-fatal): $step_name" "$operation_exec_id"
            log_warn "Exit code: $exit_code, Output: $output" "$operation_exec_id"
        fi

        ((i--))
    done

    log_info "Rollback completed" "$operation_exec_id"

    # Save rollback script for manual re-run if needed
    save_rollback_script "$yaml_file" "$operation_exec_id"

    return 0
}

# Save rollback script to file for manual execution
save_rollback_script() {
    local yaml_file="$1"
    local operation_exec_id="$2"

    local rollback_script="${ROLLBACK_SCRIPTS_DIR}/rollback_${operation_exec_id}.sh"

    log_info "Saving rollback script to: $rollback_script" "$operation_exec_id"

    cat > "$rollback_script" <<'SCRIPT_HEADER'
#!/bin/bash
# ==============================================================================
# Rollback Script
# ==============================================================================
# Generated by executor.sh
# This script can be executed manually if automatic rollback fails
# ==============================================================================

set -euo pipefail

SCRIPT_HEADER

    echo "# Operation: $(yq eval '.operation.name' "$yaml_file")" >> "$rollback_script"
    echo "# Execution ID: $operation_exec_id" >> "$rollback_script"
    echo "# Generated: $(date)" >> "$rollback_script"
    echo "" >> "$rollback_script"

    local rollback_steps=$(get_rollback_steps "$yaml_file")
    local rollback_count=$(echo "$rollback_steps" | jq 'length')

    if [[ "$rollback_count" == "0" ]]; then
        echo "# No rollback steps defined" >> "$rollback_script"
        chmod +x "$rollback_script"
        return 0
    fi

    # Add rollback steps in reverse order
    local i=$((rollback_count - 1))
    while [[ $i -ge 0 ]]; do
        local step=$(echo "$rollback_steps" | jq -r ".[$i]")
        local step_name=$(echo "$step" | jq -r '.name')
        local step_command=$(echo "$step" | jq -r '.command')

        echo "# Step: $step_name" >> "$rollback_script"
        echo "echo '[*] Executing: $step_name'" >> "$rollback_script"

        # Substitute variables
        local resolved_command=$(substitute_variables "$step_command")
        echo "$resolved_command" >> "$rollback_script"
        echo "" >> "$rollback_script"

        ((i--))
    done

    echo "echo '[v] Rollback completed'" >> "$rollback_script"

    chmod +x "$rollback_script"
    log_success "Rollback script saved: $rollback_script" "$operation_exec_id"
}

# ==============================================================================
# DRY RUN
# ==============================================================================

dry_run() {
    local yaml_file="$1"

    log_info "==================================================================="
    log_info "DRY RUN MODE - No changes will be made"
    log_info "==================================================================="

    # Set dry-run mode
    export EXECUTION_MODE="dry-run"

    # Parse operation
    if ! parse_operation_file "$yaml_file"; then
        log_error "Failed to parse operation file"
        return 1
    fi

    local operation_id=$(yq eval '.operation.id' "$yaml_file")
    local operation_name=$(yq eval '.operation.name' "$yaml_file")
    local operation_type=$(yq eval '.operation.type' "$yaml_file")

    echo ""
    echo "Operation Details:"
    echo "  ID: $operation_id"
    echo "  Name: $operation_name"
    echo "  Type: $operation_type"
    echo ""

    # Show prerequisites
    echo "Prerequisites:"
    local prerequisites=$(get_prerequisites "$yaml_file")
    local prereq_count=$(echo "$prerequisites" | jq 'length')

    if [[ "$prereq_count" == "0" ]]; then
        echo "  None"
    else
        local i=0
        while [[ $i -lt $prereq_count ]]; do
            local prereq=$(echo "$prerequisites" | jq -r ".[$i]")
            local resource_type=$(echo "$prereq" | jq -r '.resource_type')
            local name_from_config=$(echo "$prereq" | jq -r '.name_from_config // empty')
            local resource_name=$(echo "$prereq" | jq -r '.name // empty')

            if [[ -n "$name_from_config" ]]; then
                resource_name="${!name_from_config:-<not set>}"
            fi

            echo "  $((i+1)). $resource_type: $resource_name"
            ((i++))
        done
    fi
    echo ""

    # Show steps
    echo "Execution Steps:"
    local steps=$(get_steps "$yaml_file")
    local step_count=$(echo "$steps" | jq 'length')
    local i=0

    while [[ $i -lt $step_count ]]; do
        local step=$(echo "$steps" | jq -r ".[$i]")
        local step_name=$(echo "$step" | jq -r '.name')
        local step_command=$(echo "$step" | jq -r '.command')

        echo "  $((i+1)). $step_name"
        local resolved_command=$(substitute_variables "$step_command")
        echo "     Command: $resolved_command"
        ((i++))
    done
    echo ""

    # Show rollback steps
    echo "Rollback Steps:"
    local rollback_steps=$(get_rollback_steps "$yaml_file")
    local rollback_count=$(echo "$rollback_steps" | jq 'length')

    if [[ "$rollback_count" == "0" ]]; then
        echo "  None"
    else
        local i=0
        while [[ $i -lt $rollback_count ]]; do
            local step=$(echo "$rollback_steps" | jq -r ".[$i]")
            local step_name=$(echo "$step" | jq -r '.name')
            local step_command=$(echo "$step" | jq -r '.command')

            echo "  $((i+1)). $step_name"
            local resolved_command=$(substitute_variables "$step_command")
            echo "     Command: $resolved_command"
            ((i++))
        done
    fi
    echo ""

    log_info "==================================================================="
    log_info "Dry run completed - ready for execution"
    log_info "==================================================================="

    # Reset execution mode
    export EXECUTION_MODE="normal"

    return 0
}

# ==============================================================================
# EXECUTE WITH ROLLBACK (Main Entry Point)
# ==============================================================================

execute_with_rollback() {
    local yaml_file="$1"
    local force_mode="${2:-false}"

    # Ensure configuration is loaded
    if [[ -z "${AZURE_RESOURCE_GROUP:-}" ]]; then
        log_info "Loading configuration..."
        load_config || {
            log_error "Failed to load configuration"
            return 1
        }
    fi

    # Execute operation (rollback is handled internally)
    execute_operation "$yaml_file" "$force_mode"
    return $?
}

# ==============================================================================
# COMMAND LINE INTERFACE
# ==============================================================================

show_usage() {
    cat <<EOF
Usage: executor.sh <command> <operation-file> [options]

Commands:
  execute <file>       Execute operation with automatic rollback on failure
  dry-run <file>       Show what would be executed without making changes
  force <file>         Execute without prerequisite validation

Options:
  -h, --help          Show this help message

Examples:
  # Execute an operation
  ./core/executor.sh execute operations/create-vm.yaml

  # Dry run to preview
  ./core/executor.sh dry-run operations/create-vm.yaml

  # Force execution (skip prerequisites)
  ./core/executor.sh force operations/create-vm.yaml

EOF
}

# Main CLI handler
main() {
    if [[ $# -lt 2 ]]; then
        show_usage
        exit 1
    fi

    local command="$1"
    local operation_file="$2"

    case "$command" in
        execute)
            execute_with_rollback "$operation_file" "false"
            ;;
        dry-run)
            dry_run "$operation_file"
            ;;
        force)
            execute_with_rollback "$operation_file" "true"
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            echo "Unknown command: $command"
            show_usage
            exit 1
            ;;
    esac
}

# Run main if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
