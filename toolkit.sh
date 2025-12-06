#!/bin/bash
################################################################################
# Azure Infrastructure Toolkit - Main CLI Entry Point
# Version: 1.0
# Purpose: Unified interface for capability-based operations
################################################################################

set -euo pipefail

# Script directory resolution
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE_DIR="${SCRIPT_DIR}/core"

# Global flags
DRY_RUN=false
VERBOSE=false
DEBUG=false

################################################################################
# Usage and Help Functions
################################################################################

usage() {
    cat <<EOF
Azure Infrastructure Toolkit v1.0

USAGE:
  ./toolkit.sh <command> [options]

COMMANDS:
  exec          Execute a capability operation
  discover      Discover existing Azure resources
  query         Query resources (cache-first)
  validate      Validate infrastructure state
  workflow      Execute workflow definition
  state         Manage state database

GLOBAL OPTIONS:
  --verbose     Enable verbose output
  --debug       Enable debug output
  -h, --help    Show this help message

Run './toolkit.sh <command> --help' for command-specific help

EXAMPLES:
  ./toolkit.sh exec compute vm-create --vm-name test-vm
  ./toolkit.sh discover --resource-type virtualMachines
  ./toolkit.sh query compute --resource-name test-vm
  ./toolkit.sh state show
  ./toolkit.sh workflow run --file workflows/vdi-deployment.yaml

EOF
}

help_exec() {
    cat <<EOF
COMMAND: exec - Execute a capability operation

USAGE:
  ./toolkit.sh exec <capability> <operation> [options]

ARGUMENTS:
  capability    Capability domain (compute, networking, storage, etc.)
  operation     Operation to execute (e.g., vm-create, vnet-adopt)

OPTIONS:
  --dry-run     Show what would be executed without making changes
  --verbose     Enable verbose output
  --debug       Enable debug output
  --KEY VALUE   Operation-specific parameters

EXAMPLES:
  # Create a VM with specific parameters
  ./toolkit.sh exec compute vm-create \\
    --vm-name test-vm \\
    --vm-size Standard_D2s_v5 \\
    --admin-username azureuser

  # Adopt existing VNet (dry-run)
  ./toolkit.sh exec --dry-run networking vnet-adopt \\
    --vnet-name existing-vnet

  # Validate storage account
  ./toolkit.sh exec storage account-validate \\
    --account-name myaccount

  # Create network security group
  ./toolkit.sh exec networking nsg-create \\
    --nsg-name my-nsg \\
    --location eastus

NOTES:
  - Parameters are passed as --key value pairs
  - All parameters are forwarded to the capability executor
  - Use --dry-run to preview operations before execution
  - Operation definitions are in capabilities/<capability>/<operation>.yaml

EOF
}

help_query() {
    cat <<EOF
COMMAND: query - Query resources (cache-first)

USAGE:
  ./toolkit.sh query <capability> [options]

ARGUMENTS:
  capability    Capability domain to query (compute, networking, storage, etc.)

OPTIONS:
  --resource-name NAME    Filter by resource name
  --resource-type TYPE    Filter by resource type
  --tag KEY=VALUE         Filter by tag
  --force-refresh         Skip cache, query Azure directly
  --format FORMAT         Output format (json, table, yaml) [default: table]

EXAMPLES:
  # Query all compute resources
  ./toolkit.sh query compute

  # Query specific VM by name
  ./toolkit.sh query compute --resource-name test-vm

  # Query networking resources with cache refresh
  ./toolkit.sh query networking --force-refresh

  # Query storage accounts with JSON output
  ./toolkit.sh query storage --format json

  # Query by tag
  ./toolkit.sh query compute --tag environment=production

NOTES:
  - Queries use cached data by default (faster)
  - Use --force-refresh to query Azure directly
  - Cache TTL is configurable in state database

EOF
}

help_discover() {
    cat <<EOF
COMMAND: discover - Discover existing Azure resources

USAGE:
  ./toolkit.sh discover [options]

OPTIONS:
  --resource-type TYPE     Discover specific resource type
  --resource-group RG      Limit to specific resource group
  --location LOCATION      Limit to specific location
  --import                 Import discovered resources to state
  --format FORMAT          Output format (json, table, yaml) [default: table]

EXAMPLES:
  # Discover all resources in subscription
  ./toolkit.sh discover

  # Discover VMs only
  ./toolkit.sh discover --resource-type virtualMachines

  # Discover resources in specific resource group
  ./toolkit.sh discover --resource-group my-rg

  # Discover and import to state
  ./toolkit.sh discover --import

  # Discover VNets in East US
  ./toolkit.sh discover \\
    --resource-type virtualNetworks \\
    --location eastus

NOTES:
  - Discovery scans the Azure subscription for existing resources
  - Use --import to add discovered resources to state management
  - Discovered resources can then be managed via capabilities
  - Discovery results are cached in the state database

EOF
}

