#!/bin/bash
# ==============================================================================
# test-value-resolver.sh - Test Suite for Value Resolver
# ==============================================================================

# IMPORTANT: Not using -e or -u flags because we need to test failure cases and undefined variables
# The sourced modules use set -euo pipefail, but we override for testing
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Set up test environment
export PROJECT_ROOT
export INTERACTIVE_MODE="false"  # Disable prompts during testing
export DISCOVERY_ENABLED="true"
export DEBUG="false"

# Disable exit on error and nounset for test script (modules will re-enable for themselves)
set +e
set +u

# Create test config files
TEST_DIR="${PROJECT_ROOT}/tests/test-data/value-resolver"
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
defaults:
  general:
    location: "centralus"

  compute:
    vm:
      size: "Standard_D4s_v3"
      image:
        publisher: "MicrosoftWindowsDesktop"
        offer: "Windows-10"
        sku: "21h1-evd"

  storage:
    sku: "Standard_LRS"
    kind: "StorageV2"
    https_only: true
    min_tls_version: "TLS1_2"
    file_share:
      quota_gb: 100

  avd:
    host_pool:
      type: "Pooled"
      max_sessions: 16
      load_balancer_type: "BreadthFirst"

  networking:
    vnet:
      address_space: "10.0.0.0/16"
    load_balancer:
      sku: "Standard"

best_practices:
  monitoring:
    log_analytics:
      sku: "PerGB2018"
      retention_days: 30
EOF

    # Create test config.yaml
    cat > "${TEST_DIR}/config.yaml" <<'EOF'
azure:
  subscription_id: "12345678-1234-1234-1234-123456789012"
  tenant_id: "87654321-4321-4321-4321-210987654321"
  location: "eastus"
  resource_group: "test-rg"

networking:
  vnet:
    name: "test-vnet"
    address_space: "10.100.0.0/16"

storage:
  account_name: "teststorage123"
  sku: "Premium_LRS"
EOF

    # Override file paths for testing
    export STANDARDS_FILE="${TEST_DIR}/standards.yaml"
    export CONFIG_FILE="${TEST_DIR}/config.yaml"
    export STATE_DB="${TEST_DIR}/test-state.db"

    # Create minimal state.db
    rm -f "$STATE_DB"
    sqlite3 "$STATE_DB" <<'SQL'
CREATE TABLE IF NOT EXISTS config_overrides (
    config_key TEXT PRIMARY KEY,
    source TEXT NOT NULL,
    value TEXT NOT NULL,
    set_at INTEGER,
    expires_at INTEGER
);
SQL
}

cleanup_test_files() {
    rm -rf "$TEST_DIR"
}

# Source the value resolver
source "${PROJECT_ROOT}/core/value-resolver.sh"

# ==============================================================================
# TEST: resolve_from_environment
# ==============================================================================

test_resolve_from_environment_success() {
    echo "[DEBUG 1.1] Starting test"
    export TEST_VAR_123="test_value_123"

    echo "[DEBUG 1.2] About to resolve"
    local result
    result=$(resolve_from_environment "TEST_VAR_123")
    echo "[DEBUG 1.3] Resolved: $result"

    if [[ "$result" == "test_value_123" ]]; then
        test_pass "resolve_from_environment (success)"
    else
        test_fail "resolve_from_environment (success)" "Expected 'test_value_123', got '$result'"
    fi

    echo "[DEBUG 1.4] About to unset"
    unset TEST_VAR_123
    echo "[DEBUG 1.5] Function returning"
}

test_resolve_from_environment_missing() {
    unset NONEXISTENT_VAR_987

    if ! resolve_from_environment "NONEXISTENT_VAR_987" >/dev/null 2>&1; then
        test_pass "resolve_from_environment (missing)"
    else
        test_fail "resolve_from_environment (missing)" "Should fail for missing variable"
    fi
}

# ==============================================================================
# TEST: resolve_from_standards
# ==============================================================================

