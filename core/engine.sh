#!/bin/bash
# ==============================================================================
# Main Engine - Thin Wrapper for Executor (Unified Execution Path)
# ==============================================================================
#
# Purpose: Main CLI entry point that delegates to executor.sh for all operations
# Status: REFACTORED - Now uses unified execution path via executor.sh
#
# Usage:
#   ./core/engine.sh run <operation-id>
#   ./core/engine.sh workflow <workflow-id>
#   ./core/engine.sh resume
#   ./core/engine.sh status
#   ./core/engine.sh list
#
# Examples:
#   ./core/engine.sh run golden-image-install-apps           # Run golden image app installation
#   ./core/engine.sh run vnet-create                         # Run VNet creation operation
#   ./core/engine.sh run storage-account-create              # Run storage account creation
#   ./core/engine.sh workflow full-deployment                # Run multi-step workflow
#   ./core/engine.sh resume                                  # Resume from failure
#   ./core/engine.sh status                                  # Show current state
#   ./core/engine.sh list                                    # List all capability operations
#
# Architecture:
#   - This script is a THIN WRAPPER for backward CLI compatibility
#   - All operation execution is delegated to core/executor.sh
#   - Workflow execution is delegated to core/workflow-engine.sh
#   - Legacy module-based execution is DEPRECATED
#
# ==============================================================================

set -euo pipefail

# Project paths
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PROJECT_ROOT

# Legacy state.json - DEPRECATED, kept only for migration
STATE_FILE="${PROJECT_ROOT}/state.json"

# Current directories
CAPABILITIES_DIR="${PROJECT_ROOT}/capabilities"
LOGS_DIR="${PROJECT_ROOT}/artifacts/logs"

# ==============================================================================
# UNIFIED EXECUTION ARCHITECTURE
# ==============================================================================
# This engine.sh provides CLI backward compatibility while delegating all
# execution to the unified executor.sh:
#
# EXECUTION FLOW:
#   1. engine.sh (THIS FILE) - CLI wrapper, state management, operation discovery
#      └─> Delegates to executor.sh for ALL operation execution
#
#   2. executor.sh - Unified operation execution engine
#      - Prerequisite validation
#      - Step execution with rollback
#      - State tracking
#      - Resource queries
#
#   3. workflow-engine.sh - Multi-step orchestration
#      └─> Calls executor.sh for individual operation execution
#
# DEPRECATED PATHS (Backward Compatibility Only):
#   - Module-based execution (execute_module)
#   - Parallel group execution (execute_parallel_group)
#   - Legacy operation formats
#
# RECOMMENDED USAGE:
#   - Direct operation: ./core/engine.sh run <operation-id>
#   - Multi-step workflow: ./core/engine.sh workflow <workflow-id>
#   - All new operations should use capability format
# ==============================================================================

# Source core components
source "${PROJECT_ROOT}/core/config-manager.sh"
source "${PROJECT_ROOT}/core/template-engine.sh"
source "${PROJECT_ROOT}/core/progress-tracker.sh"
source "${PROJECT_ROOT}/core/error-handler.sh"
source "${PROJECT_ROOT}/core/logger.sh"
source "${PROJECT_ROOT}/core/executor.sh"  # UNIFIED EXECUTION ENGINE (primary execution path)
source "${PROJECT_ROOT}/core/state-manager.sh"  # SQLite-based state management

# ==============================================================================
# Initialize State Database (SQLite)
# ==============================================================================
init_state() {
    # Initialize SQLite database
    init_state_db || {
        log_error "Failed to initialize state database" "engine"
        return 1
    }

    # Migrate existing state.json if present (backward compatibility)
    if [[ -f "$STATE_FILE" ]]; then
        migrate_json_to_sqlite
    fi
}

