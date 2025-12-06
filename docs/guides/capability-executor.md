# Capability Executor Guide

## Overview

The **Capability Executor** (`core/capability-executor.sh`) is the execution engine for capability-based operations in the Azure Infrastructure Toolkit. It provides a structured way to load, validate, and execute operations organized by capabilities.

## Architecture

```
capabilities/
├── compute/
│   ├── capability.yaml          # Capability metadata
│   └── operations/
│       ├── create-vm.yaml       # Operation definition
│       ├── adopt-vm.yaml
│       └── modify-vm.yaml
├── networking/
│   ├── capability.yaml
│   └── operations/
│       └── ...
└── storage/
    ├── capability.yaml
    └── operations/
        └── ...
```

## Key Features

1. **Capability-Based Organization**: Operations grouped by Azure service capabilities
2. **Parameter Resolution**: Merge user params, config variables, and defaults
3. **Type Validation**: String, boolean, number, secret, object, array
4. **Mode Support**: create, adopt, modify, validate, delete
5. **State Integration**: Full integration with state-manager.sh
6. **Executor Integration**: Uses executor.sh for actual execution

## Usage

### Command-Line Interface

```bash
# Execute operation with parameters
./core/capability-executor.sh execute <capability> <operation> [--param value ...]

# List all operations for a capability
./core/capability-executor.sh list <capability>

# Validate operation configuration
./core/capability-executor.sh validate <capability> <operation>

# Show capability metadata
./core/capability-executor.sh show <capability>
```

### Examples

```bash
# Execute a VM creation with parameters
./core/capability-executor.sh execute compute create-vm \
  --vm-name test-vm \
  --vm-size Standard_D2s_v3 \
  --location centralus

# List all compute operations
./core/capability-executor.sh list compute

# Validate storage account operation
./core/capability-executor.sh validate storage create-account

# Show networking capability metadata
./core/capability-executor.sh show networking
```

### Programmatic Usage

```bash
# Source the executor
source core/capability-executor.sh

# Execute operation with JSON params
execute_capability_operation "compute" "create-vm" '{"vm_name": "test-vm", "vm_size": "Standard_D2s_v3"}'

# List operations
list_capability_operations "networking"

# Validate operation
validate_capability_operation "storage" "create-account"

# Load metadata
load_capability_metadata "compute"
```

## Functions Reference

### Core Functions

#### `execute_capability_operation(capability, operation_id, params)`

Execute a capability-based operation.

**Arguments:**
- `capability`: Capability name (e.g., "compute", "networking")
- `operation_id`: Operation identifier (e.g., "create-vm")
- `params`: JSON string with parameters (default: `{}`)

**Returns:**
- `0` on success
- `1` on failure

**Example:**
```bash
execute_capability_operation "compute" "create-vm" '{"vm_name": "test-vm"}'
```

#### `load_capability_metadata(capability)`

Load capability metadata from `capability.yaml`.

**Arguments:**
- `capability`: Capability name

**Returns:** JSON object with capability details

**Example:**
```bash
metadata=$(load_capability_metadata "compute")
echo "$metadata" | jq '.capability.name'
```

#### `list_capability_operations(capability)`

List all operations for a capability.

**Arguments:**
- `capability`: Capability name

**Returns:** JSON array of operations with details

**Example:**
```bash
operations=$(list_capability_operations "networking")
echo "$operations" | jq -r '.[] | .id'
```

#### `validate_capability_operation(capability, operation_id)`

Validate that an operation exists and is properly configured.

**Arguments:**
- `capability`: Capability name
- `operation_id`: Operation identifier

**Returns:**
- `0` if valid
- `1` if invalid

**Example:**
```bash
if validate_capability_operation "storage" "create-account"; then
    echo "Operation is valid"
fi
```

### Parameter Functions

#### `resolve_operation_parameters(operation_yaml, user_params)`

Merge user-provided params with defaults and config variables.

**Arguments:**
- `operation_yaml`: Path to operation YAML file
- `user_params`: JSON string with user parameters (default: `{}`)

**Returns:** JSON object with resolved parameters

**Priority:** user_params > config > default

**Example:**
```bash
params=$(resolve_operation_parameters "operations/create-vm.yaml" '{"vm_name": "test"}')
```

#### `parse_cli_parameters(...args)`

Convert CLI arguments to JSON parameters.

**Arguments:**
- Variable number of CLI arguments (e.g., `--vm-name test-vm --size Standard_D2s_v3`)

**Returns:** JSON object

**Example:**
```bash
params=$(parse_cli_parameters --vm-name test-vm --vm-size Standard_D2s_v3)
# Result: {"vm_name": "test-vm", "vm_size": "Standard_D2s_v3"}
```

#### `validate_parameter_types(parameter_schema, user_params)`

Validate parameter types against schema.

