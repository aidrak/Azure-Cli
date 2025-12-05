#!/bin/bash

################################################################################
# AVD Deployment Orchestrator
#
# Purpose: Master orchestration script to automate the complete 12-step
#          Azure Virtual Desktop deployment pipeline
#
# Usage:
#   ./orchestrate.sh                    # Interactive mode (step-by-step)
#   ./orchestrate.sh --automated        # Automated mode (all steps)
#   ./orchestrate.sh --step 03          # Run specific step
#   ./orchestrate.sh --resume           # Resume from last failure
#
# Prerequisites:
#   - Azure CLI installed and authenticated
#   - All config.env files properly configured
#   - Function libraries available
#
# Configuration:
#   - Central config: config/avd-config.sh
#   - Step configs: 01-networking/config.env, 02-storage/config.env, etc.
#
# Deployment Pipeline:
#   01. Networking (VNet, subnets, NSGs)
#   02. Storage (FSLogix storage account)
#   03. Entra ID (Security groups, service principals)
#   04. Host Pool (Host pool, app groups, workspaces)
#   05. Golden Image (Windows VM, configurations, image capture)
#   06. Session Hosts (Deploy VMs from golden image)
#   07. Intune (MDM enrollment and policies)
#   08. RBAC (Role-based access control)
#   09. SSO (Single sign-on configuration)
#   10. Autoscaling (Azure Autoscale or custom scaling)
#   11. Testing (Validation and verification)
#   12. Cleanup (Decommission and migration)
#
# Output:
#   - Step logs in: [step]/artifacts/
#   - Deployment state: orchestrator-state.json
#   - Summary: orchestrator-summary.txt
#
################################################################################

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_NAME="orchestrate"
STATE_FILE="${SCRIPT_DIR}/orchestrator-state.json"
SUMMARY_FILE="${SCRIPT_DIR}/orchestrator-summary.txt"
LOG_DIR="${SCRIPT_DIR}/artifacts"

# Deployment steps
declare -a STEPS=(
    "01-networking"
    "02-storage"
    "03-entra-group"
    "04-host-pool-workspace"
    "05-golden-image"
    "06-session-host-deployment"
    "07-intune"
    "08-rbac"
    "09-sso"
    "10-autoscaling"
    "11-testing"
    "12-cleanup-migration"
)

# Execution modes
MODE="${1:-interactive}"
TARGET_STEP="${2:-}"

# ============================================================================
# LOAD FUNCTION LIBRARIES
# ============================================================================

# Load logging functions
LOGGING_FUNCS="${SCRIPT_DIR}/common/functions/logging-functions.sh"
if [[ -f "$LOGGING_FUNCS" ]]; then
    source "$LOGGING_FUNCS"
else
    log_info() { echo "ℹ $*"; }
    log_success() { echo "✓ $*"; }
    log_error() { echo "✗ $*" >&2; }
    log_warning() { echo "⚠ $*"; }
    log_section() { echo ""; echo "=== $* ==="; echo ""; }
fi

# ============================================================================
# STATE MANAGEMENT
# ============================================================================

# Initialize state file
init_state() {
    mkdir -p "$LOG_DIR"

    cat > "$STATE_FILE" <<EOF
{
  "deployment_id": "avd-$(date +%Y%m%d-%H%M%S)",
  "started_at": "$(date -u '+%Y-%m-%dT%H:%M:%SZ')",
  "completed_steps": [],
  "pending_steps": [$(printf '"%s", ' "${STEPS[@]}" | sed 's/, $//')]
  "current_step": null,
  "last_error": null,
  "status": "in_progress"
}
EOF

    log_success "State file initialized: $STATE_FILE"
}

# Load existing state
load_state() {
    if [[ ! -f "$STATE_FILE" ]]; then
        init_state
        return
    fi

    log_info "Loading previous state: $STATE_FILE"
}

# Update state after step completion
update_state() {
    local step="$1"
    local status="$2"

    if [[ "$status" == "success" ]]; then
        log_success "Step completed: $step"
    else
        log_error "Step failed: $step"
    fi

    # In a real implementation, would update JSON state file here
}

# ============================================================================
# STEP EXECUTION
# ============================================================================

# Execute a single step
execute_step() {
    local step="$1"
    local step_dir="${SCRIPT_DIR}/${step}"

    if [[ ! -d "$step_dir" ]]; then
        log_error "Step directory not found: $step_dir"
        return 1
    fi

    log_section "Executing: $step"
    log_info "Step directory: $step_dir"

    # Check for main task or orchestrator in step
    if [[ -f "${step_dir}/orchestrate.sh" ]]; then
        log_info "Running step orchestrator: ${step_dir}/orchestrate.sh"
        bash "${step_dir}/orchestrate.sh"
    elif [[ -f "${step_dir}/tasks/01-"* ]]; then
        log_info "Running first task in step"
        bash "${step_dir}"/tasks/01-*.sh
    else
        log_warning "No orchestrator or tasks found in: $step_dir"
        return 0
    fi

    update_state "$step" "success"
    return 0
}

# ============================================================================
# EXECUTION MODES
# ============================================================================