test_resolve_from_standards_location() {
    local result
    result=$(resolve_from_standards "AZURE_LOCATION")

    if [[ "$result" == "centralus" ]]; then
        test_pass "resolve_from_standards (location)"
    else
        test_fail "resolve_from_standards (location)" "Expected 'centralus', got '$result'"
    fi
}

test_resolve_from_standards_vm_size() {
    local result
    result=$(resolve_from_standards "GOLDEN_IMAGE_VM_SIZE")

    if [[ "$result" == "Standard_D4s_v3" ]]; then
        test_pass "resolve_from_standards (vm_size)"
    else
        test_fail "resolve_from_standards (vm_size)" "Expected 'Standard_D4s_v3', got '$result'"
    fi
}

test_resolve_from_standards_storage_sku() {
    local result
    result=$(resolve_from_standards "STORAGE_SKU")

    if [[ "$result" == "Standard_LRS" ]]; then
        test_pass "resolve_from_standards (storage_sku)"
    else
        test_fail "resolve_from_standards (storage_sku)" "Expected 'Standard_LRS', got '$result'"
    fi
}

test_resolve_from_standards_host_pool_type() {
    local result
    result=$(resolve_from_standards "HOST_POOL_TYPE")

    if [[ "$result" == "Pooled" ]]; then
        test_pass "resolve_from_standards (host_pool_type)"
    else
        test_fail "resolve_from_standards (host_pool_type)" "Expected 'Pooled', got '$result'"
    fi
}

test_resolve_from_standards_missing() {
    local result
    result=$(resolve_from_standards "NONEXISTENT_CONFIG_KEY" 2>/dev/null)

    if [[ -z "$result" || "$result" == "null" ]]; then
        test_pass "resolve_from_standards (missing)"
    else
        test_fail "resolve_from_standards (missing)" "Expected empty, got '$result'"
    fi
}

# ==============================================================================
# TEST: resolve_from_config
# ==============================================================================

test_resolve_from_config_subscription() {
    local result
    result=$(resolve_from_config "AZURE_SUBSCRIPTION_ID")

    if [[ "$result" == "12345678-1234-1234-1234-123456789012" ]]; then
        test_pass "resolve_from_config (subscription_id)"
    else
        test_fail "resolve_from_config (subscription_id)" "Expected subscription ID, got '$result'"
    fi
}

test_resolve_from_config_vnet_name() {
    local result
    result=$(resolve_from_config "NETWORKING_VNET_NAME")

    if [[ "$result" == "test-vnet" ]]; then
        test_pass "resolve_from_config (vnet_name)"
    else
        test_fail "resolve_from_config (vnet_name)" "Expected 'test-vnet', got '$result'"
    fi
}

test_resolve_from_config_storage_override() {
    # Config has Premium_LRS, standards has Standard_LRS
    local result
    result=$(resolve_from_config "STORAGE_SKU")

    if [[ "$result" == "Premium_LRS" ]]; then
        test_pass "resolve_from_config (storage_override)"
    else
        test_fail "resolve_from_config (storage_override)" "Expected 'Premium_LRS', got '$result'"
    fi
}

# ==============================================================================
# TEST: map_var_to_resource_type
# ==============================================================================

test_map_var_to_resource_type_vnet() {
    local result
    result=$(map_var_to_resource_type "NETWORKING_VNET_NAME")

    if [[ "$result" == "vnet" ]]; then
        test_pass "map_var_to_resource_type (vnet)"
    else
        test_fail "map_var_to_resource_type (vnet)" "Expected 'vnet', got '$result'"
    fi
}

test_map_var_to_resource_type_storage() {
    local result
    result=$(map_var_to_resource_type "STORAGE_ACCOUNT_NAME")

    if [[ "$result" == "storage_account" ]]; then
        test_pass "map_var_to_resource_type (storage)"
    else
        test_fail "map_var_to_resource_type (storage)" "Expected 'storage_account', got '$result'"
    fi
}

test_map_var_to_resource_type_vm() {
    local result
    result=$(map_var_to_resource_type "SESSION_HOST_NAME")

    if [[ "$result" == "vm" ]]; then
        test_pass "map_var_to_resource_type (vm)"
    else
        test_fail "map_var_to_resource_type (vm)" "Expected 'vm', got '$result'"
    fi
}

