# Operation Executor Guide

## Overview

The Operation Executor (`core/executor.sh`) is the Phase 3 execution engine that runs infrastructure operations defined in YAML files. It provides:

- **Declarative Operations**: Define infrastructure changes in simple YAML
- **Prerequisite Validation**: Automatic verification of required resources
- **State Tracking**: Full operation history in SQLite database
- **Automatic Rollback**: Rollback on failure with saved scripts
- **Dry-Run Mode**: Preview changes before execution
- **Variable Substitution**: Use config variables in commands

## Table of Contents

1. [Quick Start](#quick-start)
2. [Operation YAML Format](#operation-yaml-format)
3. [Execution Modes](#execution-modes)
4. [Prerequisite Validation](#prerequisite-validation)
5. [Rollback Mechanism](#rollback-mechanism)
6. [State Tracking](#state-tracking)
7. [Variable Substitution](#variable-substitution)
8. [Error Handling](#error-handling)
9. [Examples](#examples)
10. [API Reference](#api-reference)

---

## Quick Start

### 1. Create an Operation YAML

```yaml
operation:
  id: "create-storage-account"
  name: "Create Azure Storage Account"
  type: "create"
  resource_type: "Microsoft.Storage/storageAccounts"
  resource_name: "${STORAGE_ACCOUNT_NAME}"

prerequisites:
  - resource_type: "Microsoft.Network/virtualNetworks"
    name_from_config: "NETWORKING_VNET_NAME"

steps:
  - name: "Create storage account"
    command: "az storage account create --name ${STORAGE_ACCOUNT_NAME} --resource-group ${AZURE_RESOURCE_GROUP} --location ${AZURE_LOCATION} --sku ${STORAGE_SKU}"

rollback:
  - name: "Delete storage account"
    command: "az storage account delete --name ${STORAGE_ACCOUNT_NAME} --resource-group ${AZURE_RESOURCE_GROUP} --yes"
```

### 2. Preview with Dry-Run

```bash
./core/executor.sh dry-run operations/create-storage.yaml
```

### 3. Execute the Operation

```bash
./core/executor.sh execute operations/create-storage.yaml
```

---

## Operation YAML Format

### Complete Structure

```yaml
operation:
  id: "unique-operation-id"              # Required: Unique identifier
  name: "Human Readable Name"            # Required: Display name
  type: "create"                         # Required: create|update|delete|configure
  resource_type: "Microsoft.*/type"      # Optional: Azure resource type
  resource_name: "${VAR_NAME}"           # Optional: Resource name for state tracking

prerequisites:                           # Optional: List of required resources
  - resource_type: "Microsoft.Network/virtualNetworks"
    name_from_config: "NETWORKING_VNET_NAME"  # Resolve from environment
    resource_group: "custom-rg"          # Optional: Override resource group

  - resource_type: "Microsoft.Storage/storageAccounts"
    name: "hardcoded-name"               # Or use hardcoded name
    resource_group: "${AZURE_RESOURCE_GROUP}"

steps:                                   # Required: Execution steps
  - name: "Step 1: Create resource"
    command: "az resource create ..."
    continue_on_error: false             # Optional: Continue if step fails

  - name: "Step 2: Configure resource"
    command: "az resource update ..."
    continue_on_error: true              # Example: continue on error

rollback:                                # Optional: Rollback steps (executed in reverse)
  - name: "Delete resource"
    command: "az resource delete ..."

  - name: "Clean up tags"
    command: "az tag delete ..."
```

### Field Reference

#### `operation` Section

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | Yes | Unique identifier for the operation type |
| `name` | string | Yes | Human-readable name shown in logs |
| `type` | string | Yes | Operation type: `create`, `update`, `delete`, `configure` |
| `resource_type` | string | No | Azure resource type (for state tracking) |
| `resource_name` | string | No | Resource name to track (supports variable substitution) |

#### `prerequisites` Section

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `resource_type` | string | Yes | Azure resource type to check |
| `name_from_config` | string | Conditional | Environment variable name to resolve |
| `name` | string | Conditional | Hardcoded resource name |
| `resource_group` | string | No | Resource group (defaults to `AZURE_RESOURCE_GROUP`) |

**Note**: Either `name_from_config` OR `name` must be specified.

#### `steps` Section

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | Yes | Step description |
| `command` | string | Yes | Shell command to execute (supports variable substitution) |
| `continue_on_error` | boolean | No | If `true`, continue even if step fails (default: `false`) |

#### `rollback` Section

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | Yes | Rollback step description |
| `command` | string | Yes | Command to undo changes (supports variable substitution) |

**Note**: Rollback steps are executed in **reverse order** (LIFO).

---

## Execution Modes

### Normal Execution

Execute operation with full validation and rollback:

```bash
./core/executor.sh execute operations/my-operation.yaml
```

**Behavior**:
- Validates prerequisites before execution
- Creates operation record in state database
- Executes steps sequentially
- Stores resource state after completion
- Automatic rollback on failure

### Dry-Run Mode

Preview what will be executed without making changes:

```bash
./core/executor.sh dry-run operations/my-operation.yaml
```

**Output**:
```
===================================================================
DRY RUN MODE - No changes will be made
===================================================================

Operation Details:
  ID: create-storage-account
  Name: Create Azure Storage Account
  Type: create

Prerequisites:
  1. Microsoft.Network/virtualNetworks: test-vnet

Execution Steps:
  1. Create storage account
     Command: az storage account create --name teststorage --resource-group test-rg ...

Rollback Steps:
  1. Delete storage account
     Command: az storage account delete --name teststorage --resource-group test-rg --yes

===================================================================
Dry run completed - ready for execution
===================================================================
```

### Force Mode

Execute without prerequisite validation:

```bash
./core/executor.sh force operations/my-operation.yaml
```

**Use Cases**:
- Testing/development
- Overriding validation when you know resources exist
- Emergency operations

**Warning**: Use with caution - may fail mid-execution if prerequisites are actually missing.

---

## Prerequisite Validation

### How It Works

1. **Parse Prerequisites**: Extract from YAML
2. **Resolve Names**: Substitute variables from environment
3. **Query Resources**: Check existence via state-manager (cache-first)
4. **Report Results**: Log validation status for each prerequisite

### Example Prerequisites

```yaml
prerequisites:
  # Method 1: Resolve from environment variable
  - resource_type: "Microsoft.Network/virtualNetworks"
    name_from_config: "NETWORKING_VNET_NAME"

  # Method 2: Hardcoded name
  - resource_type: "Microsoft.Network/networkInterfaces"
    name: "vm-nic-01"

  # Method 3: Custom resource group
  - resource_type: "Microsoft.Storage/storageAccounts"
    name_from_config: "STORAGE_ACCOUNT_NAME"
    resource_group: "different-rg"
```

### Validation Process

```
[*] Validating prerequisites...
[*] Found 3 prerequisites to validate
[*] Validating prerequisite 1/3: test-vnet (Microsoft.Network/virtualNetworks)
[*] Cache HIT: test-vnet
[v] Prerequisite validated: test-vnet
[*] Validating prerequisite 2/3: vm-nic-01 (Microsoft.Network/networkInterfaces)
[*] Cache MISS: vm-nic-01, querying Azure...
[v] Prerequisite validated: vm-nic-01
[*] Validating prerequisite 3/3: teststorage (Microsoft.Storage/storageAccounts)
[x] ERROR: Prerequisite not found: teststorage
[x] ERROR: Prerequisite validation failed: 1 of 3 prerequisites not found
```

---

## Rollback Mechanism

### Automatic Rollback on Failure

When any step fails (and `continue_on_error` is not set), the executor:

1. **Stops Execution**: No further steps are executed
2. **Executes Rollback**: Runs rollback steps in **reverse order**
3. **Logs Errors**: Captures all error details
4. **Saves Script**: Creates manual rollback script in `artifacts/rollback/`
5. **Updates State**: Marks operation as failed in database

### Rollback Execution Order

```yaml
rollback:
  - name: "Step 1"  # Executed THIRD
  - name: "Step 2"  # Executed SECOND
  - name: "Step 3"  # Executed FIRST
```

Rollback steps run in **LIFO** (Last In, First Out) order.

### Manual Rollback Scripts

If automatic rollback fails or you need to re-run rollback later:

```bash
# Automatic rollback creates a script
./artifacts/rollback/rollback_<operation-exec-id>.sh
```

Example script:

```bash
#!/bin/bash
# ==============================================================================
# Rollback Script
# ==============================================================================
# Generated by executor.sh
# Operation: Create Azure Storage Account
# Execution ID: create-storage-account_20251206_143022_Ab3X
# Generated: Fri Dec  6 14:30:45 UTC 2025
# ==============================================================================

# Step: Delete storage account
echo '[*] Executing: Delete storage account'
az storage account delete --name teststorage --resource-group test-rg --yes

echo '[v] Rollback completed'
```

### Best Practices for Rollback

1. **Always Define Rollback**: Even for read-only operations (for consistency)
2. **Test Rollback**: Use dry-run to verify rollback commands are correct
3. **Idempotent Commands**: Use `--yes` flags, check existence before delete
4. **Order Matters**: List rollback steps in logical dependency order

---

## State Tracking

### Operation Records

Every execution creates a record in the `operations` table:

```sql
CREATE TABLE operations (
    id INTEGER PRIMARY KEY,
    operation_id TEXT NOT NULL,
    capability TEXT,
    operation_name TEXT,
    operation_type TEXT,
    resource_id TEXT,
    status TEXT,
    started_at INTEGER,
    completed_at INTEGER,
    duration INTEGER,
    current_step INTEGER,
    total_steps INTEGER,
    step_description TEXT,
    error_message TEXT
);
```

### Operation Lifecycle

```
pending → running → completed (success)
                 ↘ failed (error with rollback)
```

### Querying Operation History

```bash
# Via state-manager.sh
sqlite3 state.db "SELECT operation_id, operation_name, status, duration FROM operations ORDER BY started_at DESC LIMIT 10"
```

### Resource State Updates

After successful execution, if `resource_type` and `resource_name` are defined:

1. Query Azure for latest resource state
2. Store in `resources` table with full JSON
3. Cache for 5 minutes (configurable)
4. Used for prerequisite validation in future operations

---

## Variable Substitution

### Supported Syntax

```bash
${VARIABLE_NAME}    # Bash-style (recommended)
$VARIABLE_NAME      # Also supported
```

### Variable Sources

Variables are loaded from `config.yaml` by `config-manager.sh`:

```yaml
# config.yaml
azure:
  subscription_id: "xxxxx"
  resource_group: "my-rg"

storage:
  account_name: "mystorageacct"
```

Becomes:

```bash
AZURE_SUBSCRIPTION_ID="xxxxx"
AZURE_RESOURCE_GROUP="my-rg"
STORAGE_ACCOUNT_NAME="mystorageacct"
```

### Usage in Operations

```yaml
steps:
  - name: "Create storage account"
    command: "az storage account create --name ${STORAGE_ACCOUNT_NAME} --resource-group ${AZURE_RESOURCE_GROUP} --location ${AZURE_LOCATION}"
```

Resolves to:

```bash
az storage account create --name mystorageacct --resource-group my-rg --location eastus
```

### Environment Variable Override

Runtime variables override config:

```bash
export STORAGE_ACCOUNT_NAME="override-storage"
./core/executor.sh execute operations/create-storage.yaml
# Uses "override-storage" instead of config value
```

---

## Error Handling

### Error Types

| Error Type | Behavior | Example |
|------------|----------|---------|
| **Parse Error** | Operation fails immediately | Invalid YAML syntax |
| **Prerequisite Failure** | Operation fails before execution | Required VNET not found |
| **Step Failure** | Rollback initiated (unless `continue_on_error: true`) | Azure CLI command fails |
| **Rollback Failure** | Logged as warning, manual script saved | Permission denied during delete |

### Exit Codes

```bash
0   # Success
1   # Failure (any error)
```

### Error Logging

All errors are logged to:

1. **Console**: Real-time output
2. **Structured Logs**: `artifacts/logs/deployment_YYYYMMDD.jsonl`
3. **Step Logs**: `artifacts/logs/step_<operation-exec-id>_<step-index>.log`
4. **Database**: `operations` table with error message

### Debugging Failed Operations

```bash
# 1. Check recent operation status
sqlite3 state.db "SELECT operation_id, status, error_message FROM operations WHERE status='failed' ORDER BY started_at DESC LIMIT 5"

# 2. View step logs
cat artifacts/logs/step_create-vm_20251206_143022_Ab3X_2.log

# 3. Check structured logs
cat artifacts/logs/deployment_20251206.jsonl | jq 'select(.level=="ERROR")'

# 4. Run manual rollback if needed
./artifacts/rollback/rollback_create-vm_20251206_143022_Ab3X.sh
```

---

## Examples

### Example 1: Create Virtual Network

```yaml
operation:
  id: "create-vnet"
  name: "Create Virtual Network"
  type: "create"
  resource_type: "Microsoft.Network/virtualNetworks"
  resource_name: "${NETWORKING_VNET_NAME}"

prerequisites: []

steps:
  - name: "Create virtual network"
    command: "az network vnet create --name ${NETWORKING_VNET_NAME} --resource-group ${AZURE_RESOURCE_GROUP} --address-prefixes 10.0.0.0/16"

  - name: "Create subnet"
    command: "az network vnet subnet create --vnet-name ${NETWORKING_VNET_NAME} --name default --resource-group ${AZURE_RESOURCE_GROUP} --address-prefix 10.0.1.0/24"

rollback:
  - name: "Delete virtual network"
    command: "az network vnet delete --name ${NETWORKING_VNET_NAME} --resource-group ${AZURE_RESOURCE_GROUP} --yes"
```

### Example 2: Create VM with Prerequisites

```yaml
operation:
  id: "create-vm"
  name: "Create Virtual Machine"
  type: "create"
  resource_type: "Microsoft.Compute/virtualMachines"
  resource_name: "test-vm-01"

prerequisites:
  - resource_type: "Microsoft.Network/virtualNetworks"
    name_from_config: "NETWORKING_VNET_NAME"

  - resource_type: "Microsoft.Network/networkInterfaces"
    name: "test-vm-01-nic"

steps:
  - name: "Create virtual machine"
    command: "az vm create --name test-vm-01 --resource-group ${AZURE_RESOURCE_GROUP} --nics test-vm-01-nic --image Ubuntu2204 --admin-username azureuser --generate-ssh-keys"

rollback:
  - name: "Delete virtual machine"
    command: "az vm delete --name test-vm-01 --resource-group ${AZURE_RESOURCE_GROUP} --yes"
```

### Example 3: Multi-Step Configuration

```yaml
operation:
  id: "configure-storage-advanced"
  name: "Configure Storage Account - Advanced"
  type: "configure"
  resource_type: "Microsoft.Storage/storageAccounts"
  resource_name: "${STORAGE_ACCOUNT_NAME}"

prerequisites:
  - resource_type: "Microsoft.Storage/storageAccounts"
    name_from_config: "STORAGE_ACCOUNT_NAME"

steps:
  - name: "Enable blob versioning"
    command: "az storage account blob-service-properties update --account-name ${STORAGE_ACCOUNT_NAME} --resource-group ${AZURE_RESOURCE_GROUP} --enable-versioning true"

  - name: "Enable change feed"
    command: "az storage account blob-service-properties update --account-name ${STORAGE_ACCOUNT_NAME} --resource-group ${AZURE_RESOURCE_GROUP} --enable-change-feed true"
    continue_on_error: true

  - name: "Configure default encryption"
    command: "az storage account update --name ${STORAGE_ACCOUNT_NAME} --resource-group ${AZURE_RESOURCE_GROUP} --encryption-key-source Microsoft.Storage"

  - name: "Set minimum TLS version"
    command: "az storage account update --name ${STORAGE_ACCOUNT_NAME} --resource-group ${AZURE_RESOURCE_GROUP} --min-tls-version TLS1_2"

rollback:
  - name: "Disable blob versioning"
    command: "az storage account blob-service-properties update --account-name ${STORAGE_ACCOUNT_NAME} --resource-group ${AZURE_RESOURCE_GROUP} --enable-versioning false"

  - name: "Disable change feed"
    command: "az storage account blob-service-properties update --account-name ${STORAGE_ACCOUNT_NAME} --resource-group ${AZURE_RESOURCE_GROUP} --enable-change-feed false"
```

### Example 4: Delete Operation

```yaml
operation:
  id: "delete-storage"
  name: "Delete Storage Account"
  type: "delete"
  resource_type: "Microsoft.Storage/storageAccounts"
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
