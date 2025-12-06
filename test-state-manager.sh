#!/bin/bash
# ==============================================================================
# State Manager Test Suite
# ==============================================================================
#
# Purpose: Comprehensive test of state-manager.sh functionality
#
# Usage:
#   ./test-state-manager.sh
#
# ==============================================================================

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PROJECT_ROOT

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0

# ==============================================================================
# TEST HELPERS
# ==============================================================================

print_header() {
    echo ""
    echo "========================================================================"
    echo "  $1"
    echo "========================================================================"
    echo ""
}

print_test() {
    echo -n "  Testing: $1 ... "
}

pass() {
    echo -e "${GREEN}PASS${NC}"
    ((TESTS_PASSED++))
}

fail() {
    echo -e "${RED}FAIL${NC}"
    if [[ -n "${1:-}" ]]; then
        echo "    Error: $1"
    fi
    ((TESTS_FAILED++))
}

# ==============================================================================
# SETUP
# ==============================================================================

print_header "State Manager Test Suite"

# Clean up any existing test database
TEST_DB="$PROJECT_ROOT/state.db"
if [[ -f "$TEST_DB" ]]; then
    echo "[*] Removing existing test database..."
    rm -f "$TEST_DB"
fi

# Source the state manager
echo "[*] Loading state-manager.sh..."
# Disable verbose logging during tests
export CURRENT_LOG_LEVEL=2  # WARN level
source "$PROJECT_ROOT/core/state-manager.sh" 2>/dev/null || source "$PROJECT_ROOT/core/state-manager.sh"

# ==============================================================================
# TEST 1: Database Initialization
# ==============================================================================

print_header "Test 1: Database Initialization"

print_test "Initialize database"
if init_state_db; then
    pass
else
    fail "Failed to initialize database"
fi

print_test "Check database file exists"
if [[ -f "$TEST_DB" ]]; then
    pass
else
    fail "Database file not created"
fi

print_test "Check tables exist"
table_count=$(sqlite3 "$TEST_DB" "SELECT COUNT(*) FROM sqlite_master WHERE type='table';")
if [[ "$table_count" -ge 5 ]]; then
    pass
else
    fail "Expected at least 5 tables, found $table_count"
fi

print_test "Re-initialize (idempotent)"
if init_state_db; then
    pass
else
    fail "Re-initialization failed"
fi

# ==============================================================================
# TEST 2: Resource Management
# ==============================================================================

print_header "Test 2: Resource Management"

# Create test resource JSON
TEST_RESOURCE_JSON='{
  "id": "/subscriptions/test-sub/resourceGroups/test-rg/providers/Microsoft.Compute/virtualMachines/test-vm",
  "name": "test-vm",
  "type": "Microsoft.Compute/virtualMachines",
  "location": "eastus",
  "resourceGroup": "test-rg",
  "subscriptionId": "test-sub-123",
  "properties": {
    "provisioningState": "Succeeded",
    "vmId": "12345"
  },
  "tags": {
    "environment": "test",
    "owner": "toolkit"
  }
}'

print_test "Store resource"
if store_resource "$TEST_RESOURCE_JSON"; then
    pass
else
    fail "Failed to store resource"
fi

print_test "Verify resource in database"
stored_count=$(sqlite3 "$TEST_DB" "SELECT COUNT(*) FROM resources WHERE name='test-vm';")
if [[ "$stored_count" -eq 1 ]]; then
    pass
else
    fail "Expected 1 resource, found $stored_count"
fi

print_test "Mark resource as managed"
if mark_as_managed "/subscriptions/test-sub/resourceGroups/test-rg/providers/Microsoft.Compute/virtualMachines/test-vm"; then
    pass
else
    fail "Failed to mark as managed"
fi

print_test "Verify managed flag"
managed=$(sqlite3 "$TEST_DB" "SELECT managed_by_toolkit FROM resources WHERE name='test-vm';")
if [[ "$managed" -eq 1 ]]; then
    pass
else
    fail "Resource not marked as managed"
fi

print_test "Soft delete resource"
if soft_delete_resource "/subscriptions/test-sub/resourceGroups/test-rg/providers/Microsoft.Compute/virtualMachines/test-vm"; then
    pass
else
    fail "Failed to soft delete"
fi

print_test "Verify soft delete"
deleted_at=$(sqlite3 "$TEST_DB" "SELECT deleted_at FROM resources WHERE name='test-vm';")
if [[ -n "$deleted_at" ]] && [[ "$deleted_at" != "NULL" ]]; then
    pass
else
    fail "Resource not soft deleted"
fi

# ==============================================================================
# TEST 3: Dependency Management
# ==============================================================================

print_header "Test 3: Dependency Management"

# Create two test resources for dependency testing
RESOURCE_1_JSON='{
  "id": "/subscriptions/test-sub/resourceGroups/test-rg/providers/Microsoft.Network/virtualNetworks/test-vnet",
  "name": "test-vnet",
  "type": "Microsoft.Network/virtualNetworks",
  "location": "eastus",
  "resourceGroup": "test-rg",
  "subscriptionId": "test-sub-123",
  "properties": {
    "provisioningState": "Succeeded"
  }
}'

RESOURCE_2_JSON='{
  "id": "/subscriptions/test-sub/resourceGroups/test-rg/providers/Microsoft.Compute/virtualMachines/test-vm-2",
  "name": "test-vm-2",
  "type": "Microsoft.Compute/virtualMachines",
  "location": "eastus",
  "resourceGroup": "test-rg",
  "subscriptionId": "test-sub-123",
  "properties": {
    "provisioningState": "Succeeded"
  }
}'

