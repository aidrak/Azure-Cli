#!/bin/bash
# ==============================================================================
# Capability Executor - Capability-Based Operation Execution Engine
# ==============================================================================
#
# Purpose: Load and execute capability-based operations with parameter handling
#
# Usage:
#   source core/capability-executor.sh
#   execute_capability_operation "compute" "create-vm" '{"vm_name": "test-vm"}'
#   list_capability_operations "compute"
#   validate_capability_operation "storage" "create-account"
#
# Features:
#   - Capability-based operation loading
#   - Parameter validation and merging
#   - Type checking (string, boolean, number, secret, object)
#   - Operation mode validation (create/adopt/modify/validate)
#   - Integration with executor.sh for actual execution
#   - Comprehensive error handling
#
# ==============================================================================

set -euo pipefail

# ==============================================================================
# CONFIGURATION
# ==============================================================================

PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
CAPABILITIES_DIR="${PROJECT_ROOT}/capabilities"
ARTIFACTS_DIR="${PROJECT_ROOT}/artifacts"

# Supported operation modes
VALID_OPERATION_MODES=("create" "adopt" "modify" "validate" "delete")

# Supported parameter types
VALID_PARAMETER_TYPES=("string" "boolean" "number" "secret" "object" "array")

# ==============================================================================
# SOURCE DEPENDENCIES
# ==============================================================================

if [[ -f "${PROJECT_ROOT}/core/executor.sh" ]]; then
    source "${PROJECT_ROOT}/core/executor.sh"
else
    echo "[x] ERROR: executor.sh not found" >&2
    exit 1
fi

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

# ==============================================================================
# CAPABILITY METADATA FUNCTIONS
# ==============================================================================

# Load capability metadata from capability.yaml
# Args: capability (e.g., "compute", "networking")
# Returns: JSON object with capability details
load_capability_metadata() {
    local capability="$1"

    if [[ -z "$capability" ]]; then
        log_error "Capability name is required"
        return 1
    fi

    local capability_file="${CAPABILITIES_DIR}/${capability}/capability.yaml"

    if [[ ! -f "$capability_file" ]]; then
        log_error "Capability not found: $capability (expected: $capability_file)"
        return 1
    fi

    # Validate YAML syntax
    if ! yq eval '.' "$capability_file" &>/dev/null; then
        log_error "Invalid YAML syntax in capability file: $capability_file"
        return 1
    fi

    # Check required fields
    local cap_id=$(yq eval '.capability.id' "$capability_file")
    local cap_name=$(yq eval '.capability.name' "$capability_file")

    if [[ -z "$cap_id" ]] || [[ "$cap_id" == "null" ]]; then
        log_error "Missing required field: capability.id in $capability_file"
        return 1
    fi

    if [[ -z "$cap_name" ]] || [[ "$cap_name" == "null" ]]; then
        log_error "Missing required field: capability.name in $capability_file"
        return 1
    fi

    # Return capability metadata as JSON
    yq eval -o=json '.' "$capability_file"
    return 0
}

# List all operations for a capability
# Args: capability
# Returns: JSON array of operations
list_capability_operations() {
    local capability="$1"

    if [[ -z "$capability" ]]; then
        log_error "Capability name is required"
        return 1
    fi

    local operations_dir="${CAPABILITIES_DIR}/${capability}/operations"

    if [[ ! -d "$operations_dir" ]]; then
        log_error "Operations directory not found: $operations_dir"
        return 1
    fi

    log_info "Listing operations for capability: $capability"

    # Load capability metadata to get operation list
    local capability_metadata
    capability_metadata=$(load_capability_metadata "$capability") || {
        log_error "Failed to load capability metadata"
        return 1
    }

    # Extract operations from capability metadata
    local operations
    operations=$(echo "$capability_metadata" | jq -c '.capability.operations // []')

    local operation_count=$(echo "$operations" | jq 'length')

    if [[ "$operation_count" -eq 0 ]]; then
        log_warn "No operations defined for capability: $capability"
        echo "[]"
        return 0
    fi

    log_info "Found $operation_count operations in capability: $capability"

    # Build detailed operation list with file existence check
    local detailed_operations="[]"
    local i=0

    while [[ $i -lt $operation_count ]]; do
        local operation=$(echo "$operations" | jq -r ".[$i]")
        local operation_id=$(echo "$operation" | jq -r '.id')
        local operation_name=$(echo "$operation" | jq -r '.name')
        local operation_mode=$(echo "$operation" | jq -r '.mode // "create"')
        local operation_file="${operations_dir}/${operation_id}.yaml"

        # Check if operation file exists
        local file_exists="false"
        if [[ -f "$operation_file" ]]; then
            file_exists="true"
        fi

        # Add to detailed list
        local operation_detail
        operation_detail=$(jq -n \
            --arg id "$operation_id" \
            --arg name "$operation_name" \
            --arg mode "$operation_mode" \
            --arg file "$operation_file" \
            --argjson exists "$file_exists" \
            '{
                id: $id,
                name: $name,
                mode: $mode,
                file: $file,
                exists: $exists
            }')

        detailed_operations=$(echo "$detailed_operations" | jq ". += [$operation_detail]")

        ((i++))
    done

    echo "$detailed_operations"
    return 0
}

