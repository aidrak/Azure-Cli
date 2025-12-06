#!/bin/bash
# ==============================================================================
# Query Engine Usage Examples
# ==============================================================================
#
# Purpose: Demonstrate query engine capabilities
# Usage: ./examples/query-examples.sh [example-name]
#
# ==============================================================================

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Load dependencies
source "${PROJECT_ROOT}/core/query.sh"

# Colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_header() {
    echo ""
    echo -e "${BLUE}========================================================================${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}========================================================================${NC}"
    echo ""
}

print_example() {
    echo -e "${YELLOW}Example:${NC} $1"
    echo ""
}

print_output() {
    echo -e "${GREEN}Output:${NC}"
    echo "$1"
    echo ""
}

# ==============================================================================
# EXAMPLE 1: Query All VMs (Summary)
# ==============================================================================

example_query_vms_summary() {
    print_header "Example 1: Query All VMs (Summary)"
    print_example "query_resources \"compute\""

    # Note: This will actually query Azure if credentials are configured
    # For demonstration, we'll show the command
    echo "Command: query_resources \"compute\""
    echo ""
    echo "Expected behavior:"
    echo "1. Check cache for VM list"
    echo "2. If cache miss, query Azure CLI"
    echo "3. Apply summary.jq filter (minimal data)"
    echo "4. Store in cache (TTL: 2 minutes)"
    echo "5. Return JSON array"
    echo ""
    echo "Sample output structure:"
    cat <<'EOF'
[
  {
    "name": "avd-sh-01",
    "type": "Microsoft.Compute/virtualMachines",
    "location": "eastus",
    "state": "Succeeded"
  },
  {
    "name": "avd-sh-02",
    "type": "Microsoft.Compute/virtualMachines",
    "location": "eastus",
    "state": "Succeeded"
  }
]
EOF
}

# ==============================================================================
# EXAMPLE 2: Query VMs in Specific Resource Group (Full Details)
# ==============================================================================

example_query_vms_full() {
    print_header "Example 2: Query VMs with Full Details"
    print_example "query_resources \"compute\" \"RG-Azure-VDI-01\" \"full\""

    echo "Command: query_resources \"compute\" \"RG-Azure-VDI-01\" \"full\""
    echo ""
    echo "Expected behavior:"
    echo "1. Query only VMs in RG-Azure-VDI-01"
    echo "2. Apply compute.jq filter (detailed VM info)"
    echo "3. Include VM size, OS, IPs, disks, NICs"
    echo ""
    echo "Sample output structure:"
    cat <<'EOF'
[
  {
    "id": "/subscriptions/.../virtualMachines/avd-sh-01",
    "name": "avd-sh-01",
    "resourceGroup": "RG-Azure-VDI-01",
    "location": "eastus",
    "vmSize": "Standard_D2s_v3",
    "osType": "Windows",
    "provisioningState": "Succeeded",
    "powerState": "VM running",
    "privateIp": "10.0.1.4",
    "publicIp": null,
    "adminUsername": "azureuser",
    "imageReference": {
      "publisher": "MicrosoftWindowsDesktop",
      "offer": "Windows-11",
      "sku": "win11-22h2-avd"
    },
    "osDiskName": "avd-sh-01_OsDisk_1",
    "osDiskSize": 127,
    "nicIds": ["/subscriptions/.../networkInterfaces/avd-sh-01-nic"],
    "tags": {
      "Environment": "Production",
      "ManagedBy": "azure-toolkit"
    }
  }
]
EOF
}

# ==============================================================================
# EXAMPLE 3: Query Specific VM
# ==============================================================================

example_query_specific_vm() {
    print_header "Example 3: Query Specific VM"
    print_example "query_resource \"vm\" \"avd-sh-01\" \"RG-Azure-VDI-01\""

    echo "Command: query_resource \"vm\" \"avd-sh-01\" \"RG-Azure-VDI-01\""
    echo ""
    echo "Expected behavior:"
    echo "1. Check cache: vm:RG-Azure-VDI-01:avd-sh-01"
    echo "2. On cache HIT: return cached data (log cache hit)"
    echo "3. On cache MISS: query Azure, store in cache, return"
    echo "4. Cache TTL: 5 minutes"
    echo ""
    echo "Sample output:"
    cat <<'EOF'
{
  "id": "/subscriptions/.../virtualMachines/avd-sh-01",
  "name": "avd-sh-01",
  "resourceGroup": "RG-Azure-VDI-01",
  "location": "eastus",
  "vmSize": "Standard_D2s_v3",
  "provisioningState": "Succeeded",
  "powerState": "VM running"
}
EOF
}

