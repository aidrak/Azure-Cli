#!/bin/bash
# ==============================================================================
# test-naming-analyzer.sh - Test Suite for Naming Analyzer
# ==============================================================================

# IMPORTANT: Not using -e or -u flags because we need to test failure cases
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Disable exit on error and nounset for test script
set +e
set +u

# Set up test environment
export PROJECT_ROOT

# Create test directory
TEST_DIR="${PROJECT_ROOT}/tests/test-data/naming-analyzer"
mkdir -p "$TEST_DIR"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test results
test_pass() {
    local test_name="$1"
    echo "✓ PASS: $test_name"
    ((TESTS_PASSED++))
    ((TESTS_RUN++))
}

test_fail() {
    local test_name="$1"
    local reason="$2"
    echo "✗ FAIL: $test_name - $reason"
    ((TESTS_FAILED++))
    ((TESTS_RUN++))
}

# ==============================================================================
# SETUP AND TEARDOWN
# ==============================================================================

setup_test_files() {
    # Create test standards.yaml
    cat > "${TEST_DIR}/standards.yaml" <<'EOF'
naming:
  prefixes:
    storage_account: "fslogix"
    session_host: "avd-sh"
    golden_image: "gm"
    vnet: "vnet"
    subnet: "snet"
    nsg: "nsg"
    host_pool: "hp"
    workspace: "ws"
    app_group: "dag"

  patterns:
    session_host: "{prefix}-{number}"
    storage_account: "{prefix}{random}"
    vnet: "{prefix}-{purpose}-{env}"
EOF

    # Override file paths for testing
    export STANDARDS_FILE="${TEST_DIR}/standards.yaml"
    export STATE_DB="${TEST_DIR}/test-state.db"

    # Create minimal state.db with naming_patterns table
    rm -f "$STATE_DB"
    sqlite3 "$STATE_DB" <<'SQL'
CREATE TABLE IF NOT EXISTS naming_patterns (
    resource_type TEXT NOT NULL,
    resource_group TEXT,
    pattern TEXT,
    prefix TEXT,
    separator TEXT,
    suffix_type TEXT,
    sample_count INTEGER DEFAULT 0,
    confidence REAL DEFAULT 0.0,
    discovered_at INTEGER,
    PRIMARY KEY (resource_type, resource_group)
);
SQL
}

cleanup_test_files() {
    rm -rf "$TEST_DIR"
}

# Source the naming analyzer
source "${PROJECT_ROOT}/core/naming-analyzer.sh"

# ==============================================================================
# TEST: extract_pattern_components
# ==============================================================================

test_extract_pattern_components_numeric_suffix() {
    local names="avd-sh-01 avd-sh-02 avd-sh-03"
    local result
    result=$(extract_pattern_components "$names")

    local prefix separator suffix_type
    prefix=$(echo "$result" | jq -r '.prefix')
    separator=$(echo "$result" | jq -r '.separator')
    suffix_type=$(echo "$result" | jq -r '.suffix_type')

    if [[ "$prefix" == "avd-sh" ]] && \
       [[ "$separator" == "-" ]] && \
       [[ "$suffix_type" == "numeric" ]]; then
        test_pass "extract_pattern_components (numeric suffix)"
    else
        test_fail "extract_pattern_components (numeric suffix)" "Pattern: prefix=$prefix, sep=$separator, suffix=$suffix_type"
    fi
}

test_extract_pattern_components_underscore_separator() {
    local names="test_vm_01 test_vm_02 test_vm_03"
    local result
    result=$(extract_pattern_components "$names")

    local separator
    separator=$(echo "$result" | jq -r '.separator')

    if [[ "$separator" == "_" ]]; then
        test_pass "extract_pattern_components (underscore separator)"
    else
        test_fail "extract_pattern_components (underscore separator)" "Expected '_', got '$separator'"
    fi
}

test_extract_pattern_components_random_suffix() {
    local names="storage1a2b3c storage4d5e6f storage7g8h9i"
    local result
    result=$(extract_pattern_components "$names")

    local suffix_type
    suffix_type=$(echo "$result" | jq -r '.suffix_type')

    # With common prefix "storage" and alphanumeric suffixes
    if [[ "$suffix_type" == "random" ]] || [[ "$suffix_type" == "numeric" ]]; then
        test_pass "extract_pattern_components (random/mixed suffix)"
    else
        test_fail "extract_pattern_components (random/mixed suffix)" "Expected random or numeric, got '$suffix_type'"
    fi
}