# Get operation file path
# Args: capability, operation_id
# Returns: Full path to operation YAML file
get_operation_file_path() {
    local capability="$1"
    local operation_id="$2"

    if [[ -z "$capability" ]] || [[ -z "$operation_id" ]]; then
        log_error "Capability and operation_id are required"
        return 1
    fi

    echo "${CAPABILITIES_DIR}/${capability}/operations/${operation_id}.yaml"
}

# ==============================================================================
# OPERATION VALIDATION
# ==============================================================================

# Validate capability operation exists and is properly configured
# Args: capability, operation_id
# Returns: 0 if valid, 1 otherwise
validate_capability_operation() {
    local capability="$1"
    local operation_id="$2"

    if [[ -z "$capability" ]] || [[ -z "$operation_id" ]]; then
        log_error "Capability and operation_id are required"
        return 1
    fi

    log_info "Validating capability operation: $capability/$operation_id"

    # Check capability exists
    local capability_file="${CAPABILITIES_DIR}/${capability}/capability.yaml"
    if [[ ! -f "$capability_file" ]]; then
        log_error "Capability not found: $capability"
        return 1
    fi

    # Check operation file exists
    local operation_file
    operation_file=$(get_operation_file_path "$capability" "$operation_id")

    if [[ ! -f "$operation_file" ]]; then
        log_error "Operation file not found: $operation_file"
        return 1
    fi

    # Validate YAML syntax
    if ! yq eval '.' "$operation_file" &>/dev/null; then
        log_error "Invalid YAML syntax in operation file: $operation_file"
        return 1
    fi

    # Check required fields
    local op_id=$(yq eval '.operation.id' "$operation_file")
    local op_name=$(yq eval '.operation.name' "$operation_file")
    local op_mode=$(yq eval '.operation.mode // "create"' "$operation_file")

    if [[ -z "$op_id" ]] || [[ "$op_id" == "null" ]]; then
        log_error "Missing required field: operation.id in $operation_file"
        return 1
    fi

    if [[ -z "$op_name" ]] || [[ "$op_name" == "null" ]]; then
        log_error "Missing required field: operation.name in $operation_file"
        return 1
    fi

    # Validate operation mode
    local mode_valid=false
    for valid_mode in "${VALID_OPERATION_MODES[@]}"; do
        if [[ "$op_mode" == "$valid_mode" ]]; then
            mode_valid=true
            break
        fi
    done

    if [[ "$mode_valid" == "false" ]]; then
        log_error "Invalid operation mode: $op_mode (valid: ${VALID_OPERATION_MODES[*]})"
        return 1
    fi

    # Check if operation is registered in capability.yaml
    local capability_metadata
    capability_metadata=$(load_capability_metadata "$capability") || {
        log_error "Failed to load capability metadata"
        return 1
    }

    local registered
    registered=$(echo "$capability_metadata" | jq --arg op_id "$operation_id" '.capability.operations[] | select(.id == $op_id) | .id // empty')

    if [[ -z "$registered" ]]; then
        log_warn "Operation not registered in capability.yaml: $operation_id"
        # Not fatal - continue anyway
    fi

    # Verify prerequisites (if any)
    local prerequisites
    prerequisites=$(yq eval '.prerequisites // []' "$operation_file")
    local prereq_count=$(echo "$prerequisites" | yq eval 'length' -)

    if [[ "$prereq_count" -gt 0 ]]; then
        log_info "Operation has $prereq_count prerequisites defined"
    fi

    log_success "Operation validated: $capability/$operation_id"
    return 0
}

