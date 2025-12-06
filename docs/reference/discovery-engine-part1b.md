#### `build_discovery_graph`
Build complete dependency graph from discovered resources.

**Output:**
- `discovered/dependency-graph.json`
- `discovered/dependency-graph.dot`

**Example:**
```bash
build_discovery_graph
```

### Azure Tagging Functions

#### `tag_discovered_resources`
Tag all discovered resources in Azure with discovery metadata.

**Tags Applied:**
- `discovered-by-toolkit=true`
- `discovery-timestamp=<ISO-8601-timestamp>`

**Configuration:**
Set `TAG_DISCOVERED_RESOURCES=false` to disable tagging.

**Example:**
```bash
TAG_DISCOVERED_RESOURCES=true
tag_discovered_resources
```

### Output Generation Functions

#### `generate_inventory_summary <scope> <target> <total> <duration>`
Generate token-efficient YAML summary.

**Output:** `discovered/inventory-summary.yaml`

**Format:**
```yaml
discovery:
  timestamp: "2025-12-06T10:30:00Z"
  scope: "resource-group"
  target: "RG-Azure-VDI-01"
  duration_seconds: 45
  total_resources: 47

resource_counts:
  compute:
    virtual_machines: 12
    disks: 24
  networking:
    virtual_networks: 2
    network_security_groups: 3
    network_interfaces: 12
  storage:
    storage_accounts: 3
  avd:
    host_pools: 1
    application_groups: 2
    workspaces: 1

key_resources:
  - name: "avd-vnet"
    type: "Microsoft.Network/virtualNetworks"
    dependents: 15

managed_by_toolkit: 8
external_resources: 39
```

#### `generate_inventory_full <scope> <target> <total> <duration>`
Generate full JSON inventory with complete resource details.

**Output:** `discovered/inventory-full.json`

**Format:**
```json
{
  "discovery": {
    "timestamp": "2025-12-06T10:30:00Z",
    "scope": "resource-group",
    "target": "RG-Azure-VDI-01",
    "duration_seconds": 45,
    "total_resources": 47
  },
  "resources": [
    {
      "id": "/subscriptions/.../resourceGroups/.../providers/Microsoft.Compute/virtualMachines/vm-01",
      "name": "vm-01",
      "type": "Microsoft.Compute/virtualMachines",
      "resourceGroup": "RG-Azure-VDI-01",
      "location": "eastus",
      "provisioningState": "Succeeded",
      "managedByToolkit": false,
      "tags": {...},
      "properties": {...}
    }
  ]
}
```

## Discovery Flow

### Detailed Discovery Process

```bash
discover "resource-group" "RG-Azure-VDI-01"

# Step 1: Validation
#   - Validate scope and target
#   - Check resource group exists in Azure
#   - Verify Azure CLI authentication

# Step 2: Initialize State Database
#   - Create state.db if not exists
#   - Initialize SQLite schema
#   - Create tables and indexes

# Step 3: Phase 1 - Resource Discovery
#   - Batch query: az resource list --resource-group RG-Azure-VDI-01
#   - Type-specific queries:
#     * az vm list --resource-group RG-Azure-VDI-01 --show-details
#     * az network vnet list --resource-group RG-Azure-VDI-01
#     * az storage account list --resource-group RG-Azure-VDI-01
#     * az desktopvirtualization hostpool list --resource-group RG-Azure-VDI-01
#     * az ad group list (filtered by resource group)
#   - Apply JQ filters to reduce token usage
#   - Store each resource in state database

# Step 4: Phase 2 - Dependency Analysis
#   - For each resource:
#     * Detect dependencies from properties
#     * Store in dependencies table
#   - Build complete dependency graph
#   - Detect circular dependencies
#   - Export to JSON and DOT formats

# Step 5: Phase 3 - Azure Tagging (Optional)
#   - For each discovered resource:
#     * Tag with "discovered-by-toolkit=true"
#     * Tag with "discovery-timestamp=<timestamp>"

# Step 6: Phase 4 - Output Generation
#   - Generate YAML summary (token-efficient)
#   - Generate full JSON inventory
#   - Report statistics

# Step 7: Completion
#   - Log discovery summary
#   - Report duration and resource counts
#   - Return success
```

## Token Efficiency Strategy

### Problem: Azure CLI Returns Massive JSON
```bash
# BAD: Returns 500KB+ of JSON for 10 VMs
az vm list --resource-group RG-Azure-VDI-01

