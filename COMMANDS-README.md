# AVD Deployment Command Reference Guide

Complete reference documentation for all Azure CLI and PowerShell commands used in the 12-step AVD deployment pipeline.

## Quick Navigation

| Step | Description | Commands File |
|------|-------------|--------|
| 01 | Networking Setup | [01-networking/COMMANDS.md](01-networking/COMMANDS.md) |
| 02 | Storage Setup | [02-storage/COMMANDS.md](02-storage/COMMANDS.md) |
| 03 | Entra ID & Service Principal | [03-entra-group/COMMANDS.md](03-entra-group/COMMANDS.md) |
| 04 | Host Pool & Workspace | [04-host-pool-workspace/COMMANDS.md](04-host-pool-workspace/COMMANDS.md) |
| 05 | Golden Image | [05-golden-image/COMMANDS.md](05-golden-image/COMMANDS.md) (see task scripts) |
| 06 | Session Host Deployment | [06-session-host-deployment/COMMANDS.md](06-session-host-deployment/COMMANDS.md) |
| 07 | Intune Configuration | [07-intune/COMMANDS.md](07-intune/COMMANDS.md) |
| 08 | RBAC Assignments | [08-rbac/COMMANDS.md](08-rbac/COMMANDS.md) |
| 09 | SSO Configuration | [09-sso/COMMANDS.md](09-sso/COMMANDS.md) |
| 10 | Autoscaling | [10-autoscaling/COMMANDS.md](10-autoscaling/COMMANDS.md) |
| 11 | Testing & Validation | [11-testing/COMMANDS.md](11-testing/COMMANDS.md) |
| 12 | Cleanup & Migration | [12-cleanup-migration/COMMANDS.md](12-cleanup-migration/COMMANDS.md) |

## How to Use This Guide

### For AI Assistants (Claude, Gemini, etc.)

1. **Quick Reference**: Use `grep` to search for specific commands
   ```bash
   grep -r "az vm create" .
   grep -r "az network" 01-networking/COMMANDS.md
   ```

2. **Copy & Paste**: Commands are formatted for direct terminal use
   - Substitute variables like `$RG`, `$LOCATION` as needed
   - All variable definitions are shown at the top of each file

3. **Pattern Discovery**: Find similar operations across files
   - Naming conventions are consistent (`az resource list`, `az resource create`, etc.)
   - Same patterns work across different resource types

4. **Scripting**: Combine commands from different files for workflows
   - Bash examples show how to chain commands
   - PowerShell examples show native object manipulation
   - Both are idiomatic and production-ready

### For Humans

1. **Learn by doing**: Run examples directly from files
2. **Understand parameters**: Comments explain what each flag does
3. **See alternatives**: Multiple approaches shown for common tasks
4. **Copy templates**: Use complete script examples as starting points
5. **Troubleshooting**: Each file has dedicated troubleshooting section

## Command Organization

### By Deployment Step

Each COMMANDS.md file is organized as:

1. **Prerequisites** - What you need before running commands
2. **Core Operations** - Main tasks for that step
3. **Common Patterns** - Useful examples and recipes
4. **Scripting Examples** - Complete bash/PowerShell scripts
5. **Troubleshooting** - Solutions to common problems
6. **References** - Links to Microsoft documentation

### By Command Type

```
Azure CLI (az)
  - Resource management
  - VMs and compute
  - Networking
  - Storage
  - Entra ID
  - RBAC
  - Desktop Virtualization (AVD-specific)

PowerShell (Az.*)
  - More flexible object manipulation
  - Windows-native operations
  - Group Policy
  - Registry modifications
  - Session host configuration

Graph API (via REST)
  - Advanced Azure AD operations
  - Intune policies
  - Conditional Access
  - Modern authentication
```

## Key Command Patterns

### Listing Resources