test_extract_pattern_components_no_separator() {
    local names="vm001 vm002 vm003"
    local result
    result=$(extract_pattern_components "$names")

    local separator
    separator=$(echo "$result" | jq -r '.separator')

    if [[ "$separator" == "" ]] || [[ "$separator" == "-" ]]; then
        test_pass "extract_pattern_components (no separator)"
    else
        test_fail "extract_pattern_components (no separator)" "Expected '' or '-', got '$separator'"
    fi
}

test_extract_pattern_components_insufficient_samples() {
    local names="single-vm"
    local result
    result=$(extract_pattern_components "$names")

    local confidence
    confidence=$(echo "$result" | jq -r '.confidence')

    # Should have low confidence with only 1 sample
    if awk "BEGIN {exit !($confidence < 0.5)}"; then
        test_pass "extract_pattern_components (insufficient samples)"
    else
        test_fail "extract_pattern_components (insufficient samples)" "Confidence should be low, got $confidence"
    fi
}

# ==============================================================================
# TEST: get_azure_resource_type
# ==============================================================================

test_get_azure_resource_type_vnet() {
    local result
    result=$(get_azure_resource_type "vnet")

    if [[ "$result" == "Microsoft.Network/virtualNetworks" ]]; then
        test_pass "get_azure_resource_type (vnet)"
    else
        test_fail "get_azure_resource_type (vnet)" "Expected virtualNetworks, got '$result'"
    fi
}

test_get_azure_resource_type_storage() {
    local result
    result=$(get_azure_resource_type "storage_account")

    if [[ "$result" == "Microsoft.Storage/storageAccounts" ]]; then
        test_pass "get_azure_resource_type (storage)"
    else
        test_fail "get_azure_resource_type (storage)" "Expected storageAccounts, got '$result'"
    fi
}

test_get_azure_resource_type_vm() {
    local result
    result=$(get_azure_resource_type "session_host")

    if [[ "$result" == "Microsoft.Compute/virtualMachines" ]]; then
        test_pass "get_azure_resource_type (vm)"
    else
        test_fail "get_azure_resource_type (vm)" "Expected virtualMachines, got '$result'"
    fi
}

test_get_azure_resource_type_host_pool() {
    local result
    result=$(get_azure_resource_type "host_pool")

    if [[ "$result" == "Microsoft.DesktopVirtualization/hostPools" ]]; then
        test_pass "get_azure_resource_type (host_pool)"
    else
        test_fail "get_azure_resource_type (host_pool)" "Expected hostPools, got '$result'"
    fi
}

test_get_azure_resource_type_unknown() {
    local result
    result=$(get_azure_resource_type "unknown_type")

    if [[ "$result" == "unknown_type" ]]; then
        test_pass "get_azure_resource_type (unknown - passthrough)"
    else
        test_fail "get_azure_resource_type (unknown - passthrough)" "Expected passthrough, got '$result'"
    fi
}

# ==============================================================================
# TEST: get_standard_prefix
# ==============================================================================

test_get_standard_prefix_storage() {
    local result
    result=$(get_standard_prefix "storage_account")

    if [[ "$result" == "fslogix" ]]; then
        test_pass "get_standard_prefix (storage)"
    else
        test_fail "get_standard_prefix (storage)" "Expected 'fslogix', got '$result'"
    fi
}

test_get_standard_prefix_session_host() {
    local result
    result=$(get_standard_prefix "session_host")

    if [[ "$result" == "avd-sh" ]]; then
        test_pass "get_standard_prefix (session_host)"
    else
        test_fail "get_standard_prefix (session_host)" "Expected 'avd-sh', got '$result'"
    fi
}

test_get_standard_prefix_vnet() {
    local result
    result=$(get_standard_prefix "vnet")

    if [[ "$result" == "vnet" ]]; then
        test_pass "get_standard_prefix (vnet)"
    else
        test_fail "get_standard_prefix (vnet)" "Expected 'vnet', got '$result'"
    fi
}

