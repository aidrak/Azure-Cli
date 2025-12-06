# Query Engine Documentation

## Overview

The Query Engine (`core/query.sh`) is the primary interface for querying Azure resources with intelligent caching and token efficiency optimization.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      QUERY ENGINE                            │
│                   (core/query.sh)                            │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Cache-First Strategy:                                      │
│  1. Check state-manager cache (if available)                │
│  2. On cache miss, query Azure CLI                          │
│  3. Apply JQ filter for token efficiency                    │
│  4. Store result in cache                                   │
│  5. Return filtered result                                  │
│                                                              │
└─────────────────────────────────────────────────────────────┘
         ↓                                    ↓
    ┌────────────┐                      ┌──────────────┐
    │  State     │                      │  JQ Filters  │
    │  Manager   │                      │  (queries/)  │
    └────────────┘                      └──────────────┘
```

## Core Functions

### Main Query Interface

#### `query_resources(resource_type, resource_group, output_format)`

Query resources by type with cache-first approach.

**Parameters:**
- `resource_type`: Type of resource to query
  - `compute|vms|vm` - Virtual Machines
  - `networking|vnets|vnet` - Virtual Networks
  - `storage` - Storage Accounts
  - `identity|groups|ad-group` - Entra ID Groups
  - `avd|hostpools|hostpool` - AVD Host Pools
  - `all|resources` - All resources
- `resource_group`: (Optional) Resource group name to filter by
- `output_format`: (Optional, default: "summary")
  - `summary` - Minimal information using summary.jq filter
  - `full` - Detailed information using resource-specific filter

**Returns:** JSON array of resources

**Examples:**
```bash
# Query all VMs with summary info
query_resources "compute"

# Query VMs in specific resource group with full details
query_resources "compute" "RG-Azure-VDI-01" "full"

# Query all networking resources
query_resources "networking"

# Query all resources (any type)
query_resources "all" "RG-Azure-VDI-01"
```

**Cache Behavior:**
- TTL: 120 seconds (2 minutes) for resource lists
- Cache invalidation: Automatic on resource modification
- Cache key: `{resource_type}:{resource_group}`

---

#### `query_resource(resource_type, resource_name, resource_group)`

Query a specific resource by name with cache-first approach.

**Parameters:**
- `resource_type`: Type of resource (same as `query_resources`)
- `resource_name`: Exact name of the resource
- `resource_group`: (Optional) Resource group name

**Returns:** JSON object of the resource

**Examples:**
```bash
# Query specific VM
query_resource "vm" "avd-sh-01" "RG-Azure-VDI-01"

# Query specific VNet
query_resource "vnet" "VNet-Azure-VDI" "RG-Azure-VDI-01"

# Query specific storage account
query_resource "storage" "stavdprofiles001" "RG-Azure-VDI-01"

