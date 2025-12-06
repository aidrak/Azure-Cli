# Discovery Engine Documentation

## Overview

The Discovery Engine is a comprehensive resource discovery system for Azure Infrastructure Toolkit that provides:

- **Intelligent Discovery**: Subscription-wide or resource-group-scoped resource scanning
- **Token Efficiency**: JQ-filtered queries to minimize token usage by 90%+
- **Dependency Analysis**: Automatic dependency graph construction
- **State Management**: All resources stored in SQLite for intelligent caching
- **Multiple Outputs**: YAML summary, JSON full inventory, GraphViz DOT graph
- **Azure Tagging**: Optional automatic tagging of discovered resources

## Quick Start

```bash
# Discover a resource group
source core/discovery.sh
discover "resource-group" "RG-Azure-VDI-01"

# Discover entire subscription
discover "subscription" "your-subscription-id"

# Convenience functions
discover_resource_group "RG-Azure-VDI-01"
discover_subscription  # Uses current subscription
```

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    DISCOVERY ENGINE                          │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Phase 1: Resource Discovery                                │
│  ┌────────────────────────────────────────────────────┐    │
│  │ • Batch query all resources (az resource list)     │    │
│  │ • Type-specific queries (VMs, VNets, Storage, etc) │    │
│  │ • Apply JQ filters for token efficiency            │    │
│  │ • Store in SQLite state database                   │    │
│  └────────────────────────────────────────────────────┘    │
│                           ↓                                  │
│  Phase 2: Dependency Analysis                               │
│  ┌────────────────────────────────────────────────────┐    │
│  │ • Detect dependencies from resource properties      │    │
│  │ • Build dependency graph (DAG)                      │    │
│  │ • Store relationships in dependencies table         │    │
│  │ • Export to JSON and GraphViz DOT formats          │    │
│  └────────────────────────────────────────────────────┘    │
│                           ↓                                  │
│  Phase 3: Azure Tagging (Optional)                          │
│  ┌────────────────────────────────────────────────────┐    │
│  │ • Tag resources with "discovered-by-toolkit=true"  │    │
│  │ • Add discovery timestamp                           │    │
│  └────────────────────────────────────────────────────┘    │
│                           ↓                                  │
│  Phase 4: Output Generation                                 │
│  ┌────────────────────────────────────────────────────┐    │
│  │ • Generate YAML summary (token-efficient)          │    │
│  │ • Generate full JSON inventory                      │    │
│  │ • Export dependency graphs                          │    │
│  └────────────────────────────────────────────────────┘    │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## Functions Reference

### Main Discovery Functions

#### `discover <scope> <target>`
Main discovery entry point.

**Arguments:**
- `scope`: "subscription" or "resource-group"
- `target`: Subscription ID or resource group name

**Returns:**
- 0 on success
- 1 on failure

**Example:**
```bash
discover "resource-group" "RG-Azure-VDI-01"
discover "subscription" "12345678-1234-1234-1234-123456789012"
```

**Output Files:**
- `discovered/inventory-summary.yaml` - Token-efficient summary
- `discovered/inventory-full.json` - Complete resource details
- `discovered/dependency-graph.json` - Dependency graph (JSON)
- `discovered/dependency-graph.dot` - Dependency graph (GraphViz)
- `state.db` - SQLite state database

#### `discover_resource_group <resource-group-name>`
Convenience function for resource group discovery.

**Example:**
```bash
discover_resource_group "RG-Azure-VDI-01"
```

#### `discover_subscription [subscription-id]`
Convenience function for subscription discovery. Uses current subscription if not specified.

**Example:**
```bash
discover_subscription
discover_subscription "12345678-1234-1234-1234-123456789012"
```

#### `rediscover <scope> <target>`
Re-run discovery with cache invalidation (forces fresh Azure queries).

**Example:**
```bash
rediscover "resource-group" "RG-Azure-VDI-01"
```

### Resource Type Discovery Functions

#### `discover_compute_resources <scope> <target>`
Discover compute resources: VMs, disks, availability sets.

**Returns:** Count of discovered compute resources

**Example:**
```bash
compute_count=$(discover_compute_resources "resource-group" "RG-Azure-VDI-01")
echo "Found $compute_count compute resources"
```

#### `discover_networking_resources <scope> <target>`
Discover networking resources: VNets, subnets, NSGs, NICs, public IPs.

**Returns:** Count of discovered networking resources

#### `discover_storage_resources <scope> <target>`
Discover storage resources: Storage accounts, file shares.

**Returns:** Count of discovered storage resources

