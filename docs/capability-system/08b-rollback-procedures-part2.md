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
