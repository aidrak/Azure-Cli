# Step 02 - Storage Commands Reference

Quick reference for all Azure CLI commands used in storage setup.

## Prerequisites

```bash
# Ensure authenticated
az account show

# Set subscription (if needed)
az account set --subscription "<subscription-id>"

# Variables for reference
RG="RG-Azure-VDI-01"
LOCATION="centralus"
STORAGE_ACCOUNT="myfslogixsa"  # Must be 3-24 chars, alphanumeric lowercase
```

## Storage Account Operations

### Create Premium Files Storage Account

```bash
# Create storage account for FSLogix profiles
az storage account create \
  --resource-group "RG-Azure-VDI-01" \
  --name "avdfslogix001" \
  --location "centralus" \
  --sku "Premium_LRS" \
  --kind "FileStorage" \
  --access-tier "Premium" \
  --https-only true
```

**Parameters:**
- `--sku`: "Premium_LRS" for Premium Files, "Standard_GRS" for general
- `--kind`: "FileStorage" for Premium Files, "StorageV2" for standard
- `--access-tier`: "Premium" or "Hot"

### Show Storage Account Details

```bash
az storage account show \
  --resource-group "RG-Azure-VDI-01" \
  --name "avdfslogix001" \
  --output json
```

### Get Storage Account Connection String

```bash
az storage account show-connection-string \
  --resource-group "RG-Azure-VDI-01" \
  --name "avdfslogix001" \
  --output tsv
```

### Update Storage Account (HTTPS only)

```bash
az storage account update \
  --resource-group "RG-Azure-VDI-01" \
  --name "avdfslogix001" \
  --https-only true
```

## File Share Operations

### Create File Share

```bash
# Create premium file share for FSLogix
az storage share create \
  --account-name "avdfslogix001" \
  --name "fslogix-profiles" \
  --quota 1024 \
  --enabled-protocols "SMB"
```

**Parameters:**
- `--quota`: Size in GB
- `--enabled-protocols`: "SMB" or "NFS"

### List File Shares

```bash
az storage share list \
  --account-name "avdfslogix001" \
  --output table
```

### Show File Share Details

```bash
az storage share show \
  --account-name "avdfslogix001" \
  --name "fslogix-profiles" \
  --output json
```

### Delete File Share

```bash
az storage share delete \
  --account-name "avdfslogix001" \
  --name "fslogix-profiles"
```

## Storage Account Key Operations

### Get Storage Account Keys

```bash
# Get primary key
az storage account keys list \
  --resource-group "RG-Azure-VDI-01" \
  --account-name "avdfslogix001" \
  --output table

# Get specific key in TSV format
az storage account keys list \
  --resource-group "RG-Azure-VDI-01" \
  --account-name "avdfslogix001" \
  --query "[0].value" \
  --output tsv
```

### Regenerate Storage Account Key

```bash
az storage account keys renew \
  --resource-group "RG-Azure-VDI-01" \
  --account-name "avdfslogix001" \
  --key "primary"
```

## Private Endpoint Operations

### Create Private Endpoint

```bash
az network private-endpoint create \
  --resource-group "RG-Azure-VDI-01" \
  --name "pe-storage" \
  --vnet-name "avd-vnet" \
  --subnet "private-endpoints" \
  --private-connection-resource-id "/subscriptions/<sub-id>/resourceGroups/RG-Azure-VDI-01/providers/Microsoft.Storage/storageAccounts/avdfslogix001" \
  --group-ids "file" \
  --connection-name "pe-storage-connection"
```

**Parameters:**
- `--group-ids`: "file" for File Shares, "blob" for Blob, etc.
- `--private-connection-resource-id`: Full resource ID of storage account

### List Private Endpoints

```bash
az network private-endpoint list \
  --resource-group "RG-Azure-VDI-01" \
  --output table
```

### Show Private Endpoint Details

```bash
az network private-endpoint show \
  --resource-group "RG-Azure-VDI-01" \
  --name "pe-storage"
```

## Private DNS Zone Operations

### Create Private DNS Zone for Storage

```bash
# Create private DNS zone
az network private-dns zone create \
  --resource-group "RG-Azure-VDI-01" \
  --name "privatelink.file.core.windows.net"
```