```bash
# Simple list with defaults
az <resource> list --resource-group "$RG"

# Custom output
az <resource> list --resource-group "$RG" --query "[].{name, id}" --output table

# Find specific resources
az <resource> list --query "[?contains(name, 'pattern')]"

# Export to JSON
az <resource> list > resources.json
```

### Creating Resources

```bash
# Basic creation
az <resource> create --name "name" --resource-group "$RG"

# With all parameters
az <resource> create \
  --name "name" \
  --resource-group "$RG" \
  --property "value" \
  --output json > output.json

# Batch creation (parallel)
for i in {1..3}; do
  az <resource> create --name "name-$i" &
done
wait
```

### Updating Resources

```bash
# Single property
az <resource> update --name "name" --resource-group "$RG" --property "new-value"

# Multiple properties
az <resource> update \
  --name "name" \
  --resource-group "$RG" \
  --property1 "value1" \
  --property2 "value2"
```

### Deleting Resources

```bash
# Single resource
az <resource> delete --name "name" --resource-group "$RG" --yes

# Multiple resources (batch)
az <resource> list \
  --query "[?contains(name, 'pattern')].name" -o tsv | \
  while read resource; do
    az <resource> delete --name "$resource" --resource-group "$RG" --yes
  done

# Parallel deletion (faster)
az <resource> list \
  --query "[?contains(name, 'pattern')].name" -o tsv | \
  while read resource; do
    az <resource> delete --name "$resource" --resource-group "$RG" --yes --no-wait &
  done
wait
```

## Integration with Task Scripts

These command references are **complementary to task scripts**, not replacements:

- **Task scripts** (in each step's `tasks/` directory) provide automated, production-ready workflows
- **COMMANDS.md files** provide the underlying commands and documentation for understanding/customizing

**Use together**:
1. Read COMMANDS.md to understand what a task does
2. Review task script to see implementation details
3. Run task script for automated execution: `./tasks/01-task.sh`
4. Use individual commands from COMMANDS.md for manual steps or customization

## Variables Across All Steps

Common variables used throughout:

```bash
# Subscription & Deployment
SUBSCRIPTION_ID="<subscription-id>"
RG="RG-Azure-VDI-01"
LOCATION="centralus"

# Networking
VNET="avd-vnet"
VNET_CIDR="10.0.0.0/16"
SESSION_HOSTS_SUBNET="session-hosts"
PRIVATE_ENDPOINTS_SUBNET="private-endpoints"

# Storage
STORAGE_ACCOUNT="avdfslogix001"  # Must be globally unique, lowercase, 3-24 chars
FILE_SHARE="fslogix-profiles"
FILE_SHARE_QUOTA="1024"  # GB

# Entra ID
AVD_USERS_GROUP="AVD-Users"
AVD_ADMINS_GROUP="AVD-Admins"
AVD_SP="AVD-Automation-SP"

# Desktop Virtualization
IMAGE_GALLERY="avdimagegallery"
GOLDEN_IMAGE="golden-image"
HOSTPOOL="avd-hostpool"
WORKSPACE="avd-workspace"
APPGROUP="avd-appgroup"

# Deployment
VM_PREFIX="avd-host"
VM_SIZE="Standard_D2s_v3"
VM_COUNT="3"
SCALING_PLAN="avd-scaling-plan"

# Authentication
TIMEZONE="Central Standard Time"
ADMIN_USERNAME="azureuser"
```

## Substituting Variables

All commands use shell variables. To use them:

**Option 1: Export variables first**
```bash
export RG="RG-Azure-VDI-01"
export LOCATION="centralus"

# Then copy commands directly
az group create --name "$RG" --location "$LOCATION"
```

**Option 2: Replace inline**
```bash
# Replace $RG with your actual resource group name
az group create --name "RG-Azure-VDI-01" --location "centralus"
```

**Option 3: Use from task scripts**
```bash
# Task scripts automatically load variables from config.env
cd 01-networking
./tasks/01-create-vnet.sh
```

## Advanced Usage

### Combining Commands for Automation

Example: Deploy and configure in one script

```bash
#!/bin/bash

RG="RG-Azure-VDI-01"

# Create resource group
echo "Creating resource group..."
az group create --name "$RG" --location "centralus"

# Create VNet (from 01-networking/COMMANDS.md)
echo "Creating VNet..."
az network vnet create \
  --resource-group "$RG" \
  --name "avd-vnet" \
  --address-prefix "10.0.0.0/16" \
  --location "centralus"

# Create NSG (from 01-networking/COMMANDS.md)
echo "Creating NSG..."
az network nsg create \
  --resource-group "$RG" \
  --name "nsg-session-hosts" \
  --location "centralus"

# Create storage account (from 02-storage/COMMANDS.md)
echo "Creating storage account..."
az storage account create \
  --resource-group "$RG" \
  --name "avdfslogix001" \
  --sku "Premium_LRS" \
  --kind "FileStorage"

echo "Infrastructure created successfully!"
```

### Parsing Output for Complex Workflows

```bash
# Get resource ID and use in next command
VNET_ID=$(az network vnet show \
  --resource-group "$RG" \
  --name "avd-vnet" \
  --query id -o tsv)

# Use ID in next command
az network vnet subnet create \
  --vnet-name "avd-vnet" \
  --name "session-hosts" \
  --address-prefix "10.0.1.0/24" \
  --resource-group "$RG"
```

### Bulk Operations

```bash
# List resources matching pattern and perform action
az vm list \
  --resource-group "$RG" \
  --query "[?contains(name, 'avd')].name" -o tsv | \
  while read vm; do
    echo "Processing $vm..."
    az vm get-instance-view --resource-group "$RG" --name "$vm"
  done
```

## PowerShell Usage

When Azure CLI has limitations, use PowerShell with Graph API:

```powershell
# Install modules
Install-Module Az.DesktopVirtualization
Install-Module Microsoft.Graph

# Connect
Connect-AzAccount
Connect-MgGraph

# Then use cmdlets
Get-AzDesktopVirtualizationHostpool -ResourceGroupName "RG-Azure-VDI-01"
```

## Troubleshooting Command Issues

### Command Not Found
```bash
# Verify Azure CLI installed
az version

# Update Azure CLI
az upgrade

# Install missing extension
az extension add --name "<extension-name>"
```

### Authentication Issues
```bash
# Check current authentication
az account show

# Login again
az login

# Set correct subscription
az account set --subscription "<subscription-id>"
```

### Syntax Errors
- Copy command from COMMANDS.md file (avoids typos)
- Check for unmatched quotes or brackets
- Verify variable substitution: `echo "$RG"`

### Permission Errors
```bash
# Check role assignments
az role assignment list --assignee "<principal-id>"

# Verify resource group access
az resource list --resource-group "$RG"
```

## References

- [Azure CLI Documentation](https://learn.microsoft.com/cli/azure/)
- [Azure PowerShell Documentation](https://learn.microsoft.com/powershell/azure/)
- [Azure Virtual Desktop Docs](https://learn.microsoft.com/azure/virtual-desktop/)
- [Azure CLI Reference](https://learn.microsoft.com/cli/azure/reference-index)

## See Also

- [Task Scripts](./README.md) - Automated scripts for each step
- [AI Interaction Guide](./AI-INTERACTION-GUIDE.md) - How to use with AI assistants
- [Implementation Status](./IMPLEMENTATION-STATUS.md) - Progress tracking
- [Orchestrator Guide](./orchestrate.sh) - Master automation script

---

**Pro Tip**: Search across all COMMANDS.md files for specific operations:
```bash
# Find all vm creation commands
grep -r "az vm create" .

# Find all role assignment examples
grep -r "az role assignment" .

# Find storage account commands
grep -r "az storage account" .
```