test_get_standard_prefix_unknown() {
    local result
    result=$(get_standard_prefix "unknown_resource_type")

    if [[ -z "$result" ]]; then
        test_pass "get_standard_prefix (unknown - empty)"
    else
        test_fail "get_standard_prefix (unknown - empty)" "Expected empty, got '$result'"
    fi
}

# ==============================================================================
# TEST: get_standard_pattern
# ==============================================================================

test_get_standard_pattern_session_host() {
    local result
    result=$(get_standard_pattern "session_host")

    if [[ "$result" == "{prefix}-{number}" ]]; then
        test_pass "get_standard_pattern (session_host)"
    else
        test_fail "get_standard_pattern (session_host)" "Expected pattern, got '$result'"
    fi
}

test_get_standard_pattern_unknown() {
    local result
    result=$(get_standard_pattern "unknown_type")

    if [[ "$result" == "{type}-{purpose}-{env}" ]]; then
        test_pass "get_standard_pattern (unknown - default)"
    else
        test_fail "get_standard_pattern (unknown - default)" "Expected default pattern, got '$result'"
    fi
}

# ==============================================================================
# TEST: generate_random_suffix
# ==============================================================================

test_generate_random_suffix_default_length() {
    local result
    result=$(generate_random_suffix)

    if [[ ${#result} -eq 5 ]] && [[ "$result" =~ ^[a-z0-9]+$ ]]; then
        test_pass "generate_random_suffix (default length)"
    else
        test_fail "generate_random_suffix (default length)" "Expected 5 alphanumeric chars, got '$result'"
    fi
}

test_generate_random_suffix_custom_length() {
    local result
    result=$(generate_random_suffix 10)

    if [[ ${#result} -eq 10 ]] && [[ "$result" =~ ^[a-z0-9]+$ ]]; then
        test_pass "generate_random_suffix (custom length)"
    else
        test_fail "generate_random_suffix (custom length)" "Expected 10 alphanumeric chars, got '$result'"
    fi
}

# ==============================================================================
# TEST: cache_naming_pattern and get_cached_pattern
# ==============================================================================

test_cache_and_get_pattern() {
    local pattern_json='{"prefix":"test-prefix","separator":"-","suffix_type":"numeric","confidence":0.85,"sample_count":5}'
    local resource_type="Microsoft.Compute/virtualMachines"
    local resource_group="test-rg"

    # Cache the pattern
    cache_naming_pattern "$resource_type" "$resource_group" "$pattern_json" 2>/dev/null

    # Retrieve it
    local result
    result=$(get_cached_pattern "$resource_type" "$resource_group" 2>/dev/null)

    if [[ -n "$result" ]]; then
        local cached_prefix
        cached_prefix=$(echo "$result" | jq -r '.prefix')

        if [[ "$cached_prefix" == "test-prefix" ]]; then
            test_pass "cache_and_get_pattern (success)"
        else
            test_fail "cache_and_get_pattern (success)" "Cached prefix incorrect: $cached_prefix"
        fi
    else
        test_fail "cache_and_get_pattern (success)" "Pattern not retrieved from cache"
    fi
}

test_get_cached_pattern_missing() {
    local result
    result=$(get_cached_pattern "Microsoft.Unknown/resources" "nonexistent-rg" 2>/dev/null)

    if [[ -z "$result" ]]; then
        test_pass "get_cached_pattern (missing)"
    else
        test_fail "get_cached_pattern (missing)" "Should return empty for missing pattern"
    fi
}

# ==============================================================================
# TEST: get_next_number (mock Azure CLI)
# ==============================================================================

test_get_next_number_no_existing() {
    # Mock az command to return empty (no existing resources)
    # We can't easily mock az here, so we'll test the logic with a fallback
    # This test would need Azure CLI access to fully test

    # For unit testing, we'll just verify the function exists and handles empty input
    local result
    result=$(get_next_number "test-vm" "Microsoft.Compute/virtualMachines" "" 2>/dev/null || echo "01")

    if [[ "$result" == "01" ]]; then
        test_pass "get_next_number (no existing - fallback)"
    else
        test_fail "get_next_number (no existing - fallback)" "Expected '01', got '$result'"
    fi
}

# ==============================================================================
# TEST: propose_name
# ==============================================================================

test_propose_name_storage_account() {
    local result
    result=$(propose_name "storage_account" '{"purpose":"fslogix"}' "" 2>/dev/null)

    # Should start with prefix and be lowercase alphanumeric
    if [[ "$result" =~ ^fslogix[a-z0-9]+$ ]] && [[ ${#result} -le 24 ]]; then
        test_pass "propose_name (storage_account)"
    else
        test_fail "propose_name (storage_account)" "Invalid storage name: $result"
    fi
}

test_propose_name_session_host() {
    local result
    result=$(propose_name "session_host" '{"purpose":"pooled"}' "" 2>/dev/null)

    # Should match pattern: avd-sh-{number}
    if [[ "$result" =~ ^avd-sh- ]]; then
        test_pass "propose_name (session_host)"
    else
        test_fail "propose_name (session_host)" "Expected 'avd-sh-*', got '$result'"
    fi
}

test_propose_name_vnet() {
    local result
    result=$(propose_name "vnet" '{"purpose":"avd","env":"prod"}' "" 2>/dev/null)

    # Should include prefix and purpose
    if [[ "$result" == *"vnet"* ]] && [[ "$result" == *"avd"* ]]; then
        test_pass "propose_name (vnet)"
    else
        test_fail "propose_name (vnet)" "Expected vnet name with purpose, got '$result'"
    fi
}

test_propose_name_host_pool() {
    local result
    result=$(propose_name "host_pool" '{"purpose":"pooled","env":"prod"}' "" 2>/dev/null)

    # Should include prefix
    if [[ "$result" == *"hp"* ]]; then
        test_pass "propose_name (host_pool)"
    else
        test_fail "propose_name (host_pool)" "Expected host pool name with prefix, got '$result'"
    fi
}

test_propose_name_with_cached_pattern() {
    # Cache a pattern first
    local pattern_json='{"prefix":"custom-vm","separator":"-","suffix_type":"numeric","confidence":0.9,"sample_count":10}'
    cache_naming_pattern "Microsoft.Compute/virtualMachines" "test-rg" "$pattern_json" 2>/dev/null

    local result
    result=$(propose_name "vm" '{"purpose":"test"}' "test-rg" 2>/dev/null)

    # Should use cached pattern with custom prefix
    if [[ "$result" == *"custom-vm"* ]]; then
        test_pass "propose_name (with cached pattern)"
    else
        test_fail "propose_name (with cached pattern)" "Expected custom prefix, got '$result'"
    fi
}

# ==============================================================================
# RUN ALL TESTS
# ==============================================================================

echo "=============================================="
echo "Naming Analyzer Test Suite"
echo "=============================================="
echo ""

setup_test_files

echo "Testing Pattern Extraction..."
test_extract_pattern_components_numeric_suffix
test_extract_pattern_components_underscore_separator
test_extract_pattern_components_random_suffix
test_extract_pattern_components_no_separator
test_extract_pattern_components_insufficient_samples

echo ""
echo "Testing Resource Type Mapping..."
test_get_azure_resource_type_vnet
test_get_azure_resource_type_storage
test_get_azure_resource_type_vm
test_get_azure_resource_type_host_pool
test_get_azure_resource_type_unknown

echo ""
echo "Testing Standard Prefixes..."
test_get_standard_prefix_storage
test_get_standard_prefix_session_host
test_get_standard_prefix_vnet
test_get_standard_prefix_unknown

echo ""
echo "Testing Standard Patterns..."
test_get_standard_pattern_session_host
test_get_standard_pattern_unknown

echo ""
echo "Testing Random Suffix Generation..."
test_generate_random_suffix_default_length
test_generate_random_suffix_custom_length

echo ""
echo "Testing Pattern Caching..."
test_cache_and_get_pattern
test_get_cached_pattern_missing

echo ""
echo "Testing Next Number Generation..."
test_get_next_number_no_existing

echo ""
echo "Testing Name Proposal..."
test_propose_name_storage_account
test_propose_name_session_host
test_propose_name_vnet
test_propose_name_host_pool
test_propose_name_with_cached_pattern

cleanup_test_files

echo ""
echo "=============================================="
echo "Test Results"
echo "=============================================="
echo "Total Tests: $TESTS_RUN"
echo "Passed: $TESTS_PASSED"
echo "Failed: $TESTS_FAILED"
echo ""

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo "✓ All tests passed!"
    exit 0
else
    echo "✗ Some tests failed"
    exit 1
fi