# ==============================================================================
# EXAMPLE 4: Query Networking Resources
# ==============================================================================

example_query_networking() {
    print_header "Example 4: Query Networking Resources"
    print_example "query_resources \"networking\""

    echo "Command: query_resources \"networking\""
    echo ""
    echo "Expected behavior:"
    echo "1. Query all VNets using 'az network vnet list'"
    echo "2. Apply networking.jq filter"
    echo "3. Return VNet details: address space, subnets, NSGs"
    echo ""
    echo "Sample output:"
    cat <<'EOF'
[
  {
    "id": "/subscriptions/.../virtualNetworks/VNet-Azure-VDI",
    "name": "VNet-Azure-VDI",
    "resourceGroup": "RG-Azure-VDI-01",
    "location": "eastus",
    "addressSpace": ["10.0.0.0/16"],
    "subnets": [
      {
        "name": "SessionHosts",
        "addressPrefix": "10.0.1.0/24",
        "nsgId": "/subscriptions/.../networkSecurityGroups/NSG-SessionHosts",
        "serviceEndpoints": ["Microsoft.Storage"]
      }
    ],
    "dnsServers": [],
    "provisioningState": "Succeeded",
    "enableDdosProtection": false,
    "enableVmProtection": false,
    "tags": {}
  }
]
EOF
}

# ==============================================================================
# EXAMPLE 5: Cache Invalidation
# ==============================================================================

example_cache_invalidation() {
    print_header "Example 5: Cache Invalidation"
    print_example "invalidate_cache \"compute:RG-Azure-VDI-01:*\" \"VM modified\""

    echo "Command: invalidate_cache \"compute:RG-Azure-VDI-01:*\" \"VM modified\""
    echo ""
    echo "Expected behavior:"
    echo "1. Mark all compute resources in RG-Azure-VDI-01 as invalid"
    echo "2. Next query will bypass cache and query Azure"
    echo "3. Fresh data will be cached"
    echo ""
    echo "Use cases:"
    echo "- After creating/modifying/deleting VMs"
    echo "- After deployment operations"
    echo "- Before critical queries requiring fresh data"
    echo ""
    echo "Patterns:"
    echo "  invalidate_cache \"*\"                    # Invalidate all"
    echo "  invalidate_cache \"compute:*\"             # All compute resources"
    echo "  invalidate_cache \"*:RG-Azure-VDI-01:*\"   # All resources in RG"
    echo "  invalidate_cache \"vm:*:avd-sh-01\"        # Specific VM in all RGs"
}

# ==============================================================================
# EXAMPLE 6: Format and Count Utilities
# ==============================================================================

example_utilities() {
    print_header "Example 6: Utility Functions"

    print_example "Format resource summary"
    echo "Command:"
    echo '  resources=$(query_resources "compute")'
    echo '  format_resource_summary "$resources"'
    echo ""
    echo "Output:"
    echo "  avd-sh-01 (Microsoft.Compute/virtualMachines) - eastus - Succeeded"
    echo "  avd-sh-02 (Microsoft.Compute/virtualMachines) - eastus - Succeeded"
    echo ""

    print_example "Count resources by type"
    echo "Command:"
    echo '  all=$(query_resources "all")'
    echo '  count_resources_by_type "$all"'
    echo ""
    echo "Output:"
    echo "  Microsoft.Compute/virtualMachines: 5"
    echo "  Microsoft.Network/virtualNetworks: 2"
    echo "  Microsoft.Storage/storageAccounts: 1"
}

# ==============================================================================
# EXAMPLE 7: Practical Workflow
# ==============================================================================

