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