# Query specific Entra group
query_resource "identity" "AVD-Users"
```

**Cache Behavior:**
- TTL: 300 seconds (5 minutes) for single resources
- Cache invalidation: Automatic on resource modification
- Cache key: `{resource_type}:{resource_group}:{resource_name}`

---

### Resource-Specific Query Functions

These functions are called internally by `query_resources()` but can be used directly:

#### `query_compute_resources(resource_group, output_format)`
Query all Virtual Machines.

#### `query_networking_resources(resource_group, output_format)`
Query all Virtual Networks.

#### `query_storage_resources(resource_group, output_format)`
Query all Storage Accounts.

#### `query_identity_resources(resource_group, output_format)`
Query all Entra ID Groups.

#### `query_avd_resources(resource_group, output_format)`
Query all AVD Host Pools.

#### `query_all_resources(resource_group, output_format)`
Query all resources (any type).

---

### Azure Query Helpers

#### `query_azure_raw(resource_type, resource_group)`

Execute raw Azure CLI query without filtering.

**Parameters:**
- `resource_type`: Resource type to query
- `resource_group`: (Optional) Resource group filter

**Returns:** Raw JSON from Azure CLI

**Example:**
```bash
# Get raw VM data
raw_data=$(query_azure_raw "vm" "RG-Azure-VDI-01")
```

**Use Cases:**
- Debugging Azure CLI responses
- Custom processing workflows
- Extracting fields not in standard filters

---

#### `query_azure_resource_by_name(resource_type, resource_name, resource_group)`

Query a specific resource by name from Azure (bypass cache).

---

#### `apply_jq_filter(json_data, filter_file)`

Apply JQ filter to JSON data for token efficiency.

**Parameters:**
- `json_data`: JSON string to filter
- `filter_file`: Path to JQ filter file

**Returns:** Filtered JSON

**Example:**
```bash
# Apply custom filter
filtered=$(apply_jq_filter "$raw_data" "${QUERIES_DIR}/custom.jq")
```

---

### Cache Management

#### `invalidate_cache(pattern, reason)`

Invalidate cache entries matching a pattern.

**Parameters:**
- `pattern`: Glob pattern for cache keys (default: "*")
- `reason`: Reason for invalidation (for logging)

**Examples:**
```bash
# Invalidate all compute resource caches
invalidate_cache "compute:*" "VM modified"

# Invalidate specific resource group
invalidate_cache "*:RG-Azure-VDI-01:*" "Resource group updated"

# Invalidate everything
invalidate_cache "*" "Full refresh"
```

**When to Invalidate:**
- After creating/modifying/deleting resources
- After deployment operations
- Before critical queries requiring fresh data

---

#### `cache_query_result(cache_key, result_json, ttl)`

Store query result in cache.

**Parameters:**
- `cache_key`: Unique key for cache entry
- `result_json`: JSON data to cache
- `ttl`: Time-to-live in seconds (default: 120)

**Example:**
```bash
cache_query_result "custom:my-query" "$result" 300
```

---

### Utility Functions

#### `format_resource_summary(resource_json)`

Format resource JSON as human-readable summary.

**Example:**
```bash
resources=$(query_resources "compute")
format_resource_summary "$resources"
# Output:
# avd-sh-01 (Microsoft.Compute/virtualMachines) - eastus - Succeeded
# avd-sh-02 (Microsoft.Compute/virtualMachines) - eastus - Succeeded
```

---

#### `count_resources_by_type(resources_json)`

Count resources grouped by type.

**Example:**
```bash
all_resources=$(query_resources "all")
count_resources_by_type "$all_resources"
# Output:
# Microsoft.Compute/virtualMachines: 5
# Microsoft.Network/virtualNetworks: 2
# Microsoft.Storage/storageAccounts: 1
```

---

## JQ Filters

The query engine uses JQ filters from the `queries/` directory to minimize token usage:

### Available Filters

| Filter | Purpose | Token Reduction |
|--------|---------|-----------------|
| `compute.jq` | VM essential info | ~90% |
| `networking.jq` | VNet essential info | ~85% |
| `storage.jq` | Storage account essential info | ~80% |
| `identity.jq` | Entra group essential info | ~75% |
| `avd.jq` | AVD host pool essential info | ~80% |
| `summary.jq` | Ultra-minimal overview | ~95% |

### Filter Creation

Filters are created automatically when needed by `ensure_jq_filter_exists()`.

To create custom filters:
1. Create `{type}.jq` in `queries/` directory
2. Use `map()` for array processing
3. Select only essential fields
4. Use optional operators (`?`) for safety

**Example Custom Filter:**
```jq
# queries/custom.jq
map({
    name: .name,
    location: .location,
    customField: .properties.customField? // "default"
})
```

---

## State Manager Integration

The query engine integrates with `core/state-manager.sh` for intelligent caching:

### Integration Points

1. **Cache Check** (`_get_cached_resource`)
   - Checks SQLite cache before Azure query
   - Returns cached data if valid and not expired

2. **Cache Store** (`_store_cached_resource`)
   - Stores Azure query results in SQLite
   - Updates resource metadata (last validated, provisioning state)

3. **Cache Invalidation** (`_invalidate_resource_cache`)
   - Marks cache entries as invalid
   - Called after resource modifications

### Graceful Degradation

If `state-manager.sh` is not available:
- Cache operations are skipped
- Queries execute directly against Azure CLI
- No errors thrown (graceful fallback)

---

## Usage Patterns

### Basic Query Workflow

```bash
#!/bin/bash
source core/query.sh