test_map_var_to_resource_type_unknown() {
    local result
    result=$(map_var_to_resource_type "UNKNOWN_VARIABLE_NAME")

    if [[ -z "$result" ]]; then
        test_pass "map_var_to_resource_type (unknown)"
    else
        test_fail "map_var_to_resource_type (unknown)" "Expected empty, got '$result'"
    fi
}

# ==============================================================================
# TEST: map_var_to_yaml_path
# ==============================================================================

test_map_var_to_yaml_path_simple() {
    local result
    result=$(map_var_to_yaml_path "AZURE_SUBSCRIPTION_ID" "config")

    if [[ "$result" == ".azure.subscription.id" ]]; then
        test_pass "map_var_to_yaml_path (simple)"
    else
        test_fail "map_var_to_yaml_path (simple)" "Expected '.azure.subscription.id', got '$result'"
    fi
}

test_map_var_to_yaml_path_vm_size_standards() {
    local result
    result=$(map_var_to_yaml_path "GOLDEN_IMAGE_VM_SIZE" "standards")

    if [[ "$result" == ".defaults.compute.vm.size" ]]; then
        test_pass "map_var_to_yaml_path (vm_size_standards)"
    else
        test_fail "map_var_to_yaml_path (vm_size_standards)" "Expected '.defaults.compute.vm.size', got '$result'"
    fi
}

test_map_var_to_yaml_path_storage_sku_standards() {
    local result
    result=$(map_var_to_yaml_path "STORAGE_SKU" "standards")

    if [[ "$result" == ".defaults.storage.sku" ]]; then
        test_pass "map_var_to_yaml_path (storage_sku_standards)"
    else
        test_fail "map_var_to_yaml_path (storage_sku_standards)" "Expected '.defaults.storage.sku', got '$result'"
    fi
}

# ==============================================================================
# TEST: cache_resolved_value and get_cached_value
# ==============================================================================

test_cache_and_get_value() {
    # Cache a value
    cache_resolved_value "TEST_CACHED_VAR" "cached_test_value" "user_input"

    # Retrieve it
    local result
    result=$(get_cached_value "TEST_CACHED_VAR")

    if [[ "$result" == "cached_test_value" ]]; then
        test_pass "cache_and_get_value (success)"
    else
        test_fail "cache_and_get_value (success)" "Expected 'cached_test_value', got '$result'"
    fi
}

test_get_cached_value_missing() {
    local result
    result=$(get_cached_value "NONEXISTENT_CACHED_VAR" 2>/dev/null)

    if [[ -z "$result" ]]; then
        test_pass "get_cached_value (missing)"
    else
        test_fail "get_cached_value (missing)" "Expected empty, got '$result'"
    fi
}

# ==============================================================================
# TEST: resolve_value (priority pipeline)
# ==============================================================================

test_resolve_value_environment_priority() {
    # Set environment variable (highest priority)
    export AZURE_LOCATION="env-location"

    local result
    result=$(resolve_value "AZURE_LOCATION")

    if [[ "$result" == "env-location" ]]; then
        test_pass "resolve_value (environment priority)"
    else
        test_fail "resolve_value (environment priority)" "Expected 'env-location', got '$result'"
    fi

    unset AZURE_LOCATION
}

test_resolve_value_config_priority() {
    # No environment variable, should use config.yaml
    unset AZURE_SUBSCRIPTION_ID

    local result
    result=$(resolve_value "AZURE_SUBSCRIPTION_ID")

    if [[ "$result" == "12345678-1234-1234-1234-123456789012" ]]; then
        test_pass "resolve_value (config priority)"
    else
        test_fail "resolve_value (config priority)" "Expected subscription ID, got '$result'"
    fi
}

