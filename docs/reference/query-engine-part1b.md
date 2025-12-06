
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