# ==============================================================================
# Migrate Legacy JSON State to SQLite (Backward Compatibility)
# ==============================================================================
migrate_json_to_sqlite() {
    log_info "Migrating legacy state.json to SQLite database" "engine"

    # Check if state.json has any operations
    local operation_count
    operation_count=$(jq '.operations | length' "$STATE_FILE" 2>/dev/null || echo "0")

    if [[ "$operation_count" -eq 0 ]]; then
        log_info "No operations in state.json to migrate" "engine"
        return 0
    fi

    # Extract and migrate each operation
    local operation_ids
    operation_ids=$(jq -r '.operations | keys[]' "$STATE_FILE" 2>/dev/null)

    while IFS= read -r op_id; do
        if [[ -z "$op_id" ]]; then
            continue
        fi

        # Get operation data from JSON
        local status
        local duration
        local timestamp

        status=$(jq -r ".operations[\"$op_id\"].status // \"unknown\"" "$STATE_FILE")
        duration=$(jq -r ".operations[\"$op_id\"].duration // 0" "$STATE_FILE")
        timestamp=$(jq -r ".operations[\"$op_id\"].timestamp // \"\"" "$STATE_FILE")

        # Convert ISO 8601 timestamp to Unix epoch
        local started_at
        if [[ -n "$timestamp" && "$timestamp" != "null" ]]; then
            started_at=$(date -d "$timestamp" +%s 2>/dev/null || echo "$(get_timestamp)")
        else
            started_at=$(get_timestamp)
        fi

        # Check if operation already exists in SQLite
        local exists
        exists=$(execute_sql "SELECT COUNT(*) FROM operations WHERE operation_id = '$(sql_escape "$op_id")';" 2>/dev/null || echo "0")

        if [[ "$exists" -eq 0 ]]; then
            # Create operation record in SQLite
            local completed_at="NULL"
            if [[ "$status" == "completed" || "$status" == "failed" ]]; then
                completed_at=$((started_at + duration))
            fi

            local sql="
INSERT INTO operations (
    operation_id, capability, operation_name, operation_type,
    status, started_at, completed_at, duration
) VALUES (
    '$(sql_escape "$op_id")',
    'legacy',
    '$(sql_escape "$op_id")',
    'migrated',
    '$(sql_escape "$status")',
    $started_at,
    $completed_at,
    $duration
);"

            execute_sql "$sql" "Failed to migrate operation: $op_id" 2>/dev/null || {
                log_warn "Could not migrate operation: $op_id" "engine"
                continue
            }

            log_info "Migrated operation: $op_id ($status)" "engine"
        fi
    done <<< "$operation_ids"

    # Rename state.json to state.json.migrated
    local backup_file="${STATE_FILE}.migrated.$(date +%Y%m%d_%H%M%S)"
    mv "$STATE_FILE" "$backup_file"
    log_success "Legacy state.json migrated to SQLite and backed up to: $backup_file" "engine"

    return 0
}

# ==============================================================================
# Update State (SQLite-based)
# ==============================================================================
# Note: Global state fields (current_module, current_operation, status) are now
# tracked via the operations table. Legacy update_state() is kept for compatibility
# but now uses SQLite metadata table.

update_state() {
    local field="$1"
    local value="$2"

    # Store in a metadata table for global state
    local now=$(get_timestamp)
    local sql="
CREATE TABLE IF NOT EXISTS state_metadata (
    key TEXT PRIMARY KEY,
    value TEXT,
    updated_at INTEGER
);

INSERT INTO state_metadata (key, value, updated_at)
VALUES ('$(sql_escape "$field")', '$(sql_escape "$value")', $now)
ON CONFLICT(key) DO UPDATE SET
    value = excluded.value,
    updated_at = excluded.updated_at;
"

    execute_sql "$sql" "Failed to update state: $field" >/dev/null 2>&1 || {
        log_warn "Could not update state metadata: $field" "engine"
        return 1
    }

    return 0
}

