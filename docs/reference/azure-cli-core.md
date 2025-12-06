# Azure CLI Reference - Core Commands

Authentication, account management, and resource group operations.

> **Part of Azure CLI Reference Series:**
> - **Core** (this file) - Auth, Resource Groups
> - [Networking](azure-cli-networking.md) - VNets, Subnets, NSGs
> - [Storage](azure-cli-storage.md) - Storage Accounts, File Shares
> - [Compute](azure-cli-compute.md) - VMs, Disks, Images
> - [AVD](azure-cli-avd.md) - Host Pools, Workspaces
> - [Identity](azure-cli-identity.md) - RBAC, Entra ID
> - [Management](azure-cli-management.md) - Monitoring, Tags, Locks

---

## Authentication & Account Management

```bash
# Login to Azure
az login

# Login with service principal
az login --service-principal -u <app-id> -p <password-or-cert> --tenant <tenant-id>

# Set active subscription
az account set --subscription <subscription-id>

# Show current account/subscription
az account show

# List all subscriptions
az account list --output table

# Get subscription ID
az account show --query id -o tsv

# Get tenant ID
az account show --query tenantId -o tsv
```

---

## Resource Groups

```bash
# Create resource group
az group create --name <rg-name> --location <location>

# Show resource group details
az group show --name <rg-name>

# List all resource groups
az group list --output table

# Delete resource group
az group delete --name <rg-name> --yes --no-wait

# Check if resource group exists
az group exists --name <rg-name>

# List resources in resource group
az resource list --resource-group <rg-name> --output table

# Export resource group as template
az group export --name <rg-name> --output json
```
