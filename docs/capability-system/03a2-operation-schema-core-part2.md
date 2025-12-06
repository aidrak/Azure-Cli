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
