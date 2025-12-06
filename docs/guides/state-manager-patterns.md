### Cache TTL
- Default: 300 seconds (5 minutes)
- Configurable via `CACHE_TTL` variable
- Balance freshness vs. API calls

### Indexes
All high-traffic queries are indexed:
- `resource_type`, `resource_group`, `subscription_id`
- `managed_by_toolkit`, `provisioning_state`
- `cache_key`, `cache_expires_at`
- `operation_id`, `status`, `capability`

### Database Size
- Soft deletes preserve history
- Clean up old operations periodically
- Consider archiving old data

---

## Error Handling

All functions return proper exit codes:
- **0** - Success
- **1** - Failure

Check return codes:

```bash
if store_resource "$json"; then
    log_success "Resource stored"
else
    log_error "Failed to store resource"
    return 1
fi
```

---

## Testing

Run the comprehensive test suite:

```bash
./test-state-manager.sh
```

Run the demonstration:

```bash
./demo-state-manager.sh
```

---

## Troubleshooting

### Database locked

```bash
# Check for running processes
ps aux | grep sqlite3

# Kill stuck processes
pkill -9 sqlite3
```

### Cache not invalidating

```bash
# Manual cache clear
invalidate_cache "*" "manual"
clean_expired_cache
```

### Query Azure fails

```bash
# Check Azure CLI authentication
az account show

# Re-authenticate
az login
```

---

## Advanced Usage

### Custom Queries

```bash
# Direct SQLite queries
sqlite3 state.db "
SELECT
    r.name,
    COUNT(d.id) as dependency_count
FROM resources r
LEFT JOIN dependencies d ON r.resource_id = d.resource_id
GROUP BY r.name
ORDER BY dependency_count DESC;
"
```

### Dependency Visualization

```bash
# Export dependency graph
sqlite3 state.db "
SELECT
    r1.name || ' -> ' || r2.name as edge
FROM dependencies d
JOIN resources r1 ON d.resource_id = r1.resource_id
JOIN resources r2 ON d.depends_on_resource_id = r2.resource_id;
" > deps.txt
```

### Operation Resume

```bash
# Find last failed operation
last_failed=$(get_failed_operations | jq -r '.[0].operation_id')

# Resume logic (custom implementation)
if [[ -n "$last_failed" ]]; then
    echo "Resuming operation: $last_failed"
    # ... resume logic ...
fi
```

---

## Integration Examples

### With Engine

```bash
# In core/engine.sh
source core/state-manager.sh

# Before operation
init_state_db
create_operation "$operation_id" "$capability" "$op_name" "create"
update_operation_status "$operation_id" "running"

# After operation
update_operation_status "$operation_id" "completed"
```

### With Modules

```bash
# In capabilities/compute/operations/vm-create.yaml
source core/state-manager.sh

# Store created resource
vm_json=$(az vm show --name "$vm_name" --resource-group "$rg")
store_resource "$vm_json"
mark_as_created "$(echo "$vm_json" | jq -r '.id')"
```

---

## Best Practices

1. **Always initialize** - Call `init_state_db` at script start
2. **Use cache-first** - Call `get_resource` instead of direct Azure queries
3. **Track dependencies** - Build the DAG for proper ordering
4. **Log operations** - Create operation records for audit trail
5. **Escape SQL** - Always use `sql_escape` for user input
6. **Check return codes** - Validate function success
7. **Clean cache** - Periodically run `clean_expired_cache`

---

## See Also

- [Architecture Document](/mnt/cache_pool/development/azure-cli/ARCHITECTURE.md)
- [Production Architecture](/home/brandon/.claude/plans/azure-toolkit-production.md)
- [Database Schema](/mnt/cache_pool/development/azure-cli/schemas/state.schema.sql)

---

**Last Updated**: 2025-12-06
**Version**: 1.0.0
**Status**: Production Ready
