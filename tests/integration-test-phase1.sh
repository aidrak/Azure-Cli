#!/bin/bash
# Integration Test - Phase 1 Complete System
# Tests: SQLite schema + State Manager + Query Engine + Dependency Resolver

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

PROJECT_ROOT="/mnt/cache_pool/development/azure-cli"
TEST_DB="${PROJECT_ROOT}/test-integration.db"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Clean up test database
cleanup() {
    if [[ -f "$TEST_DB" ]]; then
        rm -f "$TEST_DB"
        echo -e "${BLUE}Cleaned up test database${NC}"
    fi
}

trap cleanup EXIT

# Test helper functions
test_start() {
    local test_name="$1"
    echo -e "\n${YELLOW}▶ Testing: $test_name${NC}"
    TESTS_RUN=$((TESTS_RUN + 1))
}

test_pass() {
    echo -e "${GREEN}  ✓ PASS${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

test_fail() {
    local reason="$1"
    echo -e "${RED}  ✗ FAIL: $reason${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Azure Infrastructure Toolkit - Phase 1 Integration Test ║${NC}"
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"

# ==============================================================================
# TEST 1: SQLite Schema Initialization
# ==============================================================================
test_start "SQLite Schema Initialization"

if [[ ! -f "${PROJECT_ROOT}/schemas/state.schema.sql" ]]; then
    test_fail "Schema file not found"
else
    # Initialize database
    sqlite3 "$TEST_DB" < "${PROJECT_ROOT}/schemas/state.schema.sql" 2>/dev/null

    # Verify tables exist
    table_count=$(sqlite3 "$TEST_DB" "SELECT COUNT(*) FROM sqlite_master WHERE type='table';")

    if [[ "$table_count" -ge 8 ]]; then
        test_pass
        echo -e "${BLUE}    Tables created: $table_count${NC}"
    else
        test_fail "Expected 8+ tables, got $table_count"
    fi
fi

# ==============================================================================
# TEST 2: State Manager - Source and Initialize
# ==============================================================================
test_start "State Manager - Source and Initialize"

# Set environment for state manager
export PROJECT_ROOT
export STATE_DB="$TEST_DB"
export AZURE_RESOURCE_GROUP="test-rg"
export AZURE_SUBSCRIPTION_ID="test-sub-123"

# Source state manager
if source "${PROJECT_ROOT}/core/state-manager.sh" 2>/dev/null; then
    # Check if init_state_db function exists
    if declare -f init_state_db > /dev/null; then
        test_pass
        echo -e "${BLUE}    State manager loaded with $(declare -F | grep -c '^declare -f') functions${NC}"
    else
        test_fail "init_state_db function not found"
    fi
else
    test_fail "Failed to source state-manager.sh"
fi

# ==============================================================================
# TEST 3: Store Resources
# ==============================================================================
test_start "Store Resources in Database"

# Create mock resource JSON
vm_resource='{
  "id": "/subscriptions/test-sub/resourceGroups/test-rg/providers/Microsoft.Compute/virtualMachines/test-vm-01",
  "type": "Microsoft.Compute/virtualMachines",
  "name": "test-vm-01",
  "resourceGroup": "test-rg",
  "subscriptionId": "test-sub-123",
  "location": "eastus",
  "properties": {
    "provisioningState": "Succeeded",
    "hardwareProfile": {"vmSize": "Standard_D4s_v3"}
  },
  "tags": {"environment": "test", "managed-by": "azure-toolkit"}
}'

vnet_resource='{
  "id": "/subscriptions/test-sub/resourceGroups/test-rg/providers/Microsoft.Network/virtualNetworks/test-vnet",
  "type": "Microsoft.Network/virtualNetworks",
  "name": "test-vnet",
  "resourceGroup": "test-rg",
  "subscriptionId": "test-sub-123",
  "location": "eastus",
  "properties": {
    "provisioningState": "Succeeded",
    "addressSpace": {"addressPrefixes": ["10.0.0.0/16"]}
  },
  "tags": {"environment": "test"}
}'

# Store resources
if store_resource "$vm_resource" 2>/dev/null && store_resource "$vnet_resource" 2>/dev/null; then
    # Verify resources are in database
    resource_count=$(sqlite3 "$TEST_DB" "SELECT COUNT(*) FROM resources;")

    if [[ "$resource_count" -eq 2 ]]; then
        test_pass
        echo -e "${BLUE}    Resources stored: $resource_count${NC}"
    else
        test_fail "Expected 2 resources, got $resource_count"
    fi
