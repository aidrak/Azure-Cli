#!/bin/bash
# ==============================================================================
# Executor Test Suite
# ==============================================================================
#
# Purpose: Unit and integration tests for executor.sh
#
# Usage:
#   ./tests/test-executor.sh
#   ./tests/test-executor.sh <test-name>
#
# ==============================================================================

set -euo pipefail

# ==============================================================================
# SETUP
# ==============================================================================

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIR="${PROJECT_ROOT}/tests/test-data/executor"
TEST_DB="${TEST_DIR}/test-state.db"
TEST_CONFIG="${TEST_DIR}/test-config.yaml"

# Override paths for testing
export PROJECT_ROOT
export STATE_DB="$TEST_DB"
export CONFIG_FILE="$TEST_CONFIG"
export EXECUTION_MODE="normal"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# ==============================================================================
# TEST UTILITIES
# ==============================================================================

setup_test_env() {
    echo "[*] Setting up test environment..."

    # Create test directory
    mkdir -p "$TEST_DIR"
    mkdir -p "${TEST_DIR}/operations"
    mkdir -p "${TEST_DIR}/artifacts/logs"

    # Clean up previous test database
    rm -f "$TEST_DB"

    # Create test config
    cat > "$TEST_CONFIG" <<'EOF'
azure:
  subscription_id: "00000000-0000-0000-0000-000000000000"
  tenant_id: "11111111-1111-1111-1111-111111111111"
  location: "eastus"
  resource_group: "test-rg"

networking:
  vnet:
    name: "test-vnet"
    address_space: "10.0.0.0/16"

storage:
  account_name: "teststorage"
  sku: "Standard_LRS"
  file_share_name: "testshare"
  quota_gb: 100
EOF

    # Export test variables
    export AZURE_SUBSCRIPTION_ID="00000000-0000-0000-0000-000000000000"
    export AZURE_TENANT_ID="11111111-1111-1111-1111-111111111111"
    export AZURE_LOCATION="eastus"
    export AZURE_RESOURCE_GROUP="test-rg"
    export NETWORKING_VNET_NAME="test-vnet"
    export STORAGE_ACCOUNT_NAME="teststorage"
    export TEST_DIR

    # Source executor
    source "${PROJECT_ROOT}/core/executor.sh"

    echo "[v] Test environment ready"
}

cleanup_test_env() {
    echo "[*] Cleaning up test environment..."
    rm -rf "$TEST_DIR"
    echo "[v] Cleanup complete"
}

assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Assertion failed}"

    if [[ "$expected" == "$actual" ]]; then
        return 0
    else
        echo -e "${RED}[FAIL]${NC} $message"
        echo "  Expected: $expected"
        echo "  Actual:   $actual"
        return 1
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-String not found}"

    if [[ "$haystack" == *"$needle"* ]]; then
        return 0
    else
        echo -e "${RED}[FAIL]${NC} $message"
        echo "  Expected to find: $needle"
        echo "  In: $haystack"
        return 1
    fi
}

assert_file_exists() {
    local file="$1"
    local message="${2:-File should exist}"

    if [[ -f "$file" ]]; then
        return 0
    else
        echo -e "${RED}[FAIL]${NC} $message: $file"
        return 1
    fi
}

assert_success() {
    local command="$1"
    local message="${2:-Command should succeed}"

    if eval "$command" &>/dev/null; then
        return 0
    else
        echo -e "${RED}[FAIL]${NC} $message"
        echo "  Command: $command"
        return 1
    fi
}

assert_failure() {
    local command="$1"
    local message="${2:-Command should fail}"

    if ! eval "$command" &>/dev/null; then
        return 0
    else
        echo -e "${RED}[FAIL]${NC} $message"
        echo "  Command: $command"
        return 1
    fi
}

run_test() {
    local test_name="$1"
    local test_function="$2"

    ((++TESTS_RUN))

    echo ""
    echo "=========================================================================="
    echo "Test: $test_name"
    echo "=========================================================================="

    if $test_function; then
        ((++TESTS_PASSED))
        echo -e "${GREEN}[PASS]${NC} $test_name"
        return 0
    else
        ((++TESTS_FAILED))
        echo -e "${RED}[FAIL]${NC} $test_name"
        return 1
    fi
}