update_operation_state() {
    local operation_id="$1"
    local status="$2"
    local duration="${3:-0}"

    # Check if operation exists, create if not
    local exists
    exists=$(execute_sql "SELECT COUNT(*) FROM operations WHERE operation_id = '$(sql_escape "$operation_id")';" 2>/dev/null || echo "0")

    if [[ "$exists" -eq 0 ]]; then
        # Create new operation record
        create_operation "$operation_id" "engine" "$operation_id" "operation" "" >/dev/null 2>&1 || true
    fi

    # Update operation status using state-manager function
    update_operation_status "$operation_id" "$status" "" || {
        log_warn "Could not update operation state: $operation_id" "engine"
        return 1
    }

    return 0
}

update_module_state() {
    local module_id="$1"
    local status="$2"

    # Modules are stored as operations with type 'module'
    local exists
    exists=$(execute_sql "SELECT COUNT(*) FROM operations WHERE operation_id = '$(sql_escape "$module_id")';" 2>/dev/null || echo "0")

    if [[ "$exists" -eq 0 ]]; then
        # Create module operation record
        create_operation "$module_id" "module" "$module_id" "module" "" >/dev/null 2>&1 || true
    fi

    # Update module status
    update_operation_status "$module_id" "$status" "" || {
        log_warn "Could not update module state: $module_id" "engine"
        return 1
    }

    return 0
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
# Execute Single Operation (UNIFIED - Delegates to executor.sh)
# ==============================================================================
# REFACTORED: This function now delegates ALL execution to executor.sh
# - Provides backward compatibility for legacy CLI calls
# - Maintains state tracking for resume functionality
# - Supports both capability and legacy operation formats
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

    # DEPRECATED WARNING for legacy module-based operations
    if [[ "$operation_format" == "legacy" ]]; then
        log_warn "DEPRECATED: Legacy module-based operation format detected" "engine"
        log_warn "Consider migrating to capability-based operations for better maintainability" "engine"
        log_warn "See docs/guides/migration.md for migration guide" "engine"
    fi

    # Update global state tracking (for resume functionality)
    update_state "current_operation" "$operation_id"
    update_state "status" "running"

    local start_time=$(date +%s)

    # UNIFIED EXECUTION: Delegate to executor.sh for ALL operations
    # The executor handles:
    # - Prerequisite validation
    # - Step execution
    # - Rollback on failure
    # - State tracking
    # - Resource queries
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
}

