# Azure CLI Reference - Compute

Virtual Machines, Disks, and Image Galleries.

> **Part of Azure CLI Reference Series:**
> - [Core](azure-cli-core.md) - Auth, Resource Groups
> - [Networking](azure-cli-networking.md) - VNets, Subnets, NSGs
> - [Storage](azure-cli-storage.md) - Storage Accounts, File Shares
> - **Compute** (this file) - VMs, Disks, Images
> - [AVD](azure-cli-avd.md) - Host Pools, Workspaces
> - [Identity](azure-cli-identity.md) - RBAC, Entra ID
> - [Management](azure-cli-management.md) - Monitoring, Tags, Locks

---

## Virtual Machines

```bash
# Create VM (Windows)
az vm create \
  --resource-group <rg-name> \
  --name <vm-name> \
  --image <image-urn> \
  --size <vm-size> \
  --admin-username <username> \
  --admin-password <password> \
  --vnet-name <vnet-name> \
  --subnet <subnet-name>

# Create VM with existing NIC
az vm create \
  --resource-group <rg-name> \
  --name <vm-name> \
  --nics <nic-name> \
  --image <image-urn> \
  --size <vm-size> \
  --admin-username <username> \
  --admin-password <password>

# Create VM without public IP
az vm create \
  --resource-group <rg-name> \
  --name <vm-name> \
  --image <image-urn> \
  --size <vm-size> \
  --admin-username <username> \
  --admin-password <password> \
  --vnet-name <vnet-name> \
  --subnet <subnet-name> \
  --public-ip-address ""

# Show VM details
az vm show \
  --resource-group <rg-name> \
  --name <vm-name>

# List VMs
az vm list --resource-group <rg-name> --output table

# Get VM public IP
az vm show \
  --resource-group <rg-name> \
  --name <vm-name> \
  --show-details \
  --query publicIps -o tsv

# Get VM private IP
az vm show \
  --resource-group <rg-name> \
  --name <vm-name> \
  --show-details \
  --query privateIps -o tsv

# Start VM
az vm start \
  --resource-group <rg-name> \
  --name <vm-name>

# Stop VM (deallocate)
az vm deallocate \
  --resource-group <rg-name> \
  --name <vm-name>

# Restart VM
az vm restart \
  --resource-group <rg-name> \
  --name <vm-name>

# Delete VM
az vm delete \
  --resource-group <rg-name> \
  --name <vm-name> \
  --yes

# Generalize VM (for image capture)
az vm generalize \
  --resource-group <rg-name> \
  --name <vm-name>

# Run command on VM
az vm run-command invoke \
  --resource-group <rg-name> \
  --name <vm-name> \
  --command-id RunPowerShellScript \
  --scripts "<powershell-script>"

# List VM sizes available in location
az vm list-sizes --location <location> --output table

# List VM images
az vm image list --output table

# List VM images for specific publisher
az vm image list \
  --publisher MicrosoftWindowsDesktop \
  --all \
  --output table
```

---

## VM Disks

```bash
# Create managed disk
az disk create \
  --resource-group <rg-name> \
  --name <disk-name> \
  --size-gb <size> \
  --sku Premium_LRS

# Show disk
az disk show \
  --resource-group <rg-name> \
  --name <disk-name>

# List disks
az disk list \
  --resource-group <rg-name> \
  --output table

# List orphaned disks (not attached to VMs)
az disk list \
  --resource-group <rg-name> \
  --query "[?managedBy==null]" \
  --output table

# Delete disk
az disk delete \
  --resource-group <rg-name> \
  --name <disk-name> \
  --yes

# Attach disk to VM
az vm disk attach \
  --resource-group <rg-name> \
  --vm-name <vm-name> \
  --name <disk-name>

# Detach disk from VM
az vm disk detach \
  --resource-group <rg-name> \
  --vm-name <vm-name> \
  --name <disk-name>
```

---

## Azure Compute Gallery (Shared Image Gallery)

```bash
# Create Azure Compute Gallery
az sig create \
  --resource-group <rg-name> \
  --gallery-name <gallery-name>

# Create image definition
az sig image-definition create \
  --resource-group <rg-name> \
  --gallery-name <gallery-name> \
  --gallery-image-definition <image-def-name> \
  --publisher <publisher-name> \
  --offer <offer-name> \
  --sku <sku-name> \
  --os-type Windows \
  --os-state Generalized \
  --hyper-v-generation V2

# Create image version from VM
az sig image-version create \
  --resource-group <rg-name> \
  --gallery-name <gallery-name> \
  --gallery-image-definition <image-def-name> \
  --gallery-image-version <version> \
  --managed-image <vm-id-or-name>

# List galleries
az sig list --resource-group <rg-name> --output table

# List image definitions
az sig image-definition list \
  --resource-group <rg-name> \
  --gallery-name <gallery-name> \
  --output table

# List image versions
az sig image-version list \
  --resource-group <rg-name> \
  --gallery-name <gallery-name> \
  --gallery-image-definition <image-def-name> \
  --output table

# Show image version
az sig image-version show \
  --resource-group <rg-name> \
  --gallery-name <gallery-name> \
  --gallery-image-definition <image-def-name> \
  --gallery-image-version <version>

# Delete image version
az sig image-version delete \
  --resource-group <rg-name> \
  --gallery-name <gallery-name> \
  --gallery-image-definition <image-def-name> \
  --gallery-image-version <version>
```

---

