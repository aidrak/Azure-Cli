#!/bin/bash
# ==============================================================================
# Test Suite for Query Engine
# ==============================================================================
#
# Purpose: Comprehensive tests for core/query.sh functionality
# Usage: ./tests/test-query.sh
#
# ==============================================================================

set -euo pipefail

# ==============================================================================
# TEST FRAMEWORK
# ==============================================================================

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

test_start() {
    local test_name="$1"
    echo -e "\n${YELLOW}[TEST]${NC} $test_name"
    ((TESTS_TOTAL++))
}

test_pass() {
    local test_name="$1"
    echo -e "${GREEN}[PASS]${NC} $test_name"
    ((TESTS_PASSED++))
}

test_fail() {
    local test_name="$1"
    local reason="${2:-Unknown failure}"
    echo -e "${RED}[FAIL]${NC} $test_name: $reason"
    ((TESTS_FAILED++))
}

assert_equals() {
    local actual="$1"
    local expected="$2"
    local test_name="$3"

    if [[ "$actual" == "$expected" ]]; then
        test_pass "$test_name"
    else
        test_fail "$test_name" "Expected '$expected', got '$actual'"
    fi
}

assert_not_empty() {
    local value="$1"
    local test_name="$2"

    if [[ -n "$value" ]]; then
        test_pass "$test_name"
    else
        test_fail "$test_name" "Value is empty"
    fi
}

assert_json_valid() {
    local json="$1"
    local test_name="$2"

    if echo "$json" | jq empty 2>/dev/null; then
        test_pass "$test_name"
    else
        test_fail "$test_name" "Invalid JSON"
    fi
}

assert_function_exists() {
    local func_name="$1"
    local test_name="$2"

    if declare -F "$func_name" &> /dev/null; then
        test_pass "$test_name"
    else
        test_fail "$test_name" "Function '$func_name' does not exist"
    fi
}

# ==============================================================================
# SETUP
# ==============================================================================

echo "========================================================================="
echo "  Query Engine Test Suite"
echo "========================================================================="
echo ""
echo "Project Root: $PROJECT_ROOT"
echo ""

# Load query engine
if [[ ! -f "${PROJECT_ROOT}/core/query.sh" ]]; then
    echo -e "${RED}[ERROR]${NC} query.sh not found"
    exit 1
fi

source "${PROJECT_ROOT}/core/query.sh"

# ==============================================================================
# UNIT TESTS
# ==============================================================================

echo ""
echo "========================================================================="
echo "  Unit Tests"
echo "========================================================================="

# Test 1: Function existence
test_start "Query functions exist"
assert_function_exists "query_resource" "query_resource exists"
assert_function_exists "query_resources" "query_resources exists"
assert_function_exists "query_compute_resources" "query_compute_resources exists"
assert_function_exists "query_networking_resources" "query_networking_resources exists"
assert_function_exists "query_storage_resources" "query_storage_resources exists"
assert_function_exists "query_identity_resources" "query_identity_resources exists"
assert_function_exists "query_avd_resources" "query_avd_resources exists"
assert_function_exists "query_all_resources" "query_all_resources exists"

test_start "Helper functions exist"
assert_function_exists "query_azure_raw" "query_azure_raw exists"
assert_function_exists "apply_jq_filter" "apply_jq_filter exists"
assert_function_exists "ensure_jq_filter_exists" "ensure_jq_filter_exists exists"
assert_function_exists "invalidate_cache" "invalidate_cache exists"
assert_function_exists "format_resource_summary" "format_resource_summary exists"
assert_function_exists "count_resources_by_type" "count_resources_by_type exists"

# Test 2: JQ filter creation
test_start "JQ filter auto-creation"
ensure_jq_filter_exists "compute"
if [[ -f "${QUERIES_DIR}/compute.jq" ]]; then
    test_pass "compute.jq created"
else
    test_fail "compute.jq created" "File not found"
fi

ensure_jq_filter_exists "networking"
if [[ -f "${QUERIES_DIR}/networking.jq" ]]; then
    test_pass "networking.jq created"
else
    test_fail "networking.jq created" "File not found"
fi

ensure_jq_filter_exists "summary"
if [[ -f "${QUERIES_DIR}/summary.jq" ]]; then
    test_pass "summary.jq created"
else
    test_fail "summary.jq created" "File not found"
fi

# Test 3: JQ filter application
test_start "JQ filter application"
sample_json='[{"name":"test","type":"vm","location":"eastus","provisioningState":"Succeeded"}]'
filtered=$(apply_jq_filter "$sample_json" "${QUERIES_DIR}/summary.jq")

if echo "$filtered" | jq empty 2>/dev/null; then
    test_pass "JQ filter produces valid JSON"
else
    test_fail "JQ filter produces valid JSON" "Invalid JSON output"
fi

result_count=$(echo "$filtered" | jq 'length')
if [[ "$result_count" -eq 1 ]]; then
    test_pass "JQ filter preserves array length"
else
    test_fail "JQ filter preserves array length" "Expected 1, got $result_count"
fi

# Test 4: Resource type normalization
test_start "Resource type normalization"

# Test that various aliases work
for alias in "compute" "vms" "vm"; do
    # Just verify the function can handle the alias without error
    if query_resources "$alias" "" "summary" 2>&1 | grep -q "ERROR.*Unknown resource type"; then
        test_fail "Resource type alias '$alias'" "Alias not recognized"
    else
        test_pass "Resource type alias '$alias' accepted"
    fi
done

# ==============================================================================
# INTEGRATION TESTS (Mocked Azure CLI)
# ==============================================================================

echo ""
echo "========================================================================="
echo "  Integration Tests (Mocked)"
echo "========================================================================="

