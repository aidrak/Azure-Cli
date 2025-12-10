---
name: azure-troubleshooting
description: Debug and fix Azure deployment failures. Analyzes JSONL logs, queries state database, identifies error patterns, suggests fixes, and resumes operations. Use when operations fail, deployments stop, troubleshooting errors, checking why something failed, or resuming from failure.
allowed-tools: Read, Bash, Grep, Edit
---

# Azure Troubleshooting

Debug and fix Azure deployment failures using logs, state database, and automated error handling.

## When to use this Skill

- Operation failed with error message
- User asks "What went wrong?" or "Why did it fail?"
- User needs to resume a failed deployment
- User wants to check deployment logs
- User asks to troubleshoot or debug an issue
- Deployment is stuck or incomplete
- User asks "How do I fix..." or "What's the error?"
- User wants to understand failure root cause

## Quick Troubleshooting Workflow

```bash
# 1. Load configuration
source core/config-manager.sh && load_config

# 2. Check engine status
./core/engine.sh status

# 3. Try to resume (engine auto-checkpoints)
./core/engine.sh resume

# 4. If resume fails, debug:
#    a) Check logs for error patterns
#    b) Query state database for failure details
#    c) Analyze error message
#    d) Fix underlying issue (config, Azure, permissions)
#    e) Retry operation
```

## Key Troubleshooting Commands

### Check Current State

```bash
# Engine status
./core/engine.sh status

# List recent operations
./core/engine.sh list --recent

# Query state database for non-successful operations
sqlite3 state.db "SELECT operation_id, status, error_message FROM operations WHERE status != 'SUCCESS' ORDER BY timestamp DESC"

# Find failed operations
sqlite3 state.db "SELECT operation_id, status, error_message FROM operations WHERE status = 'FAILED' ORDER BY timestamp DESC LIMIT 10"

# Check last operation
sqlite3 state.db "SELECT operation_id, status, error_message, timestamp FROM operations ORDER BY timestamp DESC LIMIT 1"
```

### View Logs

All logs are in JSONL format at `artifacts/logs/deployment_YYYYMMDD.jsonl`:

```bash
# Today's log file
tail -f artifacts/logs/deployment_$(date +%Y%m%d).jsonl

# Last 50 lines
tail -50 artifacts/logs/deployment_*.jsonl

# Search for errors
grep -i "error\|failed\|exception\|\\[x\\]" artifacts/logs/deployment_*.jsonl | tail -20

# Show errors with context (5 lines after)
grep -i -A5 "error\|failed" artifacts/logs/deployment_*.jsonl | tail -30
```

### Trace Specific Operation

```bash
# Find all log entries for an operation
grep "operation-id" artifacts/logs/deployment_*.jsonl

# Get operation details from state database
sqlite3 state.db "SELECT * FROM operations WHERE operation_id = 'compute-create-vm'"

# Show operation timeline
sqlite3 state.db "SELECT operation_id, status, timestamp FROM operations WHERE operation_id LIKE '%compute%' ORDER BY timestamp"
```

## Common Issues and Fixes

### Issue: "Config not loaded"

**Symptoms**: Variables are empty, `{{VARIABLE}}` appears in output

**Solution**:
```bash
# Load configuration
source core/config-manager.sh && load_config

# Verify variables are set
echo $AZURE_RESOURCE_GROUP
echo $AZURE_LOCATION
echo $AZURE_SUBSCRIPTION_ID

# If still empty, check config.yaml
cat config.yaml | grep -A10 "azure:"
```

### Issue: "Azure authentication failed"

**Symptoms**: "Permission denied", "Unauthorized", "Login required"

**Solution**:
```bash
# Login to Azure
az login

# Check current account
az account show

# Set subscription if needed
az account set --subscription "$AZURE_SUBSCRIPTION_ID"

# Verify you have correct subscription
az account show -o table
```

### Issue: "Variable not found in template"

**Symptoms**: `{{VARIABLE_NAME}}` appears unchanged in output