# ==============================================================================
# TEST CASES
# ==============================================================================

test_parse_operation_file() {
    # Create test operation YAML
    local test_op="${TEST_DIR}/operations/test-parse.yaml"
    cat > "$test_op" <<'EOF'
operation:
  id: "test-op"
  name: "Test Operation"
  type: "create"
  resource_type: "Microsoft.Compute/virtualMachines"

prerequisites: []

steps:
  - name: "Test step"
    command: "echo 'test'"

rollback: []
EOF

    # Test parsing
    if parse_operation_file "$test_op"; then
        echo "[v] Parsed operation successfully"
        return 0
    else
        echo "[x] Failed to parse operation"
        return 1
    fi
}

test_parse_invalid_yaml() {
    # Create invalid YAML
    local test_op="${TEST_DIR}/operations/test-invalid.yaml"
    cat > "$test_op" <<'EOF'
operation:
  id: "test-op"
  name: "Test Operation"
  invalid: yaml: structure
EOF

    # Should fail to parse
    if ! parse_operation_file "$test_op" 2>/dev/null; then
        echo "[v] Correctly rejected invalid YAML"
        return 0
    else
        echo "[x] Should have failed on invalid YAML"
        return 1
    fi
}

test_substitute_variables() {
    local template='Resource group: ${AZURE_RESOURCE_GROUP}, Location: ${AZURE_LOCATION}'
    local result=$(substitute_variables "$template")

    assert_contains "$result" "test-rg" "Should substitute AZURE_RESOURCE_GROUP" || return 1
    assert_contains "$result" "eastus" "Should substitute AZURE_LOCATION" || return 1

    echo "[v] Variable substitution working"
    return 0
}

test_get_prerequisites() {
    local test_op="${TEST_DIR}/operations/test-prereq.yaml"
    cat > "$test_op" <<'EOF'
operation:
  id: "test-prereq"
  name: "Test Prerequisites"
  type: "create"

prerequisites:
  - resource_type: "Microsoft.Network/virtualNetworks"
    name_from_config: "NETWORKING_VNET_NAME"
  - resource_type: "Microsoft.Storage/storageAccounts"
    name: "test-storage"

steps:
  - name: "Test"
    command: "echo test"

rollback: []
EOF

    local prereqs=$(get_prerequisites "$test_op")
    local count=$(echo "$prereqs" | jq 'length')

    assert_equals "2" "$count" "Should find 2 prerequisites" || return 1

    local first_type=$(echo "$prereqs" | jq -r '.[0].resource_type')
    assert_contains "$first_type" "virtualNetworks" "First prereq type" || return 1

    echo "[v] Prerequisites extracted correctly"
    return 0
}

test_get_steps() {
    local test_op="${TEST_DIR}/operations/test-steps.yaml"
    cat > "$test_op" <<'EOF'
operation:
  id: "test-steps"
  name: "Test Steps"
  type: "create"

prerequisites: []

steps:
  - name: "Step 1"
    command: "echo step1"
  - name: "Step 2"
    command: "echo step2"
  - name: "Step 3"
    command: "echo step3"

rollback: []
EOF

    local steps=$(get_steps "$test_op")
    local count=$(echo "$steps" | jq 'length')

    assert_equals "3" "$count" "Should find 3 steps" || return 1

    local first_name=$(echo "$steps" | jq -r '.[0].name')
    assert_equals "Step 1" "$first_name" "First step name" || return 1

    echo "[v] Steps extracted correctly"
    return 0
}

test_get_rollback_steps() {
    local test_op="${TEST_DIR}/operations/test-rollback.yaml"
    cat > "$test_op" <<'EOF'
operation:
  id: "test-rollback"
  name: "Test Rollback"
  type: "create"

prerequisites: []

steps:
  - name: "Create resource"
    command: "echo creating"

rollback:
  - name: "Delete resource"
    command: "echo deleting"
  - name: "Clean up"
    command: "echo cleanup"
EOF

    local rollback=$(get_rollback_steps "$test_op")
    local count=$(echo "$rollback" | jq 'length')

    assert_equals "2" "$count" "Should find 2 rollback steps" || return 1

    echo "[v] Rollback steps extracted correctly"
    return 0
}

