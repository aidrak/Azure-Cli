# Workflows Directory

## Overview

The workflows directory contains end-to-end workflow definitions that orchestrate multiple capabilities to achieve complete deployment scenarios. Workflows combine operations from multiple capabilities in a coordinated sequence with proper dependency management.

## Purpose

While capabilities provide focused, single-domain operations (e.g., creating a VM, configuring a network), workflows provide complete deployment scenarios that combine multiple capabilities to achieve business objectives (e.g., "deploy complete AVD environment").

## Workflow Structure

Each workflow is defined in a YAML file with the following structure:

```yaml
workflow:
  id: "unique-workflow-id"
  name: "Human-Readable Workflow Name"
  description: "Detailed description of what this workflow accomplishes"
  version: "1.0.0"

  # Capabilities used by this workflow
  required_capabilities:
    - compute
    - networking
    - storage
    - identity
    - avd

  # Input parameters required from user
  parameters:
    - name: "parameter_name"
      type: "string|number|boolean|array|object"
      description: "What this parameter controls"
      required: true|false
      default: "default_value"

  # Workflow steps (operations to execute)
  steps:
    - id: "step-1"
      capability: "capability-name"
      operation: "operation-name"
      inputs: { }
      depends_on: []

  # Output values from workflow
  outputs:
    - name: "output_name"
      value: "{{ outputs.step-id.field }}"
      description: "What this output represents"
```

## Common Workflows

### Complete AVD Deployment

**File:** `deploy-avd-complete.yaml`

Deploys a complete AVD environment from scratch:
1. Create resource group
2. Create virtual network and subnets
3. Create NSGs with security rules
4. Create storage account and file shares
5. Create Entra ID groups
6. Create managed identities
7. Assign RBAC roles
8. Create AVD host pool
9. Create application groups
10. Create workspace
11. Deploy session hosts
12. Configure FSLogix
13. Create scaling plan

### Add Session Hosts

**File:** `add-session-hosts.yaml`

Adds new session hosts to existing host pool:
1. Validate host pool exists
2. Create NICs in existing subnet
3. Deploy VMs with AVD image
4. Domain join VMs
5. Install AVD agent
6. Register with host pool
7. Configure FSLogix

### Disaster Recovery Setup

**File:** `setup-dr.yaml`

Configures disaster recovery for AVD:
1. Create resources in secondary region
2. Configure geo-redundant storage
3. Set up VNET peering
4. Configure backup policies
5. Create runbooks for failover

## Workflow vs Module vs Operation

| Concept | Scope | Purpose | Example |
|---------|-------|---------|---------|
| **Workflow** | End-to-end scenario | Complete business objective | Deploy AVD environment |
| **Capability** | Domain/service | Group related resources | Compute, Networking |
| **Operation** | Single action | Specific resource task | Create VM, Create subnet |

## Creating New Workflows

### 1. Identify Scenario

Define clear business objective:
- What is the complete end state?
- What capabilities are required?
- What are the dependencies?

### 2. Design Steps

List all operations needed:
- Group by capability
- Identify dependencies
- Plan for error handling

### 3. Define Parameters

What inputs are needed:
- Environment configuration
- Resource naming
- Sizing/performance
- Security settings

### 4. Map Outputs

What information is produced:
- Resource IDs
- Connection strings
- Access URLs
- Configuration values

### 5. Test and Validate

Verify workflow:
- Test in clean environment
- Validate idempotency
- Test failure scenarios
- Document prerequisites

## Workflow Best Practices

### Design Principles

1. **Idempotent**: Can be run multiple times safely
2. **Resumable**: Can continue after failure
3. **Atomic**: Each step is independent
4. **Documented**: Clear purpose and usage

### Error Handling

1. **Validation Steps**: Check prerequisites before execution
2. **Rollback Strategy**: Define cleanup for failures
3. **State Tracking**: Record progress for resume
4. **Clear Errors**: Provide actionable error messages

### Parameter Design