**Arguments:**
- `parameter_schema`: JSON schema defining expected types
- `user_params`: JSON with user-provided parameters

**Returns:**
- `0` if all types valid
- `1` if validation fails

**Supported Types:**
- `string`: Text values
- `boolean`: true/false
- `number`: Numeric values
- `secret`: Secure strings (flagged for secure handling)
- `object`: JSON objects
- `array`: JSON arrays

#### `export_parameters_to_env(resolved_params)`

Export parameters as environment variables for template substitution.

**Arguments:**
- `resolved_params`: JSON object with resolved parameters

**Behavior:**
- Parameters exported as `PARAM_<NAME>` (uppercase)
- Example: `{"vm_name": "test"}` → `PARAM_VM_NAME=test`

## Operation YAML Format

### Capability Definition (`capability.yaml`)

```yaml
capability:
  id: "compute"
  name: "Compute Resources"
  description: "VM and compute-related operations"
  version: "1.0.0"

  operations:
    - id: "create-vm"
      name: "Create Virtual Machine"
      mode: "create"
      description: "Create a new VM from scratch"

    - id: "adopt-vm"
      name: "Adopt Existing VM"
      mode: "adopt"
      description: "Adopt an existing VM into management"
```

### Operation Definition (`operations/create-vm.yaml`)

```yaml
operation:
  id: "create-vm"
  name: "Create Virtual Machine"
  mode: "create"                 # create|adopt|modify|validate|delete
  type: "infrastructure"
  resource_type: "virtualMachines"

  duration:
    expected: 300
    timeout: 600
    type: "NORMAL"

  # Parameter definitions
  parameters:
    vm_name:
      type: "string"
      required: true
      description: "Name of the virtual machine"
      # No default - must be provided

    vm_size:
      type: "string"
      required: false
      description: "VM size/SKU"
      default: "Standard_D2s_v3"

    vm_count:
      type: "number"
      required: false
      description: "Number of VMs to create"
      default: 1

    enable_monitoring:
      type: "boolean"
      required: false
      description: "Enable Azure Monitor"
      default: true

    resource_group:
      type: "string"
      required: true
      description: "Resource group name"
      from_config: "AZURE_RESOURCE_GROUP"    # Load from config

    admin_password:
      type: "secret"
      required: true

      description: "Admin password"
      from_config: "ADMIN_PASSWORD"

    tags:
      type: "object"
      required: false
      description: "Resource tags"
      default: {}

  # Prerequisites (optional)
  prerequisites:
    - resource_type: "virtualNetworks"
      name_from_config: "NETWORKING_VNET_NAME"
      resource_group: "{{AZURE_RESOURCE_GROUP}}"

  # Execution steps
  steps:
    - name: "Create VM"
      command: |
        az vm create \
          --name "${PARAM_VM_NAME}" \
          --resource-group "${PARAM_RESOURCE_GROUP}" \
          --size "${PARAM_VM_SIZE}" \
          --admin-password "${PARAM_ADMIN_PASSWORD}" \
          --tags "${PARAM_TAGS}"

  # Rollback steps (optional)
  rollback:
    - name: "Delete VM on failure"
      command: |
        az vm delete \
          --name "${PARAM_VM_NAME}" \
          --resource-group "${PARAM_RESOURCE_GROUP}" \
          --yes
```

## Parameter Resolution Flow

```
1. User provides parameters
   --vm-name test-vm --vm-size Standard_D4s_v3

2. Parse CLI to JSON
   {"vm_name": "test-vm", "vm_size": "Standard_D4s_v3"}

3. Load operation parameters schema
   {
     "vm_name": {"type": "string", "required": true},
     "vm_size": {"type": "string", "default": "Standard_D2s_v3"},
     "resource_group": {"from_config": "AZURE_RESOURCE_GROUP"}
   }

4. Resolve parameters (priority: user > config > default)
   {
     "vm_name": "test-vm",              # from user
     "vm_size": "Standard_D4s_v3",      # from user (overrides default)
     "resource_group": "RG-Azure-VDI-01" # from config
   }

5. Validate types
   ✓ vm_name is string
   ✓ vm_size is string
   ✓ resource_group is string

6. Export to environment
   PARAM_VM_NAME=test-vm
   PARAM_VM_SIZE=Standard_D4s_v3
   PARAM_RESOURCE_GROUP=RG-Azure-VDI-01

7. Execute operation (templates can use ${PARAM_*})
```

## Operation Modes

| Mode | Purpose | Behavior |
|------|---------|----------|
| `create` | Create new resource | Fails if resource exists |
| `adopt` | Adopt existing resource | Brings existing resource under management |
| `modify` | Modify existing resource | Updates resource configuration |
| `validate` | Validate resource state | Checks resource meets requirements |
| `delete` | Delete resource | Removes resource from Azure |

## Integration with Executor