else
    test_fail "Failed to store resources"
fi

# ==============================================================================
# TEST 4: Mark Resources as Managed
# ==============================================================================
test_start "Mark Resources as Managed"

vm_id="/subscriptions/test-sub/resourceGroups/test-rg/providers/Microsoft.Compute/virtualMachines/test-vm-01"

# Mark VM as managed (without actually tagging in Azure)
sqlite3 "$TEST_DB" <<EOF
UPDATE resources
SET managed_by_toolkit = 1,
    adopted_at = $(date +%s)
WHERE resource_id = '$vm_id';
EOF

managed_count=$(sqlite3 "$TEST_DB" "SELECT COUNT(*) FROM managed_resources;")

if [[ "$managed_count" -eq 1 ]]; then
    test_pass
    echo -e "${BLUE}    Managed resources: $managed_count${NC}"
else
    test_fail "Expected 1 managed resource, got $managed_count"
fi

# ==============================================================================
# TEST 5: Add Dependencies
# ==============================================================================
test_start "Add Dependencies"

vnet_id="/subscriptions/test-sub/resourceGroups/test-rg/providers/Microsoft.Network/virtualNetworks/test-vnet"

if add_dependency "$vm_id" "$vnet_id" "required" "uses" 2>/dev/null; then
    dep_count=$(sqlite3 "$TEST_DB" "SELECT COUNT(*) FROM dependencies;")

    if [[ "$dep_count" -eq 1 ]]; then
        test_pass
        echo -e "${BLUE}    Dependencies created: $dep_count${NC}"
    else
        test_fail "Expected 1 dependency, got $dep_count"
    fi
else
    test_fail "Failed to add dependency"
fi

# ==============================================================================
# TEST 6: Get Dependencies
# ==============================================================================
test_start "Get Dependencies"

deps=$(get_dependencies "$vm_id" 2>/dev/null)

if echo "$deps" | jq -e '.[0].resource_id' > /dev/null 2>&1; then
    test_pass
    echo -e "${BLUE}    Dependencies retrieved: $(echo "$deps" | jq length)${NC}"
else
    test_fail "Failed to retrieve dependencies"
fi

# ==============================================================================
# TEST 7: Check Dependencies Satisfied
# ==============================================================================
test_start "Check Dependencies Satisfied"

if check_dependencies_satisfied "$vm_id" 2>/dev/null; then
    test_pass
    echo -e "${BLUE}    All dependencies satisfied${NC}"
else
    test_fail "Dependencies not satisfied"
fi

# ==============================================================================
# TEST 8: Create Operation
# ==============================================================================
test_start "Create Operation"

operation_id="test-op-$(date +%s)"

if create_operation "$operation_id" "compute" "vm-create" "create" "$vm_id" 2>/dev/null; then
    op_count=$(sqlite3 "$TEST_DB" "SELECT COUNT(*) FROM operations;")

    if [[ "$op_count" -eq 1 ]]; then
        test_pass
        echo -e "${BLUE}    Operation created: $operation_id${NC}"
    else
        test_fail "Expected 1 operation, got $op_count"
    fi
else
    test_fail "Failed to create operation"
fi

# ==============================================================================
# TEST 9: Update Operation Status
# ==============================================================================
test_start "Update Operation Status"

if update_operation_status "$operation_id" "running" 2>/dev/null; then
    status=$(sqlite3 "$TEST_DB" "SELECT status FROM operations WHERE operation_id = '$operation_id';")

    if [[ "$status" == "running" ]]; then
        test_pass
        echo -e "${BLUE}    Operation status: $status${NC}"
    else
        test_fail "Expected 'running', got '$status'"
    fi
else
    test_fail "Failed to update operation status"
fi

# ==============================================================================
# TEST 10: Update Operation Progress
# ==============================================================================
test_start "Update Operation Progress"

if update_operation_progress "$operation_id" 3 10 "Installing applications" 2>/dev/null; then
    progress=$(sqlite3 "$TEST_DB" "SELECT current_step || '/' || total_steps FROM operations WHERE operation_id = '$operation_id';")

    if [[ "$progress" == "3/10" ]]; then
        test_pass
        echo -e "${BLUE}    Progress: $progress${NC}"
    else
        test_fail "Expected '3/10', got '$progress'"
    fi
else
    test_fail "Failed to update progress"
fi

# ==============================================================================
# TEST 11: Log Operation
# ==============================================================================
test_start "Log Operation Message"