#### `discover_identity_resources <scope> <target>`
Discover identity resources: Entra ID groups.

**Returns:** Count of discovered identity resources

#### `discover_avd_resources <scope> <target>`
Discover AVD resources: Host pools, application groups, workspaces.

**Returns:** Count of discovered AVD resources

#### `discover_all_resources <scope> <target>`
Batch discovery using `az resource list` (most efficient).

**Returns:** Total count of discovered resources

### Dependency Graph Functions


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


# RESULT: Consumes ~150,000 tokens (massive)
```

### Solution: JQ Filtering Immediately
```bash
# GOOD: Apply JQ filter immediately
az vm list --resource-group RG-Azure-VDI-01 | jq -f queries/compute.jq

# RESULT: Returns only 50KB (~15,000 tokens) - 90% reduction!
```

### Token Reduction Comparison

| Query Type | Raw Output | Filtered Output | Token Reduction |
|------------|------------|-----------------|-----------------|
| 10 VMs | 500 KB | 50 KB | 90% |
| 5 VNets | 200 KB | 20 KB | 90% |
| 3 Storage Accounts | 150 KB | 15 KB | 90% |
| **Total** | **850 KB** | **85 KB** | **90%** |

### JQ Filter Examples

**Summary Filter** (`queries/summary.jq`):
```jq
map({
    name: .name,
    type: (.type // .resourceType // "unknown"),
    location: .location,
    state: (.provisioningState // .properties.provisioningState? // "Unknown")
})
```

**Compute Filter** (`queries/compute.jq`):
```jq
map({
    id: .id,
    name: .name,
    resourceGroup: .resourceGroup,
    location: .location,
    vmSize: .hardwareProfile.vmSize,
    osType: .storageProfile.osDisk.osType,
    provisioningState: .provisioningState,
    powerState: ((.instanceView.statuses[]? | select(.code | startswith("PowerState/")) | .displayStatus) // "Unknown"),
    privateIp: (.privateIps[0]? // null),
    publicIp: (.publicIps[0]? // null),
    tags: .tags
})
```

## Error Handling

### Common Errors and Solutions

#### 1. Authentication Error
```
ERROR: No subscription found or not accessible
```

**Solution:**
```bash
az login
az account set --subscription "subscription-id"
```

#### 2. Resource Group Not Found
```
ERROR: Resource group not found: RG-Does-Not-Exist
```

**Solution:**
Verify resource group name:
```bash
az group list --query "[].name" -o table
```

#### 3. Permission Denied
```
ERROR: Failed to query resources (permission denied)
```

**Solution:**
Ensure you have Reader role on subscription/resource group:
```bash
az role assignment list --assignee $(az ad signed-in-user show --query id -o tsv)
```

#### 4. SQLite Database Locked
```
ERROR: database is locked
```

**Solution:**
Close other processes accessing state.db:
```bash
rm -f state.db-wal state.db-shm  # Remove WAL files
```

#### 5. Empty Discovery Results
```
WARNING: No resources found in resource group
```

**Solution:**
- Verify resource group is not empty
- Check Azure subscription is active
- Ensure proper permissions

## Performance Optimization

### Optimization Strategies

1. **Batch Queries**: Use `az resource list` instead of individual queries
2. **JQ Filtering**: Apply filters immediately to reduce memory usage
3. **Parallel Discovery**: Query independent resource types in parallel (future)
4. **Cache-First**: Check state database before querying Azure
5. **Incremental Discovery**: Only query changed resources (future)

### Performance Metrics

| Metric | Target | Typical |
|--------|--------|---------|
| Discovery Time (50 resources) | < 60s | 45s |
| Discovery Time (200 resources) | < 180s | 150s |
| Token Usage Reduction | > 85% | 90% |
| Cache Hit Rate | > 70% | 75% |

## Integration with Other Components

### State Manager Integration
```bash
# Discovery stores all resources in state.db
source core/discovery.sh
discover_resource_group "RG-Azure-VDI-01"

# Later: Query resources from cache
source core/state-manager.sh
get_resource "virtualMachines" "vm-01" "RG-Azure-VDI-01"
# Returns cached result (no Azure API call!)
```

### Query Engine Integration
```bash
# Discovery populates state.db
discover_resource_group "RG-Azure-VDI-01"

# Query engine uses cache-first approach
source core/query.sh
query_resources "compute" "RG-Azure-VDI-01"
# Uses cached data from discovery
```

### Dependency Resolver Integration
```bash
# Discovery builds dependency graph
discover_resource_group "RG-Azure-VDI-01"

# Query dependencies
source core/dependency-resolver.sh
get_dependency_tree "/subscriptions/.../virtualMachines/vm-01"
```

## Configuration


### Environment Variables

```bash
# Discovery configuration
export TAG_DISCOVERED_RESOURCES=true    # Tag resources in Azure
export DISCOVERY_BATCH_SIZE=100         # Batch size for queries
export DISCOVERY_TIMEOUT=600            # Timeout in seconds

# State manager configuration
export STATE_DB="${PROJECT_ROOT}/state.db"
export CACHE_TTL=300                    # Cache TTL in seconds

# Logging configuration
export CURRENT_LOG_LEVEL=1              # 0=DEBUG, 1=INFO, 2=WARN
```

## Advanced Usage

### Custom Discovery with Filters

```bash
# Discover only VMs (skip other resources)
source core/discovery.sh
source core/state-manager.sh

init_state_db
vm_count=$(discover_compute_resources "resource-group" "RG-Azure-VDI-01")
echo "Discovered $vm_count compute resources"

# Build dependency graph
build_discovery_graph
```

### Incremental Discovery

```bash
# Initial discovery
discover_resource_group "RG-Azure-VDI-01"

# Later: Rediscover with cache invalidation
rediscover "resource-group" "RG-Azure-VDI-01"
```

### Query Discovered Resources

```bash
# Discover resources
discover_resource_group "RG-Azure-VDI-01"

# Query state database
sqlite3 state.db <<'EOF'
SELECT
    resource_type,
    COUNT(*) as count
FROM resources
WHERE deleted_at IS NULL
GROUP BY resource_type
ORDER BY count DESC;
EOF
```

### Export Dependency Graph to PNG

```bash
# Discover and build graph
discover_resource_group "RG-Azure-VDI-01"

# Convert DOT to PNG (requires graphviz)
dot -Tpng discovered/dependency-graph.dot -o discovered/dependency-graph.png
```

## Best Practices

1. **Run Discovery Before Operations**
   ```bash
   # Always discover first to populate state database
   discover_resource_group "RG-Azure-VDI-01"

   # Then run operations (they'll use cached data)
   ./core/engine.sh run compute/vm-create
   ```

2. **Use Scoped Discovery**
   ```bash
   # GOOD: Scope to specific resource group
   discover_resource_group "RG-Azure-VDI-01"

   # AVOID: Full subscription discovery (unless needed)
   discover_subscription  # Can be very slow!
   ```

3. **Leverage Cache**
   ```bash
   # First run: Populates cache (slow)
   discover_resource_group "RG-Azure-VDI-01"

   # Subsequent queries: Use cache (fast)
   query_resources "compute" "RG-Azure-VDI-01"
   ```

4. **Monitor Progress**
   ```bash
   # Enable debug logging
   export CURRENT_LOG_LEVEL=0
   discover_resource_group "RG-Azure-VDI-01"
   ```

5. **Regular Rediscovery**
   ```bash
   # Rediscover daily to keep state fresh
   rediscover "resource-group" "RG-Azure-VDI-01"
   ```

## Troubleshooting

### Enable Debug Logging
```bash
export CURRENT_LOG_LEVEL=0  # Enable DEBUG logs
discover_resource_group "RG-Azure-VDI-01"
```

### Check State Database
```bash
# Verify resources were stored
sqlite3 state.db "SELECT COUNT(*) FROM resources;"

# Check recent discoveries
sqlite3 state.db "SELECT name, resource_type FROM resources ORDER BY discovered_at DESC LIMIT 10;"
```

### Validate Dependency Graph
```bash
# Check for circular dependencies
source core/dependency-resolver.sh
detect_circular_dependencies
```

### View Discovery Logs
```bash
# View structured logs
cat artifacts/logs/deployment_*.jsonl | jq 'select(.operation_id | contains("discovery"))'
```

## Future Enhancements

- [ ] Parallel resource type discovery
- [ ] Incremental discovery (only query changed resources)
- [ ] Discovery scheduling (cron integration)
- [ ] Resource change detection
- [ ] Cost estimation integration
- [ ] Compliance scanning
- [ ] Resource health checks
- [ ] Export to Terraform/Bicep
- [ ] Interactive dependency graph visualization
- [ ] Discovery report generation (HTML/PDF)

## See Also

- [State Manager Documentation](./state-management.md)
- [Query Engine Documentation](./query-engine-part1a.md)
- [Dependency Resolver Documentation](./dependency-resolver.md)
- [Architecture Documentation](../ARCHITECTURE.md)