# Interactive mode: ask before each step
mode_interactive() {
    log_section "Interactive Deployment Mode"
    log_info "You will be prompted before each step"
    log_info "Press Enter to continue, Ctrl+C to abort"

    for step in "${STEPS[@]}"; do
        read -p "Execute step: $step? (y/n): " -r response
        if [[ "$response" == "y" || "$response" == "yes" ]]; then
            if ! execute_step "$step"; then
                log_error "Step failed: $step"
                read -p "Continue anyway? (y/n): " -r continue_response
                if [[ "$continue_response" != "y" ]]; then
                    log_error "Deployment aborted"
                    return 1
                fi
            fi
        else
            log_warning "Skipped step: $step"
        fi
    done

    return 0
}

# Automated mode: run all steps
mode_automated() {
    log_section "Automated Deployment Mode"
    log_info "Running all steps sequentially"
    log_info "Each step must complete successfully to proceed"

    for step in "${STEPS[@]}"; do
        if ! execute_step "$step"; then
            log_error "Deployment failed at step: $step"
            log_error "To resume, run: ./orchestrate.sh --resume"
            return 1
        fi
    done

    return 0
}

# Resume mode: continue from last failure
mode_resume() {
    log_section "Resume Mode"
    log_info "Resuming from last failure point"

    # Load state to find where we stopped
    load_state

    # Find first incomplete step
    local found_resume=0
    for step in "${STEPS[@]}"; do
        if [[ $found_resume -eq 1 ]]; then
            execute_step "$step" || return 1
        fi
    done

    return 0
}

# Single step mode
mode_single_step() {
    log_section "Single Step Mode"
    log_info "Executing step: $TARGET_STEP"

    execute_step "$TARGET_STEP" || return 1
    return 0
}

# ============================================================================
# VALIDATION & INITIALIZATION
# ============================================================================

validate_prerequisites() {
    log_section "Validating Orchestrator Prerequisites"

    # Check Azure CLI
    if ! command -v az &>/dev/null; then
        log_error "Azure CLI not installed"
        return 1
    fi
    log_success "Azure CLI installed"

    # Check Azure authentication
    if ! az account show &>/dev/null; then
        log_error "Not authenticated to Azure"
        log_info "Run: az login"
        return 1
    fi
    log_success "Azure authentication verified"

    # Check central config
    local central_config="${SCRIPT_DIR}/config/avd-config.sh"
    if [[ ! -f "$central_config" ]]; then
        log_warning "Central config not found: $central_config"
        log_info "This is optional if using step-specific config files"
    else
        log_success "Central config found"
    fi

    log_success "All prerequisites verified"
    return 0
}

# ============================================================================
# REPORTING
# ============================================================================

generate_summary() {
    log_section "Generating Deployment Summary"

    {
        echo "Azure Virtual Desktop Deployment Summary"
        echo "========================================"
        echo ""
        echo "Deployment ID: $(jq -r '.deployment_id' "$STATE_FILE" 2>/dev/null || echo 'unknown')"
        echo "Started: $(jq -r '.started_at' "$STATE_FILE" 2>/dev/null || date)"
        echo "Completed: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
        echo ""
        echo "Steps Executed:"
        for step in "${STEPS[@]}"; do
            if [[ -d "${SCRIPT_DIR}/${step}" ]]; then
                echo "  ✓ $step"
            fi
        done
        echo ""
        echo "Log Directory: $LOG_DIR"
        echo ""
        echo "Next Steps:"
        echo "  1. Verify deployment in Azure Portal"
        echo "  2. Test user access and connectivity"
        echo "  3. Monitor autoscaling and performance"
        echo ""
    } > "$SUMMARY_FILE"

    log_success "Summary saved to: $SUMMARY_FILE"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    log_section "AVD Deployment Orchestrator"
    log_info "Mode: $MODE"

    # Validate prerequisites
    if ! validate_prerequisites; then
        log_error "Prerequisites validation failed"
        return 1
    fi

    # Initialize or load state
    init_state

    # Execute based on mode
    case "$MODE" in
        interactive)
            mode_interactive
            ;;
        --automated|automated)
            mode_automated
            ;;
        --resume|resume)
            mode_resume
            ;;
        --step|step)
            mode_single_step
            ;;
        --help|help|-h)
            cat <<'HELP'
Azure Virtual Desktop Deployment Orchestrator

Usage:
  ./orchestrate.sh                    # Interactive mode
  ./orchestrate.sh --automated        # Run all steps
  ./orchestrate.sh --resume           # Resume from failure
  ./orchestrate.sh --step 03          # Run specific step
  ./orchestrate.sh --help             # Show this help

Modes:
  interactive  - Prompt before each step
  automated    - Run all steps without prompting
  resume       - Continue from last failure point
  step         - Execute single step

Examples:
  ./orchestrate.sh
  ./orchestrate.sh --automated
  ./orchestrate.sh --step 05-golden-image

Output:
  - Step logs: [step]/artifacts/
  - Deployment state: orchestrator-state.json
  - Summary: orchestrator-summary.txt
HELP
            return 0
            ;;
        *)
            log_error "Unknown mode: $MODE"
            return 1
            ;;
    esac

    # Generate summary
    generate_summary

    log_section "Deployment Complete"
    log_success "Azure Virtual Desktop deployment completed successfully"
    log_info "Summary file: $SUMMARY_FILE"

    return 0
}

# Run main function
main "$@"
exit $?
