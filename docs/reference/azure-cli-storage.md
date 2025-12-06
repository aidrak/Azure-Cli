# Azure CLI Reference - Storage

Storage Accounts and File Shares.

> **Part of Azure CLI Reference Series:**
> - [Core](azure-cli-core.md) - Auth, Resource Groups
> - [Networking](azure-cli-networking.md) - VNets, Subnets, NSGs
> - **Storage** (this file) - Storage Accounts, File Shares
> - [Compute](azure-cli-compute.md) - VMs, Disks, Images
> - [AVD](azure-cli-avd.md) - Host Pools, Workspaces
> - [Identity](azure-cli-identity.md) - RBAC, Entra ID
> - [Management](azure-cli-management.md) - Monitoring, Tags, Locks

---

## Storage Accounts

```bash
# Create storage account (Standard)
az storage account create \
  --resource-group <rg-name> \
  --name <storage-account-name> \
  --location <location> \
  --sku Standard_LRS

# Create storage account (Premium Files for FSLogix)
az storage account create \
  --resource-group <rg-name> \
  --name <storage-account-name> \
  --location <location> \
  --sku Premium_LRS \
  --kind FileStorage

# Show storage account
az storage account show \
  --resource-group <rg-name> \
  --name <storage-account-name>

# List storage accounts
az storage account list \
  --resource-group <rg-name> \
  --output table

# Delete storage account
az storage account delete \
  --resource-group <rg-name> \
  --name <storage-account-name> \
  --yes

# Get storage account key
az storage account keys list \
  --resource-group <rg-name> \
  --account-name <storage-account-name> \
  --query "[0].value" -o tsv

# Get storage account connection string
az storage account show-connection-string \
  --resource-group <rg-name> \
  --name <storage-account-name> \
  --query connectionString -o tsv

# Update storage account (enable HTTPS only)
az storage account update \
  --resource-group <rg-name> \
  --name <storage-account-name> \
  --https-only true

# Disable public network access
az storage account update \
  --resource-group <rg-name> \
  --name <storage-account-name> \
  --public-network-access Disabled
```

---

## Storage - File Shares

```bash
# Create file share
az storage share create \
  --account-name <storage-account-name> \
  --name <share-name> \
  --quota <size-in-gb>

# Create file share (Premium with specific quota)
az storage share create \
  --account-name <storage-account-name> \
  --name <share-name> \
  --quota 1024

# List file shares
az storage share list \
  --account-name <storage-account-name> \
  --output table

# Show file share
az storage share show \
  --account-name <storage-account-name> \
  --name <share-name>

# Delete file share
az storage share delete \
  --account-name <storage-account-name> \
  --name <share-name>

# Update file share quota
az storage share update \
  --account-name <storage-account-name> \
  --name <share-name> \
  --quota <new-size-in-gb>
```

---