help_state() {
    cat <<EOF
COMMAND: state - Manage state database

USAGE:
  ./toolkit.sh state <action> [options]

ACTIONS:
  init          Initialize state database
  show          Show state information
  export        Export state to file
  import        Import state from file
  cleanup       Cleanup orphaned state entries

OPTIONS (action-specific):
  show:
    --resource-id ID      Show specific resource
    --capability CAP      Show resources for capability
    --format FORMAT       Output format (json, table) [default: table]

  export:
    --output FILE         Output file path [default: state-export.json]

  import:
    --input FILE          Input file path (required)
    --merge               Merge with existing state

  cleanup:
    --dry-run            Show what would be cleaned without removing
    --force              Skip confirmation prompts

EXAMPLES:
  # Initialize state database
  ./toolkit.sh state init

  # Show all state
  ./toolkit.sh state show

  # Show compute resources
  ./toolkit.sh state show --capability compute

  # Export state
  ./toolkit.sh state export --output backup.json

  # Import state
  ./toolkit.sh state import --input backup.json

  # Cleanup orphaned entries (dry-run)
  ./toolkit.sh state cleanup --dry-run

NOTES:
  - State database tracks all managed resources
  - Regular exports recommended for backup
  - Cleanup removes entries for deleted Azure resources

EOF
}

help_validate() {
    cat <<EOF
COMMAND: validate - Validate infrastructure state

USAGE:
  ./toolkit.sh validate [options]

OPTIONS:
  --capability CAP        Validate specific capability domain
  --resource-id ID        Validate specific resource
  --fix                   Attempt to fix validation failures
  --report FILE           Generate validation report

EXAMPLES:
  # Validate all managed resources
  ./toolkit.sh validate

  # Validate compute resources only
  ./toolkit.sh validate --capability compute

  # Validate and fix issues
  ./toolkit.sh validate --fix

  # Generate validation report
  ./toolkit.sh validate --report validation-report.json

  # Validate specific resource
  ./toolkit.sh validate --resource-id /subscriptions/.../resourceGroups/...

NOTES:
  - Validation checks resource existence and configuration
  - Use --fix to automatically remediate issues
  - Reports include drift detection and recommendations
  - Validation results are logged for audit trail

EOF
}

help_workflow() {
    cat <<EOF
COMMAND: workflow - Execute workflow definition

USAGE:
  ./toolkit.sh workflow <action> [options]

ACTIONS:
  run           Execute a workflow
  validate      Validate workflow definition
  list          List available workflows

OPTIONS:
  run:
    --file FILE           Workflow definition file (required)
    --dry-run            Preview workflow without execution
    --step STEP          Start from specific step
    --var KEY=VALUE      Override workflow variables

  validate:
    --file FILE           Workflow definition file (required)

EXAMPLES:
  # Execute VDI deployment workflow
  ./toolkit.sh workflow run --file workflows/vdi-deployment.yaml

  # Dry-run workflow
  ./toolkit.sh workflow run --dry-run --file workflows/test.yaml

  # Resume from specific step
  ./toolkit.sh workflow run --file workflows/vdi-deployment.yaml --step 3

  # Override workflow variables
  ./toolkit.sh workflow run \\
    --file workflows/deploy.yaml \\
    --var environment=production \\
    --var vm_count=5

  # Validate workflow definition
  ./toolkit.sh workflow validate --file workflows/test.yaml

  # List available workflows
  ./toolkit.sh workflow list

NOTES:
  - Workflows orchestrate multiple capability operations
  - Workflow definitions use YAML format
  - Failed workflows can be resumed from last successful step
  - Variables can be defined in workflow or overridden via CLI

EOF
}

################################################################################
# Utility Functions
################################################################################

log_info() {
    echo "[INFO] $*" >&2
}

log_error() {
    echo "[ERROR] $*" >&2
}

log_debug() {
    if [[ "$DEBUG" == "true" ]]; then
        echo "[DEBUG] $*" >&2
    fi
}

log_verbose() {
    if [[ "$VERBOSE" == "true" ]] || [[ "$DEBUG" == "true" ]]; then
        echo "[VERBOSE] $*" >&2
    fi
}

check_dependencies() {
    local missing_deps=()

    # Check for required commands
    for cmd in jq yq sqlite3; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done

    # Check for Azure CLI
    if ! command -v az &> /dev/null; then
        missing_deps+=("azure-cli")
    fi

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        log_error "Please install missing dependencies and try again"
        exit 1
    fi
}

################################################################################
# Parameter Parsing Functions
################################################################################

parse_exec_params() {
    local json="{"
    local first=true

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --debug)
                DEBUG=true
                VERBOSE=true
                shift
                ;;
            --*)
                local key="${1#--}"
                # Convert kebab-case to snake_case
                key="${key//-/_}"

                if [[ $# -lt 2 ]]; then
                    log_error "Option $1 requires a value"
                    exit 1
                fi

                local value="$2"

                # Add comma separator
                if [[ "$first" == "false" ]]; then
                    json+=","
                fi
                first=false

                # Escape quotes in value
                value="${value//\"/\\\"}"
                json+="\"$key\":\"$value\""

                shift 2
                ;;
            *)
                log_error "Unknown parameter: $1"
                exit 1
                ;;
        esac
    done

    json+="}"
    echo "$json"
}

################################################################################
# Command Implementation Functions
################################################################################

