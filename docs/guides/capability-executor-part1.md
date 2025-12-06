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
