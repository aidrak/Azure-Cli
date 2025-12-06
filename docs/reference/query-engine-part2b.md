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