# Query all VMs
vms=$(query_resources "compute")
echo "$vms" | jq -r '.[] | "\(.name) - \(.powerState)"'

# Query specific VM
vm=$(query_resource "vm" "avd-sh-01" "RG-Azure-VDI-01")
echo "$vm" | jq -r '.vmSize'
```

### Cache-First with Fallback

```bash
# Try cache first, fallback to Azure on miss
resource=$(query_resource "vm" "my-vm" "my-rg")

# Force fresh query by invalidating cache first
invalidate_cache "vm:my-rg:my-vm" "Force refresh"
resource=$(query_resource "vm" "my-vm" "my-rg")
```

### Bulk Queries with Filtering

```bash
# Query all VMs, filter in JQ
all_vms=$(query_resources "compute" "" "full")
running_vms=$(echo "$all_vms" | jq '[.[] | select(.powerState == "VM running")]')

echo "Running VMs: $(echo "$running_vms" | jq 'length')"
```

### Multi-Resource Queries

```bash
# Query multiple resource types
compute=$(query_resources "compute")
networking=$(query_resources "networking")
storage=$(query_resources "storage")

# Combine into single summary
jq -n \
    --argjson c "$compute" \
    --argjson n "$networking" \
    --argjson s "$storage" \
    '{
        compute: ($c | length),
        networking: ($n | length),
        storage: ($s | length)
    }'
```

### Error Handling

```bash
# Query with error handling
if ! vm=$(query_resource "vm" "my-vm" "my-rg" 2>/dev/null); then
    log_error "Failed to query VM"
    exit 1
fi

# Check if resource exists
if [[ -z "$vm" ]] || [[ "$vm" == "null" ]]; then
    log_error "VM not found"
    exit 1
fi
```

---

## Performance Considerations

### Cache TTL Strategy

- **Single Resource:** 300s (5 min)
  - Assumption: Individual resources change infrequently
  - Longer TTL reduces Azure API calls

- **Resource Lists:** 120s (2 min)
  - Assumption: Lists may change more frequently
  - Shorter TTL for fresher data

### Token Efficiency

**Example: Querying 10 VMs**

| Approach | Total Tokens | Efficiency |
|----------|--------------|------------|
| Raw Azure CLI output | ~20,000 | Baseline |
| Full filter (`compute.jq`) | ~2,000 | 90% reduction |
| Summary filter | ~500 | 97.5% reduction |

**Best Practices:**
1. Use `summary` format for overviews
2. Use `full` format only when needed
3. Query specific resources when possible (not lists)
4. Leverage cache for repeated queries

### Azure API Rate Limits

Azure CLI has rate limits. The cache helps by:
- Reducing redundant API calls
- Batch queries when possible
- Invalidate strategically (not aggressively)

**Rate Limit Guidelines:**
- ~12,000 reads/hour per subscription
- Cache reduces calls by 80-95% typically

---

## Troubleshooting

### Cache Not Working

**Symptom:** Every query hits Azure (no cache hits)

**Solutions:**
1. Check if `state-manager.sh` exists:
   ```bash
   ls -l core/state-manager.sh
   ```
2. Check SQLite database:
   ```bash
   sqlite3 state.db "SELECT COUNT(*) FROM resources;"
   ```
3. Enable debug logging:
   ```bash
   export DEBUG=1
   source core/query.sh
   ```

### JQ Filter Errors

**Symptom:** JQ errors when querying resources

**Solutions:**
1. Test filter manually:
   ```bash
   az vm list -o json | jq -f queries/compute.jq
   ```
2. Check filter syntax:
   ```bash
   jq --help
   ```
3. Regenerate filter:
   ```bash
   rm queries/compute.jq
   source core/query.sh
   ensure_jq_filter_exists "compute"
   ```

### Azure CLI Errors

**Symptom:** "Command failed" errors

**Solutions:**
1. Verify Azure login:
   ```bash
   az account show
   ```
2. Check resource group exists:
   ```bash
   az group show --name RG-Azure-VDI-01
   ```
3. Verify permissions:
   ```bash
   az role assignment list --assignee $(az account show --query user.name -o tsv)
   ```

---

## Integration with Other Components

### With State Manager

```bash
source core/state-manager.sh
source core/query.sh