**Solution**:
```bash
# Check what variables are loaded
env | grep -i azure | sort

# Reload config
source core/config-manager.sh && load_config

# Check if variable exists in config.yaml
cat config.yaml | grep -i "variable_name"

# Add missing variable to config.yaml if needed
```

### Issue: "Operation failed mid-execution"

**Symptoms**: Operation status is FAILED, partial work completed

**Solution**:
```bash
# Engine auto-creates checkpoints
./core/engine.sh resume

# If resume fails, check what specifically failed
sqlite3 state.db "SELECT error_message FROM operations WHERE operation_id = 'operation-id'"

# Review logs for the specific failure point
grep "operation-id" artifacts/logs/deployment_*.jsonl | grep -i "error\|failed"

# Fix the underlying issue (permissions, config, etc.)
# Then retry the operation
./core/engine.sh run operation-id
```

### Issue: "VM not ready / Timeout"

**Symptoms**: "Timed out waiting for", "VM not responding"

**Solution**:
```bash
# Check VM power state
az vm get-instance-view -g "$AZURE_RESOURCE_GROUP" -n "vm-name" -o json | jq -r '.statuses[] | select(.code | startswith("PowerState/")) | .displayStatus'

# Check provisioning state
az vm show -g "$AZURE_RESOURCE_GROUP" -n "vm-name" -o json | jq -r '.provisioningState'

# Start VM if deallocated
az vm start -g "$AZURE_RESOURCE_GROUP" -n "vm-name"

# Check dependency operations completed
sqlite3 state.db "SELECT operation_id, status FROM operations WHERE operation_id LIKE '%vm%' ORDER BY timestamp"

# Wait and retry
sleep 60
./core/engine.sh run operation-id
```

### Issue: "Permission denied on Azure resource"

**Symptoms**: "AuthorizationFailed", "Forbidden", "Insufficient privileges"

**Solution**:
```bash
# Check your Azure role assignments
az role assignment list --assignee $(az account show --query user.name -o tsv) -o table

# Verify subscription is correct
az account show -o table

# Common required roles:
# - Contributor (for creating resources)
# - User Access Administrator (for RBAC assignments)
# - Network Contributor (for networking)

# Contact Azure admin if permissions are missing
```

### Issue: "State database locked"

**Symptoms**: "database is locked", "cannot write to state.db"

**Solution**:
```bash
# Check for other running processes
ps aux | grep engine.sh

# Wait for other operations to complete
sleep 10

# If stuck, check for stale locks
fuser state.db

# Restart the operation
./core/engine.sh run operation-id
```

## Debugging Workflow

### Step 1: Identify what failed

```bash
# Check engine status
./core/engine.sh status

# Query recent operations
sqlite3 state.db "SELECT operation_id, status, timestamp FROM operations ORDER BY timestamp DESC LIMIT 10"

# View recent log entries
tail -30 artifacts/logs/deployment_$(date +%Y%m%d).jsonl
```

### Step 2: Get error details

```bash
# Get error message from state database
sqlite3 state.db "SELECT operation_id, error_message FROM operations WHERE status = 'FAILED' ORDER BY timestamp DESC LIMIT 1"

# Search logs for error context
grep -i -A10 "error" artifacts/logs/deployment_*.jsonl | tail -30
```

### Step 3: Analyze the error