1. **Sensible Defaults**: Minimize required inputs
2. **Validation**: Check parameter values early
3. **Documentation**: Explain each parameter
4. **Grouping**: Organize related parameters

### Dependency Management

1. **Explicit Dependencies**: Use `depends_on` clearly
2. **Parallel Execution**: Allow independent steps to run concurrently
3. **Output Chaining**: Pass outputs between steps
4. **Conditional Steps**: Support optional features

## Example: Simple Workflow

```yaml
workflow:
  id: "create-vm-with-networking"
  name: "Create VM with Complete Network Setup"
  description: "Creates a virtual machine with virtual network, subnet, NSG, and public IP"
  version: "1.0.0"

  required_capabilities:
    - networking
    - compute

  parameters:
    - name: "vm_name"
      type: "string"
      required: true
    - name: "vm_size"
      type: "string"
      default: "Standard_D2s_v5"

  steps:
    # Step 1: Create virtual network
    - id: "create-vnet"
      capability: "networking"
      operation: "vnet-create"
      inputs:
        vnet_name: "{{ params.vm_name }}-vnet"
        address_space: "10.0.0.0/16"

    # Step 2: Create subnet
    - id: "create-subnet"
      capability: "networking"
      operation: "subnet-create"
      depends_on: ["create-vnet"]
      inputs:
        vnet_name: "{{ outputs.create-vnet.vnet_name }}"
        subnet_name: "default"
        address_prefix: "10.0.1.0/24"

    # Step 3: Create NSG
    - id: "create-nsg"
      capability: "networking"
      operation: "nsg-create"
      inputs:
        nsg_name: "{{ params.vm_name }}-nsg"

    # Step 4: Create NIC
    - id: "create-nic"
      capability: "networking"
      operation: "nic-create"
      depends_on: ["create-subnet", "create-nsg"]
      inputs:
        nic_name: "{{ params.vm_name }}-nic"
        subnet_id: "{{ outputs.create-subnet.subnet_id }}"
        nsg_id: "{{ outputs.create-nsg.nsg_id }}"

    # Step 5: Create VM
    - id: "create-vm"
      capability: "compute"
      operation: "vm-create"
      depends_on: ["create-nic"]
      inputs:
        vm_name: "{{ params.vm_name }}"
        vm_size: "{{ params.vm_size }}"
        nic_id: "{{ outputs.create-nic.nic_id }}"

  outputs:
    - name: "vm_id"
      value: "{{ outputs.create-vm.vm_id }}"
    - name: "private_ip"
      value: "{{ outputs.create-nic.private_ip }}"
```

## Testing Workflows

### Validation Testing

```bash
# Validate workflow syntax
./tools/validate-workflow.sh workflows/deploy-avd-complete.yaml

# Dry-run workflow (no changes)
./core/engine.sh workflow deploy-avd-complete --dry-run

# Execute workflow
./core/engine.sh workflow deploy-avd-complete
```

### Test Scenarios

1. **Clean Deployment**: Test in empty resource group
2. **Idempotency**: Run same workflow twice
3. **Partial Failure**: Interrupt and resume
4. **Parameter Validation**: Test with invalid inputs
5. **Cleanup**: Verify all resources removed

## Related Documentation

- [Execution Engine](../docs/02-execution-engine.md) - How workflows are executed
- [Dependency Resolver](../docs/dependency-resolver-guide.md) - Dependency management
- [Module Structure](../docs/04-module-structure.md) - Operation format
- [State Management](../docs/05-state-and-logging.md) - State tracking

## Planned Workflows

Future workflows to implement:

- `deploy-avd-complete.yaml` - Complete AVD deployment
- `add-session-hosts.yaml` - Add hosts to existing pool
- `scale-host-pool.yaml` - Scale up/down session hosts
- `setup-dr.yaml` - Configure disaster recovery
- `migrate-profiles.yaml` - Migrate user profiles
- `update-images.yaml` - Update session host images
- `configure-monitoring.yaml` - Set up monitoring and alerts
- `implement-backup.yaml` - Configure backup policies
