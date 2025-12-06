# Operation Schema Reference

**Complete YAML schema specification for capability operations**

## Table of Contents

1. [Complete Schema Structure](#complete-schema-structure)
2. [Identity and Metadata](#identity-and-metadata)
3. [Classification](#classification)
4. [Duration](#duration)
5. [Parameters](#parameters)
6. [Prerequisites](#prerequisites)
7. [Idempotency](#idempotency)
8. [Template](#template)
9. [Validation](#validation)
10. [Rollback](#rollback)
11. [Fixes](#fixes)

---

## Complete Schema Structure

Every operation defines a YAML document with this structure:

```yaml
operation:
  # Identity and metadata
  id: string                          # Unique operation ID (kebab-case)
  name: string                        # Human-readable name
  description: string                 # Detailed operation description

  # Classification
  capability: string                  # Domain: networking|storage|identity|compute|avd|management
  operation_mode: string              # CRUD: create|read|update|delete|configure|validate
  resource_type: string               # Azure ARM resource type (Microsoft.Network/virtualNetworks)

  # Duration and timeout
  duration:
    expected: integer                 # Expected execution time (seconds)
    timeout: integer                  # Maximum allowed time (seconds)
    type: string                      # FAST (<5min) | NORMAL (5-10min) | WAIT (10+min)

  # Parameters
  parameters:
    required: [...]                   # Must be provided by user
    optional: [...]                   # Optional with defaults

  # Pre and post execution
  prerequisites:
    operations: [...]                 # Required prior operations
    resources: [...]                  # Required existing resources

  # Idempotency
  idempotency:
    enabled: boolean                  # Whether idempotency is checked
    check_command: string             # Command to verify existence
    skip_if_exists: boolean           # Skip if resource exists

  # Execution template
  template:
    type: string                      # powershell-local|powershell-remote|bash-local
    command: string                   # Full script/command

  # Validation after execution
  validation:
    enabled: boolean
    checks: [...]                     # Post-execution verification checks

  # Rollback on failure
  rollback:
    enabled: boolean
    steps: [...]                      # Cleanup procedures

  # Self-healing
  fixes: [...]                        # Applied fixes with timestamps
```

---

## Identity and Metadata

### Field Specifications

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | Yes | Unique operation identifier (kebab-case, e.g., "vnet-create") |
| `name` | string | Yes | Human-readable operation name |
| `description` | string | Yes | Detailed operation description (2-3 sentences) |

### Field Rules

**id:**
- MUST use kebab-case format
- MUST be unique across all capabilities
- MUST NOT include numeric prefixes
- SHOULD be descriptive and action-oriented

**Examples:**
```yaml
✓ id: "vnet-create"
✓ id: "storage-account-configure"
✓ id: "golden-image-install-apps"
✗ id: "01-create-vnet" (numeric prefix)
✗ id: "create_vnet" (snake_case)
✗ id: "CreateVNet" (PascalCase)
```

**name:**
- MUST be human-readable
- SHOULD use title case
- SHOULD be 3-8 words maximum

**Examples:**
```yaml
✓ name: "Create Virtual Network"
✓ name: "Configure Storage Account Security"
✗ name: "VNet" (too short)
✗ name: "This operation creates a virtual network..." (too long)
```

**description:**
- MUST be 2-3 sentences
- MUST describe what the operation does
- SHOULD mention key parameters or features

**Examples:**
```yaml
✓ description: "Create Azure VNet with configured address space, optional DNS servers, and region-specific deployment. Supports custom DNS and service endpoint configuration."

✗ description: "Creates VNet" (too short, not descriptive)
```

---

## Classification

### Field Specifications

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `capability` | string | Yes | Domain: `networking`, `storage`, `identity`, `compute`, `avd`, `management`, `test-capability` |
| `operation_mode` | string | Yes | Operation type: `create`, `read`, `update`, `delete`, `configure`, `validate` |
| `resource_type` | string | Yes | Azure ARM resource type (e.g., "Microsoft.Network/virtualNetworks") |

### Valid Values

**capability:**
```yaml
- networking       # Network infrastructure
- storage          # Storage accounts, file shares
- identity         # Entra ID, RBAC
- compute          # VMs, images, disks
- avd              # Azure Virtual Desktop
- management       # Resource groups, governance
- test-capability  # Testing operations
```

**operation_mode:**
```yaml
- create:    # Create new resource
- read:      # Query/retrieve resource information
- update:    # Modify existing resource
- delete:    # Remove resource
- configure: # Configure/customize resource
- validate:  # Verify resource state/configuration
```

**resource_type:**
Must be a valid Azure ARM resource type:
```yaml
# Networking
"Microsoft.Network/virtualNetworks"
"Microsoft.Network/networkSecurityGroups"
"Microsoft.Network/publicIPAddresses"

# Storage
"Microsoft.Storage/storageAccounts"

# Compute
"Microsoft.Compute/virtualMachines"
"Microsoft.Compute/images"

# AVD
"Microsoft.DesktopVirtualization/hostPools"
"Microsoft.DesktopVirtualization/workspaces"

# Identity
"Microsoft.Graph/groups"
"Microsoft.Authorization/roleAssignments"

# Management
"Microsoft.Resources/resourceGroups"
```

### Examples

```yaml
# Networking operation
capability: "networking"
operation_mode: "create"
resource_type: "Microsoft.Network/virtualNetworks"

# Storage operation
capability: "storage"
operation_mode: "configure"
resource_type: "Microsoft.Storage/storageAccounts"

# Identity operation
capability: "identity"
operation_mode: "create"
resource_type: "Microsoft.Graph/groups"
```

---

## Duration

### Field Specifications

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `duration.expected` | integer | Yes | Expected execution time in seconds |
| `duration.timeout` | integer | Yes | Maximum allowed time in seconds |
| `duration.type` | string | Yes | Duration category: `FAST`, `NORMAL`, or `WAIT` |

### Duration Type Guidelines

```yaml
FAST:   <  5 minutes   (300 seconds)
  Examples:
    - Group creation (30s)
    - NSG rules (60s)
    - RBAC assignments (45s)

NORMAL: 5-10 minutes   (300-600 seconds)
  Examples:
    - Storage account (90s)
    - DNS zone (120s)
    - Host pool (120s)

WAIT:   > 10 minutes   (600+ seconds)
  Examples:
    - VM creation (420s)
    - VPN gateway (1200s)
    - Golden image pipeline (3600s)
```

### Best Practices

**Setting Expected Time:**
- Base on actual testing in target environment
- Add 20% buffer for network variance
- Consider Azure region performance differences

**Setting Timeout:**
- Typically 2-3x expected time
- FAST operations: 5 minutes max
- NORMAL operations: 10 minutes max
- WAIT operations: 15-30 minutes

**Examples:**
```yaml
# Fast operation (group creation)
duration:
  expected: 30
  timeout: 300
  type: "FAST"

# Normal operation (storage account)
duration:
  expected: 90
  timeout: 600
  type: "NORMAL"

# Wait operation (VM creation)
duration:
  expected: 420
  timeout: 900
  type: "WAIT"
```

---

## Parameters

### Structure

Parameters are split into required and optional:

```yaml
parameters:
  required:
    - name: "parameter_name"
      type: "string|integer|boolean|array"
      description: "Parameter description"
      default: "{{PLACEHOLDER}}"
      sensitive: false
      validation_regex: "optional_regex"
      validation_enum: ["value1", "value2"]

  optional:
    - name: "optional_parameter"
      type: "string"
      description: "Optional parameter description"
      default: "default_value"
      sensitive: false
```

### Parameter Types

**String Parameters:**
```yaml
- name: "vnet_name"
  type: "string"
  description: "Name of the virtual network"
  default: "{{NETWORKING_VNET_NAME}}"
  sensitive: false
```

**Integer Parameters:**
```yaml
- name: "max_sessions"
  type: "integer"
  description: "Maximum sessions per host"
  default: 10
  validation_regex: "^[1-9][0-9]{0,2}$"  # 1-999
```

**Boolean Parameters:**
```yaml
- name: "enable_secure_boot"
  type: "boolean"
  description: "Enable Secure Boot"
  default: true
```

**Array Parameters:**
```yaml
- name: "address_space"
  type: "string"
  description: "Address space (space-separated)"
  default: "10.0.0.0/16 10.1.0.0/16"
```

### Parameter Features

**default:**
- Provides default value
- Supports {{PLACEHOLDER}} syntax for variable substitution
- Required for all parameters

**sensitive:**
- If true, value is masked in logs
- Use for passwords, secrets, API keys
- Defaults to false

**validation_regex:**
- Optional regex pattern for validation
- Validates parameter value before execution
- Example: `^[a-z0-9-]{3,24}$` for storage account names

**validation_enum:**
- Optional list of allowed values
- Validates parameter is in allowed list
- Example: `["Standard_LRS", "Premium_LRS"]`

### Placeholder Syntax

**Format:** `{{VARIABLE_NAME}}`

**Rules:**
1. Placeholders are replaced at execution time
2. Derived from `config.yaml` variables
3. Case-sensitive (e.g., `{{VNET_NAME}}` ≠ `{{vnet_name}}`)
4. Supports nested paths: `{{PATH.TO.VALUE}}`

**Example from config.yaml:**
```yaml
networking:
  vnet:
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
- [Operation Lifecycle](04-operation-lifecycle.md) - How operations execute
- [Best Practices](12-best-practices.md) - Schema design guidelines

---

**Last Updated:** 2025-12-06
