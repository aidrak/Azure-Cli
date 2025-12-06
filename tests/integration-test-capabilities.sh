#!/bin/bash
# ==============================================================================
# Integration Test - Capability System
# ==============================================================================
# Verifies that key operations from each capability can be loaded, parsed,
# and executed (in dry-run mode) by the new engine.
# ==============================================================================

set -u

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENGINE="${PROJECT_ROOT}/core/engine.sh"
LOG_DIR="${PROJECT_ROOT}/tests/logs/capabilities"

# Ensure log directory exists
mkdir -p "$LOG_DIR"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Operations to test (one per capability)
declare -A TEST_OPS
TEST_OPS=(
    ["networking"]="vnet-create"
    ["storage"]="account-create"
    ["identity"]="group-create"
    ["compute"]="vm-create"
    ["avd"]="hostpool-create"
    ["management"]="resource-group-create"
)

echo "========================================================================"
echo "  Starting Capability Integration Tests"
echo "========================================================================"
echo "Engine: $ENGINE"
echo "Mode:   DRY-RUN"
echo ""

failed_tests=0
passed_tests=0

# Export execution mode for engine
export EXECUTION_MODE="dry-run"

for cap in "${!TEST_OPS[@]}"; do
    op_id="${TEST_OPS[$cap]}"
    log_file="${LOG_DIR}/${cap}_${op_id}.log"
    
    echo -n "Testing capability '$cap' (Op: $op_id)... "
    
    # Run the engine
    if "$ENGINE" run "$op_id" > "$log_file" 2>&1; then
        # Check for success indicators in the log
        if grep -q "Operation completed successfully" "$log_file"; then
            echo -e "${GREEN}[PASS]${NC}"
            ((passed_tests++))
        else
            echo -e "${RED}[FAIL]${NC} (Exit code 0 but missing success message)"
            echo "See log: $log_file"
            ((failed_tests++))
        fi
    else
        echo -e "${RED}[FAIL]${NC} (Non-zero exit code)"
        echo "See log: $log_file"
        ((failed_tests++))
    fi
    
    # Validation: Check if variable substitution happened
    # We check for the Resource Group, which should be in almost every operation
    if ! grep -q "RG-Azure-VDI-01" "$log_file"; then
        echo "  [!] WARNING: 'RG-Azure-VDI-01' not found in output. Variable substitution may have failed."
    fi
done

echo ""
echo "========================================================================"
echo "  Test Summary"
echo "========================================================================"
echo "Passed: $passed_tests"
echo "Failed: $failed_tests"
echo ""

if [[ $failed_tests -gt 0 ]]; then
    exit 1
else
    exit 0
fi
