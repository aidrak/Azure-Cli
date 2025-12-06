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
