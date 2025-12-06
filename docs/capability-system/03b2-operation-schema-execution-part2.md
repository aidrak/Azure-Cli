
---

## Validation

### Structure

```yaml
validation:
  enabled: boolean
  checks:
    - type: "check_type"
      description: "Check description"
      # Type-specific fields
```

### Check Types

| Type | Purpose | Parameters |
|------|---------|-----------|
| `resource_exists` | Verify resource exists in Azure | `resource_type`, `resource_name` |
| `provisioning_state` | Verify provisioning state | `expected` (usually "Succeeded") |
| `property_equals` | Verify property value | `property`, `expected` |
| `group_exists` | Verify Entra ID group | `group_name` |
| `group_type` | Verify group type | `expected` (e.g., "Security") |
| `custom` | Execute custom verification | `command` returns 0 for success |

### Examples

**Resource Exists:**
```yaml
- type: "resource_exists"
  resource_type: "Microsoft.Network/virtualNetworks"
  resource_name: "{{NETWORKING_VNET_NAME}}"
  description: "VNet exists"
```

**Provisioning State:**
```yaml
- type: "provisioning_state"
  expected: "Succeeded"
  description: "VNet provisioned successfully"
```

**Property Equals:**
```yaml
- type: "property_equals"
  property: "sku.name"
  expected: "Premium_LRS"
  description: "Storage SKU is Premium_LRS"
```

**Custom Check:**
```yaml
- type: "custom"
  command: |
    $count = az vm list --query "length([])" -o tsv
    if [ "$count" -gt 0 ]; then exit 0; else exit 1; fi
  description: "At least one VM exists"
```

---

## Rollback

### Structure

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

### Step Fields

| Field | Type | Purpose |
|-------|------|---------|
| `name` | string | Step identifier |
| `description` | string | Step description |
| `command` | string | Command to execute |
| `continue_on_error` | boolean | Continue even if command fails |

### Examples

**Simple Rollback:**
```yaml
rollback:
  enabled: true
  steps:
    - name: "Delete Virtual Network"
      description: "Remove the VNet and associated resources"
      command: |
        az network vnet delete \
          --resource-group "{{AZURE_RESOURCE_GROUP}}" \
          --name "{{NETWORKING_VNET_NAME}}" \
          --yes
      continue_on_error: false
```

**Multi-Step Rollback:**
```yaml
rollback:
  enabled: true
  steps:
    - name: "Delete File Shares"
      description: "Remove all file shares"
      command: |
        az storage share delete \
          --account-name "{{STORAGE_ACCOUNT_NAME}}" \
          --name "{{STORAGE_SHARE_NAME}}"
      continue_on_error: true

    - name: "Delete Storage Account"
      description: "Remove the storage account"
      command: |
        az storage account delete \
          --resource-group "{{AZURE_RESOURCE_GROUP}}" \
          --name "{{STORAGE_ACCOUNT_NAME}}" \
          --yes
      continue_on_error: false
```

---

## Fixes

### Structure

```yaml
fixes:
  - issue_code: "ISSUE_CODE"
    description: "Issue description"
    applied_at: "2025-12-06T14:23:45Z"
    fix_command: |
      # Fix command
    retry_count: integer
    success: boolean
```

### Fields

| Field | Type | Purpose |
|-------|------|---------|
| `issue_code` | string | Unique identifier for the issue |
| `description` | string | Human-readable description |
| `applied_at` | string | ISO 8601 timestamp when fix was applied |
| `fix_command` | string | Command to execute for fix |
| `retry_count` | integer | Number of times to retry |
| `success` | boolean | Whether fix was successful |

### Examples

```yaml
fixes:
  - issue_code: "VNET_CREATION_TIMEOUT"
    description: "VNet creation timed out due to DNS resolution"
    applied_at: "2025-12-06T14:23:45Z"
    fix_command: |
      az network vnet update \
        --resource-group "{{AZURE_RESOURCE_GROUP}}" \
        --name "{{NETWORKING_VNET_NAME}}" \
        --set "dnsSetting.dnsServers=@['8.8.8.8','8.8.4.4']"
    retry_count: 2
    success: true
```

---

## Related Documentation

- [Architecture Overview](01-architecture-overview.md) - System design principles
- [Operation Lifecycle](04-operation-lifecycle.md) - How operations execute
- [Best Practices](12-best-practices.md) - Schema design guidelines

---

**Last Updated:** 2025-12-06