# ==============================================================================
# PARAMETER HANDLING
# ==============================================================================

# Parse CLI parameters from command-line arguments
# Args: remaining command-line arguments (e.g., --vm-name test-vm --size Standard_D2s_v3)
# Returns: JSON object with parameters
parse_cli_parameters() {
    local params="{}"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --*)
                local key="${1#--}"
                local value="${2:-}"

                # Convert kebab-case to snake_case
                key=$(echo "$key" | tr '-' '_')

                # Detect value type
                if [[ "$value" =~ ^[0-9]+$ ]]; then
                    # Number
                    params=$(echo "$params" | jq --arg k "$key" --argjson v "$value" '. + {($k): $v}')
                elif [[ "$value" == "true" ]] || [[ "$value" == "false" ]]; then
                    # Boolean
                    params=$(echo "$params" | jq --arg k "$key" --argjson v "$value" '. + {($k): $v}')
                elif [[ "$value" == "{"* ]] || [[ "$value" == "["* ]]; then
                    # JSON object or array
                    params=$(echo "$params" | jq --arg k "$key" --argjson v "$value" '. + {($k): $v}')
                else
                    # String
                    params=$(echo "$params" | jq --arg k "$key" --arg v "$value" '. + {($k): $v}')
                fi

                shift 2
                ;;
            *)
                log_warn "Ignoring unrecognized parameter: $1"
                shift
                ;;
        esac
    done

    echo "$params"
}

# Validate parameter types
# Args: parameter_schema (JSON), user_params (JSON)
# Returns: 0 if valid, 1 otherwise
validate_parameter_types() {
    local parameter_schema="$1"
    local user_params="$2"

    if [[ -z "$parameter_schema" ]] || [[ "$parameter_schema" == "null" ]] || [[ "$parameter_schema" == "{}" ]]; then
        # No schema defined - skip validation
        return 0
    fi

    log_debug "Validating parameter types..."

    # Get all parameter names from schema
    local param_names
    param_names=$(echo "$parameter_schema" | jq -r 'keys[]')

    local validation_errors=0

    for param_name in $param_names; do
        local expected_type=$(echo "$parameter_schema" | jq -r --arg name "$param_name" '.[$name].type // "string"')
        local actual_value=$(echo "$user_params" | jq -r --arg name "$param_name" '.[$name] // empty')

        if [[ -z "$actual_value" ]]; then
            # Parameter not provided - will be checked in required validation
            continue
        fi

        # Validate type
        case "$expected_type" in
            string)
                # Always valid (jq returns strings by default)
                ;;
            boolean)
                if [[ "$actual_value" != "true" ]] && [[ "$actual_value" != "false" ]]; then
                    log_error "Parameter '$param_name' must be boolean (true/false), got: $actual_value"
                    ((validation_errors++))
                fi
                ;;
            number)
                if ! [[ "$actual_value" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
                    log_error "Parameter '$param_name' must be a number, got: $actual_value"
                    ((validation_errors++))
                fi
                ;;
            secret)
                # Secrets are treated as strings but flagged for secure handling
                log_debug "Parameter '$param_name' is a secret (will be handled securely)"
                ;;
            object)
                # Verify it's valid JSON object
                if ! echo "$user_params" | jq -e --arg name "$param_name" '.[$name] | type == "object"' &>/dev/null; then
                    log_error "Parameter '$param_name' must be an object"
                    ((validation_errors++))
                fi
                ;;
            array)
                # Verify it's valid JSON array
                if ! echo "$user_params" | jq -e --arg name "$param_name" '.[$name] | type == "array"' &>/dev/null; then
                    log_error "Parameter '$param_name' must be an array"
                    ((validation_errors++))
                fi
                ;;
            *)
                log_warn "Unknown parameter type: $expected_type for parameter: $param_name"
                ;;
        esac
    done

    if [[ $validation_errors -gt 0 ]]; then
        log_error "Parameter type validation failed with $validation_errors errors"
        return 1
    fi

    log_success "Parameter types validated"
    return 0
}