test_resolve_value_standards_fallback() {
    # Variable not in config, should fall back to standards
    unset HOST_POOL_TYPE

    local result
    result=$(resolve_value "HOST_POOL_TYPE")

    if [[ "$result" == "Pooled" ]]; then
        test_pass "resolve_value (standards fallback)"
    else
        test_fail "resolve_value (standards fallback)" "Expected 'Pooled', got '$result'"
    fi
}

test_resolve_value_not_found() {
    unset COMPLETELY_UNKNOWN_VAR
    export INTERACTIVE_MODE="false"  # Disable prompts

    if ! resolve_value "COMPLETELY_UNKNOWN_VAR" "" "{}" >/dev/null 2>&1; then
        test_pass "resolve_value (not found)"
    else
        test_fail "resolve_value (not found)" "Should fail for unknown variable"
    fi
}

# ==============================================================================
# TEST: validate_required_values
# ==============================================================================

test_validate_required_values_success() {
    export AZURE_SUBSCRIPTION_ID="test-sub-id"
    export AZURE_TENANT_ID="test-tenant-id"

    if validate_required_values "AZURE_SUBSCRIPTION_ID AZURE_TENANT_ID" 2>/dev/null; then
        test_pass "validate_required_values (success)"
    else
        test_fail "validate_required_values (success)" "Should validate successfully"
    fi

    unset AZURE_SUBSCRIPTION_ID AZURE_TENANT_ID
}

test_validate_required_values_missing() {
    unset MISSING_VAR_1 MISSING_VAR_2
    export INTERACTIVE_MODE="false"

    if ! validate_required_values "MISSING_VAR_1 MISSING_VAR_2" 2>/dev/null; then
        test_pass "validate_required_values (missing)"
    else
        test_fail "validate_required_values (missing)" "Should fail for missing values"
    fi
}

# ==============================================================================
# TEST: resolve_values (batch resolution)
# ==============================================================================

test_resolve_values_batch() {
    export VAR_BATCH_1="value1"
    export VAR_BATCH_2="value2"

    local results
    results=$(resolve_values "VAR_BATCH_1 VAR_BATCH_2")

    if echo "$results" | grep -q "VAR_BATCH_1=value1" && \
       echo "$results" | grep -q "VAR_BATCH_2=value2"; then
        test_pass "resolve_values (batch)"
    else
        test_fail "resolve_values (batch)" "Batch resolution failed"
    fi

    unset VAR_BATCH_1 VAR_BATCH_2
}

# ==============================================================================
# RUN ALL TESTS
# ==============================================================================

echo "=============================================="
echo "Value Resolver Test Suite"
echo "=============================================="
echo ""

setup_test_files

echo "Testing Environment Resolution..."
test_resolve_from_environment_success
echo "[DEBUG] About to run test_resolve_from_environment_missing..."
test_resolve_from_environment_missing
echo "[DEBUG] test_resolve_from_environment_missing completed"

echo ""
echo "Testing Standards Resolution..."
test_resolve_from_standards_location
test_resolve_from_standards_vm_size
test_resolve_from_standards_storage_sku
test_resolve_from_standards_host_pool_type
test_resolve_from_standards_missing

echo ""
echo "Testing Config Resolution..."
test_resolve_from_config_subscription
test_resolve_from_config_vnet_name
test_resolve_from_config_storage_override

echo ""
echo "Testing Variable Mapping..."
test_map_var_to_resource_type_vnet
test_map_var_to_resource_type_storage
test_map_var_to_resource_type_vm
test_map_var_to_resource_type_unknown
test_map_var_to_yaml_path_simple
test_map_var_to_yaml_path_vm_size_standards
test_map_var_to_yaml_path_storage_sku_standards

echo ""
echo "Testing Caching..."
test_cache_and_get_value
test_get_cached_value_missing

echo ""
echo "Testing Priority Pipeline..."
test_resolve_value_environment_priority
test_resolve_value_config_priority
test_resolve_value_standards_fallback
test_resolve_value_not_found

echo ""
echo "Testing Validation..."
test_validate_required_values_success
test_validate_required_values_missing

echo ""
echo "Testing Batch Resolution..."
test_resolve_values_batch

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