test_generate_operation_id() {
    local id1=$(generate_operation_id "test-op")
    local id2=$(generate_operation_id "test-op")

    # IDs should be different (due to timestamp/random)
    if [[ "$id1" != "$id2" ]]; then
        echo "[v] Generated unique operation IDs: $id1, $id2"
        return 0
    else
        echo "[x] Operation IDs should be unique"
        return 1
    fi
}

test_dry_run_mode() {
    local test_op="${TEST_DIR}/operations/test-dryrun.yaml"
    cat > "$test_op" <<'EOF'
operation:
  id: "test-dryrun"
  name: "Test Dry Run"
  type: "create"
  resource_type: "Microsoft.Compute/virtualMachines"

prerequisites: []

steps:
  - name: "Create VM"
    command: "echo 'This should not execute'"

rollback:
  - name: "Delete VM"
    command: "echo 'This should not execute either'"
EOF

    # Run dry-run
    local output
    output=$(dry_run "$test_op" 2>&1)

    assert_contains "$output" "DRY RUN MODE" "Should indicate dry run mode" || return 1
    assert_contains "$output" "Create VM" "Should show step name" || return 1
    assert_contains "$output" "Delete VM" "Should show rollback step" || return 1

    echo "[v] Dry run mode working"
    return 0
}

test_execute_simple_operation() {
    # Initialize state DB
    init_state_db

    local test_op="${TEST_DIR}/operations/test-execute.yaml"
    cat > "$test_op" <<'EOF'
operation:
  id: "test-execute"
  name: "Test Execute"
  type: "create"
  resource_type: "Microsoft.Compute/virtualMachines"

prerequisites: []

steps:
  - name: "Step 1"
    command: "echo 'Step 1 executed' > ${TEST_DIR}/step1.txt"
  - name: "Step 2"
    command: "echo 'Step 2 executed' > ${TEST_DIR}/step2.txt"

rollback:
  - name: "Cleanup"
    command: "rm -f ${TEST_DIR}/step*.txt"
EOF

    # Execute operation
    if execute_operation "$test_op" "true"; then  # Force mode to skip prereq validation
        echo "[v] Operation executed successfully"

        # Verify step outputs
        assert_file_exists "${TEST_DIR}/step1.txt" "Step 1 output file" || return 1
        assert_file_exists "${TEST_DIR}/step2.txt" "Step 2 output file" || return 1

        return 0
    else
        echo "[x] Operation execution failed"
        return 1
    fi
}

test_rollback_on_failure() {
    # Initialize state DB
    init_state_db

    local test_op="${TEST_DIR}/operations/test-rollback-exec.yaml"
    cat > "$test_op" <<'EOF'
operation:
  id: "test-rollback-exec"
  name: "Test Rollback Execution"
  type: "create"

prerequisites: []

steps:
  - name: "Create marker"
    command: "touch ${TEST_DIR}/marker.txt"
  - name: "Fail intentionally"
    command: "exit 1"
  - name: "Should not execute"
    command: "touch ${TEST_DIR}/should-not-exist.txt"

rollback:
  - name: "Remove marker"
    command: "rm -f ${TEST_DIR}/marker.txt"
EOF

    # Execute operation (should fail and rollback)
    if ! execute_operation "$test_op" "true" 2>/dev/null; then
        echo "[v] Operation failed as expected"

        # Verify rollback executed
        if [[ ! -f "${TEST_DIR}/marker.txt" ]]; then
            echo "[v] Rollback removed marker file"
        else
            echo "[x] Rollback did not execute properly"
            return 1
        fi

        # Verify step 3 did not execute
        if [[ ! -f "${TEST_DIR}/should-not-exist.txt" ]]; then
            echo "[v] Subsequent steps correctly skipped"
        else
            echo "[x] Steps after failure should not execute"
            return 1
        fi

        return 0
    else
        echo "[x] Operation should have failed"
        return 1
    fi
}