### Link VNet to Private DNS Zone

```bash
az network private-dns link vnet create \
  --resource-group "RG-Azure-VDI-01" \
  --zone-name "privatelink.file.core.windows.net" \
  --name "avd-vnet-link" \
  --virtual-network "avd-vnet" \
  --registration-enabled false
```

### Create A Record in Private DNS

```bash
az network private-dns record-set a create \
  --resource-group "RG-Azure-VDI-01" \
  --zone-name "privatelink.file.core.windows.net" \
  --name "avdfslogix001"

az network private-dns record-set a add-record \
  --resource-group "RG-Azure-VDI-01" \
  --zone-name "privatelink.file.core.windows.net" \
  --record-set-name "avdfslogix001" \
  --ipv4-address "10.0.2.10"
```

### List Private DNS Records

```bash
az network private-dns record-set list \
  --resource-group "RG-Azure-VDI-01" \
  --zone-name "privatelink.file.core.windows.net"
```

## Entra ID Kerberos Authentication

### Enable Kerberos on Storage Account

```bash
# Note: Requires Azure CLI 2.45.0+

# First, get the storage account ID
STORAGE_ID=$(az storage account show \
  --resource-group "RG-Azure-VDI-01" \
  --name "avdfslogix001" \
  --query id -o tsv)

# Enable Kerberos authentication (via Azure PowerShell or REST API)
# See Step 02 task scripts for implementation details
```

**Note:** Azure CLI has limited support for Kerberos configuration. Use PowerShell or REST API for full control:

```powershell
# PowerShell alternative
Set-AzStorageAccount -ResourceGroupName "RG-Azure-VDI-01" \
  -Name "avdfslogix001" \
  -EnableAzureActiveDirectoryKerberos $true
```

## Common Patterns

### Check if Storage Account Exists

```bash
az storage account show \
  --resource-group "RG-Azure-VDI-01" \
  --name "avdfslogix001" &>/dev/null && echo "exists" || echo "not found"
```

### Check if File Share Exists

```bash
az storage share exists \
  --account-name "avdfslogix001" \
  --name "fslogix-profiles" \
  --output json
```

### Get Storage Account ID

```bash
az storage account show \
  --resource-group "RG-Azure-VDI-01" \
  --name "avdfslogix001" \
  --query id -o tsv
```

### Mount File Share on Linux (for reference)

```bash
# Install CIFS utilities
sudo apt-get install cifs-utils

# Mount file share
STORAGE_KEY=$(az storage account keys list \
  --resource-group "RG-Azure-VDI-01" \
  --account-name "avdfslogix001" \
  --query "[0].value" -o tsv)

sudo mount -t cifs \
  "//avdfslogix001.file.core.windows.net/fslogix-profiles" \
  "/mnt/fslogix" \
  -o "username=Azure\avdfslogix001,password=$STORAGE_KEY,vers=3.0,dir_mode=0777,file_mode=0777,cache=strict,actimeo=30"
```

## Troubleshooting

### Storage Account Name Already Exists
- Must be globally unique within Azure
- Retry with different name or numeric suffix

### Cannot Create Premium File Share
- Must use "FileStorage" kind and "Premium_LRS" SKU
- Premium Files only available in certain regions

### Private Endpoint Creation Fails
- Ensure subnet exists and is in correct VNet
- Check storage account resource ID format
- Verify permissions on storage account

### Cannot Enable Kerberos
- Requires Azure AD identity on storage account
- May require specific SKU or region
- Check Azure CLI version (2.45.0+)

## References

- [Storage Account Documentation](https://learn.microsoft.com/en-us/azure/storage/common/storage-account-overview)
- [Azure Files Documentation](https://learn.microsoft.com/en-us/azure/storage/files/storage-files-introduction)
- [FSLogix Documentation](https://learn.microsoft.com/en-us/fslogix/overview-what-is-fslogix)
- [Kerberos Authentication for Azure Files](https://learn.microsoft.com/en-us/azure/storage/files/storage-files-identity-auth-active-directory-enable)
- [Private Endpoints](https://learn.microsoft.com/en-us/azure/private-link/private-endpoint-overview)
