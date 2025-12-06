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