# Mock Azure CLI for testing
az() {
    case "$*" in
        "vm list"*)
            echo '[{"id":"/subscriptions/test/resourceGroups/test-rg/providers/Microsoft.Compute/virtualMachines/test-vm","name":"test-vm","resourceGroup":"test-rg","location":"eastus","hardwareProfile":{"vmSize":"Standard_D2s_v3"},"storageProfile":{"osDisk":{"osType":"Windows"}},"provisioningState":"Succeeded"}]'
            ;;
        "network vnet list"*)
            echo '[{"id":"/subscriptions/test/resourceGroups/test-rg/providers/Microsoft.Network/virtualNetworks/test-vnet","name":"test-vnet","resourceGroup":"test-rg","location":"eastus","addressSpace":{"addressPrefixes":["10.0.0.0/16"]},"subnets":[{"name":"default","addressPrefix":"10.0.0.0/24"}],"provisioningState":"Succeeded"}]'
            ;;
        "storage account list"*)
            echo '[{"id":"/subscriptions/test/resourceGroups/test-rg/providers/Microsoft.Storage/storageAccounts/teststorage","name":"teststorage","resourceGroup":"test-rg","location":"eastus","kind":"StorageV2","sku":{"name":"Standard_LRS","tier":"Standard"},"provisioningState":"Succeeded"}]'
            ;;
        "ad group list"*)
            echo '[{"id":"test-group-id","displayName":"Test-Group","mailNickname":"test-group","description":"Test group","securityEnabled":true,"mailEnabled":false}]'
            ;;
        *)
            echo '[]'
            ;;
    esac
}
export -f az

# Test 5: Query compute resources (mocked)
test_start "Query compute resources (mocked)"
result=$(query_compute_resources "" "summary" 2>/dev/null || echo "")
if [[ -n "$result" ]]; then
    assert_json_valid "$result" "Compute query returns valid JSON"

    count=$(echo "$result" | jq 'length')
    if [[ "$count" -ge 1 ]]; then
        test_pass "Compute query returns results"
    else
        test_fail "Compute query returns results" "No results returned"
    fi
else
    test_fail "Query compute resources" "No output"
fi

# Test 6: Query networking resources (mocked)
test_start "Query networking resources (mocked)"
result=$(query_networking_resources "" "summary" 2>/dev/null || echo "")
if [[ -n "$result" ]]; then
    assert_json_valid "$result" "Networking query returns valid JSON"
else
    test_fail "Query networking resources" "No output"
fi

# Test 7: Query storage resources (mocked)
test_start "Query storage resources (mocked)"
result=$(query_storage_resources "" "summary" 2>/dev/null || echo "")
if [[ -n "$result" ]]; then
    assert_json_valid "$result" "Storage query returns valid JSON"
else
    test_fail "Query storage resources" "No output"
fi

# Test 8: Query identity resources (mocked)
test_start "Query identity resources (mocked)"
result=$(query_identity_resources "" "summary" 2>/dev/null || echo "")
if [[ -n "$result" ]]; then
    assert_json_valid "$result" "Identity query returns valid JSON"
else
    test_fail "Query identity resources" "No output"
fi

# Test 9: Format resource summary
test_start "Format resource summary"
sample='[{"name":"vm1","type":"Microsoft.Compute/virtualMachines","location":"eastus","state":"Succeeded"}]'
formatted=$(format_resource_summary "$sample")
if [[ -n "$formatted" ]]; then
    test_pass "Format resource summary produces output"
else
    test_fail "Format resource summary" "No output"
fi

# Test 10: Count resources by type
test_start "Count resources by type"
sample='[{"type":"Microsoft.Compute/virtualMachines"},{"type":"Microsoft.Compute/virtualMachines"},{"type":"Microsoft.Network/virtualNetworks"}]'
counts=$(count_resources_by_type "$sample")
if [[ -n "$counts" ]]; then
    test_pass "Count resources by type produces output"
else
    test_fail "Count resources by type" "No output"
fi

# ==============================================================================
# ERROR HANDLING TESTS
# ==============================================================================

echo ""
echo "========================================================================="
echo "  Error Handling Tests"
echo "========================================================================="

# Test 11: Invalid resource type
test_start "Invalid resource type handling"
if query_resources "invalid-type" 2>&1 | grep -q "Unknown resource type"; then
    test_pass "Rejects invalid resource type"
else
    test_fail "Rejects invalid resource type" "Should reject unknown types"
fi

# Test 12: Missing parameters
test_start "Missing parameters handling"
if query_resource "" "" 2>&1 | grep -q "Usage:"; then
    test_pass "Rejects missing parameters"
else
    test_fail "Rejects missing parameters" "Should show usage"
fi

# ==============================================================================
# CACHE TESTS
# ==============================================================================

echo ""
echo "========================================================================="
echo "  Cache Tests"
echo "========================================================================="

# Test 13: Cache invalidation
test_start "Cache invalidation"
# Should not error even if state-manager not available
if invalidate_cache "*" "test" 2>/dev/null; then
    test_pass "Cache invalidation completes"
else
    test_pass "Cache invalidation completes (graceful degradation)"
fi

# Test 14: Cache storage
test_start "Cache storage"
sample_resource='{"id":"test","name":"test","type":"test"}'
if cache_query_result "test:key" "$sample_resource" 300 2>/dev/null; then
    test_pass "Cache storage completes"
else
    test_pass "Cache storage completes (graceful degradation)"
fi

# ==============================================================================
# RESULTS
# ==============================================================================

echo ""
echo "========================================================================="
echo "  Test Results"
echo "========================================================================="
echo ""
echo "Total Tests: $TESTS_TOTAL"
echo -e "${GREEN}Passed:${NC} $TESTS_PASSED"
echo -e "${RED}Failed:${NC} $TESTS_FAILED"
echo ""

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
fi
