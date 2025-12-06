# Operation Examples

This directory contains example operation YAML files demonstrating the executor's capabilities.

## Available Examples

| File | Description | Use Case |
|------|-------------|----------|
| `operation-example.yaml` | Comprehensive example with all features | Template for new operations |
| `create-vnet.yaml` | Create VNet with multiple subnets | Networking foundation |
| `create-vm.yaml` | Create VM with NIC | Compute resources |
| `configure-resource.yaml` | Configure existing storage account | Resource updates |
| `delete-resource.yaml` | Delete VM with cleanup | Resource deletion |

## Quick Start

### 1. Preview an Operation (Dry-Run)

```bash
# See what would be executed without making changes
./core/executor.sh dry-run examples/create-vnet.yaml
```

**Output:**
```
===================================================================
DRY RUN MODE - No changes will be made
===================================================================

Operation Details:
  ID: create-vnet-subnets
  Name: Create Virtual Network with Multiple Subnets
  Type: create

Prerequisites:
  None

Execution Steps:
  1. Create virtual network
     Command: az network vnet create --name test-vnet ...
  2. Create session hosts subnet
     Command: az network vnet subnet create ...
  ...
```

### 2. Execute an Operation

```bash
# Load configuration first
source core/config-manager.sh
load_config

# Execute the operation
./core/executor.sh execute examples/create-vnet.yaml
```

### 3. Force Execution (Skip Prerequisites)

```bash
# Execute without prerequisite validation
./core/executor.sh force examples/configure-resource.yaml
```

## Example Breakdown

### Example 1: Basic Resource Creation

**File:** `create-vnet.yaml`

**What it does:**
- Creates a virtual network
- Creates three subnets (session hosts, private endpoints, management)
- Uses variables from config.yaml
- Provides rollback to delete everything

**When to use:**
- Setting up networking foundation
- Need multiple subnets for different purposes
- Want automatic cleanup on failure

**How to customize:**
- Change subnet address prefixes
- Add/remove subnets
- Add NSG associations

### Example 2: Resource with Prerequisites

**File:** `create-vm.yaml`

**What it does:**
- Validates VNet exists before starting
- Creates NIC in specified subnet
- Creates VM with SSH access
- Optionally opens SSH port

**When to use:**
- Creating VMs in existing networks
- Need prerequisite validation
- Want NIC and VM in one operation

**How to customize:**
- Change VM size: `--size Standard_B2s`
- Use different OS: `--image Win2022Datacenter`
- Add data disks

### Example 3: Configuration Only

**File:** `configure-resource.yaml`

**What it does:**
- Validates storage account exists
- Enables security features
- Configures blob versioning and soft delete
- Sets TLS requirements

**When to use:**
- Updating existing resources
- Hardening security settings
- Enabling advanced features

**How to customize:**
- Add/remove security settings
- Change retention periods
- Enable different features

### Example 4: Resource Deletion

**File:** `delete-resource.yaml`

**What it does:**
- Validates VM exists
- Stops VM gracefully
- Deletes VM and associated resources
- Creates audit log entry

**When to use:**
- Cleaning up test resources
- Decommissioning infrastructure
- Need audit trail of deletions

**How to customize:**
- Add backup step before deletion
- Skip NIC/disk deletion
- Add notification step

## Creating Your Own Operations

### Step 1: Copy Template

```bash
cp examples/operation-example.yaml operations/my-operation.yaml
```

### Step 2: Customize

Edit `operations/my-operation.yaml`:

```yaml
operation:
  id: "my-operation"           # Make it unique
  name: "My Custom Operation"  # Descriptive name
  type: "create"               # create|update|delete|configure
  resource_type: "Microsoft.*/type"
  resource_name: "${MY_RESOURCE_NAME}"

prerequisites:
  # Add required resources
  - resource_type: "Microsoft.Network/virtualNetworks"
    name_from_config: "NETWORKING_VNET_NAME"

steps:
  # Add your commands
  - name: "Create my resource"
    command: "az ... create ..."

rollback:
  # Add cleanup commands (in reverse order)
  - name: "Delete my resource"
    command: "az ... delete ..."
```

### Step 3: Test

```bash
# 1. Dry run first
./core/executor.sh dry-run operations/my-operation.yaml

# 2. Execute
./core/executor.sh execute operations/my-operation.yaml
```

## Best Practices

### 1. Always Define Rollback

Even if rollback is complex, define what should happen on failure:

```yaml
rollback:
  # If resource can't be deleted, at least log it
  - name: "Log failed operation for manual cleanup"
    command: "echo 'Manual cleanup required' >> artifacts/manual-cleanup.log"
```

### 2. Use `continue_on_error` for Optional Steps

```yaml
steps:
  - name: "Enable optional feature"
    command: "az ... update --enable-feature true"
    continue_on_error: true  # Don't fail if feature not supported
```

### 3. Check Resource Existence Before Delete

```yaml
steps:
  - name: "Delete disk if exists"
    command: |
      if az disk show --name my-disk --resource-group ${AZURE_RESOURCE_GROUP} &>/dev/null; then
        az disk delete --name my-disk --resource-group ${AZURE_RESOURCE_GROUP} --yes
      fi
```