cmd_exec() {
    if [[ $# -lt 2 ]]; then
        log_error "exec command requires capability and operation arguments"
        help_exec
        exit 1
    fi

    local capability="$1"
    local operation="$2"
    shift 2

    log_verbose "Executing capability: $capability, operation: $operation"

    # Parse remaining args as parameters
    local params
    params=$(parse_exec_params "$@")

    log_debug "Parsed parameters: $params"

    # Load capability executor
    if [[ ! -f "$CORE_DIR/capability-executor.sh" ]]; then
        log_error "Capability executor not found: $CORE_DIR/capability-executor.sh"
        exit 1
    fi

    source "$CORE_DIR/capability-executor.sh"

    # Execute
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN - No changes will be made"
    fi

    execute_capability_operation "$capability" "$operation" "$params"
}

cmd_query() {
    if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
        help_query
        exit 0
    fi

    log_verbose "Executing query command"

    # Load query module
    if [[ ! -f "$CORE_DIR/query.sh" ]]; then
        log_error "Query module not found: $CORE_DIR/query.sh"
        exit 1
    fi

    source "$CORE_DIR/query.sh"
    query_resources "$@"
}

cmd_discover() {
    if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
        help_discover
        exit 0
    fi

    log_verbose "Executing discover command"

    # Load discovery module
    if [[ ! -f "$CORE_DIR/discovery.sh" ]]; then
        log_error "Discovery module not found: $CORE_DIR/discovery.sh"
        exit 1
    fi

    source "$CORE_DIR/discovery.sh"
    discover "$@"
}

cmd_state() {
    if [[ $# -lt 1 ]]; then
        log_error "state command requires an action"
        help_state
        exit 1
    fi

    if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
        help_state
        exit 0
    fi

    local action="$1"
    shift

    log_verbose "Executing state command: $action"

    # Load state manager
    if [[ ! -f "$CORE_DIR/state-manager.sh" ]]; then
        log_error "State manager not found: $CORE_DIR/state-manager.sh"
        exit 1
    fi

    source "$CORE_DIR/state-manager.sh"

    case "$action" in
        init)
            init_state_db "$@"
            ;;
        show)
            show_state "$@"
            ;;
        export)
            export_state "$@"
            ;;
        import)
            import_state "$@"
            ;;
        cleanup)
            cleanup_orphaned "$@"
            ;;
        *)
            log_error "Unknown state action: $action"
            help_state
            exit 1
            ;;
    esac
}

cmd_validate() {
    if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
        help_validate
        exit 0
    fi

    log_verbose "Executing validate command"

    # Load required modules
    if [[ ! -f "$CORE_DIR/state-manager.sh" ]]; then
        log_error "State manager not found: $CORE_DIR/state-manager.sh"
        exit 1
    fi

    if [[ ! -f "$CORE_DIR/query.sh" ]]; then
        log_error "Query module not found: $CORE_DIR/query.sh"
        exit 1
    fi

    source "$CORE_DIR/state-manager.sh"
    source "$CORE_DIR/query.sh"

    validate_infrastructure "$@"
}

cmd_workflow() {
    if [[ $# -lt 1 ]]; then
        log_error "workflow command requires an action"
        help_workflow
        exit 1
    fi

    if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
        help_workflow
        exit 0
    fi

    local action="$1"
    shift

    log_verbose "Executing workflow command: $action"

    # Load workflow engine
    if [[ ! -f "$CORE_DIR/workflow-engine.sh" ]]; then
        log_error "Workflow engine not found: $CORE_DIR/workflow-engine.sh"
        exit 1
    fi

    source "$CORE_DIR/workflow-engine.sh"

    case "$action" in
        run)
            execute_workflow "$@"
            ;;
        validate)
            validate_workflow "$@"
            ;;
        list)
            list_workflows "$@"
            ;;
        *)
            log_error "Unknown workflow action: $action"
            help_workflow
            exit 1
            ;;
    esac
}

################################################################################
# Main Entry Point
################################################################################

main() {
    # Parse global flags first
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --verbose)
                VERBOSE=true
                shift
                ;;
            --debug)
                DEBUG=true
                VERBOSE=true
                shift
                ;;
            --help|-h)
                usage
                exit 0
                ;;
            -*)
                # Unknown flag, will be handled by subcommand
                break
                ;;
            *)
                # Command found
                break
                ;;
        esac
    done

    if [[ $# -lt 1 ]]; then
        log_error "No command specified"
        usage
        exit 1
    fi

    local command="$1"
    shift

    # Check dependencies before executing commands
    check_dependencies

    # Dispatch to command handler
    case "$command" in
        exec)
            cmd_exec "$@"
            ;;
        query)
            cmd_query "$@"
            ;;
        discover)
            cmd_discover "$@"
            ;;
        state)
            cmd_state "$@"
            ;;
        validate)
            cmd_validate "$@"
            ;;
        workflow)
            cmd_workflow "$@"
            ;;
        help|--help|-h)
            usage
            exit 0
            ;;
        *)
            log_error "Unknown command: $command"
            usage
            exit 1
            ;;
    esac
}

# Execute main function
main "$@"
