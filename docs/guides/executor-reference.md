  resource_name: "${STORAGE_ACCOUNT_NAME}"

prerequisites:
  - resource_type: "Microsoft.Storage/storageAccounts"
    name_from_config: "STORAGE_ACCOUNT_NAME"

steps:
  - name: "Delete storage account"
    command: "az storage account delete --name ${STORAGE_ACCOUNT_NAME} --resource-group ${AZURE_RESOURCE_GROUP} --yes"

rollback:
  # Note: Cannot restore deleted storage account
  # Rollback would require recreation from backup
  - name: "Log deletion for audit"
    command: "echo 'Storage account ${STORAGE_ACCOUNT_NAME} deleted - manual recreation required' >> ${PROJECT_ROOT}/artifacts/deletion-audit.log"
```

---

## API Reference

### Functions

#### `execute_operation(yaml_file, [force_mode])`

Execute an operation defined in YAML.

**Parameters**:
- `yaml_file` (string): Path to operation YAML file
- `force_mode` (boolean, optional): Skip prerequisite validation (default: `false`)

**Returns**: Exit code 0 on success, 1 on failure

**Example**:
```bash
execute_operation "operations/create-vm.yaml" "false"
```

#### `dry_run(yaml_file)`

Preview operation without executing.

**Parameters**:
- `yaml_file` (string): Path to operation YAML file

**Returns**: Exit code 0 on success, 1 on parse error

**Example**:
```bash
dry_run "operations/create-vm.yaml"
```

#### `execute_with_rollback(yaml_file, [force_mode])`

Main entry point - loads config and executes operation.

**Parameters**:
- `yaml_file` (string): Path to operation YAML file
- `force_mode` (boolean, optional): Skip prerequisite validation

**Returns**: Exit code 0 on success, 1 on failure

**Example**:
```bash
execute_with_rollback "operations/create-vm.yaml" "true"
```

#### `validate_prerequisites(yaml_file, operation_exec_id)`

Validate all prerequisites exist.

**Parameters**:
- `yaml_file` (string): Path to operation YAML file
- `operation_exec_id` (string): Unique execution ID for logging

**Returns**: Exit code 0 if all prerequisites exist, 1 otherwise

#### `execute_rollback(yaml_file, operation_exec_id, failed_step_index)`

Execute rollback steps in reverse order.

**Parameters**:
- `yaml_file` (string): Path to operation YAML file
- `operation_exec_id` (string): Unique execution ID
- `failed_step_index` (integer): Index of step that failed

**Returns**: Exit code 0 (rollback is best-effort)

### CLI Usage

```bash
./core/executor.sh <command> <operation-file> [options]

Commands:
  execute <file>       Execute operation with automatic rollback on failure
  dry-run <file>       Show what would be executed without making changes
  force <file>         Execute without prerequisite validation

Options:
  -h, --help          Show help message
```

---

## Best Practices

### 1. Design Operations

- **Single Responsibility**: One operation per YAML (e.g., don't mix VM creation with networking)
- **Idempotent Steps**: Use Azure CLI flags like `--no-wait` carefully
- **Clear Naming**: Use descriptive operation IDs and step names

### 2. Prerequisites

- **Minimal Prerequisites**: Only list direct dependencies
- **Use Config Variables**: Prefer `name_from_config` over hardcoded names
- **Document Missing Prerequisites**: Comment why prerequisites aren't needed

### 3. Error Handling

- **Use `continue_on_error` Sparingly**: Only for truly optional steps
- **Test Rollback**: Always test rollback works before production use
- **Log Everything**: Add echo statements in complex commands

### 4. Variable Management

- **Consistent Naming**: Match variable names in config.yaml exactly
- **Validate Config First**: Run `load_config` to verify all variables are set
- **Document Custom Variables**: Comment any non-standard variables

### 5. Testing

- **Always Dry-Run First**: Preview changes before execution
- **Test in Stages**: Test prerequisites → steps → rollback separately
- **Monitor State**: Check database after each operation

---

## Troubleshooting

### Issue: "Configuration file not found"

**Solution**: Ensure `config.yaml` exists and `load_config` is called:
```bash
source core/config-manager.sh
load_config
```

### Issue: "Prerequisite validation failed"

**Solution**: Check resource exists or use force mode:
```bash
# Check if resource exists
az resource show --ids "/subscriptions/.../resourceGroups/.../providers/Microsoft.Network/virtualNetworks/test-vnet"

# Or force execution (use cautiously)
./core/executor.sh force operations/my-operation.yaml
```

### Issue: "Variable not substituted"

**Solution**: Verify variable is exported:
```bash
# Check if variable is set
echo $STORAGE_ACCOUNT_NAME

# Load config if not set
source core/config-manager.sh
load_config
```

### Issue: "Rollback failed"

**Solution**: Use manual rollback script:
```bash
# Find rollback script
ls -lt artifacts/rollback/

# Execute manually
./artifacts/rollback/rollback_<operation-exec-id>.sh
```

---

## Integration with Other Components

### With State Manager

Executor uses state-manager.sh for:
- Creating operation records
- Updating operation status
- Storing resource state
- Cache-first resource queries

### With Query Engine

Executor uses query.sh for:
- Prerequisite validation
- Post-execution resource queries
- Cache management

### With Logger

Executor uses logger.sh for:
- Structured logging
- Operation lifecycle tracking
- Error logging

### With Config Manager

Executor uses config-manager.sh for:
- Loading configuration
- Environment variable management
- Variable validation

---

## Future Enhancements

- **Parallel Execution**: Execute independent steps in parallel
- **Conditional Steps**: Skip steps based on runtime conditions
- **Step Dependencies**: Define dependencies between steps
- **Retry Logic**: Automatic retry with exponential backoff
- **Notifications**: Slack/email notifications on completion
- **Approval Gates**: Require manual approval before critical steps

---

## Support

For issues or questions:

1. Check logs: `artifacts/logs/deployment_*.jsonl`
2. Review state: `sqlite3 state.db "SELECT * FROM operations"`
3. Run tests: `./tests/test-executor.sh`
4. Consult other docs:
   - [State Manager](../core/state-manager.sh)
   - [Query Engine](../core/query.sh)
   - [Configuration Guide](./01-configuration.md)
