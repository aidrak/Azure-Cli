# Azure CLI Reference - Management & Operations

Monitoring, Tags, Locks, Policy, Querying, and Filtering.

> **Part of Azure CLI Reference Series:**
> - [Core](azure-cli-core.md) - Auth, Resource Groups
> - [Networking](azure-cli-networking.md) - VNets, Subnets, NSGs
> - [Storage](azure-cli-storage.md) - Storage Accounts, File Shares
> - [Compute](azure-cli-compute.md) - VMs, Disks, Images
> - [AVD](azure-cli-avd.md) - Host Pools, Workspaces
> - [Identity](azure-cli-identity.md) - RBAC, Entra ID
> - **Management** (this file) - Monitoring, Tags, Locks

---

## Monitoring & Diagnostics

```bash
# Create Log Analytics workspace
az monitor log-analytics workspace create \
  --resource-group <rg-name> \
  --workspace-name <workspace-name> \
  --location <location>

# Get workspace ID
az monitor log-analytics workspace show \
  --resource-group <rg-name> \
  --workspace-name <workspace-name> \
  --query customerId -o tsv

# Enable diagnostic settings (example: NSG)
az monitor diagnostic-settings create \
  --resource <resource-id> \
  --name <diagnostic-setting-name> \
  --workspace <workspace-id> \
  --logs '[{"category": "NetworkSecurityGroupEvent", "enabled": true}]'

# List activity log
az monitor activity-log list \
  --resource-group <rg-name> \
  --output table

# Create alert rule
az monitor metrics alert create \
  --resource-group <rg-name> \
  --name <alert-name> \
  --scopes <resource-id> \
  --condition "avg Percentage CPU > 80" \
  --description "CPU usage alert"
```

---

## Tags

```bash
# Add tags to resource
az resource tag \
  --tags Environment=Production Department=IT \
  --resource-group <rg-name> \
  --name <resource-name> \
  --resource-type <resource-type>

# Update tags on resource group
az group update \
  --resource-group <rg-name> \
  --tags Environment=Production CostCenter=IT

# List resources by tag
az resource list \
  --tag Environment=Production \
  --output table

# Remove all tags
az resource tag \
  --tags \
  --resource-group <rg-name> \
  --name <resource-name> \
  --resource-type <resource-type>
```

---

## Locks

```bash
# Create resource lock (delete protection)
az lock create \
  --name <lock-name> \
  --lock-type CanNotDelete \
  --resource-group <rg-name>

# Create resource lock (read-only)
az lock create \
  --name <lock-name> \
  --lock-type ReadOnly \
  --resource-group <rg-name>

# List locks
az lock list --resource-group <rg-name> --output table

# Delete lock
az lock delete \
  --name <lock-name> \
  --resource-group <rg-name>
```

---

## Policy

```bash
# List policy definitions
az policy definition list --output table

# Show policy definition
az policy definition show --name <policy-name>

# Assign policy to resource group
az policy assignment create \
  --name <assignment-name> \
  --policy <policy-definition-id> \
  --resource-group <rg-name>

# List policy assignments
az policy assignment list --resource-group <rg-name> --output table

# Delete policy assignment
az policy assignment delete \
  --name <assignment-name> \
  --resource-group <rg-name>
```

---

## Extensions & Features

```bash
# Install Azure CLI extension
az extension add --name <extension-name>

# List installed extensions
az extension list --output table

# Update extension
az extension update --name <extension-name>

# Remove extension
az extension remove --name <extension-name>

# Register resource provider
az provider register --namespace Microsoft.DesktopVirtualization

# List resource providers
az provider list --output table

# Show resource provider
az provider show --namespace Microsoft.DesktopVirtualization
```

---

## Querying & Filtering

```bash
# Query with JMESPath
az <command> --query "<jmespath-expression>" -o tsv

# Common query examples:
# Get single property
--query "name" -o tsv

# Get property from array
--query "[0].name" -o tsv

# Filter array
--query "[?location=='eastus']"

# Select specific properties
--query "[].{Name:name, Location:location}"

# Output formats
-o table    # Table format
-o json     # JSON format (default)
-o tsv      # Tab-separated values
-o yaml     # YAML format
-o jsonc    # Colorized JSON
-o none     # No output
```

---

## Common Service Tags for NSG Rules

```text
# AVD-specific service tags
WindowsVirtualDesktop           # AVD Gateway traffic
AzureMonitor                    # Monitoring and diagnostics
AzureActiveDirectory            # Entra ID authentication
AzureCloud                      # General Azure services
Storage                         # Azure Storage
Storage.CentralUS               # Storage in specific region

# Other useful tags
Internet                        # Internet traffic
VirtualNetwork                  # VNet traffic
AzureLoadBalancer              # Azure Load Balancer
```

---

## Useful Global Parameters

```bash
# Apply to all az commands:

--resource-group <rg-name>      # Specify resource group
--location <location>           # Specify region
--subscription <sub-id>         # Specify subscription
--output table                  # Format output as table
--query "<expression>"          # Filter results with JMESPath
--debug                         # Enable debug logging
--verbose                       # Verbose output
--no-wait                       # Don't wait for operation to complete
--yes                           # Automatic yes to prompts
--only-show-errors              # Only show errors, suppress warnings
```

---

## Notes for AI Assistants

**When working with Azure CLI:**
1. Always check resource existence before creating
2. Use `--no-wait` for long-running operations when appropriate
3. Use `--query` to extract specific values (e.g., IDs, IPs)
4. Use `--output table` for human-readable output
5. Use `-o tsv` for script-friendly single values
6. Always specify `--resource-group` to avoid ambiguity
7. Use `--debug` for troubleshooting command issues
8. Prefer idempotent operations (check-then-create)
9. Use resource IDs over names when available (more specific)
10. Use service tags in NSG rules instead of hardcoded IPs

**Resource naming conventions for AVD:**
- Resource groups: `RG-<project>-<env>-<number>`
- VNets: `vnet-<purpose>-<env>`
- Subnets: `snet-<purpose>`
- NSGs: `nsg-<purpose>`
- VMs: `<prefix>-<pool>-<number>`
- Storage: `<purpose><random>` (lowercase, no hyphens)
- Host pools: `Pool-<type>-<env>`
- Workspaces: `AVD-Workspace-<env>`

**Common locations:**
- `eastus`, `eastus2`, `westus`, `westus2`, `centralus`
- `northeurope`, `westeurope`
- `uksouth`, `ukwest`
- `australiaeast`, `australiasoutheast`

