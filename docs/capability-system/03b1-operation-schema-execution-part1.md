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
