  [ERROR] Cannot configure non-existent storage account
```

---

## Real Operation Examples

### Example 1: VNet Creation (Create Only)

**Scenario:** Create VNet only if it doesn't exist.

```yaml
operation:
  id: "vnet-create"
  name: "Create Virtual Network"
  
idempotency:
  enabled: true
  check_command: |
    az network vnet show \
      --resource-group "{{AZURE_RESOURCE_GROUP}}" \
      --name "{{NETWORKING_VNET_NAME}}" \
      --output none 2>/dev/null
  skip_if_exists: true
```

**Behavior:**
- First run: VNet created
- Subsequent runs: Skipped (VNet already exists)
- Safe to retry after failures

---

### Example 2: Storage Account (Create with Config)

**Scenario:** Create storage account if missing, skip if exists.

```yaml
operation:
  id: "storage-account-create"
  name: "Create Storage Account"
  
idempotency:
  enabled: true
  check_command: |
    az storage account show \
      --resource-group "{{AZURE_RESOURCE_GROUP}}" \
      --name "{{STORAGE_ACCOUNT_NAME}}" \
      --output none 2>/dev/null
  skip_if_exists: true
```

**Behavior:**
- Checks for storage account by name
- Skips if found
- Creates if missing

---

### Example 3: Entra ID Group (Idempotent Creation)

**Scenario:** Create group, handling duplicate names gracefully.

```yaml
operation:
  id: "group-create"
  name: "Create Entra ID Group"
  
idempotency:
  enabled: true
  check_command: |
    az ad group list \
      --filter "displayName eq '{{ENTRA_GROUP_USERS_STANDARD}}'" \
      --query "[0].id" -o tsv 2>/dev/null
  skip_if_exists: true
```

**Behavior:**
- Queries for group by display name
- Exits 0 if group found (has ID)
- Exits non-zero if query returns empty
- Skips creation if group exists

---

### Example 4: VM Extension (Update if Exists)

**Scenario:** Add or update VM extension.

```yaml
operation:
  id: "vm-extension-add"
  name: "Add VM Extension"
  
idempotency:
  enabled: true
  check_command: |
    az vm extension show \
      --resource-group "{{AZURE_RESOURCE_GROUP}}" \
      --vm-name "{{VM_NAME}}" \
      --name "{{EXTENSION_NAME}}" \
      --output none 2>/dev/null
  skip_if_exists: false
```

**Behavior:**
- Checks if extension exists
- Even if exists, proceeds to update
- Updates extension configuration

---

### Example 5: Host Pool Update (Always Run)

**Scenario:** Update host pool settings (always execute).

```yaml
operation:
  id: "hostpool-update"
  name: "Update Host Pool Settings"
  
idempotency:
  enabled: true
  check_command: |
    az desktopvirtualization hostpool show \
      --resource-group "{{AZURE_RESOURCE_GROUP}}" \
      --name "{{HOST_POOL_NAME}}" \
      --output none 2>/dev/null
  skip_if_exists: false
```

**Behavior:**
- Verifies host pool exists
- Always proceeds to update
- Fails if host pool missing (update requires existing resource)

---

## Design Patterns

### Pattern 1: Existence Check Only

**When to use:** Simple resource creation.

```yaml
idempotency:
  enabled: true
  check_command: |
    az resource show \
      --resource-type "Microsoft.Network/virtualNetworks" \
      --name "{{RESOURCE_NAME}}" \
      --output none 2>/dev/null
  skip_if_exists: true
```

### Pattern 2: Query by Filter

**When to use:** Resources identified by properties (groups, tags).

```yaml
idempotency:
  enabled: true
  check_command: |
    az ad group list \
      --filter "displayName eq '{{GROUP_NAME}}'" \
      --query "[0].id" -o tsv 2>/dev/null | grep -q .
  skip_if_exists: true
```

### Pattern 3: Multi-Step Check

**When to use:** Complex validation required.

```yaml
idempotency:
  enabled: true
  check_command: |
    # Check resource exists AND is in correct state
    az resource show \
      --name "{{RESOURCE_NAME}}" \
      --query "provisioningState" -o tsv 2>/dev/null | grep -q "Succeeded"
  skip_if_exists: true
```

### Pattern 4: Disabled for Always-Run

**When to use:** Operations that should always execute.

```yaml
idempotency:
  enabled: false
  # No check_command needed
```

---

## Related Documentation

- [Operation Lifecycle](04-operation-lifecycle.md) - Where idempotency fits in execution
- [Operation Schema](03-operation-schema.md) - Idempotency schema details
- [Best Practices](12-best-practices.md) - Idempotency design guidelines

---

**Last Updated:** 2025-12-06