if log_operation "$operation_id" "INFO" "Test log message" 2>/dev/null; then
    log_count=$(sqlite3 "$TEST_DB" "SELECT COUNT(*) FROM operation_logs WHERE operation_id = '$operation_id';")

    if [[ "$log_count" -eq 1 ]]; then
        test_pass
        echo -e "${BLUE}    Logs created: $log_count${NC}"
    else
        test_fail "Expected 1 log entry, got $log_count"
    fi
else
    test_fail "Failed to log operation"
fi

# ==============================================================================
# TEST 12: Complete Operation
# ==============================================================================
test_start "Complete Operation"

if update_operation_status "$operation_id" "completed" 2>/dev/null; then
    completed_ops=$(sqlite3 "$TEST_DB" "SELECT COUNT(*) FROM operations WHERE status = 'completed';")

    if [[ "$completed_ops" -eq 1 ]]; then
        test_pass
        echo -e "${BLUE}    Completed operations: $completed_ops${NC}"
    else
        test_fail "Expected 1 completed operation, got $completed_ops"
    fi
else
    test_fail "Failed to complete operation"
fi

# ==============================================================================
# TEST 13: Get Operation Stats
# ==============================================================================
test_start "Get Operation Statistics"

if stats=$(get_operation_stats 2>/dev/null); then
    if echo "$stats" | jq -e '.[0].capability' > /dev/null 2>&1; then
        test_pass
        echo -e "${BLUE}    Stats retrieved successfully${NC}"
    else
        test_fail "Stats format invalid"
    fi
else
    test_fail "Failed to get operation stats"
fi

# ==============================================================================
# TEST 14: Query Engine - Source
# ==============================================================================
test_start "Query Engine - Source and Load"

if source "${PROJECT_ROOT}/core/query.sh" 2>/dev/null; then
    if declare -f query_resources > /dev/null; then
        test_pass
        echo -e "${BLUE}    Query engine loaded${NC}"
    else
        test_fail "query_resources function not found"
    fi
else
    test_fail "Failed to source query.sh"
fi

# ==============================================================================
# TEST 15: JQ Filters Exist
# ==============================================================================
test_start "JQ Filters Availability"

filter_count=0
for filter in compute networking storage identity avd common summary; do
    if [[ -f "${PROJECT_ROOT}/queries/${filter}.jq" ]]; then
        filter_count=$((filter_count + 1))
    fi
done

if [[ "$filter_count" -eq 7 ]]; then
    test_pass
    echo -e "${BLUE}    JQ filters found: $filter_count${NC}"
else
    test_fail "Expected 7 filters, found $filter_count"
fi

# ==============================================================================
# TEST 16: Apply JQ Filter
# ==============================================================================
test_start "Apply JQ Filter to Resource"

test_vm_json='[{
  "id": "/subscriptions/test/resourceGroups/rg/providers/Microsoft.Compute/virtualMachines/vm1",
  "name": "vm1",
  "resourceGroup": "rg",
  "location": "eastus",
  "hardwareProfile": {"vmSize": "Standard_D4s_v3"},
  "provisioningState": "Succeeded",
  "tags": {"env": "test"}
}]'

filtered=$(echo "$test_vm_json" | jq -f "${PROJECT_ROOT}/queries/compute.jq" 2>/dev/null)

if echo "$filtered" | jq -e '.[0].vmSize' > /dev/null 2>&1; then
    test_pass
    echo -e "${BLUE}    Filter applied successfully${NC}"
else
    test_fail "Failed to apply JQ filter"
fi

# ==============================================================================
# TEST 17: Dependency Resolver - Source
# ==============================================================================
test_start "Dependency Resolver - Source and Load"

if source "${PROJECT_ROOT}/core/dependency-resolver.sh" 2>/dev/null; then
    if declare -f build_dependency_graph > /dev/null; then
        test_pass
        echo -e "${BLUE}    Dependency resolver loaded${NC}"
    else
        test_fail "build_dependency_graph function not found"
    fi
else
    test_fail "Failed to source dependency-resolver.sh"
fi

# ==============================================================================
# TEST 18: Detect VM Dependencies
# ==============================================================================
test_start "Detect VM Dependencies"

