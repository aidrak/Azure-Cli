    name: "avd-vnet-prod"
    address_space: ["10.0.0.0/16"]
```

**Placeholder mapping (environment variable format):**
```
{{NETWORKING_VNET_NAME}}           → networking.vnet.name
{{NETWORKING_VNET_ADDRESS_SPACE}}  → networking.vnet.address_space
```

---

## Prerequisites

### Structure

```yaml
prerequisites:
  operations:
    - "operation-id-1"
    - "operation-id-2"
  resources:
    - type: "Microsoft.Network/virtualNetworks"
      name: "{{NETWORKING_VNET_NAME}}"
    - type: "Microsoft.Resources/resourceGroups"
      name: "{{AZURE_RESOURCE_GROUP}}"
```

### Fields

**operations:**
- List of operation IDs that must complete first
- Engine ensures these run before current operation
- Used for dependency resolution

**resources:**
- List of Azure resources that must exist
- Engine can validate before execution
- Each resource has `type` and `name`

### Examples

```yaml
# Host pool requires resource group and VNet
prerequisites:
  operations:
    - "resource-group-create"
    - "vnet-create"
  resources:
    - type: "Microsoft.Resources/resourceGroups"
      name: "{{AZURE_RESOURCE_GROUP}}"
    - type: "Microsoft.Network/virtualNetworks"
      name: "{{NETWORKING_VNET_NAME}}"
```

---

## Idempotency

### Structure

```yaml
idempotency:
  enabled: boolean
  check_command: string
  skip_if_exists: boolean
```

### Fields

| Field | Type | Purpose |
|-------|------|---------|
| `enabled` | boolean | Whether to check for existing resource |
| `check_command` | string | Command that returns 0 if exists, non-zero if missing |
| `skip_if_exists` | boolean | Skip execution if resource already exists |

### Examples

**VNet Creation:**
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

**Storage Account:**
```yaml
idempotency:
  enabled: true
  check_command: |
    az storage account show \
      --resource-group "{{AZURE_RESOURCE_GROUP}}" \
      --name "{{STORAGE_ACCOUNT_NAME}}" \
      --output none 2>/dev/null
  skip_if_exists: true
```

**Entra ID Group:**
```yaml
idempotency:
  enabled: true
  check_command: |
    az ad group list \
      --filter "displayName eq '{{ENTRA_GROUP_USERS_STANDARD}}'" \
      --query "[0].id" -o tsv 2>/dev/null
  skip_if_exists: true
```

---

## Template

### Structure

```yaml
template:
  type: "powershell-local|powershell-remote|bash-local"
  command: |
    # Script content
```

### Valid Template Types

**powershell-local:**
- PowerShell script executed on local machine
- Default for most operations
- Uses `pwsh` command

**powershell-remote:**
- PowerShell script executed on Azure VM
- Uses `az vm run-command invoke`
- For VM customization (golden image)

**bash-local:**
- Bash script executed on local machine
- For CLI-only operations
- Uses `/bin/bash`

### Examples

**PowerShell Local:**
```yaml
template:
  type: "powershell-local"
  command: |
    cat > /tmp/vnet-create-wrapper.ps1 << 'PSWRAPPER'
    Write-Host "[START] VNet creation..."
    az network vnet create `
      --resource-group "{{AZURE_RESOURCE_GROUP}}" `
      --name "{{NETWORKING_VNET_NAME}}" `
      --location "{{AZURE_LOCATION}}"
    PSWRAPPER
    pwsh -NoProfile -NonInteractive -File /tmp/vnet-create-wrapper.ps1
    rm -f /tmp/vnet-create-wrapper.ps1
```

**PowerShell Remote:**
```yaml
template:
  type: "powershell-remote"
  command: |
    # Runs on Azure VM
    Write-Host "Installing applications..."
    choco install vlc -y
```

**Bash Local:**
```yaml
template:
  type: "bash-local"
  command: |
    az network vnet create \
      --resource-group "{{AZURE_RESOURCE_GROUP}}" \
      --name "{{NETWORKING_VNET_NAME}}" \
      --location "{{AZURE_LOCATION}}"
```


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
- [Operation Lifecycle](04-04a1-operation-lifecycle-phases1-2.md) - How operations execute
- [Best Practices](12-best-practices.md) - Schema design guidelines

---

**Last Updated:** 2025-12-06
