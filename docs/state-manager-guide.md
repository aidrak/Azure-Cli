# State Manager Guide

**Production-grade SQLite state management for Azure Infrastructure Toolkit**

---

## Overview

The State Manager (`core/state-manager.sh`) is the **CORE** of the Azure Infrastructure Toolkit, providing:

- **Intelligent caching** - Cache-first resource queries with 5-minute TTL
- **Dependency tracking** - Build and validate resource dependency graphs (DAG)
- **Operation history** - Complete audit trail with resume capability
- **Smart invalidation** - Automatic cache invalidation on resource changes
- **Analytics** - Performance metrics and operational insights

---

## Quick Start

```bash
# Load the state manager
source core/state-manager.sh

# Initialize database
init_state_db

# Store a resource
RESOURCE_JSON='{"id": "/subscriptions/.../resourceGroups/rg/providers/Microsoft.Compute/virtualMachines/vm1", ...}'
store_resource "$RESOURCE_JSON"

# Query with cache-first approach
get_resource "virtualMachines" "vm1" "rg-name"

# Track dependencies
add_dependency "$vm_id" "$vnet_id" "required" "uses"

# Create operation
create_operation "deploy-vm-001" "compute" "vm-create" "create"
update_operation_status "deploy-vm-001" "running"
update_operation_status "deploy-vm-001" "completed"
```

---

## Database Architecture

### Location
- **Database**: `/mnt/cache_pool/development/azure-cli/state.db`
- **Schema**: `/mnt/cache_pool/development/azure-cli/schemas/state.schema.sql`

### Tables

#### Core Tables
1. **resources** - Resource metadata and properties
2. **dependencies** - Resource dependency graph
3. **operations** - Operation history and tracking
4. **operation_logs** - Detailed operation logs
5. **cache_metadata** - Smart caching layer

#### Analytics Views
- **active_resources** - Non-deleted resources
- **managed_resources** - Resources managed by toolkit
- **failed_operations** - Failed operations eligible for retry
- **running_operations** - Currently running operations
- **operation_stats** - Aggregated operation statistics
- **resource_stats** - Resource counts and states

---

## API Reference

### Database Initialization

#### `init_state_db()`
Initialize SQLite database if not exists.

**Usage:**
```bash
init_state_db
```

**Returns:** 0 on success, 1 on failure

**Features:**
- Idempotent (safe to call multiple times)
- Creates schema from `schemas/state.schema.sql`
- Fallback inline schema if file not found
- Enables foreign keys and triggers

---

### Resource Management

#### `store_resource(resource_json)`
Store or update resource in database.

**Arguments:**
- `resource_json` - Full Azure resource JSON

**Usage:**
```bash
RESOURCE_JSON=$(az vm show --name vm1 --resource-group rg1)
store_resource "$RESOURCE_JSON"
```

**Features:**
- Upsert operation (INSERT or UPDATE)
- Automatic cache expiry (5 minutes)
- JSON validation
- SQL injection prevention

---

#### `get_resource(resource_type, resource_name, resource_group)`
Get resource from cache or query Azure.

**Arguments:**
- `resource_type` - Azure resource type (e.g., "virtualMachines")
- `resource_name` - Resource name
- `resource_group` - Resource group (optional, defaults to AZURE_RESOURCE_GROUP)

**Usage:**
```bash
# Cache-first query
vm_json=$(get_resource "virtualMachines" "vm1" "rg-name")
```

**Returns:** JSON resource data

**Features:**
- **Cache HIT**: Returns cached data if valid (< 5 min old)
- **Cache MISS**: Queries Azure CLI, stores result, returns data
- Automatic cache management
- Logging of cache hits/misses

---

#### `mark_as_managed(resource_id)`
Mark resource as managed by toolkit.

**Arguments:**
- `resource_id` - Full Azure resource ID

**Usage:**
```bash
mark_as_managed "/subscriptions/sub-id/resourceGroups/rg/providers/Microsoft.Compute/virtualMachines/vm1"
```

**Features:**
- Sets `managed_by_toolkit = 1`
- Records `adopted_at` timestamp
- Tags resource in Azure (best effort)

---

#### `mark_as_created(resource_id)`
Mark resource as created by toolkit.

