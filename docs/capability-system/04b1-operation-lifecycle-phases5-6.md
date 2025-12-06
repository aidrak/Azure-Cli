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

