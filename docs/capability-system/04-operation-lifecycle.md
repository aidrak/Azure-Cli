# Operation Lifecycle

**Complete execution flow from discovery to completion**

## Table of Contents

1. [Complete Execution Flow](#complete-execution-flow)
2. [Phase 1: Discovery](#phase-1-discovery)
3. [Phase 2: Validation](#phase-2-validation)
4. [Phase 3: Idempotency Check](#phase-3-idempotency-check)
5. [Phase 4: Execution](#phase-4-execution)
6. [Phase 5: Validation Checks](#phase-5-validation-checks)
7. [Phase 6: State Tracking](#phase-6-state-tracking)
8. [Phase 7: Rollback](#phase-7-rollback)
9. [Phase 8: Self-Healing](#phase-8-self-healing)
10. [ASCII Flow Diagram](#ascii-flow-diagram)

---

## Complete Execution Flow

The operation lifecycle consists of 8 distinct phases:

```
1. DISCOVERY
   ├─ Engine scans capabilities/{capability}/operations/
   ├─ Loads operation YAML
   └─ Validates schema
        │
        ↓
2. VALIDATION
   ├─ Check all parameters provided
   ├─ Validate parameter types
   ├─ Verify {{PLACEHOLDER}} substitution
   └─ Check prerequisites satisfied
        │
        ↓
3. IDEMPOTENCY CHECK
   ├─ Run check_command
   ├─ If exits with 0: resource exists
   └─ If skip_if_exists=true: skip execution
        │
        ↓
4. EXECUTION
   ├─ Substitute all {{PLACEHOLDERS}}
   ├─ Write script to temp file
   ├─ Execute template command
   ├─ Monitor duration (fail if timeout)
   └─ Capture output and errors
        │
        ↓
5. VALIDATION CHECKS
   ├─ Run each validation check
   ├─ Verify expected states
   ├─ Store results in artifacts
   └─ Fail if critical checks fail
        │
        ↓
6. STATE TRACKING
   ├─ Log execution results
   ├─ Record timestamps
   ├─ Store artifact outputs
   └─ Update state.json
        │
        ↓
7. ROLLBACK (on failure)
   ├─ Execute rollback steps in order
   ├─ Respect continue_on_error flags
   └─ Log rollback results
        │
        ↓
8. SELF-HEALING (if applicable)
   ├─ Apply recorded fixes
   ├─ Retry up to 3 times
   ├─ Track fix history
   └─ Log healing outcomes
```

---

## Phase 1: Discovery

### Overview

The engine discovers operations by scanning the capability directory structure.

### Discovery Process

```bash
# Scan capability directories
for capability in capabilities/*/; do
  # Scan operations directory
  for operation in $capability/operations/*.yaml; do
    # Load YAML
    # Validate schema
    # Register operation
  done
done
```

### What Gets Validated

1. **YAML Syntax** - Valid YAML format
2. **Required Fields** - All mandatory fields present
3. **Field Types** - Correct data types
4. **Enum Values** - Valid capability, operation_mode, etc.

### Example

```bash
# Engine discovers:
capabilities/networking/operations/vnet-create.yaml
capabilities/storage/operations/account-create.yaml
capabilities/identity/operations/group-create.yaml
...

# Loads and validates each YAML file
```

### Failure Handling

If schema validation fails:
- Operation is not registered
- Error logged with details
- Engine continues discovering other operations
- Invalid operation cannot be executed

---

## Phase 2: Validation

### Overview

Before execution, the engine validates that all requirements are met.

### Validation Checks

**Parameter Validation:**
```
1. Check all required parameters provided
2. Validate parameter types (string, integer, boolean, array)
3. Apply validation_regex if specified
4. Apply validation_enum if specified
5. Verify sensitive parameters handled correctly
```

**Placeholder Validation:**
```
1. Find all {{PLACEHOLDER}} instances
2. Verify corresponding config.yaml values exist
3. Validate placeholder names are valid
4. Prepare substitution mapping
```

**Prerequisite Validation:**
```
1. Check required operations completed
2. Verify required resources exist in Azure
3. Validate dependency chain is satisfied
```

### Example

```yaml
# Operation requires these parameters
parameters:
  required:
    - name: "vnet_name"
      type: "string"
      default: "{{NETWORKING_VNET_NAME}}"

# Engine validates:
✓ Parameter "vnet_name" present
✓ Type is string
✓ Placeholder {{NETWORKING_VNET_NAME}} exists in config.yaml
✓ Value is non-empty
```

### Failure Handling

If validation fails:
- Operation does not execute
- Clear error message shown
- Indicates which validation failed
- User can correct and retry

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
  exit 0  # Success
else
  exit 1  # Failure
fi
```

**property_equals:**
```bash
value=$(az resource show \
  --query "$property" -o tsv)
if [ "$value" = "$expected" ]; then
  exit 0  # Success
else
  exit 1  # Failure
fi
```

### Example

```yaml
validation:
  enabled: true
  checks:
    - type: "resource_exists"
      resource_type: "Microsoft.Network/virtualNetworks"
      resource_name: "{{NETWORKING_VNET_NAME}}"
      description: "VNet exists"
      # Executes: az resource show ...

    - type: "provisioning_state"
      expected: "Succeeded"
      description: "VNet provisioned"
      # Executes: az ... --query provisioningState
```

### Results Storage

```json
{
  "operation_id": "vnet-create",
  "validation_results": {
    "enabled": true,
    "checks": [
      {
        "type": "resource_exists",
        "result": "PASS",
        "timestamp": "2025-12-06T14:23:45Z"
      },
      {
        "type": "provisioning_state",
        "result": "PASS",
        "expected": "Succeeded",
        "actual": "Succeeded",
        "timestamp": "2025-12-06T14:23:46Z"
      }
    ],
    "overall": "PASS"
  }
}
```

---

## Phase 6: State Tracking

### Overview

Record all execution details for auditing, debugging, and resumption.

### What Gets Tracked

**Execution Metadata:**
- Operation ID
- Start timestamp
- End timestamp
- Duration (actual)
- Exit code
- Status (success/failure)

**Outputs:**
- stdout capture
- stderr capture
- Validation results
- Resource IDs created

**Artifacts:**
- Generated scripts
- Configuration files
- Logs

### State File Structure

```json
{
  "operations": {
    "vnet-create": {
      "id": "vnet-create",
      "status": "completed",
      "start_time": "2025-12-06T14:23:00Z",
      "end_time": "2025-12-06T14:23:45Z",
      "duration_seconds": 45,
      "exit_code": 0,
      "outputs": {
        "vnet_id": "/subscriptions/.../virtualNetworks/avd-vnet-prod"
      },
      "validation": {
        "overall": "PASS",
        "checks": [...]
      }
    }
  }
}
```

### Usage

**Resume Deployments:**
```bash
# Check which operations completed
cat state.json | jq '.operations[].status'

# Resume from last incomplete operation
./core/engine.sh resume
```

**Debugging:**
```bash
# View operation logs
cat artifacts/logs/vnet-create.log

# View validation results
cat artifacts/validation/vnet-create.json
```

---

## Phase 7: Rollback

### Overview

On failure, automatically clean up resources to prevent partial deployments.

### When Rollback Triggers

- Operation script exits with non-zero code
- Timeout exceeded
- Critical validation check fails
- Dependency failure

### Rollback Execution

```bash
for step in rollback_steps; do
  echo "[ROLLBACK] $step_name"

  eval "$step_command"
  exit_code=$?

  if [ $exit_code -ne 0 ] && [ "$continue_on_error" = "false" ]; then
    echo "[ERROR] Rollback step failed: $step_name"
    break
  fi
done
```

### Example

```yaml
rollback:
  enabled: true
  steps:
    - name: "Delete Virtual Network"
      description: "Remove the VNet"
      command: |
        az network vnet delete \
          --resource-group "{{AZURE_RESOURCE_GROUP}}" \
          --name "{{NETWORKING_VNET_NAME}}" \
          --yes
      continue_on_error: false
```

**Execution:**
```
[ROLLBACK] Step 1/1: Delete Virtual Network
[INFO] Deleting VNet: avd-vnet-prod
[SUCCESS] VNet deleted
[ROLLBACK] Complete
```

---

## Phase 8: Self-Healing

### Overview

Apply known fixes for common issues and retry automatically.

### Self-Healing Process

```
1. Operation fails with specific error
   ↓
2. Match error to known issue_code in fixes array
   ↓
3. Apply fix_command
   ↓
4. Retry operation (up to retry_count times)
   ↓
5. Track success/failure
   ↓
6. Update fix history
```

### Example

```yaml
fixes:
  - issue_code: "DNS_RESOLUTION_FAILED"
    description: "DNS server temporarily unavailable"
    fix_command: |
      sleep 5  # Wait for DNS to recover
      retry_current_operation
    retry_count: 3
```

**Execution:**
```
[ERROR] VNet creation failed: DNS resolution timeout
[HEALING] Applying fix: DNS_RESOLUTION_FAILED
[HEALING] Waiting 5 seconds for DNS recovery...
[HEALING] Retrying operation (attempt 1/3)
[SUCCESS] VNet created successfully
```

### Fix History

```json
{
  "operation_id": "vnet-create",
  "issue_code": "DNS_RESOLUTION_FAILED",
  "applied_at": "2025-12-06T14:23:45Z",
  "retry_count": 1,
  "success": true,
  "execution_time_ms": 5234
}
```

---

## ASCII Flow Diagram

```
┌─────────────────────────────────────────┐
│ Engine discovers operation              │
│ capabilities/compute/operations/vm.yaml │
└────────────┬────────────────────────────┘
             │
             ↓
      ┌──────────────────┐
      │ Load & validate  │
      │ schema           │
      └────────┬─────────┘
               │
             ┌─┴──────────────────────┐
             │ Parameters OK?         │
             └─┬──────────────────────┘
               │
      ┌────────↓─────────┐
      │ Run idempotency  │
      │ check_command    │
      └────────┬─────────┘
               │
         ┌─────┴──────┐
      YES│            │NO
         │            │
    Skip ↓         ┌──↓──────────────┐
         │         │ Substitute      │
         │         │ {{PLACEHOLDERS}}│
         │         └────────┬────────┘
         │                  │
         │              ┌───↓────────────┐
         │              │ Execute script │
         │              │ w/ timeout     │
         │              └────────┬───────┘
         │                       │
         │                  ┌────↓─────────┐
         │                  │ Timeout?     │
         │                  └────┬─────┬───┘
         │                       │     │
         │                    YES│     │NO
         │                       │     │
         │                   Rollback  │
         │                       │  ┌──↓──────────────────┐
         │                       │  │ Run validation      │
         │                       │  │ checks              │
         │                       │  └───────┬─────────────┘
         │                       │          │
         │                       │   All OK?├──┐
         │                       │      │    │  │NO
         │                       │      ↓    │  │
         ├───────────────────────┴─→ Update   │  │
         │                      state.json   │  │
         │                                   ↓  │
         │                           Apply fixes│
         │                            (self-heal)
         │                                   │
         ↓                                   ↓
      SUCCESS                            RETRY
                                      (max 3 times)
                                           │
                                     ┌─────┴─────┐
                                     │ All retry?│
                                     └──┬────┬───┘
                                   YES│    │NO
                                      │    │
                                  Continue
                                      │
                                      ↓
                                    FAIL
```

---

## Related Documentation

- [Operation Schema](03-operation-schema.md) - YAML schema details
- [Idempotency](06-idempotency.md) - Detailed idempotency patterns
- [Validation Framework](07-validation-framework.md) - Validation check details
- [Rollback Procedures](08-rollback-procedures.md) - Rollback design
- [Self-Healing](09-self-healing.md) - Self-healing system

---

**Last Updated:** 2025-12-06