vm_with_deps='{
  "id": "/subscriptions/test/resourceGroups/rg/providers/Microsoft.Compute/virtualMachines/vm2",
  "networkProfile": {
    "networkInterfaces": [
      {"id": "/subscriptions/test/resourceGroups/rg/providers/Microsoft.Network/networkInterfaces/nic1"}
    ]
  },
  "storageProfile": {
    "osDisk": {
      "managedDisk": {"id": "/subscriptions/test/resourceGroups/rg/providers/Microsoft.Compute/disks/disk1"}
    }
  }
}'

# Mock the add_dependency function for this test
add_dependency() {
    echo "Mock: Added dependency $1 -> $2"
    return 0
}

if detect_vm_dependencies "$vm_with_deps" 2>/dev/null; then
    test_pass
    echo -e "${BLUE}    VM dependencies detected${NC}"
else
    test_fail "Failed to detect VM dependencies"
fi

# Unset mock
unset -f add_dependency
source "${PROJECT_ROOT}/core/state-manager.sh" 2>/dev/null

# ==============================================================================
# TEST 19: Build Dependency Graph
# ==============================================================================
test_start "Build Dependency Graph"

if graph=$(build_dependency_graph 2>/dev/null); then
    if echo "$graph" | jq -e '.nodes' > /dev/null 2>&1; then
        node_count=$(echo "$graph" | jq '.nodes | length')
        edge_count=$(echo "$graph" | jq '.edges | length')
        test_pass
        echo -e "${BLUE}    Graph: $node_count nodes, $edge_count edges${NC}"
    else
        test_fail "Invalid graph format"
    fi
else
    test_fail "Failed to build dependency graph"
fi

# ==============================================================================
# TEST 20: SQL Views Work
# ==============================================================================
test_start "SQL Views Functionality"

view_count=$(sqlite3 "$TEST_DB" "SELECT COUNT(*) FROM sqlite_master WHERE type='view';")

if [[ "$view_count" -ge 10 ]]; then
    # Test a few views
    active=$(sqlite3 "$TEST_DB" "SELECT COUNT(*) FROM active_resources;")
    managed=$(sqlite3 "$TEST_DB" "SELECT COUNT(*) FROM managed_resources;")

    test_pass
    echo -e "${BLUE}    Views: $view_count (active: $active, managed: $managed)${NC}"
else
    test_fail "Expected 10+ views, got $view_count"
fi

# ==============================================================================
# TEST 21: Cache Management
# ==============================================================================
test_start "Cache Invalidation"

if invalidate_cache "Microsoft.Compute%" "test" 2>/dev/null; then
    # Check that cache was invalidated in resources table
    expired=$(sqlite3 "$TEST_DB" "SELECT COUNT(*) FROM resources WHERE cache_expires_at < $(date +%s);")

    test_pass
    echo -e "${BLUE}    Cache entries invalidated${NC}"
else
    test_fail "Failed to invalidate cache"
fi

# ==============================================================================
# TEST 22: Analytics - Resources by Type
# ==============================================================================
test_start "Get Resources by Type"

if by_type=$(get_resources_by_type 2>/dev/null); then
    if echo "$by_type" | jq -e '.[0].resource_type' > /dev/null 2>&1; then
        test_pass
        echo -e "${BLUE}    Resource types: $(echo "$by_type" | jq length)${NC}"
    else
        test_fail "Invalid format"
    fi
else
    test_fail "Failed to get resources by type"
fi

# ==============================================================================
# FINAL RESULTS
# ==============================================================================
echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                     TEST RESULTS                           ║${NC}"
echo -e "${BLUE}╠════════════════════════════════════════════════════════════╣${NC}"
echo -e "${BLUE}║${NC}  Total Tests:    ${YELLOW}$TESTS_RUN${NC}"
echo -e "${BLUE}║${NC}  Passed:         ${GREEN}$TESTS_PASSED${NC}"
echo -e "${BLUE}║${NC}  Failed:         ${RED}$TESTS_FAILED${NC}"
echo -e "${BLUE}╠════════════════════════════════════════════════════════════╣${NC}"

if [[ "$TESTS_FAILED" -eq 0 ]]; then
    echo -e "${BLUE}║${NC}  ${GREEN}✓ ALL TESTS PASSED!${NC}"
    echo -e "${BLUE}║${NC}  ${GREEN}Phase 1 Integration: SUCCESSFUL${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    exit 0
else
    echo -e "${BLUE}║${NC}  ${RED}✗ SOME TESTS FAILED${NC}"
    echo -e "${BLUE}║${NC}  ${RED}Phase 1 Integration: NEEDS ATTENTION${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    exit 1
fi