# Resolve operation parameters by merging defaults with user-provided params
# Args: operation_yaml (file path), user_params (JSON string)
# Returns: JSON object with resolved parameters
resolve_operation_parameters() {
    local operation_yaml="$1"
    local user_params="${2:-{}}"

    if [[ ! -f "$operation_yaml" ]]; then
        log_error "Operation file not found: $operation_yaml"
        return 1
    fi

    # Parse user params if it's a string
    if [[ ! "$user_params" =~ ^\{.*\}$ ]] && [[ ! "$user_params" =~ ^\[.*\]$ ]]; then
        log_error "Invalid user parameters JSON: $user_params"
        return 1
    fi

    # Get parameter definitions from operation YAML
    local param_definitions
    param_definitions=$(yq eval -o=json '.operation.parameters // {}' "$operation_yaml")

    # Start with empty resolved parameters
    local resolved_params="{}"

    # Get all parameter names from definitions
    local param_names
    param_names=$(echo "$param_definitions" | jq -r 'keys[]' 2>/dev/null || echo "")

    if [[ -z "$param_names" ]]; then
        log_debug "No parameters defined in operation"
        echo "{}"
        return 0
    fi

    # Process each parameter
    for param_name in $param_names; do
        local param_def
        param_def=$(echo "$param_definitions" | jq --arg name "$param_name" '.[$name]')

        local default_value=$(echo "$param_def" | jq -r '.default // empty')
        local required=$(echo "$param_def" | jq -r '.required // false')
        local from_config=$(echo "$param_def" | jq -r '.from_config // empty')
        local param_type=$(echo "$param_def" | jq -r '.type // "string"')

        # Determine final value (priority: user_params > config > default)
        local final_value=""

        # 1. Check user-provided parameters
        local user_value
        user_value=$(echo "$user_params" | jq -r --arg name "$param_name" '.[$name] // empty')

        if [[ -n "$user_value" ]]; then
            final_value="$user_value"
            log_debug "Parameter '$param_name' = '$final_value' (from user)"
        # 2. Check config variable
        elif [[ -n "$from_config" ]]; then
            # Resolve from environment (config variables are exported as ENV vars)
            final_value="${!from_config:-}"
            if [[ -n "$final_value" ]]; then
                log_debug "Parameter '$param_name' = '$final_value' (from config: $from_config)"
            fi
        # 3. Use default value
        elif [[ -n "$default_value" ]]; then
            final_value="$default_value"
            log_debug "Parameter '$param_name' = '$final_value' (default)"
        fi

        # Check if required parameter is missing
        if [[ "$required" == "true" ]] && [[ -z "$final_value" ]]; then
            log_error "Required parameter missing: $param_name"
            return 1
        fi

        # Add to resolved parameters (with proper type)
        if [[ -n "$final_value" ]]; then
            case "$param_type" in
                number)
                    resolved_params=$(echo "$resolved_params" | jq --arg k "$param_name" --argjson v "$final_value" '. + {($k): $v}')
                    ;;
                boolean)
                    resolved_params=$(echo "$resolved_params" | jq --arg k "$param_name" --argjson v "$final_value" '. + {($k): $v}')
                    ;;
                object|array)
                    resolved_params=$(echo "$resolved_params" | jq --arg k "$param_name" --argjson v "$final_value" '. + {($k): $v}')
                    ;;
                *)
                    # string, secret
                    resolved_params=$(echo "$resolved_params" | jq --arg k "$param_name" --arg v "$final_value" '. + {($k): $v}')
                    ;;
            esac
        fi
    done

    # Validate parameter types
    if ! validate_parameter_types "$param_definitions" "$resolved_params"; then
        log_error "Parameter validation failed"
        return 1
    fi

    echo "$resolved_params"
    return 0
}

