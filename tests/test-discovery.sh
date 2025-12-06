#!/bin/bash
# ==============================================================================
# Discovery Engine - Test Suite
# ==============================================================================
#
# Purpose: Comprehensive tests for discovery engine functionality
#
# Usage:
#   ./tests/test-discovery.sh
#
# ==============================================================================

set -euo pipefail

# Get project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

# Test configuration
TEST_RESOURCE_GROUP="${TEST_RESOURCE_GROUP:-}"
CLEANUP_AFTER_TEST="${CLEANUP_AFTER_TEST:-true}"

# Test results
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Colors (optional)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# ==============================================================================
# Test Helper Functions
# ==============================================================================

test_start() {
    local test_name="$1"
    echo ""
    echo "========================================================================"
    echo "TEST: $test_name"
    echo "========================================================================"
    ((TESTS_RUN++)) || true
}

test_pass() {
    local test_name="$1"
    echo -e "${GREEN}[PASS]${NC} $test_name"
    ((TESTS_PASSED++)) || true
}

test_fail() {
    local test_name="$1"
    local error="${2:-Unknown error}"
    echo -e "${RED}[FAIL]${NC} $test_name"
    echo "  Error: $error"
    ((TESTS_FAILED++)) || true
}

assert_file_exists() {
    local file="$1"
    local test_name="${2:-File exists}"

    if [[ -f "$file" ]]; then
        test_pass "$test_name"
        return 0
    else
        test_fail "$test_name" "File not found: $file"
        return 1
    fi
}

assert_command_exists() {
    local cmd="$1"
    local test_name="${2:-Command exists: $cmd}"

    if command -v "$cmd" &>/dev/null; then
        test_pass "$test_name"
        return 0
    else
        test_fail "$test_name" "Command not found: $cmd"
        return 1
    fi
}

assert_function_exists() {
    local func="$1"
    local test_name="${2:-Function exists: $func}"

    if declare -F "$func" &>/dev/null; then
        test_pass "$test_name"
        return 0
    else
        test_fail "$test_name" "Function not found: $func"
        return 1
    fi
}

assert_db_table_exists() {
    local table="$1"
    local test_name="${2:-Database table exists: $table}"

    if sqlite3 state.db "SELECT name FROM sqlite_master WHERE type='table' AND name='$table';" | grep -q "$table"; then
        test_pass "$test_name"
        return 0
    else
        test_fail "$test_name" "Table not found: $table"
        return 1
    fi
}

# ==============================================================================
# Test Suite
# ==============================================================================

test_01_prerequisites() {
    test_start "Prerequisites Check"

    assert_command_exists "az" "Azure CLI installed"
    assert_command_exists "sqlite3" "SQLite3 installed"
    assert_command_exists "jq" "JQ installed"

    # Check Azure authentication
    if az account show &>/dev/null; then
        test_pass "Azure CLI authenticated"
    else
        test_fail "Azure CLI authenticated" "Not logged in (run: az login)"
    fi
}

test_02_file_structure() {
    test_start "File Structure"

    assert_file_exists "core/discovery.sh" "Discovery engine exists"
    assert_file_exists "core/state-manager.sh" "State manager exists"
    assert_file_exists "core/query.sh" "Query engine exists"
    assert_file_exists "core/dependency-resolver.sh" "Dependency resolver exists"
    assert_file_exists "core/logger.sh" "Logger exists"

    assert_file_exists "queries/summary.jq" "Summary JQ filter exists"
    assert_file_exists "queries/compute.jq" "Compute JQ filter exists"
}

test_03_module_loading() {
    test_start "Module Loading"

    # Source discovery engine
    if source core/discovery.sh 2>&1 | grep -q "Discovery engine loaded"; then
        test_pass "Discovery engine loads successfully"
    else
        test_fail "Discovery engine loads successfully" "Failed to load"
        return 1
    fi

    # Check exported functions
    assert_function_exists "discover" "discover() function exported"
    assert_function_exists "discover_resource_group" "discover_resource_group() function exported"
    assert_function_exists "discover_subscription" "discover_subscription() function exported"
    assert_function_exists "discover_compute_resources" "discover_compute_resources() function exported"
    assert_function_exists "discover_networking_resources" "discover_networking_resources() function exported"
    assert_function_exists "build_discovery_graph" "build_discovery_graph() function exported"
    assert_function_exists "generate_inventory_summary" "generate_inventory_summary() function exported"
}

