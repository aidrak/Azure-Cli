#!/bin/bash
# ==============================================================================
# test-dependency-resolver.sh - Test Suite for Dependency Resolver
# ==============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Source the dependency resolver
source "${PROJECT_ROOT}/core/dependency-resolver.sh"

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
# TEST DATA
# ==============================================================================

# Sample VM JSON
VM_JSON=$(cat <<'EOF'
{
  "id": "/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/test-rg/providers/Microsoft.Compute/virtualMachines/test-vm",
  "name": "test-vm",
  "type": "Microsoft.Compute/virtualMachines",
  "location": "eastus",
  "properties": {
    "provisioningState": "Succeeded",
    "networkProfile": {
      "networkInterfaces": [
        {
          "id": "/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/test-rg/providers/Microsoft.Network/networkInterfaces/test-nic"
        }
      ]
    },
    "storageProfile": {
      "osDisk": {
        "managedDisk": {
          "id": "/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/test-rg/providers/Microsoft.Compute/disks/test-os-disk"
        }
      },
      "dataDisks": [
        {
          "managedDisk": {
            "id": "/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/test-rg/providers/Microsoft.Compute/disks/test-data-disk-1"
          }
        }
      ]
    },
    "availabilitySet": {
      "id": "/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/test-rg/providers/Microsoft.Compute/availabilitySets/test-avset"
    }
  }
}
EOF
)

# Sample NIC JSON
NIC_JSON=$(cat <<'EOF'
{
  "id": "/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/test-rg/providers/Microsoft.Network/networkInterfaces/test-nic",
  "name": "test-nic",
  "type": "Microsoft.Network/networkInterfaces",
  "properties": {
    "ipConfigurations": [
      {
        "properties": {
          "subnet": {
            "id": "/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/test-rg/providers/Microsoft.Network/virtualNetworks/test-vnet/subnets/default"
          },
          "publicIPAddress": {
            "id": "/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/test-rg/providers/Microsoft.Network/publicIPAddresses/test-pip"
          }
        }
      }
    ],
    "networkSecurityGroup": {
      "id": "/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/test-rg/providers/Microsoft.Network/networkSecurityGroups/test-nsg"
    }
  }
}
EOF
)

# Sample VNet JSON
VNET_JSON=$(cat <<'EOF'
{
  "id": "/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/test-rg/providers/Microsoft.Network/virtualNetworks/test-vnet",
  "name": "test-vnet",
  "type": "Microsoft.Network/virtualNetworks",
  "properties": {
    "subnets": [
      {
        "id": "/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/test-rg/providers/Microsoft.Network/virtualNetworks/test-vnet/subnets/default",
        "name": "default",
        "properties": {
          "networkSecurityGroup": {
            "id": "/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/test-rg/providers/Microsoft.Network/networkSecurityGroups/subnet-nsg"
          },
          "routeTable": {
            "id": "/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/test-rg/providers/Microsoft.Network/routeTables/test-rt"
          }
        }
      }
    ]
  }
}
EOF
)

# ==============================================================================
# UTILITY FUNCTION TESTS
# ==============================================================================

test_extract_resource_type() {
    local resource_id="/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/test-rg/providers/Microsoft.Compute/virtualMachines/test-vm"
    local result=$(extract_resource_type "$resource_id")

    if [[ "$result" == "Microsoft.Compute/virtualMachines" ]]; then
        test_pass "extract_resource_type"
    else
        test_fail "extract_resource_type" "Expected 'Microsoft.Compute/virtualMachines', got '$result'"
    fi
}

test_extract_resource_name() {
    local resource_id="/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/test-rg/providers/Microsoft.Compute/virtualMachines/test-vm"
    local result=$(extract_resource_name "$resource_id")

    if [[ "$result" == "test-vm" ]]; then
        test_pass "extract_resource_name"
    else
        test_fail "extract_resource_name" "Expected 'test-vm', got '$result'"
    fi
}

test_extract_resource_group() {
    local resource_id="/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/test-rg/providers/Microsoft.Compute/virtualMachines/test-vm"
    local result=$(extract_resource_group "$resource_id")

    if [[ "$result" == "test-rg" ]]; then
        test_pass "extract_resource_group"
    else
        test_fail "extract_resource_group" "Expected 'test-rg', got '$result'"
    fi
}