# Export parameters as environment variables for operation execution
# Args: resolved_params (JSON)
export_parameters_to_env() {
    local resolved_params="$1"

    if [[ -z "$resolved_params" ]] || [[ "$resolved_params" == "{}" ]] || [[ "$resolved_params" == "null" ]]; then
        log_debug "No parameters to export"
        return 0
    fi

    log_debug "Exporting parameters to environment..."

    # Export each parameter as PARAM_<NAME>
    local param_names
    param_names=$(echo "$resolved_params" | jq -r 'keys[]')

    for param_name in $param_names; do
        local param_value
        param_value=$(echo "$resolved_params" | jq -r --arg name "$param_name" '.[$name]')

        # Convert to uppercase and export
        local env_var_name="PARAM_$(echo "$param_name" | tr '[:lower:]' '[:upper:]')"
        export "$env_var_name"="$param_value"

        log_debug "Exported: $env_var_name=$param_value"
    done

    return 0
}

# ==============================================================================
# CAPABILITY OPERATION EXECUTION
# ==============================================================================

# Execute a capability-based operation
# Args: capability, operation_id, params (JSON string or empty)
# Returns: 0 on success, 1 on failure
execute_capability_operation() {
    local capability="$1"
    local operation_id="$2"
    local params="${3:-{}}"

    if [[ -z "$capability" ]] || [[ -z "$operation_id" ]]; then
        log_error "Usage: execute_capability_operation <capability> <operation_id> [params]"
        return 1
    fi

    log_info "Executing capability operation: $capability/$operation_id"

    # Ensure configuration is loaded
    if [[ -z "${AZURE_RESOURCE_GROUP:-}" ]]; then
        log_info "Loading configuration..."
        load_config || {
            log_error "Failed to load configuration"
            return 1
        }
    fi

    # Initialize state database
    init_state_db || {
        log_error "Failed to initialize state database"
        return 1
    }

    # Validate operation
    if ! validate_capability_operation "$capability" "$operation_id"; then
        log_error "Operation validation failed"
        return 1
    fi

    # Get operation file path
    local operation_file
    operation_file=$(get_operation_file_path "$capability" "$operation_id")

    # Load operation YAML
    local operation_yaml
    operation_yaml=$(yq eval -o=json '.' "$operation_file") || {
        log_error "Failed to parse operation YAML: $operation_file"
        return 1
    }

    # Get operation mode
    local operation_mode
    operation_mode=$(echo "$operation_yaml" | jq -r '.operation.mode // "create"')
    log_info "Operation mode: $operation_mode"

    # Resolve parameters
    log_info "Resolving operation parameters..."
    local resolved_params
    resolved_params=$(resolve_operation_parameters "$operation_file" "$params") || {
        log_error "Failed to resolve operation parameters"
        return 1
    }

    log_success "Parameters resolved successfully"
    log_debug "Resolved parameters: $resolved_params"

    # Export parameters to environment for template substitution
    export_parameters_to_env "$resolved_params"

    # Execute operation using executor.sh
    log_info "Executing operation via executor.sh..."

    local operation_exec_id
    operation_exec_id=$(generate_operation_id "$operation_id")

    # Create operation record in state database
    create_operation "$operation_exec_id" "$capability" "$operation_id" "$operation_mode" "" || {
        log_error "Failed to create operation record"
        return 1
    }

    # Execute the operation
    local execution_result=0
    execute_operation "$operation_file" "false" || execution_result=$?

    if [[ $execution_result -eq 0 ]]; then
        log_success "Capability operation completed successfully: $capability/$operation_id"

        # Update capability metadata (last execution timestamp, etc.)
        update_capability_metadata "$capability" "$operation_id" "completed" || true

        return 0
    else
        log_error "Capability operation failed: $capability/$operation_id"

        # Update capability metadata
        update_capability_metadata "$capability" "$operation_id" "failed" || true

        return 1
    fi
}

# ==============================================================================
# CAPABILITY METADATA UPDATES
# ==============================================================================

