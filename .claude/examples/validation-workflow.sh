#!/bin/bash
# ==============================================================================
# Configuration Validation Workflow Examples
# ==============================================================================
#
# Demonstrates the three validation functions:
# - preflight_check: System readiness verification
# - validate_operation_config: Operation-specific variable validation
# - dry_run_operation: Safe preview execution
#
# Usage:
#   bash .claude/examples/validation-workflow.sh
#
# ==============================================================================

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$PROJECT_ROOT"

# ==============================================================================
# Example 1: Basic System Pre-Flight Check
# ==============================================================================
example_1_preflight_basic() {
    echo ""
    echo "=============================================================================="
    echo "EXAMPLE 1: Basic System Pre-Flight Check"
    echo "=============================================================================="
    echo ""
    echo "This validates the entire system is ready for operations."
    echo ""

    source core/config-manager.sh && load_config >/dev/null 2>&1

    preflight_check
}

# ==============================================================================
# Example 2: Pre-Flight Check with Operation Validation
# ==============================================================================
example_2_preflight_with_operation() {
    echo ""
    echo "=============================================================================="
    echo "EXAMPLE 2: Pre-Flight Check with Operation Validation"
    echo "=============================================================================="
    echo ""
    echo "This validates the system AND checks a specific operation."
    echo ""

    source core/config-manager.sh && load_config >/dev/null 2>&1

    preflight_check "vnet-create"
}

# ==============================================================================
# Example 3: Validate Operation Configuration
# ==============================================================================
example_3_validate_operation_config() {
    echo ""
    echo "=============================================================================="
    echo "EXAMPLE 3: Validate Operation Configuration"
    echo "=============================================================================="
    echo ""
    echo "This validates all variables required for a specific operation."
    echo ""

    source core/config-manager.sh && load_config >/dev/null 2>&1

    # First attempt - should fail due to missing NETWORKING_VNET_NAME
    echo "[ATTEMPT 1] Without NETWORKING_VNET_NAME variable:"
    echo "---"
    validate_operation_config "vnet-create" || true

    echo ""
    echo "[ATTEMPT 2] With NETWORKING_VNET_NAME variable:"
    echo "---"
    export NETWORKING_VNET_NAME="demo-vnet"
    validate_operation_config "vnet-create"
}

# ==============================================================================
# Example 4: Dry-Run Operation Preview
# ==============================================================================
example_4_dry_run_operation() {
    echo ""
    echo "=============================================================================="
    echo "EXAMPLE 4: Dry-Run Operation Preview"
    echo "=============================================================================="
    echo ""
    echo "This previews operation execution without making any changes."
    echo ""

    source core/config-manager.sh && load_config >/dev/null 2>&1
    export NETWORKING_VNET_NAME="demo-vnet"

    dry_run_operation "vnet-create"
}

# ==============================================================================
# Example 5: Complete Pre-Execution Workflow
# ==============================================================================
example_5_complete_workflow() {
    echo ""
    echo "=============================================================================="
    echo "EXAMPLE 5: Complete Pre-Execution Workflow"
    echo "=============================================================================="
    echo ""
    echo "This demonstrates the recommended workflow:"
    echo "  1. Load configuration"
    echo "  2. Run system pre-flight checks"
    echo "  3. Validate operation configuration"
    echo "  4. Preview operation with dry-run"
    echo "  5. Ready to execute (not shown here)"
    echo ""

    # Step 1: Load configuration
    echo "[STEP 1] Loading configuration..."
    source core/config-manager.sh && load_config >/dev/null 2>&1
    echo "[v] Configuration loaded"
    echo ""

    # Step 2: Run system pre-flight checks
    echo "[STEP 2] Running system pre-flight checks..."
    if preflight_check "vnet-create"; then
        echo "[v] System ready"
    else
        echo "[x] System validation failed"
        return 1
    fi
    echo ""

    # Step 3: Validate operation configuration
    echo "[STEP 3] Validating operation configuration..."
    export NETWORKING_VNET_NAME="demo-vnet"
    if validate_operation_config "vnet-create"; then
        echo "[v] Configuration valid"
    else
        echo "[x] Configuration validation failed"
        return 1
    fi
    echo ""

    # Step 4: Preview operation with dry-run
    echo "[STEP 4] Previewing operation execution..."
    if dry_run_operation "vnet-create"; then
        echo "[v] Dry-run successful"
    else
        echo "[x] Dry-run validation failed"
        return 1
    fi
    echo ""

    # Step 5: Ready to execute
    echo "[STEP 5] Ready to execute!"
    echo "---"
    echo "To execute this operation, run:"
    echo "  ./core/engine.sh run vnet-create"
    echo ""
}