# Query and store
vm=$(query_resource "vm" "my-vm" "my-rg")
store_resource "$vm"

# Mark as managed
resource_id=$(echo "$vm" | jq -r '.id')
mark_as_managed "$resource_id"
```

### With Engine

```bash
source core/engine.sh
source core/query.sh

# Validate resource before operation
vm=$(query_resource "vm" "my-vm" "my-rg")
if [[ $(echo "$vm" | jq -r '.provisioningState') != "Succeeded" ]]; then
    log_error "VM not in succeeded state"
    exit 1
fi

# Run operation
./core/engine.sh run compute/update-vm
```

### With Discovery

```bash
source core/query.sh
source core/discovery.sh

# Query resources for discovery
all_resources=$(query_resources "all")

# Build dependency graph
build_dependency_graph "$all_resources"
```

---

## Advanced Usage

### Custom Resource Types

To add support for new resource types:

1. Add case to `query_azure_raw()`:
```bash
custom-type)
    result=$(az custom resource list -o json 2>/dev/null) || exit_code=$?
    ;;
```

2. Create JQ filter: `queries/custom-type.jq`

3. Add case to `query_resources()`:
```bash
custom-type)
    query_custom_type_resources "$resource_group" "$output_format"
    ;;
```

### Complex Queries

Use raw queries with custom JQ filters:

```bash
# Query VMs with complex filter
raw=$(query_azure_raw "vm")
filtered=$(echo "$raw" | jq '[
    .[]
    | select(.location == "eastus")
    | select(.tags.environment == "production")
    | {name, size: .hardwareProfile.vmSize}
]')
```

### Parallel Queries

Query multiple resources in parallel:

```bash
#!/bin/bash
query_resources "compute" &
query_resources "networking" &
query_resources "storage" &
wait

echo "All queries complete"
```

---

## Future Enhancements

### Planned Features

1. **Query History**
   - Track query performance metrics
   - Identify slow queries
   - Optimize cache strategy

2. **Smart Cache Prefetching**
   - Predict commonly queried resources
   - Prefetch before expiration
   - Reduce cache misses

3. **GraphQL-like Query Language**
   - Specify exact fields needed
   - Generate custom JQ filters on-the-fly
   - Ultra-precise token control

4. **Distributed Caching**
   - Share cache across multiple instances
   - Redis/Memcached backend option
   - Team-wide query optimization

---

## Reference

### Environment Variables

| Variable | Purpose | Default |
|----------|---------|---------|
| `PROJECT_ROOT` | Project root directory | Auto-detected |
| `QUERIES_DIR` | JQ filters directory | `${PROJECT_ROOT}/queries` |
| `CACHE_TTL_SINGLE_RESOURCE` | Single resource cache TTL | 300s |
| `CACHE_TTL_RESOURCE_LIST` | Resource list cache TTL | 120s |
| `DEBUG` | Enable debug logging | 0 |

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | General error (Azure CLI, invalid parameters) |
| 2 | Resource not found |
| 3 | Cache error |

---

## Examples

See [examples/query-examples.sh](../examples/query-examples.sh) for comprehensive usage examples.

---

**Last Updated:** 2025-12-06
**Version:** 1.0.0
