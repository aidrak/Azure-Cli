# Rollback Procedures

**Automatic cleanup and reversal when operations fail**

## Table of Contents

1. [Purpose and Use Cases](#purpose-and-use-cases)
2. [Rollback Step Structure](#rollback-step-structure)
3. [continue_on_error Flag](#continue_on_error-flag)
4. [Step Execution Order](#step-execution-order)
5. [Rollback Examples](#rollback-examples)

---

## Purpose and Use Cases

### Purpose

**Automatically clean up resources if operation fails** to prevent partial deployments and resource orphaning.

### Use Cases

**1. Partial Failures**
- Created some resources but failed midway
- Example: VNet created, but subnet creation failed
- Rollback: Delete VNet to maintain clean state

**2. Timeout Failures**
- Resource created but didn't validate in time
- Example: VM created but timeout before validation
- Rollback: Delete VM to prevent orphaned resources

**3. Configuration Errors**
- Created with wrong parameters
- Example: Storage account with wrong SKU
- Rollback: Delete and allow retry with correct config

**4. Integration Failures**
- Resource created but can't integrate with others
- Example: NSG created but can't attach to subnet
- Rollback: Delete NSG, fix dependencies, retry

### Benefits

- **Clean State:** No orphaned resources
- **Cost Control:** Delete failed resources immediately
- **Retry Safety:** Clean slate for retry attempts
- **Audit Trail:** Log all cleanup actions

---

## Rollback Step Structure

### Complete Structure

```yaml
rollback:
  enabled: boolean
  steps:
    - name: "Step name"
      description: "Step description"
      command: |
        # Rollback command
      continue_on_error: boolean
```

### Field Reference

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `enabled` | boolean | Yes | Whether rollback is enabled |
| `steps` | array | Yes | List of rollback steps |
| `steps[].name` | string | Yes | Step identifier |
| `steps[].description` | string | Yes | Human-readable description |
| `steps[].command` | string | Yes | Command to execute |
| `steps[].continue_on_error` | boolean | Yes | Continue if this step fails |

### Simple Example

```yaml
rollback:
  enabled: true
  steps:
    - name: "Delete Virtual Network"
      description: "Remove the VNet and all associated resources"
      command: |
        az network vnet delete \
          --resource-group "{{AZURE_RESOURCE_GROUP}}" \
          --name "{{NETWORKING_VNET_NAME}}" \
          --yes
      continue_on_error: false
```

---

## continue_on_error Flag

### continue_on_error: false (CRITICAL)

**Behavior:**
- If step fails, stop rollback immediately
- Report rollback failure
- Manual intervention may be required

**Use Cases:**
- Essential cleanup steps
- Deleting main resource
- Critical operations that must succeed

**Example:**
```yaml
- name: "Delete Storage Account"
  description: "Remove the storage account"
  command: |
    az storage account delete \
      --resource-group "{{AZURE_RESOURCE_GROUP}}" \
      --name "{{STORAGE_ACCOUNT_NAME}}" \
      --yes
  continue_on_error: false  # Must succeed
```

**Result if fails:**
```
[ROLLBACK] Step 1/3: Delete Storage Account
[ERROR] Failed to delete storage account
[ROLLBACK] Stopping - critical step failed
[ACTION REQUIRED] Manual cleanup needed
```

---

### continue_on_error: true (OPTIONAL)

**Behavior:**
- If step fails, log warning and continue
- Attempt remaining rollback steps
- Rollback completes with warnings

**Use Cases:**
- Secondary cleanup (logs, metadata)
- Best-effort deletion
- Resources that may not exist

**Example:**
```yaml
- name: "Remove DNS records"
  description: "Clean up associated DNS records"
  command: |
    az network dns zone delete \
      --resource-group "{{AZURE_RESOURCE_GROUP}}" \
      --name "{{DNS_ZONE_NAME}}" \
      --yes
  continue_on_error: true  # OK if fails
```

**Result if fails:**
```
[ROLLBACK] Step 2/3: Remove DNS records
[WARNING] Failed to delete DNS records (may not exist)
[ROLLBACK] Continuing to next step
[ROLLBACK] Step 3/3: Update metadata
```

---

### When to Use Each

| Scenario | Flag | Reason |
|----------|------|--------|
| Delete main resource | `false` | Critical - must clean up |
| Delete dependent resource | `false` | Prevent orphans |
| Remove optional config | `true` | May not exist |
| Clean up logs/temp files | `true` | Non-critical |
| Delete backup resources | `true` | Best effort |

---

## Step Execution Order

### Sequential Execution

Rollback steps execute **sequentially** in the order defined:

```
Step 1 (Delete main resource)
   ↓ (if succeeds or continue_on_error=true)
Step 2 (Remove associated resources)
   ↓ (if succeeds or continue_on_error=true)
Step 3 (Update metadata)
   ↓
Rollback complete
```

### Execution Flow

```bash
for step in rollback_steps; do
  echo "[ROLLBACK] $step_name"

  eval "$step_command"
  exit_code=$?

  if [ $exit_code -ne 0 ]; then
    if [ "$continue_on_error" = "false" ]; then
      echo "[ERROR] Rollback step failed: $step_name"
      break  # Stop rollback
    else
      echo "[WARNING] Step failed but continuing: $step_name"
      # Continue to next step
    fi
  fi
done
```

### Reverse Order Pattern

**Best Practice:** Rollback in reverse order of creation.

```yaml
# Creation order:
# 1. VNet
# 2. Subnet
# 3. NSG

# Rollback order (reverse):
rollback:
  enabled: true
  steps:
    - name: "Delete NSG"        # Step 3 (created last)
      command: "az network nsg delete ..."
      continue_on_error: false

    - name: "Delete Subnet"     # Step 2
      command: "az network vnet subnet delete ..."
      continue_on_error: false

    - name: "Delete VNet"       # Step 1 (created first)
      command: "az network vnet delete ..."
      continue_on_error: false
```

---

## Rollback Examples

### Example 1: VNet Deletion (Simple)

**Scenario:** Single resource cleanup.

```yaml
rollback:
  enabled: true
  steps:
    - name: "Delete Virtual Network"
      description: "Remove the VNet and all associated resources"
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
[SUCCESS] VNet deleted successfully
[ROLLBACK] Complete
```

---

### Example 2: Storage Account (Multi-Step)

**Scenario:** Delete file shares before storage account.

```yaml
rollback:
  enabled: true
  steps:
    - name: "Delete File Shares"
      description: "Remove all file shares from storage account"
      command: |
        az storage share delete \
          --account-name "{{STORAGE_ACCOUNT_NAME}}" \
          --name "{{STORAGE_SHARE_NAME}}"
      continue_on_error: true  # May not exist

    - name: "Delete Storage Account"
      description: "Remove the storage account"
      command: |
        az storage account delete \
          --resource-group "{{AZURE_RESOURCE_GROUP}}" \
          --name "{{STORAGE_ACCOUNT_NAME}}" \
          --yes
      continue_on_error: false  # Must succeed
```

**Execution:**
```
[ROLLBACK] Step 1/2: Delete File Shares
[INFO] Deleting file share: profiles
[SUCCESS] File share deleted

[ROLLBACK] Step 2/2: Delete Storage Account
[INFO] Deleting storage account: avdstorprod
[SUCCESS] Storage account deleted

[ROLLBACK] Complete
```

---

### Example 3: Complex Rollback (AVD Host Pool)

**Scenario:** Multi-tier cleanup with dependencies.

```yaml
rollback:
  enabled: true
  steps:
    - name: "Remove Session Hosts"
      description: "Delete all session hosts from host pool"
      command: |
        az desktopvirtualization hostpool update \
          --resource-group "{{AZURE_RESOURCE_GROUP}}" \
          --name "{{HOST_POOL_NAME}}" \
          --status Unavailable
      continue_on_error: true  # Best effort

    - name: "Delete Application Groups"
      description: "Remove application groups"
      command: |
        az desktopvirtualization applicationgroup delete \
          --resource-group "{{AZURE_RESOURCE_GROUP}}" \
          --name "{{APP_GROUP_NAME}}" \
          --yes
      continue_on_error: true  # May not exist

    - name: "Delete Host Pool"
      description: "Remove the host pool itself"
      command: |
        az desktopvirtualization hostpool delete \
          --resource-group "{{AZURE_RESOURCE_GROUP}}" \
          --name "{{HOST_POOL_NAME}}" \
          --yes
      continue_on_error: false  # Critical
```

**Execution:**
```
[ROLLBACK] Step 1/3: Remove Session Hosts
[INFO] Marking session hosts unavailable
[SUCCESS] Session hosts marked unavailable

[ROLLBACK] Step 2/3: Delete Application Groups
[INFO] Deleting app group: Desktop-AppGroup
[SUCCESS] App group deleted

[ROLLBACK] Step 3/3: Delete Host Pool
[INFO] Deleting host pool: avd-pool-prod
[SUCCESS] Host pool deleted

[ROLLBACK] Complete
```

---

### Example 4: Network Infrastructure (Dependencies)

**Scenario:** Complex network with multiple dependencies.

```yaml
rollback:
  enabled: true
  steps:
    - name: "Detach NSG from Subnet"
      description: "Remove NSG association"
      command: |
        az network vnet subnet update \
          --resource-group "{{AZURE_RESOURCE_GROUP}}" \
          --vnet-name "{{NETWORKING_VNET_NAME}}" \
          --name "{{SUBNET_NAME}}" \
          --network-security-group ""
      continue_on_error: true

    - name: "Delete NSG"
      description: "Remove network security group"
      command: |
        az network nsg delete \
          --resource-group "{{AZURE_RESOURCE_GROUP}}" \
          --name "{{NSG_NAME}}"
      continue_on_error: false

    - name: "Delete Subnet"
      description: "Remove subnet"
      command: |
        az network vnet subnet delete \
          --resource-group "{{AZURE_RESOURCE_GROUP}}" \
          --vnet-name "{{NETWORKING_VNET_NAME}}" \
          --name "{{SUBNET_NAME}}"
      continue_on_error: false

    - name: "Delete VNet"
      description: "Remove virtual network"
      command: |
        az network vnet delete \
          --resource-group "{{AZURE_RESOURCE_GROUP}}" \
          --name "{{NETWORKING_VNET_NAME}}"
      continue_on_error: false
```

---

### Example 5: Entra ID Group (Simple)

**Scenario:** Delete Entra ID group on failure.

```yaml
rollback:
  enabled: true
  steps:
    - name: "Delete Entra ID Group"
      description: "Remove the security group"
      command: |
        GROUP_ID=$(az ad group list \
          --filter "displayName eq '{{ENTRA_GROUP_NAME}}'" \
          --query "[0].id" -o tsv)

        if [ -n "$GROUP_ID" ]; then
          az ad group delete --group "$GROUP_ID"
        fi
      continue_on_error: false
```

---

## Rollback Best Practices

### 1. Reverse Order

**Delete in reverse order of creation:**

```
Create:  A → B → C
Rollback: C → B → A
```

### 2. Dependency Awareness

**Delete dependents before dependencies:**

```yaml
✓ Delete subnet before VNet
✓ Delete NSG before VNet
✗ Delete VNet first (subnet still attached)
```

### 3. Error Tolerance

**Use continue_on_error wisely:**

```yaml
# Critical: Storage account deletion
continue_on_error: false

# Optional: Temp file cleanup
continue_on_error: true
```

### 4. Idempotent Rollback

**Rollback should be safe to run multiple times:**

```yaml
# Check if resource exists before deleting
command: |
  if az network vnet show --name "{{VNET_NAME}}" 2>/dev/null; then
    az network vnet delete --name "{{VNET_NAME}}" --yes
  fi
```

### 5. Logging

**Include clear logging:**

```yaml
command: |
  echo "[ROLLBACK] Deleting VNet: {{VNET_NAME}}"
  az network vnet delete ... --yes
  echo "[ROLLBACK] VNet deleted successfully"
```

---

## Related Documentation

- [Operation Lifecycle](04-operation-lifecycle.md) - When rollback triggers
- [Operation Schema](03-operation-schema.md) - Rollback schema details
- [Best Practices](12-best-practices.md) - Rollback design guidelines

---

**Last Updated:** 2025-12-06