test_04_state_database_init() {
    test_start "State Database Initialization"

    # Remove existing database
    rm -f state.db

    # Source modules
    source core/discovery.sh &>/dev/null

    # Initialize database
    if init_state_db; then
        test_pass "State database initialization"
    else
        test_fail "State database initialization" "init_state_db failed"
        return 1
    fi

    # Check database exists
    assert_file_exists "state.db" "state.db file created"

    # Check tables exist
    assert_db_table_exists "resources" "resources table"
    assert_db_table_exists "dependencies" "dependencies table"
    assert_db_table_exists "operations" "operations table"
    assert_db_table_exists "operation_logs" "operation_logs table"
}

test_05_helper_functions() {
    test_start "Helper Functions"

    source core/discovery.sh &>/dev/null

    # Test validate_discovery_scope
    if validate_discovery_scope "resource-group" "test-rg" 2>/dev/null; then
        test_fail "validate_discovery_scope (invalid RG)" "Should reject non-existent RG"
    else
        test_pass "validate_discovery_scope (invalid RG)"
    fi

    # Test get_discovery_timestamp
    local timestamp=$(get_discovery_timestamp)
    if [[ "$timestamp" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]; then
        test_pass "get_discovery_timestamp format"
    else
        test_fail "get_discovery_timestamp format" "Invalid format: $timestamp"
    fi
}

test_06_jq_filters() {
    test_start "JQ Filters"

    # Test summary filter
    local test_json='[{"name":"vm-01","type":"Microsoft.Compute/virtualMachines","location":"eastus","provisioningState":"Succeeded"}]'

    local filtered=$(echo "$test_json" | jq -f queries/summary.jq)

    if echo "$filtered" | jq -e '.[0].name == "vm-01"' &>/dev/null; then
        test_pass "Summary JQ filter works"
    else
        test_fail "Summary JQ filter works" "Filter failed"
    fi

    # Test compute filter
    local vm_json='[{"id":"/subscriptions/sub/resourceGroups/rg/providers/Microsoft.Compute/virtualMachines/vm-01","name":"vm-01","resourceGroup":"rg","location":"eastus","hardwareProfile":{"vmSize":"Standard_D2s_v3"},"storageProfile":{"osDisk":{"osType":"Linux"}}}]'

    local filtered=$(echo "$vm_json" | jq -f queries/compute.jq)

    if echo "$filtered" | jq -e '.[0].vmSize == "Standard_D2s_v3"' &>/dev/null; then
        test_pass "Compute JQ filter works"
    else
        test_fail "Compute JQ filter works" "Filter failed"
    fi
}

test_07_mock_discovery() {
    test_start "Mock Discovery (No Azure Resources)"

    source core/discovery.sh &>/dev/null
    init_state_db &>/dev/null

    # Test with mock data (empty results)
    # This tests the logic without requiring actual Azure resources

    # Create mock resource
    local mock_resource='{
        "id": "/subscriptions/test/resourceGroups/test-rg/providers/Microsoft.Compute/virtualMachines/test-vm",
        "name": "test-vm",
        "type": "Microsoft.Compute/virtualMachines",
        "resourceGroup": "test-rg",
        "location": "eastus",
        "properties": {
            "provisioningState": "Succeeded"
        },
        "tags": {}
    }'

    # Store mock resource
    if store_resource "$mock_resource"; then
        test_pass "Store mock resource"
    else
        test_fail "Store mock resource" "store_resource failed"
    fi

    # Query mock resource
    local count=$(sqlite3 state.db "SELECT COUNT(*) FROM resources WHERE name='test-vm';")
    if [[ "$count" -eq 1 ]]; then
        test_pass "Query stored mock resource"
    else
        test_fail "Query stored mock resource" "Expected 1, got $count"
    fi
}

test_08_output_directories() {
    test_start "Output Directory Creation"

    # Ensure discovered directory exists
    if [[ -d "discovered" ]]; then
        test_pass "discovered/ directory exists"
    else
        mkdir -p discovered
        test_pass "discovered/ directory created"
    fi

    # Check writable
    if touch discovered/test-write &>/dev/null; then
        rm -f discovered/test-write
        test_pass "discovered/ directory writable"
    else
        test_fail "discovered/ directory writable" "Permission denied"
    fi
}