# ==============================================================================
# Execute Operations in Parallel Group (DEPRECATED)
# ==============================================================================
# DEPRECATED: Module-based parallel execution is deprecated
# - Use workflow-engine.sh with parallel steps instead
# - Maintained for backward compatibility only
# ==============================================================================
execute_parallel_group() {
    local module_dir="$1"
    shift
    local operations=($@)
    local pids=()
    local results=()
    local op_count=${#operations[@]}

    log_warn "DEPRECATED: Parallel group execution via modules is deprecated" "engine"
    log_warn "Use workflow-engine.sh with parallel execution for new implementations" "engine"

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
# Execute Module (DEPRECATED - Legacy Module-Based Execution)
# ==============================================================================
# DEPRECATED: Module-based execution is deprecated in favor of:
# - Direct operation execution via capabilities/
# - Multi-step workflows via workflow-engine.sh
# - Maintained for backward compatibility only
# ==============================================================================
execute_module() {
    local module_name="$1"
    local module_dir="${MODULES_DIR}/${module_name}"

    log_warn "DEPRECATED: Module-based execution is deprecated" "engine"
    log_warn "Migrate to capability operations or workflows for new implementations" "engine"
    log_warn "See docs/guides/migration.md for migration guidance" "engine"

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
# Resume from Failure (SQLite-based)
# ==============================================================================
resume_execution() {
    log_info "Resuming from previous state" "engine"

    # Check for failed operations in SQLite
    local failed_ops
    failed_ops=$(execute_sql "
SELECT operation_id, capability, operation_name, status, retry_count, max_retries
FROM operations
WHERE status = 'failed'
AND retry_count < max_retries
ORDER BY started_at DESC
LIMIT 1;
" 2>/dev/null)

    if [[ -z "$failed_ops" ]]; then
        log_info "No failed operations to resume" "engine"
        return 0
    fi

    # Parse the failed operation
    local failed_operation
    failed_operation=$(echo "$failed_ops" | awk -F'|' '{print $1}')

    if [[ -z "$failed_operation" ]]; then
        log_info "No failed operations found" "engine"
        return 0
    fi

    log_info "Found failed operation: $failed_operation" "engine"

    # Get current module from state metadata (if exists)
    local current_module
    current_module=$(execute_sql "SELECT value FROM state_metadata WHERE key = 'current_module';" 2>/dev/null || echo "")

    echo ""
    echo "Resume failed operation: $failed_operation?"
    read -p "Retry? (y/n): " -n 1 -r
    echo ""

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Increment retry counter
        execute_sql "
UPDATE operations
SET retry_count = retry_count + 1
WHERE operation_id = '$(sql_escape "$failed_operation")';
" >/dev/null 2>&1

        # Determine module directory (if module-based)
        local module_dir=""
        if [[ -n "$current_module" && "$current_module" != "null" ]]; then
            module_dir="${MODULES_DIR}/${current_module}"
        fi

        execute_single_operation "$module_dir" "$failed_operation"
        return $?
    else
        log_info "Resume cancelled by user" "engine"
        return 1
    fi
}

# ==============================================================================
# Show Current Status (SQLite-based)
# ==============================================================================
show_status() {
    if [[ ! -f "$STATE_DB" ]]; then
        echo "No state database found"
        echo "Run an operation first to initialize state tracking"
        return 0
    fi

    # Get global status from metadata
    local status
    status=$(execute_sql "SELECT value FROM state_metadata WHERE key = 'status';" 2>/dev/null || echo "unknown")

    local current_module
    current_module=$(execute_sql "SELECT value FROM state_metadata WHERE key = 'current_module';" 2>/dev/null || echo "none")

    local current_operation
    current_operation=$(execute_sql "SELECT value FROM state_metadata WHERE key = 'current_operation';" 2>/dev/null || echo "none")

    echo "=========================================="
    echo "  Deployment State"
    echo "=========================================="
    echo "Status: $status"
    echo "Current Module: $current_module"
    echo "Current Operation: $current_operation"
    echo ""

    # Show operation summary
    echo "Operations Summary:"
    echo "------------------------------------------"

    local summary
    summary=$(execute_sql "
SELECT
    status,
    COUNT(*) as count
FROM operations
GROUP BY status
ORDER BY
    CASE status
        WHEN 'running' THEN 1
        WHEN 'failed' THEN 2
        WHEN 'completed' THEN 3
        WHEN 'pending' THEN 4
        ELSE 5
    END;
" 2>/dev/null)

    if [[ -n "$summary" ]]; then
        echo "$summary" | while IFS='|' read -r op_status count; do
            printf "  %-15s : %d\n" "$op_status" "$count"
        done
    else
        echo "  No operations tracked yet"
    fi

    echo ""
    echo "Recent Operations (last 10):"
    echo "------------------------------------------"

    local recent_ops
    recent_ops=$(execute_sql "
SELECT
    operation_id,
    status,
    datetime(started_at, 'unixepoch', 'localtime') as started,
    COALESCE(duration, 0) as duration
FROM operations
ORDER BY started_at DESC
LIMIT 10;
" 2>/dev/null)

    if [[ -n "$recent_ops" ]]; then
        echo "$recent_ops" | while IFS='|' read -r op_id op_status started dur; do
            printf "  %-35s : %-10s [%s] (%ds)\n" "$op_id" "$op_status" "$started" "$dur"
        done
    else
        echo "  No operations found"
    fi

    echo "=========================================="
    echo ""
    echo "Use 'sqlite3 $STATE_DB' to query state directly"
    echo "Or run: ./core/engine.sh resume"
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