store_resource "$RESOURCE_1_JSON" &>/dev/null
store_resource "$RESOURCE_2_JSON" &>/dev/null

print_test "Add dependency"
if add_dependency \
    "/subscriptions/test-sub/resourceGroups/test-rg/providers/Microsoft.Compute/virtualMachines/test-vm-2" \
    "/subscriptions/test-sub/resourceGroups/test-rg/providers/Microsoft.Network/virtualNetworks/test-vnet" \
    "required" \
    "uses"; then
    pass
else
    fail "Failed to add dependency"
fi

print_test "Verify dependency in database"
dep_count=$(sqlite3 "$TEST_DB" "SELECT COUNT(*) FROM dependencies;")
if [[ "$dep_count" -ge 1 ]]; then
    pass
else
    fail "Dependency not stored"
fi

print_test "Get dependencies"
deps=$(get_dependencies "/subscriptions/test-sub/resourceGroups/test-rg/providers/Microsoft.Compute/virtualMachines/test-vm-2")
if [[ -n "$deps" ]] && [[ "$deps" != "[]" ]]; then
    pass
else
    fail "Failed to get dependencies"
fi

print_test "Check dependencies satisfied"
if check_dependencies_satisfied "/subscriptions/test-sub/resourceGroups/test-rg/providers/Microsoft.Compute/virtualMachines/test-vm-2"; then
    pass
else
    fail "Dependencies check failed"
fi

# ==============================================================================
# TEST 4: Operation Management
# ==============================================================================

print_header "Test 4: Operation Management"

TEST_OP_ID="test-operation-$(date +%s)"

print_test "Create operation"
if create_operation "$TEST_OP_ID" "compute" "vm-create" "create" ""; then
    pass
else
    fail "Failed to create operation"
fi

print_test "Update operation status to running"
if update_operation_status "$TEST_OP_ID" "running"; then
    pass
else
    fail "Failed to update status"
fi

print_test "Update operation progress"
if update_operation_progress "$TEST_OP_ID" 1 3 "Installing OS"; then
    pass
else
    fail "Failed to update progress"
fi

print_test "Log operation message"
if log_operation "$TEST_OP_ID" "INFO" "Test log message"; then
    pass
else
    fail "Failed to log operation"
fi

print_test "Update operation status to completed"
if update_operation_status "$TEST_OP_ID" "completed"; then
    pass
else
    fail "Failed to complete operation"
fi

print_test "Get operation status"
status=$(get_operation_status "$TEST_OP_ID")
if [[ -n "$status" ]] && [[ "$status" != "[]" ]]; then
    pass
else
    fail "Failed to get operation status"
fi

# Create a failed operation for testing
FAILED_OP_ID="test-failed-$(date +%s)"
create_operation "$FAILED_OP_ID" "compute" "vm-create" "create" "" &>/dev/null
update_operation_status "$FAILED_OP_ID" "running" &>/dev/null
update_operation_status "$FAILED_OP_ID" "failed" "Test error" &>/dev/null

print_test "Get failed operations"
failed=$(get_failed_operations)
if [[ -n "$failed" ]] && [[ "$failed" != "[]" ]]; then
    pass
else
    fail "Failed to get failed operations"
fi

# ==============================================================================
# TEST 5: Cache Management
# ==============================================================================

print_header "Test 5: Cache Management"

print_test "Invalidate cache"
if invalidate_cache "Microsoft.Compute%" "testing"; then
    pass
else
    fail "Failed to invalidate cache"
fi

print_test "Clean expired cache"
if clean_expired_cache; then
    pass
else
    fail "Failed to clean cache"
fi

# ==============================================================================
# TEST 6: Analytics
# ==============================================================================

print_header "Test 6: Analytics"

print_test "Get operation stats"
stats=$(get_operation_stats)
if [[ -n "$stats" ]]; then
    pass
else
    fail "Failed to get stats"
fi

print_test "Get managed resources count"
count=$(get_managed_resources_count)
if [[ -n "$count" ]]; then
    pass
else
    fail "Failed to get count"
fi

print_test "Get resources by type"
by_type=$(get_resources_by_type)
if [[ -n "$by_type" ]]; then
    pass
else
    fail "Failed to get resources by type"
fi

# ==============================================================================
# TEST 7: SQL Escape Function
# ==============================================================================

print_header "Test 7: SQL Escape Function"

print_test "SQL escape single quotes"
input="test's value"
output=$(sql_escape "$input")
if [[ "$output" == "test''s value" ]]; then
    pass
else
    fail "Expected \"test''s value\", got \"$output\""
fi

print_test "SQL escape complex string"
input="O'Reilly's \"Book\" & Co."
output=$(sql_escape "$input")
if [[ "$output" == "O''Reilly''s \"Book\" & Co." ]]; then
    pass
else
    fail "SQL escape failed on complex string"
fi

# ==============================================================================
# TEST SUMMARY
# ==============================================================================

print_header "Test Summary"

TOTAL_TESTS=$((TESTS_PASSED + TESTS_FAILED))

echo "Total Tests: $TOTAL_TESTS"
echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
echo ""

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}ALL TESTS PASSED!${NC}"
    echo ""
    exit 0
else
    echo -e "${RED}SOME TESTS FAILED!${NC}"
    echo ""
    exit 1
fi
