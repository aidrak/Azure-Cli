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