**Arguments:**
- `resource_id` - Full Azure resource ID

**Usage:**
```bash
mark_as_created "/subscriptions/sub-id/resourceGroups/rg/providers/Microsoft.Compute/virtualMachines/vm1"
```

**Features:**
- Sets `managed_by_toolkit = 1`
- Records `created_at` timestamp
- Tags resource in Azure (best effort)

---

#### `soft_delete_resource(resource_id)`
Soft delete resource (mark as deleted without removing from DB).

**Arguments:**
- `resource_id` - Full Azure resource ID

**Usage:**
```bash
soft_delete_resource "$resource_id"
```

**Features:**
- Sets `deleted_at` timestamp
- Resource remains in database for audit
- Excluded from active queries

---

### Dependency Management

#### `add_dependency(resource_id, depends_on_id, dependency_type, relationship)`
Add dependency relationship between resources.

**Arguments:**
- `resource_id` - Dependent resource ID
- `depends_on_id` - Dependency target ID
- `dependency_type` - "required", "optional", or "reference" (default: "required")
- `relationship` - "uses", "contains", "references" (default: "uses")

**Usage:**
```bash
# VM depends on VNet
add_dependency "$vm_id" "$vnet_id" "required" "uses"

# Subnet contained by VNet
add_dependency "$subnet_id" "$vnet_id" "required" "contains"
```

**Features:**
- Upsert operation (prevents duplicates)
- Builds directed acyclic graph (DAG)
- Updates `validated_at` on conflict

---

#### `get_dependencies(resource_id)`
Get resources that this resource depends on.

**Arguments:**
- `resource_id` - Resource ID

**Returns:** JSON array of dependencies

**Usage:**
```bash
deps=$(get_dependencies "$vm_id")
echo "$deps" | jq '.[] | .name'
```

---

#### `get_dependents(resource_id)`
Get resources that depend on this resource.

**Arguments:**
- `resource_id` - Resource ID

**Returns:** JSON array of dependents

**Usage:**
```bash
dependents=$(get_dependents "$vnet_id")
echo "$dependents" | jq '.[] | .name'
```

---

#### `check_dependencies_satisfied(resource_id)`
Check if all required dependencies are satisfied.

**Arguments:**
- `resource_id` - Resource ID

**Returns:** 0 if satisfied, 1 if not

**Usage:**
```bash
if check_dependencies_satisfied "$vm_id"; then
    echo "Dependencies satisfied, can proceed"
else
    echo "Dependencies not satisfied, must wait"
fi
```

**Validation:**
- Checks all `dependency_type = 'required'`
- Verifies dependency exists in DB
- Checks `provisioning_state = 'Succeeded'`
- Excludes soft-deleted resources

---

### Operation Management

#### `create_operation(operation_id, capability, operation_name, operation_type, resource_id)`
Create operation record.

**Arguments:**
- `operation_id` - Unique operation ID
- `capability` - Capability name (e.g., "compute", "networking")
- `operation_name` - Operation name (e.g., "vm-create")
- `operation_type` - "create", "adopt", "modify", "validate"
- `resource_id` - Target resource ID (optional)

**Usage:**
```bash
OP_ID="golden-image-$(date +%s)"
create_operation "$OP_ID" "compute" "create-golden-image" "create"
```

**Features:**
- Initial status: "pending"
- Records `started_at` timestamp
- Supports parent/child operations

---

#### `update_operation_status(operation_id, status, error_message)`
Update operation status.

**Arguments:**
- `operation_id` - Operation ID
- `status` - "pending", "running", "completed", "failed", "blocked"
- `error_message` - Error message (optional, for failed status)

**Usage:**
```bash
update_operation_status "$OP_ID" "running"
# ... operation executes ...
update_operation_status "$OP_ID" "completed"
```

**Features:**
- Automatic duration calculation for "completed"/"failed"
- Error message storage
- Timestamp tracking

---

#### `update_operation_progress(operation_id, current_step, total_steps, step_description)`
Update operation progress.

**Arguments:**
- `operation_id` - Operation ID
- `current_step` - Current step number
- `total_steps` - Total number of steps
- `step_description` - Description of current step (optional)

