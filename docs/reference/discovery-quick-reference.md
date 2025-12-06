# Discovery Engine - Quick Reference

## One-Liners

```bash
# Discover resource group
source core/discovery.sh && discover_resource_group "RG-Azure-VDI-01"

# Discover subscription
source core/discovery.sh && discover_subscription

# Rediscover (invalidate cache)
source core/discovery.sh && rediscover "resource-group" "RG-Azure-VDI-01"

# View summary
cat discovered/inventory-summary.yaml

# View full inventory
cat discovered/inventory-full.json | jq '.'

# Convert graph to PNG
dot -Tpng discovered/dependency-graph.dot -o graph.png
```

## Common Queries

### Resource Counts
```bash
sqlite3 state.db "SELECT resource_type, COUNT(*) FROM resources GROUP BY resource_type;"
```

### VMs Only
```bash
sqlite3 state.db "SELECT name, location FROM resources WHERE resource_type LIKE '%virtualMachines%';"
```

### Dependencies
```bash
sqlite3 state.db "SELECT * FROM dependencies WHERE dependency_type = 'required';"
```

### Recent Discoveries
```bash
sqlite3 state.db "SELECT name, datetime(discovered_at, 'unixepoch') FROM resources ORDER BY discovered_at DESC LIMIT 10;"
```

## Output Files

| File | Description | Format |
|------|-------------|--------|
| `discovered/inventory-summary.yaml` | Token-efficient summary | YAML |
| `discovered/inventory-full.json` | Complete resource details | JSON |
| `discovered/dependency-graph.json` | Dependency graph data | JSON |
| `discovered/dependency-graph.dot` | GraphViz visualization | DOT |
| `state.db` | SQLite state database | SQLite |

## Functions Cheat Sheet

| Function | Purpose | Usage |
|----------|---------|-------|
| `discover` | Main discovery | `discover "resource-group" "RG-01"` |
| `discover_resource_group` | RG discovery | `discover_resource_group "RG-01"` |
| `discover_subscription` | Sub discovery | `discover_subscription` |
| `rediscover` | Invalidate + discover | `rediscover "resource-group" "RG-01"` |
| `discover_compute_resources` | VMs only | `discover_compute_resources "resource-group" "RG-01"` |
| `discover_networking_resources` | Networks only | `discover_networking_resources "resource-group" "RG-01"` |
| `build_discovery_graph` | Build graph | `build_discovery_graph` |
| `tag_discovered_resources` | Tag in Azure | `tag_discovered_resources` |

## Configuration

```bash
# Disable Azure tagging
export TAG_DISCOVERED_RESOURCES=false

# Enable debug logging
export CURRENT_LOG_LEVEL=0

# Custom state database location
export STATE_DB="/custom/path/state.db"

# Custom cache TTL (seconds)
export CACHE_TTL=600
```

## Error Codes

| Code | Meaning | Solution |
|------|---------|----------|
| 1 | Invalid scope/target | Check arguments |
| 1 | Resource group not found | Verify RG exists |
| 1 | Authentication failed | Run `az login` |
| 1 | Permission denied | Check RBAC permissions |

## Integration Examples

### With State Manager
```bash
source core/discovery.sh
source core/state-manager.sh

discover_resource_group "RG-01"
get_resource "virtualMachines" "vm-01" "RG-01"  # Uses cache!
```

### With Query Engine
```bash
source core/discovery.sh
source core/query.sh

discover_resource_group "RG-01"
query_resources "compute" "RG-01"  # Uses cached data
```

### With Dependency Resolver
```bash
source core/discovery.sh
source core/dependency-resolver.sh

discover_resource_group "RG-01"
get_dependency_tree "/subscriptions/.../virtualMachines/vm-01"
```

## Performance Tips

1. **Scope Discovery**: Use resource group scope when possible
2. **Use Cache**: Run discovery once, query many times
3. **JQ Filters**: Filters reduce token usage by 90%+
4. **Batch Queries**: `discover_all_resources` is most efficient
5. **Regular Rediscovery**: Keep state fresh with daily rediscovery

## Troubleshooting

```bash
# Check state database
sqlite3 state.db "SELECT COUNT(*) FROM resources;"

# Enable debug logging
export CURRENT_LOG_LEVEL=0

# View discovery logs
cat artifacts/logs/deployment_*.jsonl | jq 'select(.operation_id | contains("discovery"))'

# Verify Azure CLI
az account show

# Test resource group access
az group show --name "RG-Azure-VDI-01"
```

## Common Workflows

### Initial Discovery
```bash
source core/discovery.sh
discover_resource_group "RG-Azure-VDI-01"
```

### Daily Refresh
```bash
source core/discovery.sh
rediscover "resource-group" "RG-Azure-VDI-01"
```

### Custom Report
```bash
source core/discovery.sh
discover_resource_group "RG-Azure-VDI-01"

sqlite3 state.db -json <<'EOF' > custom-report.json
SELECT name, location, resource_type
FROM resources
WHERE resource_type LIKE '%virtualMachines%';
EOF
```

### Dependency Analysis
```bash
source core/discovery.sh
discover_resource_group "RG-Azure-VDI-01"

# View graph
dot -Tpng discovered/dependency-graph.dot -o graph.png
open graph.png  # macOS
xdg-open graph.png  # Linux
```

## Key Metrics

| Metric | Target | Notes |
|--------|--------|-------|
| Discovery Time (50 resources) | < 60s | Resource group scope |
| Discovery Time (200 resources) | < 180s | Resource group scope |
| Token Reduction | > 85% | Via JQ filtering |
| Cache Hit Rate | > 70% | After initial discovery |

## See Also

- [Full Documentation](./discovery-engine-part1a.md)
- [Architecture](../ARCHITECTURE.md)
- [State Manager](./state-management.md)
- [Examples](../examples/discovery-example.sh)
