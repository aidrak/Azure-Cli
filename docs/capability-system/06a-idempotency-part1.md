# Idempotency

**Ensuring operations are safe to run multiple times with the same parameters**

## Table of Contents

1. [Purpose and Benefits](#purpose-and-benefits)
2. [Check Command Execution](#check-command-execution)
3. [skip_if_exists Behavior](#skip_if_exists-behavior)
4. [Real Operation Examples](#real-operation-examples)
5. [Design Patterns](#design-patterns)

---

## Purpose and Benefits

### Purpose

**Idempotency:** The property that an operation can be run multiple times without changing the result beyond the initial application.

In the context of Azure deployments:
- Running a "create VNet" operation twice should not create two VNets
- The second execution should detect the existing VNet and skip gracefully
- The end result is the same whether run once or multiple times

### Benefits

**1. Safety**
- Can safely retry failed operations
- No accidental duplicate resources
- Reduces operational errors

**2. Resumability**
- Resume interrupted deployments
- Pick up where you left off after failures
- No need to start from scratch

**3. Replayability**
- Replay operations in same environment
- Test deployment scripts safely
- Verify configurations without changes

**4. Automation**
- Automated remediation without manual checks
- CI/CD pipelines can retry safely
- Self-healing systems can re-run operations

**5. Peace of Mind**
- Developers can confidently re-run operations
- No "what if I already ran this?" anxiety
- Clear success messages for existing resources

---

## Check Command Execution

### How It Works

The `check_command` determines if a resource already exists:

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

### Execution Logic

```bash
# 1. Engine executes check_command
check_command...

# 2. Check exit code
if [ $? -eq 0 ]; then
    # Resource exists (exit code 0)
    echo "[INFO] Resource found"
    
    if [ "$skip_if_exists" = "true" ]; then
        echo "[INFO] Resource already exists, skipping"
        exit 0  # Success (operation skipped)
    else
        echo "[INFO] Resource exists, proceeding anyway"
        # Continue to execution
    fi
else
    # Resource doesn't exist (exit code non-zero)
    echo "[INFO] Resource not found, proceeding with creation"
    # Continue to execution
fi
```

### Exit Code Semantics

**Exit Code 0 (Success):**
- Resource exists
- Check command found the resource
- Resource is in expected state

**Exit Code Non-Zero (Failure):**
- Resource does not exist
- Resource not found in Azure
- Proceed with creation

### Best Practices for Check Commands

**1. Use --output none for silence:**
```bash
✓ az network vnet show ... --output none
✗ az network vnet show ...  (produces JSON output)
```

**2. Redirect errors to /dev/null:**
```bash
✓ ... 2>/dev/null
✗ ...  (error messages pollute logs)
```

**3. Check specific resource, not list:**
```bash
✓ az network vnet show --name "specific-vnet"
✗ az network vnet list  (too broad, inefficient)
```

**4. Keep it fast (< 5 seconds):**
```bash
✓ Single resource query
✗ Complex multi-step validation
```

---

## skip_if_exists Behavior

### When skip_if_exists: true

**Behavior:**
- If check_command succeeds (exit 0) → Skip operation, return success
- If check_command fails (non-zero) → Proceed with creation

**Use Cases:**
- Create operations (don't create duplicates)
- Most idempotent operations
- Safe retry scenarios

**Example:**
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

**Result:**
```
First run:
  [INFO] Checking if VNet exists...
  [INFO] Resource not found, proceeding with creation
  [SUCCESS] VNet created: avd-vnet-prod

Second run:
  [INFO] Checking if VNet exists...
  [INFO] Resource already exists, skipping
  [SUCCESS] Operation completed (skipped)
```

---

### When skip_if_exists: false

**Behavior:**
- If check_command succeeds (exit 0) → Proceed anyway (for updates)
- If check_command fails (non-zero) → Proceed (may fail if resource expected)

**Use Cases:**
- Update/configure operations
- Operations that must run even if resource exists
- Validation operations

**Example:**
```yaml
idempotency:
  enabled: true
  check_command: |
    az storage account show \
      --resource-group "{{AZURE_RESOURCE_GROUP}}" \
      --name "{{STORAGE_ACCOUNT_NAME}}" \
      --output none 2>/dev/null
  skip_if_exists: false
```

**Result:**
```
Run when resource exists:
  [INFO] Checking if storage account exists...
  [INFO] Resource exists, proceeding anyway
  [INFO] Updating storage account configuration...
  [SUCCESS] Storage account configured

Run when resource missing:
  [INFO] Checking if storage account exists...
  [INFO] Resource not found, proceeding
