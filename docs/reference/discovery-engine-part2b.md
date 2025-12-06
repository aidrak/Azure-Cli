
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