# Update capability metadata after operation execution
# Args: capability, operation_id, status
update_capability_metadata() {
    local capability="$1"
    local operation_id="$2"
    local status="$3"

    local capability_file="${CAPABILITIES_DIR}/${capability}/capability.yaml"

    if [[ ! -f "$capability_file" ]]; then
        log_warn "Capability file not found for metadata update: $capability_file"
        return 1
    fi

    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    # Update last_executed timestamp for the operation
    # This uses yq to update the YAML in-place
    yq eval -i \
        --arg op_id "$operation_id" \
        --arg ts "$timestamp" \
        --arg status "$status" \
        '(.capability.operations[] | select(.id == $op_id)) += {"last_executed": $ts, "last_status": $status}' \
        "$capability_file" 2>/dev/null || {
        log_warn "Failed to update capability metadata (operation may not be registered)"
        return 1
    }

    log_debug "Updated capability metadata: $capability/$operation_id = $status"
    return 0
}

# ==============================================================================
# COMMAND LINE INTERFACE
# ==============================================================================

show_usage() {
    cat <<EOF
Usage: capability-executor.sh <command> [options]

Commands:
  execute <capability> <operation> [--param value ...]
                      Execute a capability operation with parameters

  list <capability>   List all operations for a capability

  validate <capability> <operation>
                      Validate operation configuration

  show <capability>   Show capability metadata

Options:
  --param-name value  Operation parameters (can specify multiple)
  -h, --help          Show this help message

Examples:
  # Execute operation with parameters
  ./core/capability-executor.sh execute compute create-vm \\
    --vm-name test-vm --vm-size Standard_D2s_v3

  # List operations for a capability
  ./core/capability-executor.sh list compute

  # Validate operation
  ./core/capability-executor.sh validate compute create-vm

  # Show capability metadata
  ./core/capability-executor.sh show compute

EOF
}

# Main CLI handler
main() {
    if [[ $# -lt 1 ]]; then
        show_usage
        exit 1
    fi

    local command="$1"
    shift

    case "$command" in
        execute)
            if [[ $# -lt 2 ]]; then
                echo "Error: execute requires capability and operation_id"
                echo ""
                show_usage
                exit 1
            fi

            local capability="$1"
            local operation_id="$2"
            shift 2

            # Parse remaining arguments as parameters
            local params
            if [[ $# -gt 0 ]]; then
                params=$(parse_cli_parameters "$@")
            else
                params="{}"
            fi

            execute_capability_operation "$capability" "$operation_id" "$params"
            ;;

        list)
            if [[ $# -lt 1 ]]; then
                echo "Error: list requires capability name"
                echo ""
                show_usage
                exit 1
            fi

            local capability="$1"
            local operations
            operations=$(list_capability_operations "$capability")

            echo ""
            echo "Operations for capability: $capability"
            echo "========================================"
            echo "$operations" | jq -r '.[] | "  [\(.mode)] \(.id) - \(.name) (exists: \(.exists))"'
            echo ""
            ;;

        validate)
            if [[ $# -lt 2 ]]; then
                echo "Error: validate requires capability and operation_id"
                echo ""
                show_usage
                exit 1
            fi

            local capability="$1"
            local operation_id="$2"

            validate_capability_operation "$capability" "$operation_id"
            ;;

        show)
            if [[ $# -lt 1 ]]; then
                echo "Error: show requires capability name"
                echo ""
                show_usage
                exit 1
            fi

            local capability="$1"
            local metadata
            metadata=$(load_capability_metadata "$capability")

            echo ""
            echo "Capability Metadata: $capability"
            echo "================================="
            echo "$metadata" | jq '.'
            echo ""
            ;;

        -h|--help)
            show_usage
            exit 0
            ;;

        *)
            echo "Unknown command: $command"
            echo ""
            show_usage
            exit 1
            ;;
    esac
}

# ==============================================================================
# EXPORT FUNCTIONS
# ==============================================================================

export -f load_capability_metadata
export -f list_capability_operations
export -f get_operation_file_path
export -f validate_capability_operation
export -f parse_cli_parameters
export -f validate_parameter_types
export -f resolve_operation_parameters
export -f export_parameters_to_env
export -f execute_capability_operation
export -f update_capability_metadata

# ==============================================================================
# INITIALIZATION
# ==============================================================================

log_info "Capability Executor loaded" "capability-executor"

# Run main if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