test_continue_on_error() {
    # Initialize state DB
    init_state_db

    local test_op="${TEST_DIR}/operations/test-continue.yaml"
    cat > "$test_op" <<'EOF'
operation:
  id: "test-continue"
  name: "Test Continue On Error"
  type: "create"

prerequisites: []

steps:
  - name: "Step 1"
    command: "touch ${TEST_DIR}/step1.txt"
  - name: "Failing step"
    command: "exit 1"
    continue_on_error: true
  - name: "Step 3"
    command: "touch ${TEST_DIR}/step3.txt"

rollback: []
EOF

    # Execute operation
    if execute_operation "$test_op" "true"; then
        echo "[v] Operation completed despite error in step 2"

        # Verify all steps executed
        assert_file_exists "${TEST_DIR}/step1.txt" "Step 1 executed" || return 1
        assert_file_exists "${TEST_DIR}/step3.txt" "Step 3 executed after error" || return 1

        return 0
    else
        echo "[x] Operation should have continued on error"
        return 1
    fi
}

test_save_rollback_script() {
    local test_op="${TEST_DIR}/operations/test-save-rollback.yaml"
    cat > "$test_op" <<'EOF'
operation:
  id: "test-save-rollback"
  name: "Test Save Rollback Script"
  type: "create"

prerequisites: []

steps:
  - name: "Test step"
    command: "echo test"

rollback:
  - name: "Rollback step 1"
    command: "echo rollback1"
  - name: "Rollback step 2"
    command: "echo rollback2"
EOF

    local operation_exec_id="test_save_rollback_123"

    # Save rollback script
    save_rollback_script "$test_op" "$operation_exec_id"

    local script_path="${ROLLBACK_SCRIPTS_DIR}/rollback_${operation_exec_id}.sh"

    # Verify script was created
    assert_file_exists "$script_path" "Rollback script created" || return 1

    # Verify script is executable
    if [[ -x "$script_path" ]]; then
        echo "[v] Rollback script is executable"
    else
        echo "[x] Rollback script should be executable"
        return 1
    fi

    # Verify script contains rollback commands
    local content=$(cat "$script_path")
    assert_contains "$content" "echo rollback1" "Contains rollback command 1" || return 1
    assert_contains "$content" "echo rollback2" "Contains rollback command 2" || return 1

    echo "[v] Rollback script saved correctly"
    return 0
}

# ==============================================================================
# TEST RUNNER
# ==============================================================================

run_all_tests() {
    echo "=========================================================================="
    echo "Executor Test Suite"
    echo "=========================================================================="

    setup_test_env

    # Run all tests
    run_test "Parse operation file" test_parse_operation_file
    run_test "Parse invalid YAML" test_parse_invalid_yaml
    run_test "Substitute variables" test_substitute_variables
    run_test "Get prerequisites" test_get_prerequisites
    run_test "Get steps" test_get_steps
    run_test "Get rollback steps" test_get_rollback_steps
    run_test "Generate operation ID" test_generate_operation_id
    run_test "Dry run mode" test_dry_run_mode
    run_test "Execute simple operation" test_execute_simple_operation
    run_test "Rollback on failure" test_rollback_on_failure
    run_test "Continue on error" test_continue_on_error
    run_test "Save rollback script" test_save_rollback_script

    # Print summary
    echo ""
    echo "=========================================================================="
    echo "Test Summary"
    echo "=========================================================================="
    echo "Total tests:  $TESTS_RUN"
    echo -e "Passed:       ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Failed:       ${RED}$TESTS_FAILED${NC}"
    echo "=========================================================================="

    cleanup_test_env

    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}All tests passed!${NC}"
        return 0
    else
        echo -e "${RED}Some tests failed${NC}"
        return 1
    fi
}

# ==============================================================================
# MAIN
# ==============================================================================

main() {
    if [[ $# -eq 0 ]]; then
        run_all_tests
    else
        setup_test_env
        run_test "$1" "$1"
        cleanup_test_env
    fi
}

main "$@"
