
---

## Phase 3: Idempotency Check

### Overview

Check if the resource already exists to prevent duplicate creation.

### Check Process

```bash
# Execute check_command
exit_code=$(eval "$check_command"; echo $?)

if [ $exit_code -eq 0 ]; then
  # Resource exists
  if [ "$skip_if_exists" = "true" ]; then
    echo "[INFO] Resource already exists, skipping"
    exit 0  # Success, operation skipped
  fi
else
  # Resource doesn't exist
  # Proceed with creation
fi
```

### Example

```yaml
idempotency:
  enabled: true
  check_command: |
    az network vnet show \
      --resource-group "{{AZURE_RESOURCE_GROUP}}" \
      --name "{{NETWORKING_VNET_NAME}}" \
      --output none 2>/dev/null
  skip_if_exists: true
```

**Scenario 1: Resource Exists**
```bash
# check_command succeeds (exit 0)
# skip_if_exists = true
# Result: Operation skipped, marked as success
```

**Scenario 2: Resource Doesn't Exist**
```bash
# check_command fails (exit non-zero)
# Result: Proceed to execution phase
```

### Benefits

- Safe to retry failed operations
- Resumable deployments
- No accidental duplicate resources
- Faster re-runs (skips completed operations)

---

## Phase 4: Execution

### Overview

Execute the operation's template command with full monitoring.

### Execution Process

```bash
1. Substitute all {{PLACEHOLDERS}} in command
2. Write script to temporary file
3. Set timeout timer
4. Execute script
5. Monitor for timeout
6. Capture stdout and stderr
7. Store exit code
8. Clean up temporary file
```

### Placeholder Substitution

```bash
# Original command
az network vnet create \
  --resource-group "{{AZURE_RESOURCE_GROUP}}" \
  --name "{{NETWORKING_VNET_NAME}}"

# After substitution
az network vnet create \
  --resource-group "RG-AVD-PROD" \
  --name "avd-vnet-prod"
```

### Timeout Monitoring

```bash
# Set timeout
timeout=$duration_timeout

# Execute with timeout
timeout $timeout bash /tmp/operation-script.sh

# Check result
if [ $? -eq 124 ]; then
  echo "[ERROR] Operation timed out after $timeout seconds"
  trigger_rollback
fi
```

### Output Capture

```bash
# Capture all output
exec 1> >(tee -a operation.log)
exec 2> >(tee -a operation.error.log >&2)

# Execute command
eval "$command"

# Store exit code
exit_code=$?
```

### Example

```yaml
template:
  type: "powershell-local"
  command: |
    cat > /tmp/vnet-create.ps1 << 'PSWRAPPER'
    Write-Host "[START] Creating VNet..."
    az network vnet create `
      --resource-group "{{AZURE_RESOURCE_GROUP}}" `
      --name "{{NETWORKING_VNET_NAME}}"
    Write-Host "[DONE] VNet created"
    PSWRAPPER

    timeout 300 pwsh -File /tmp/vnet-create.ps1
    rm -f /tmp/vnet-create.ps1
```

---

## Phase 5: Validation Checks

### Overview

After successful execution, verify the operation achieved its intended result.

### Validation Sequence

```
1. Operation script completes with exit code 0
   ↓
2. Run each validation check in order
   ↓
3. For each check:
   a. Execute check command
   b. Compare result to expected value
   c. Mark as PASS or FAIL
   ↓
4. Aggregate results:
   - All critical checks pass → SUCCESS
   - Any critical check fails → FAIL (trigger rollback)
   - Only non-critical checks fail → SUCCESS (with warnings)
```

### Check Types Execution

**resource_exists:**
```bash
az resource show \
  --resource-type "$resource_type" \
  --name "$resource_name" \
  --output none
# Exit 0 = exists, non-zero = missing
```

**provisioning_state:**
```bash
state=$(az resource show \
  --query "provisioningState" -o tsv)
if [ "$state" = "$expected" ]; then
