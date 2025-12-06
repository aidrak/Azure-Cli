# Executor Quick Reference

## Commands

```bash
# Preview (dry-run)
./core/executor.sh dry-run <operation.yaml>

# Execute
./core/executor.sh execute <operation.yaml>

# Force (skip prerequisites)
./core/executor.sh force <operation.yaml>

# Help
./core/executor.sh --help
```

## Minimal Operation YAML

```yaml
operation:
  id: "my-operation"
  name: "My Operation"
  type: "create"

prerequisites: []

steps:
  - name: "Do something"
    command: "az resource create ..."

rollback:
  - name: "Undo something"
    command: "az resource delete ..."
```

## Variable Substitution

```yaml
# In YAML
command: "az ... --name ${STORAGE_ACCOUNT_NAME} --rg ${AZURE_RESOURCE_GROUP}"

# Variables loaded from config.yaml
# Available: AZURE_*, NETWORKING_*, STORAGE_*, etc.
```

## Prerequisites

```yaml
prerequisites:
  # Method 1: From environment variable
  - resource_type: "Microsoft.Network/virtualNetworks"
    name_from_config: "NETWORKING_VNET_NAME"

  # Method 2: Hardcoded
  - resource_type: "Microsoft.Storage/storageAccounts"
    name: "mystorageaccount"
```

## Step Options

```yaml
steps:
  # Normal step (fails operation on error)
  - name: "Critical step"
    command: "az ... create ..."

  # Optional step (continues on error)
  - name: "Optional step"
    command: "az ... update ..."
    continue_on_error: true
```

## Rollback

```yaml
rollback:
  - name: "Step 3 cleanup"  # Executed FIRST
  - name: "Step 2 cleanup"  # Executed SECOND
  - name: "Step 1 cleanup"  # Executed THIRD
# Rollback runs in REVERSE order (LIFO)
```

## Error Checking

```bash
# Check operation status
sqlite3 state.db "SELECT operation_id, status, error_message FROM operations WHERE status='failed' ORDER BY started_at DESC LIMIT 5"

# View logs
cat artifacts/logs/deployment_$(date +%Y%m%d).jsonl | jq 'select(.level=="ERROR")'

# Find rollback script
ls -lt artifacts/rollback/
```

## Common Patterns

### Create with Dependency

```yaml
steps:
  - name: "Get dependency ID"
    command: |
      VNET_ID=$(az network vnet show --name ${VNET_NAME} --rg ${RG} --query id -o tsv)

  - name: "Create resource"
    command: |
      az resource create --vnet-id $VNET_ID ...
```

### Conditional Creation

```yaml
steps:
  - name: "Create if not exists"
    command: |
      if ! az resource show --name ${NAME} --rg ${RG} 2>/dev/null; then
        az resource create --name ${NAME} ...
      fi
```

### Multi-line Commands

```yaml
steps:
  - name: "Create with many options"
    command: |
      az storage account create \
        --name ${STORAGE_ACCOUNT_NAME} \
        --resource-group ${AZURE_RESOURCE_GROUP} \
        --location ${AZURE_LOCATION} \
        --sku Standard_LRS \
        --kind StorageV2
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Variable not substituted | `source core/config-manager.sh && load_config` |
| Prerequisite validation fails | Check resource exists or use `force` mode |
| Step fails | Check `artifacts/logs/step_*.log` |
| Need to re-run rollback | Execute `artifacts/rollback/rollback_*.sh` |
| YAML syntax error | Validate with `yq eval '.' operation.yaml` |

## Files

```
core/executor.sh              # Main executor
tests/test-executor.sh        # Tests
docs/executor-guide.md        # Full documentation
examples/operation-example.yaml  # Template
PHASE3-IMPLEMENTATION.md      # Implementation summary
```

## Quick Test

```bash
# Run tests
./tests/test-executor.sh

# Test dry-run
./core/executor.sh dry-run examples/create-vnet.yaml
```