### 4. Use Variables for All Configurable Values

```yaml
# Good
command: "az resource create --name ${RESOURCE_NAME} --location ${AZURE_LOCATION}"

# Bad (hardcoded)
command: "az resource create --name hardcoded-name --location eastus"
```

### 5. Add Descriptive Step Names

```yaml
# Good
- name: "Create storage account with ZRS replication"
  command: "az storage account create ..."

# Bad
- name: "Create storage"
  command: "az storage account create ..."
```

## Testing Your Operations

### Test Checklist

- [ ] Dry-run shows correct commands
- [ ] All variables are substituted
- [ ] Prerequisites exist (or use force mode)
- [ ] Operation completes successfully
- [ ] Resource state is stored in database
- [ ] Rollback works when step fails
- [ ] Rollback script is saved

### Test Scenarios

#### 1. Test Successful Execution

```bash
./core/executor.sh execute examples/create-vnet.yaml

# Verify in database
sqlite3 state.db "SELECT * FROM operations WHERE operation_id LIKE 'create-vnet%' ORDER BY started_at DESC LIMIT 1"
```

#### 2. Test Failed Execution (Rollback)

```bash
# Modify operation to fail intentionally
# Add: command: "exit 1"
./core/executor.sh execute examples/create-vnet.yaml

# Should see rollback execution
# Check rollback script created:
ls -la artifacts/rollback/
```

#### 3. Test Prerequisite Validation

```bash
# Try to create VM without VNet
./core/executor.sh execute examples/create-vm.yaml

# Should fail with: "Prerequisite not found: test-vnet"
```

## Common Patterns

### Pattern 1: Create Resource with Dependencies

```yaml
steps:
  - name: "Get dependency resource ID"
    command: |
      VNET_ID=$(az network vnet show \
        --name ${NETWORKING_VNET_NAME} \
        --resource-group ${AZURE_RESOURCE_GROUP} \
        --query id -o tsv)

  - name: "Create resource using dependency"
    command: |
      az resource create \
        --name my-resource \
        --vnet-id $VNET_ID
```

### Pattern 2: Conditional Execution

```yaml
steps:
  - name: "Create only if not exists"
    command: |
      if ! az resource show --name my-resource --resource-group ${AZURE_RESOURCE_GROUP} &>/dev/null; then
        az resource create --name my-resource ...
      else
        echo "Resource already exists, skipping"
      fi
```

### Pattern 3: Multi-Resource Creation

```yaml
steps:
  - name: "Create resource 1"
    command: "az ... create ..."

  - name: "Wait for resource 1 to be ready"
    command: |
      az resource wait \
        --name resource-1 \
        --resource-group ${AZURE_RESOURCE_GROUP} \
        --created

  - name: "Create resource 2 (depends on resource 1)"
    command: "az ... create ..."
```

### Pattern 4: Capture and Use Output

```yaml
steps:
  - name: "Create resource and capture ID"
    command: |
      RESOURCE_ID=$(az resource create \
        --name my-resource \
        --query id -o tsv)
      echo "Created resource: $RESOURCE_ID"

  - name: "Use captured ID"
    command: |
      az role assignment create \
        --assignee $USER_ID \
        --role Contributor \
        --scope $RESOURCE_ID
```

## Troubleshooting

### Issue: Variable Not Substituted

**Problem:**
```
Command: az ... create --name ${MY_VARIABLE}
```

**Solution:**
```bash
# Check if variable is set
echo $MY_VARIABLE

# Load config
source core/config-manager.sh
load_config

# Verify variable is exported
env | grep MY_VARIABLE
```

### Issue: Prerequisite Validation Fails

**Problem:**
```
[x] ERROR: Prerequisite not found: my-vnet
```

**Solution:**
```bash
# Check if resource actually exists
az network vnet show --name my-vnet --resource-group my-rg

# Or skip validation (force mode)
./core/executor.sh force examples/my-operation.yaml
```

### Issue: Rollback Doesn't Execute

**Problem:**
Rollback steps don't run when operation fails.

**Solution:**
- Check if step has `continue_on_error: true` (bypasses rollback)
- Verify rollback section exists in YAML
- Check logs: `cat artifacts/logs/deployment_*.jsonl | jq 'select(.level=="ERROR")'`

### Issue: Command Fails with "Command Not Found"

**Problem:**
```
/bin/bash: line 1: az: command not found
```

**Solution:**
```bash
# Ensure Azure CLI is installed and in PATH
which az

# Login to Azure
az login

# Set subscription
az account set --subscription ${AZURE_SUBSCRIPTION_ID}
```

## Next Steps

1. **Review the documentation**: See `docs/executor-guide.md` for complete reference
2. **Explore other examples**: Check all YAML files in this directory
3. **Create your own**: Copy a template and customize for your needs
4. **Run tests**: Execute `./tests/test-executor.sh` to verify executor works

## Support

For issues or questions:
- Check logs: `artifacts/logs/deployment_*.jsonl`
- Review state: `sqlite3 state.db "SELECT * FROM operations"`
- Read docs: `docs/executor-guide.md`