The capability-executor uses `executor.sh` for actual execution:

```bash
# Capability executor prepares parameters and validates
execute_capability_operation() {
    # ... parameter resolution ...
    # ... validation ...

    # Calls executor for actual execution
    execute_operation "$operation_file" "false"
}
```

Benefits:
- Reuses battle-tested execution logic
- Automatic rollback on failure
- Progress tracking and logging
- State management integration

## Error Handling

### Missing Required Parameter

```bash
# Operation requires vm_name
./core/capability-executor.sh execute compute create-vm

# Output:
# [x] ERROR: Required parameter missing: vm_name
```

### Invalid Parameter Type

```bash
# vm_count expects number, got string
./core/capability-executor.sh execute compute create-vm \
  --vm-name test-vm \
  --vm-count "not-a-number"

# Output:
# [x] ERROR: Parameter 'vm_count' must be a number, got: not-a-number
```

### Capability Not Found

```bash
./core/capability-executor.sh list nonexistent-capability

# Output:
# [x] ERROR: Capability not found: nonexistent-capability
```

### Operation File Missing

```bash
./core/capability-executor.sh execute compute nonexistent-operation

# Output:
# [x] ERROR: Operation file not found: .../operations/nonexistent-operation.yaml
```

## Best Practices

### 1. Parameter Naming

Use snake_case for parameter names:
```yaml
parameters:

  vm_name:           # ✓ Good
  vmName:            # ✗ Avoid (camelCase)
  "vm-name":         # ✗ Avoid (kebab-case in YAML)
```

CLI converts kebab-case to snake_case:
```bash
--vm-name test-vm   # → vm_name: "test-vm"
```

### 2. Required vs Optional

Mark parameters as required only if truly necessary:
```yaml
vm_name:
  required: true     # ✓ Must be provided

vm_size:
  required: false    # ✓ Has sensible default
  default: "Standard_D2s_v3"
```

### 3. Config Integration

Use `from_config` for values in `config.yaml`:
```yaml
resource_group:
  from_config: "AZURE_RESOURCE_GROUP"
  required: true
```

### 4. Secrets Handling

Mark sensitive parameters as `secret`:
```yaml
admin_password:
  type: "secret"
  required: true
  from_config: "ADMIN_PASSWORD"  # Don't hardcode!
```

### 5. Type Validation

Always specify parameter types:
```yaml
vm_count:
  type: "number"     # ✓ Validated

vm_name:
  # No type specified → defaults to string
```

## Troubleshooting

### Configuration Not Loaded

```bash
# Error: Config variable not resolved
[x] ERROR: Config variable not found: AZURE_RESOURCE_GROUP

# Solution: Load config before execution
source core/config-manager.sh
load_config
./core/capability-executor.sh execute compute create-vm
```

### Parameter Not Exported

```bash
# Template uses ${PARAM_VM_NAME} but it's empty

# Cause: Parameter resolution failed silently
# Solution: Check parameter name matches exactly (case-sensitive)
```

### Operation Mode Invalid

```bash
# Error: Invalid operation mode
[x] ERROR: Invalid operation mode: update (valid: create adopt modify validate delete)

# Solution: Use valid mode in operation YAML
```

## Advanced Usage

### Custom Parameter Validation

Extend `validate_parameter_types()` for custom validation:

```bash
# In your wrapper script
source core/capability-executor.sh

custom_validate() {
    local params="$1"

    # Add custom validation logic
    local vm_size=$(echo "$params" | jq -r '.vm_size')

    if [[ ! "$vm_size" =~ ^Standard_D[0-9]+s_v[0-9]+$ ]]; then
        log_error "Invalid VM size format: $vm_size"
        return 1
    fi

    return 0
}

# Use in execution flow
params=$(resolve_operation_parameters "$op_file" "$user_params")
custom_validate "$params" || exit 1
execute_capability_operation "compute" "create-vm" "$params"
```

### Batch Execution

```bash
# Execute multiple operations
for operation in create-vm configure-vm enable-monitoring; do
    log_info "Executing: $operation"
    execute_capability_operation "compute" "$operation" "$params"
done
```

### Dynamic Parameter Generation

```bash
# Generate parameters programmatically
vm_count=5

for i in $(seq 1 $vm_count); do
    params=$(jq -n \
        --arg name "vm-${i}" \
        --arg size "Standard_D2s_v3" \
        '{vm_name: $name, vm_size: $size}')

    execute_capability_operation "compute" "create-vm" "$params"
done
```

## See Also

- [Executor Guide](executor-overview.md) - Operation execution engine
- [State Manager Guide](state-manager-overview.md) - State tracking
- [Query Engine](query-engine.md) - Resource queries
- [Configuration](../config.yaml) - System configuration

---

**Last Updated**: 2025-12-06
**Version**: 1.0.0
**Status**: Production Ready