# ==============================================================================
# Example 6: Handling Missing Variables
# ==============================================================================
example_6_missing_variables() {
    echo ""
    echo "=============================================================================="
    echo "EXAMPLE 6: Handling Missing Variables"
    echo "=============================================================================="
    echo ""
    echo "This demonstrates how the validator catches missing variables."
    echo ""

    source core/config-manager.sh && load_config >/dev/null 2>&1

    echo "[SCENARIO] Attempting to validate without required variables..."
    echo "---"

    # This will fail because NETWORKING_VNET_NAME is not set
    if validate_operation_config "vnet-create"; then
        echo "[v] Validation passed"
    else
        echo "[x] Validation failed (as expected)"
    fi

    echo ""
    echo "[REMEDIATION] Setting the missing variable..."
    export NETWORKING_VNET_NAME="production-vnet"
    echo "export NETWORKING_VNET_NAME='production-vnet'"
    echo ""

    echo "[RETRY] Validating again..."
    echo "---"
    validate_operation_config "vnet-create"
}

# ==============================================================================
# Example 7: Error Detection and Recovery
# ==============================================================================
example_7_error_detection() {
    echo ""
    echo "=============================================================================="
    echo "EXAMPLE 7: Error Detection and Recovery"
    echo "=============================================================================="
    echo ""
    echo "This demonstrates the validator detecting various error conditions."
    echo ""

    source core/config-manager.sh && load_config >/dev/null 2>&1

    # Error 1: Operation not found
    echo "[ERROR 1] Operation not found"
    echo "---"
    if validate_operation_config "nonexistent-operation"; then
        echo "[v] This shouldn't appear"
    else
        echo "[x] Operation validation failed (as expected)"
    fi
    echo ""

    # Error 2: Missing variables
    echo "[ERROR 2] Missing required variables"
    echo "---"
    if validate_operation_config "vnet-create"; then
        echo "[v] This shouldn't appear"
    else
        echo "[x] Variable validation failed (as expected)"
    fi
    echo ""

    # Recovery: Provide missing variable
    echo "[RECOVERY] Providing missing variable"
    export NETWORKING_VNET_NAME="recovery-vnet"
    validate_operation_config "vnet-create"
}

# ==============================================================================
# Main Menu
# ==============================================================================
show_menu() {
    echo ""
    echo "=============================================================================="
    echo "Configuration Validation Workflow Examples"
    echo "=============================================================================="
    echo ""
    echo "Choose an example to run:"
    echo ""
    echo "  1) Basic System Pre-Flight Check"
    echo "  2) Pre-Flight Check with Operation Validation"
    echo "  3) Validate Operation Configuration"
    echo "  4) Dry-Run Operation Preview"
    echo "  5) Complete Pre-Execution Workflow"
    echo "  6) Handling Missing Variables"
    echo "  7) Error Detection and Recovery"
    echo "  8) Run all examples"
    echo "  9) Exit"
    echo ""
}

# ==============================================================================
# Main Loop
# ==============================================================================
main() {
    while true; do
        show_menu
        read -p "Select an example (1-9): " choice

        case $choice in
            1) example_1_preflight_basic ;;
            2) example_2_preflight_with_operation ;;
            3) example_3_validate_operation_config ;;
            4) example_4_dry_run_operation ;;
            5) example_5_complete_workflow ;;
            6) example_6_missing_variables ;;
            7) example_7_error_detection ;;
            8)
                example_1_preflight_basic
                example_2_preflight_with_operation
                example_3_validate_operation_config
                example_4_dry_run_operation
                example_5_complete_workflow
                example_6_missing_variables
                example_7_error_detection
                ;;
            9)
                echo "Exiting..."
                exit 0
                ;;
            *)
                echo "Invalid choice. Please select 1-9."
                ;;
        esac

        read -p "Press ENTER to continue..."
    done
}

# Run main loop if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