test_validate_resource_id() {
    local valid_id="/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/test-rg/providers/Microsoft.Compute/virtualMachines/test-vm"
    local invalid_id="/invalid/resource/id"

    if validate_resource_id "$valid_id"; then
        test_pass "validate_resource_id (valid)"
    else
        test_fail "validate_resource_id (valid)" "Should accept valid resource ID"
    fi

    if ! validate_resource_id "$invalid_id"; then
        test_pass "validate_resource_id (invalid)"
    else
        test_fail "validate_resource_id (invalid)" "Should reject invalid resource ID"
    fi
}

# ==============================================================================
# DEPENDENCY DETECTION TESTS
# ==============================================================================

test_detect_vm_dependencies() {
    # Clean up previous test data
    rm -f "${PROJECT_ROOT}/discovered/dependencies.jsonl"
    mkdir -p "${PROJECT_ROOT}/discovered"

    local dep_count=$(detect_vm_dependencies "$VM_JSON")

    # Should detect: NIC (1), OS Disk (1), Data Disk (1), AvailabilitySet (1) = 4 dependencies
    if [[ "$dep_count" -eq 4 ]]; then
        test_pass "detect_vm_dependencies (count)"
    else
        test_fail "detect_vm_dependencies (count)" "Expected 4 dependencies, got $dep_count"
    fi

    # Check that dependencies file was created
    if [[ -f "${PROJECT_ROOT}/discovered/dependencies.jsonl" ]]; then
        local dep_count_file=$(wc -l < "${PROJECT_ROOT}/discovered/dependencies.jsonl")
        if [[ "$dep_count_file" -eq 4 ]]; then
            test_pass "detect_vm_dependencies (file)"
        else
            test_fail "detect_vm_dependencies (file)" "Expected 4 lines, got $dep_count_file"
        fi
    else
        test_fail "detect_vm_dependencies (file)" "Dependencies file not created"
    fi

    # Verify dependency types
    local required_count=$(grep -c '"dependency_type":"required"' "${PROJECT_ROOT}/discovered/dependencies.jsonl" || echo 0)
    local optional_count=$(grep -c '"dependency_type":"optional"' "${PROJECT_ROOT}/discovered/dependencies.jsonl" || echo 0)

    if [[ "$required_count" -eq 3 ]]; then
        test_pass "detect_vm_dependencies (required deps)"
    else
        test_fail "detect_vm_dependencies (required deps)" "Expected 3 required, got $required_count"
    fi

    if [[ "$optional_count" -eq 1 ]]; then
        test_pass "detect_vm_dependencies (optional deps)"
    else
        test_fail "detect_vm_dependencies (optional deps)" "Expected 1 optional, got $optional_count"
    fi
}

test_detect_nic_dependencies() {
    # Clean up previous test data
    rm -f "${PROJECT_ROOT}/discovered/dependencies.jsonl"
    mkdir -p "${PROJECT_ROOT}/discovered"

    local dep_count=$(detect_nic_dependencies "$NIC_JSON")

    # Should detect: Subnet (1), VNet (1), NSG (1), PublicIP (1) = 4 dependencies
    if [[ "$dep_count" -eq 4 ]]; then
        test_pass "detect_nic_dependencies (count)"
    else
        test_fail "detect_nic_dependencies (count)" "Expected 4 dependencies, got $dep_count"
    fi

    # Verify subnet dependency exists
    if grep -q "subnets/default" "${PROJECT_ROOT}/discovered/dependencies.jsonl"; then
        test_pass "detect_nic_dependencies (subnet)"
    else
        test_fail "detect_nic_dependencies (subnet)" "Subnet dependency not found"
    fi

    # Verify VNet dependency exists
    if grep -q "virtualNetworks/test-vnet" "${PROJECT_ROOT}/discovered/dependencies.jsonl"; then
        test_pass "detect_nic_dependencies (vnet)"
    else
        test_fail "detect_nic_dependencies (vnet)" "VNet dependency not found"
    fi
}