test_09_dependency_detection() {
    test_start "Dependency Detection (Mock)"

    source core/discovery.sh &>/dev/null
    source core/dependency-resolver.sh &>/dev/null

    # Create mock VM with NIC dependency
    local mock_vm='{
        "id": "/subscriptions/test/resourceGroups/test-rg/providers/Microsoft.Compute/virtualMachines/test-vm",
        "name": "test-vm",
        "type": "Microsoft.Compute/virtualMachines",
        "properties": {
            "networkProfile": {
                "networkInterfaces": [
                    {
                        "id": "/subscriptions/test/resourceGroups/test-rg/providers/Microsoft.Network/networkInterfaces/test-nic"
                    }
                ]
            }
        }
    }'

    # Detect dependencies
    local dep_count=$(detect_vm_dependencies "$mock_vm" 2>/dev/null || echo "0")

    if [[ "$dep_count" -gt 0 ]]; then
        test_pass "Dependency detection (VM -> NIC)"
    else
        test_fail "Dependency detection (VM -> NIC)" "No dependencies detected"
    fi
}

test_10_integration_test() {
    test_start "Integration Test (Optional - Requires Azure Resources)"

    if [[ -z "$TEST_RESOURCE_GROUP" ]]; then
        echo -e "${YELLOW}[SKIP]${NC} Integration test (set TEST_RESOURCE_GROUP to run)"
        return 0
    fi

    # Verify resource group exists
    if ! az group show --name "$TEST_RESOURCE_GROUP" &>/dev/null; then
        echo -e "${YELLOW}[SKIP]${NC} Resource group not found: $TEST_RESOURCE_GROUP"
        return 0
    fi

    source core/discovery.sh &>/dev/null

    # Run discovery
    echo "Running discovery on: $TEST_RESOURCE_GROUP"
    if discover_resource_group "$TEST_RESOURCE_GROUP" 2>&1 | tee /tmp/discovery-test.log; then
        test_pass "Full discovery execution"
    else
        test_fail "Full discovery execution" "Discovery failed"
        return 1
    fi

    # Check outputs
    assert_file_exists "discovered/inventory-summary.yaml" "Inventory summary generated"
    assert_file_exists "discovered/inventory-full.json" "Full inventory generated"
    assert_file_exists "discovered/dependency-graph.dot" "Dependency graph generated"

    # Validate inventory summary
    if grep -q "discovery:" discovered/inventory-summary.yaml; then
        test_pass "Inventory summary format valid"
    else
        test_fail "Inventory summary format valid" "Invalid YAML format"
    fi

    # Validate full inventory
    if jq -e '.discovery.total_resources' discovered/inventory-full.json &>/dev/null; then
        test_pass "Full inventory JSON valid"
    else
        test_fail "Full inventory JSON valid" "Invalid JSON format"
    fi
}

# ==============================================================================
# Cleanup
# ==============================================================================

cleanup() {
    if [[ "$CLEANUP_AFTER_TEST" == "true" ]]; then
        echo ""
        echo "Cleaning up test artifacts..."
        rm -f state.db state.db-wal state.db-shm
        rm -f /tmp/discovery-test.log
        echo "Cleanup complete"
    fi
}

# ==============================================================================
# Test Summary
# ==============================================================================

print_summary() {
    echo ""
    echo "========================================================================"
    echo "TEST SUMMARY"
    echo "========================================================================"
    echo ""
    echo "  Tests Run:    $TESTS_RUN"
    echo -e "  Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "  Tests Failed: ${RED}$TESTS_FAILED${NC}"
    echo ""

    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}ALL TESTS PASSED${NC}"
        echo ""
        return 0
    else
        echo -e "${RED}SOME TESTS FAILED${NC}"
        echo ""
        return 1
    fi
}

# ==============================================================================
# Main Execution
# ==============================================================================

main() {
    echo "========================================================================"
    echo "Azure Infrastructure Toolkit - Discovery Engine Test Suite"
    echo "========================================================================"
    echo ""

    # Run tests
    test_01_prerequisites
    test_02_file_structure
    test_03_module_loading
    test_04_state_database_init
    test_05_helper_functions
    test_06_jq_filters
    test_07_mock_discovery
    test_08_output_directories
    test_09_dependency_detection
    test_10_integration_test

    # Cleanup
    cleanup

    # Print summary
    print_summary
}

# Run main
main
exit $?