example_practical_workflow() {
    print_header "Example 7: Practical Workflow"

    cat <<'EOF'
#!/bin/bash
# Practical example: Check VM status before deployment

source core/query.sh

RG="RG-Azure-VDI-01"
VM_NAME="avd-sh-01"

echo "Checking VM status..."

# Query specific VM (cache-first)
vm=$(query_resource "vm" "$VM_NAME" "$RG")

# Check if VM exists
if [[ -z "$vm" ]] || [[ "$vm" == "null" ]]; then
    echo "ERROR: VM not found: $VM_NAME"
    exit 1
fi

# Extract VM state
state=$(echo "$vm" | jq -r '.provisioningState')
power=$(echo "$vm" | jq -r '.powerState')

echo "VM: $VM_NAME"
echo "Provisioning State: $state"
echo "Power State: $power"

# Validate state
if [[ "$state" != "Succeeded" ]]; then
    echo "ERROR: VM not in succeeded state"
    exit 1
fi

if [[ "$power" != "VM running" ]]; then
    echo "WARNING: VM is not running"
fi

echo "VM is ready for operations"

# After making changes, invalidate cache
# invalidate_cache "vm:${RG}:${VM_NAME}" "Post-deployment update"
EOF
}

# ==============================================================================
# EXAMPLE 8: Multi-Resource Query
# ==============================================================================

example_multi_resource() {
    print_header "Example 8: Multi-Resource Query"

    cat <<'EOF'
#!/bin/bash
# Query multiple resource types and generate summary

source core/query.sh

echo "Querying Azure infrastructure..."

# Query all resource types
compute=$(query_resources "compute" "" "summary")
networking=$(query_resources "networking" "" "summary")
storage=$(query_resources "storage" "" "summary")

# Count resources
compute_count=$(echo "$compute" | jq 'length')
networking_count=$(echo "$networking" | jq 'length')
storage_count=$(echo "$storage" | jq 'length')

# Generate summary
echo ""
echo "Infrastructure Summary:"
echo "======================"
echo "Virtual Machines: $compute_count"
echo "Virtual Networks: $networking_count"
echo "Storage Accounts: $storage_count"
echo ""

# Show resource details
echo "Virtual Machines:"
format_resource_summary "$compute"

echo ""
echo "Virtual Networks:"
format_resource_summary "$networking"

echo ""
echo "Storage Accounts:"
format_resource_summary "$storage"
EOF
}

# ==============================================================================
# EXAMPLE 9: Error Handling
# ==============================================================================

example_error_handling() {
    print_header "Example 9: Error Handling"

    cat <<'EOF'
#!/bin/bash
# Robust error handling for queries

source core/query.sh

query_with_retry() {
    local resource_type="$1"
    local resource_name="$2"
    local resource_group="$3"
    local max_retries=3
    local retry_count=0

    while [[ $retry_count -lt $max_retries ]]; do
        if result=$(query_resource "$resource_type" "$resource_name" "$resource_group" 2>/dev/null); then
            if [[ -n "$result" ]] && [[ "$result" != "null" ]]; then
                echo "$result"
                return 0
            fi
        fi

        ((retry_count++))
        echo "Retry $retry_count/$max_retries..." >&2
        sleep 2
    done

    echo "ERROR: Failed after $max_retries retries" >&2
    return 1
}

# Usage
if vm=$(query_with_retry "vm" "avd-sh-01" "RG-Azure-VDI-01"); then
    echo "Successfully queried VM"
else
    echo "Failed to query VM"
    exit 1
fi
EOF
}

# ==============================================================================
# MAIN
# ==============================================================================

show_menu() {
    echo ""
    echo "Query Engine Examples"
    echo "====================="
    echo ""
    echo "1. Query All VMs (Summary)"
    echo "2. Query VMs with Full Details"
    echo "3. Query Specific VM"
    echo "4. Query Networking Resources"
    echo "5. Cache Invalidation"
    echo "6. Utility Functions"
    echo "7. Practical Workflow"
    echo "8. Multi-Resource Query"
    echo "9. Error Handling"
    echo "0. Show All Examples"
    echo ""
}

run_example() {
    case "$1" in
        1) example_query_vms_summary ;;
        2) example_query_vms_full ;;
        3) example_query_specific_vm ;;
        4) example_query_networking ;;
        5) example_cache_invalidation ;;
        6) example_utilities ;;
        7) example_practical_workflow ;;
        8) example_multi_resource ;;
        9) example_error_handling ;;
        0)
            example_query_vms_summary
            example_query_vms_full
            example_query_specific_vm
            example_query_networking
            example_cache_invalidation
            example_utilities
            example_practical_workflow
            example_multi_resource
            example_error_handling
            ;;
        *)
            echo "Invalid example number"
            show_menu
            ;;
    esac
}

# Run example or show menu
if [[ $# -eq 0 ]]; then
    show_menu
    echo -n "Select example (0-9): "
    read -r choice
    run_example "$choice"
else
    run_example "$1"
fi