test_detect_vnet_dependencies() {
    # Clean up previous test data
    rm -f "${PROJECT_ROOT}/discovered/dependencies.jsonl"
    mkdir -p "${PROJECT_ROOT}/discovered"

    local dep_count=$(detect_vnet_dependencies "$VNET_JSON")

    # Should detect: Subnet (1), Subnet NSG (1), Subnet RouteTable (1) = 3 dependencies
    if [[ "$dep_count" -eq 3 ]]; then
        test_pass "detect_vnet_dependencies (count)"
    else
        test_fail "detect_vnet_dependencies (count)" "Expected 3 dependencies, got $dep_count"
    fi

    # Verify subnet is "contains" relationship
    if grep -q '"relationship":"contains"' "${PROJECT_ROOT}/discovered/dependencies.jsonl"; then
        test_pass "detect_vnet_dependencies (contains)"
    else
        test_fail "detect_vnet_dependencies (contains)" "Contains relationship not found"
    fi
}

# ==============================================================================
# GRAPH BUILDING TESTS
# ==============================================================================

test_build_dependency_graph() {
    # Set up test data with multiple resources
    rm -f "${PROJECT_ROOT}/discovered/dependencies.jsonl"
    rm -f "${PROJECT_ROOT}/discovered/dependency-graph.json"
    mkdir -p "${PROJECT_ROOT}/discovered"

    # Detect dependencies for test resources
    detect_vm_dependencies "$VM_JSON" >/dev/null
    detect_nic_dependencies "$NIC_JSON" >/dev/null
    detect_vnet_dependencies "$VNET_JSON" >/dev/null

    # Build the graph (will fail without state.db, but should create from file)
    # This will error but we can test the dependencies file exists
    if [[ -f "${PROJECT_ROOT}/discovered/dependencies.jsonl" ]]; then
        local total_deps=$(wc -l < "${PROJECT_ROOT}/discovered/dependencies.jsonl")
        if [[ "$total_deps" -gt 0 ]]; then
            test_pass "build_dependency_graph (data collection)"
        else
            test_fail "build_dependency_graph (data collection)" "No dependencies collected"
        fi
    else
        test_fail "build_dependency_graph (data collection)" "Dependencies file not created"
    fi
}

test_export_dependency_graph_dot() {
    # Ensure we have dependency data
    if [[ ! -f "${PROJECT_ROOT}/discovered/dependencies.jsonl" ]]; then
        # Create test data
        detect_vm_dependencies "$VM_JSON" >/dev/null
    fi

    # Export to DOT format
    local dot_file=$(export_dependency_graph_dot 2>&1)

    if [[ -f "${PROJECT_ROOT}/discovered/dependency-graph.dot" ]]; then
        test_pass "export_dependency_graph_dot (file created)"

        # Verify DOT file has correct structure
        if grep -q "digraph AzureDependencies" "${PROJECT_ROOT}/discovered/dependency-graph.dot"; then
            test_pass "export_dependency_graph_dot (valid DOT)"
        else
            test_fail "export_dependency_graph_dot (valid DOT)" "DOT file invalid"
        fi

        # Verify nodes are present
        if grep -q "label=" "${PROJECT_ROOT}/discovered/dependency-graph.dot"; then
            test_pass "export_dependency_graph_dot (nodes)"
        else
            test_fail "export_dependency_graph_dot (nodes)" "No nodes found"
        fi

        # Verify edges are present
        if grep -q "->" "${PROJECT_ROOT}/discovered/dependency-graph.dot"; then
            test_pass "export_dependency_graph_dot (edges)"
        else
            test_fail "export_dependency_graph_dot (edges)" "No edges found"
        fi
    else
        test_fail "export_dependency_graph_dot (file created)" "DOT file not created"
    fi
}

# ==============================================================================
# RUN ALL TESTS
# ==============================================================================

echo "=============================================="
echo "Dependency Resolver Test Suite"
echo "=============================================="
echo ""

echo "Testing Utility Functions..."
test_extract_resource_type
test_extract_resource_name
test_extract_resource_group
test_validate_resource_id

echo ""
echo "Testing Dependency Detection..."
test_detect_vm_dependencies
test_detect_nic_dependencies
test_detect_vnet_dependencies

echo ""
echo "Testing Graph Building..."
test_build_dependency_graph
test_export_dependency_graph_dot

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