**Usage:**
```bash
update_operation_progress "$OP_ID" 1 5 "Installing FSLogix"
update_operation_progress "$OP_ID" 2 5 "Configuring OS"
```

---

#### `log_operation(operation_id, level, message, details)`
Log operation message.

**Arguments:**
- `operation_id` - Operation ID
- `level` - "INFO", "WARN", "ERROR", "SUCCESS", "PROGRESS"
- `message` - Log message
- `details` - Additional JSON details (optional)

**Usage:**
```bash
log_operation "$OP_ID" "INFO" "Starting VM creation"
log_operation "$OP_ID" "ERROR" "Failed to create VM" '{"error_code": "QuotaExceeded"}'
```

---

#### `get_operation_status(operation_id)`
Get operation status.

**Arguments:**
- `operation_id` - Operation ID

**Returns:** JSON operation record

**Usage:**
```bash
status=$(get_operation_status "$OP_ID")
echo "$status" | jq '.status'
```

---

#### `get_failed_operations()`
Get failed operations eligible for retry.

**Returns:** JSON array of failed operations

**Usage:**
```bash
failed=$(get_failed_operations)
echo "$failed" | jq '.[] | .operation_id'
```

---

#### `get_running_operations()`
Get currently running operations.

**Returns:** JSON array of running operations

**Usage:**
```bash
running=$(get_running_operations)
echo "$running" | jq '.[] | .operation_id'
```

---

### Cache Management

#### `invalidate_cache(pattern, reason)`
Invalidate cache entries matching pattern.

**Arguments:**
- `pattern` - SQL LIKE pattern (default: "*")
- `reason` - Invalidation reason (default: "manual")

**Usage:**
```bash
# Invalidate all compute resources
invalidate_cache "Microsoft.Compute%" "resource_updated"

# Invalidate all cache
invalidate_cache "*" "manual_refresh"
```

---

#### `clean_expired_cache()`
Clean expired cache entries.

**Usage:**
```bash
clean_expired_cache
```

**Features:**
- Removes entries past TTL
- Removes invalidated entries
- Automatic maintenance

---

### Analytics

#### `get_operation_stats()`
Get operation statistics.

**Returns:** JSON statistics by capability, type, and status

**Usage:**
```bash
stats=$(get_operation_stats)
echo "$stats" | jq '.[] | select(.status == "failed")'
```

---

#### `get_managed_resources_count()`
Get count of managed resources.

**Returns:** Integer count

**Usage:**
```bash
count=$(get_managed_resources_count)
echo "Managed resources: $count"
```

---

#### `get_resources_by_type()`
Get resources grouped by type.

**Returns:** JSON array with counts per type

**Usage:**
```bash
by_type=$(get_resources_by_type)
echo "$by_type" | jq '.[] | "\(.resource_type): \(.count)"'
```

---

## Design Patterns

### Cache-First Pattern

```bash
# Always check cache before querying Azure
resource=$(get_resource "virtualMachines" "vm-name" "rg-name")

# Function handles:
# 1. Check SQLite cache (< 5 min old)
# 2. If cache miss, query Azure CLI
# 3. Store in cache
# 4. Return result
```

### Atomic Updates with Transactions

```bash
# Use BEGIN/COMMIT for multi-statement operations
sqlite3 state.db <<EOF
BEGIN TRANSACTION;
INSERT INTO resources (...) VALUES (...);
INSERT INTO dependencies (...) VALUES (...);
COMMIT;
EOF
```

### Dependency Validation Before Execution

```bash
# Always check dependencies before executing
if check_dependencies_satisfied "$resource_id"; then
    # Proceed with operation
    create_operation "$op_id" "compute" "vm-create" "create" "$resource_id"
else
    # Block operation
    log_warn "Dependencies not satisfied, blocking operation"
fi
```

### SQL Injection Prevention

```bash
# ALWAYS use sql_escape() for user input
user_input="O'Reilly"
safe_input=$(sql_escape "$user_input")  # "O''Reilly"

# Use in SQL
sql="INSERT INTO resources (name) VALUES ('$safe_input');"
```

---

## Performance Considerations

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
# In modules/compute/vm-create.sh
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