Questions to ask:
- Is it a configuration issue? (Missing variables, wrong values)
- Is it an Azure API error? (Permissions, quota, resource conflict)
- Is it a script error? (PowerShell syntax, command failed)
- Is it a dependency issue? (Previous operation didn't complete)
- Is it a timeout? (Operation took too long)

### Step 4: Fix the root cause

Based on error type:
- **Config error**: Update config.yaml, reload with `source core/config-manager.sh && load_config`
- **Azure permission error**: Check `az role assignment list`, contact admin
- **Script error**: Review operation YAML, fix PowerShell script
- **Dependency error**: Check prerequisite operations completed successfully
- **Timeout error**: Increase timeout in operation YAML, or wait and retry

### Step 5: Resume or retry

```bash
# Try resume first (uses checkpoint)
./core/engine.sh resume

# Or manually retry the specific operation
./core/engine.sh run operation-id

# Monitor in real-time
tail -f artifacts/logs/deployment_$(date +%Y%m%d).jsonl
```

## Log Analysis Patterns

### Find all errors in logs

```bash
# PowerShell [x] marker or ERROR keyword
grep "\\[x\\]\\|ERROR\\|FAILED" artifacts/logs/deployment_*.jsonl

# With timestamp
grep "\\[x\\]\\|ERROR\\|FAILED" artifacts/logs/deployment_*.jsonl | jq -r '.timestamp, .message'
```

### Count successes vs failures

```bash
# Count successes
grep -c "\\[v\\] Success\|SUCCESS" artifacts/logs/deployment_*.jsonl

# Count failures
grep -c "\\[x\\] Error\|FAILED" artifacts/logs/deployment_*.jsonl

# Summary by operation
sqlite3 state.db "SELECT status, COUNT(*) FROM operations GROUP BY status"
```

### Find operations by status

```bash
# All failed operations
sqlite3 state.db "SELECT operation_id FROM operations WHERE status = 'FAILED'"

# All in-progress operations (might be stuck)
sqlite3 state.db "SELECT operation_id, timestamp FROM operations WHERE status = 'IN_PROGRESS'"

# All successful operations
sqlite3 state.db "SELECT operation_id FROM operations WHERE status = 'SUCCESS' ORDER BY timestamp"
```

## Error Handler Script

The system includes automated error detection at `core/error-handler.sh`:

### Features

- **Anti-destructive patterns**: Blocks "start over" or "delete VM" suggestions
- **Incremental fixes**: Promotes trial-and-error fixes, preserves work
- **Error pattern detection**: Recognizes common Azure errors
- **Fix suggestions**: Proposes solutions based on error patterns

### Using error handler

```bash
# Source error handler
source core/error-handler.sh

# Handle operation error
handle_operation_error "operation-id" "artifacts/logs/deployment.jsonl" 1

# Check for destructive actions in proposed fix
check_destructive_action "proposed fix text"
```

## Prevention Tips

1. **Always load config first**
   ```bash
   source core/config-manager.sh && load_config
   ```

2. **Validate before running**
   ```bash
   # Check variables are set
   echo $AZURE_RESOURCE_GROUP
   echo $AZURE_LOCATION

   # Verify Azure authentication
   az account show
   ```

3. **Enable validation in operations**
   ```yaml
   validation:
     enabled: true
     checks:
       - type: "exit_code"
         expected: 0
   ```

4. **Monitor in real-time**
   ```bash
   tail -f artifacts/logs/deployment_*.jsonl
   ```

5. **Use checkpoints**
   - Engine auto-saves state before critical operations
   - Use `./core/engine.sh resume` to continue from checkpoint

## Examples

### Example 1: Operation failed, find why

```bash
source core/config-manager.sh && load_config

# Check what failed
./core/engine.sh status

# Get error details
sqlite3 state.db "SELECT operation_id, error_message FROM operations WHERE status = 'FAILED' ORDER BY timestamp DESC LIMIT 1"

# View logs around the error
grep -i -A10 "error" artifacts/logs/deployment_$(date +%Y%m%d).jsonl | tail -30
```

### Example 2: Resume from failure

```bash
source core/config-manager.sh && load_config

# Engine automatically created checkpoint on failure
./core/engine.sh resume

# Monitor progress
tail -f artifacts/logs/deployment_$(date +%Y%m%d).jsonl
```

### Example 3: Debug variable issue

```bash
source core/config-manager.sh && load_config

# Check loaded variables
echo "Resource Group: $AZURE_RESOURCE_GROUP"
echo "Location: $AZURE_LOCATION"
echo "Subscription: $AZURE_SUBSCRIPTION_ID"

# If missing, check config.yaml
cat config.yaml | head -30

# Reload config
source core/config-manager.sh && load_config

# Verify now loaded
env | grep AZURE
```

### Example 4: Azure permissions issue

```bash
# Check your permissions
az role assignment list --assignee $(az account show --query user.name -o tsv) -o table

# Verify subscription
az account show -o table

# Check if you can create resources
az group exists -n "$AZURE_RESOURCE_GROUP"

# Try to list resources
az resource list -g "$AZURE_RESOURCE_GROUP" -o table
```

### Example 5: VM not responding

```bash
source core/config-manager.sh && load_config

# Check VM status
az vm get-instance-view -g "$AZURE_RESOURCE_GROUP" -n "vm-golden-image" -o json | jq -r '.statuses[]'

# Check power state specifically
az vm get-instance-view -g "$AZURE_RESOURCE_GROUP" -n "vm-golden-image" -o json | jq -r '.statuses[] | select(.code | startswith("PowerState/")) | .displayStatus'

# If deallocated, start it
az vm start -g "$AZURE_RESOURCE_GROUP" -n "vm-golden-image"

# Wait for ready state
sleep 60

# Retry operation
./core/engine.sh run compute-vm-configure
```

## State Database Schema

The state.db SQLite database tracks all operations:

```sql
-- Common queries

-- Get operation history
SELECT operation_id, status, timestamp FROM operations ORDER BY timestamp DESC;

-- Find failures
SELECT operation_id, error_message FROM operations WHERE status = 'FAILED';

-- Operation timeline
SELECT operation_id, status, timestamp FROM operations WHERE operation_id LIKE '%keyword%' ORDER BY timestamp;

-- Status summary
SELECT status, COUNT(*) as count FROM operations GROUP BY status;

-- Recent activity (last 24 hours)
SELECT operation_id, status FROM operations WHERE timestamp > datetime('now', '-1 day') ORDER BY timestamp DESC;
```

## Log Format

Logs are in JSONL (JSON Lines) format:

```json
{"timestamp": "2025-12-07T10:30:45Z", "level": "INFO", "operation_id": "compute-create-vm", "message": "[*] Creating VM..."}
{"timestamp": "2025-12-07T10:32:10Z", "level": "SUCCESS", "operation_id": "compute-create-vm", "message": "[v] VM created successfully"}
{"timestamp": "2025-12-07T10:35:22Z", "level": "ERROR", "operation_id": "compute-vm-configure", "message": "[x] Error: Connection timeout"}
```

Parse with jq:
```bash
# Pretty print logs
cat artifacts/logs/deployment_*.jsonl | jq '.'

# Filter by level
cat artifacts/logs/deployment_*.jsonl | jq 'select(.level == "ERROR")'

# Get just messages
cat artifacts/logs/deployment_*.jsonl | jq -r '.message'
```

## Advanced Troubleshooting

### Network connectivity issues

```bash
# Test Azure connectivity
curl -I https://management.azure.com/

# Check DNS resolution
nslookup management.azure.com

# Test specific endpoint
az rest --method get --url "https://management.azure.com/subscriptions?api-version=2020-01-01"
```

### Resource quota issues

```bash
# Check quota usage
az vm list-usage --location "$AZURE_LOCATION" -o table

# Check network quota
az network list-usage --location "$AZURE_LOCATION" -o table
```

### Deployment validation

```bash
# Validate specific operation YAML syntax
yamllint capabilities/compute/operations/vm-create.yaml

# Test template variable substitution
source core/template-engine.sh
substitute_variables "capabilities/compute/operations/vm-create.yaml"
```

## Related Skills

- **azure-state-query**: Check current Azure infrastructure state
- **azure-operations**: Deploy and modify infrastructure

## Documentation

- Error handler: `core/error-handler.sh`
- Logger: `core/logger.sh`
- State manager: `core/state-manager.sh`
- Troubleshooting guide: `QUICKSTART.md#troubleshooting`
