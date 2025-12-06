# Azure CLI Reference - Networking

VNets, Subnets, NSGs, Peering, Private Endpoints, and DNS.

> **Part of Azure CLI Reference Series:**
> - [Core](azure-cli-core.md) - Auth, Resource Groups
> - **Networking** (this file) - VNets, Subnets, NSGs
> - [Storage](azure-cli-storage.md) - Storage Accounts, File Shares
> - [Compute](azure-cli-compute.md) - VMs, Disks, Images
> - [AVD](azure-cli-avd.md) - Host Pools, Workspaces
> - [Identity](azure-cli-identity.md) - RBAC, Entra ID
> - [Management](azure-cli-management.md) - Monitoring, Tags, Locks

---

## Networking - Virtual Networks

```bash
# Create VNet
az network vnet create \
  --resource-group <rg-name> \
  --name <vnet-name> \
  --address-prefixes <cidr> \
  --location <location>

# Create VNet with subnet
az network vnet create \
  --resource-group <rg-name> \
  --name <vnet-name> \
  --address-prefixes <cidr> \
  --subnet-name <subnet-name> \
  --subnet-prefixes <subnet-cidr>

# Show VNet details
az network vnet show \
  --resource-group <rg-name> \
  --name <vnet-name>

# List VNets
az network vnet list --resource-group <rg-name> --output table

# Delete VNet
az network vnet delete \
  --resource-group <rg-name> \
  --name <vnet-name>

# Get VNet ID
az network vnet show \
  --resource-group <rg-name> \
  --name <vnet-name> \
  --query id -o tsv

# Update VNet (add address space)
az network vnet update \
  --resource-group <rg-name> \
  --name <vnet-name> \
  --address-prefixes <cidr1> <cidr2>
```

---

## Networking - Subnets

```bash
# Create subnet
az network vnet subnet create \
  --resource-group <rg-name> \
  --vnet-name <vnet-name> \
  --name <subnet-name> \
  --address-prefixes <subnet-cidr>

# Create subnet with NSG
az network vnet subnet create \
  --resource-group <rg-name> \
  --vnet-name <vnet-name> \
  --name <subnet-name> \
  --address-prefixes <subnet-cidr> \
  --network-security-group <nsg-name>

# Show subnet details
az network vnet subnet show \
  --resource-group <rg-name> \
  --vnet-name <vnet-name> \
  --name <subnet-name>

# List subnets
az network vnet subnet list \
  --resource-group <rg-name> \
  --vnet-name <vnet-name> \
  --output table

# Update subnet (attach NSG)
az network vnet subnet update \
  --resource-group <rg-name> \
  --vnet-name <vnet-name> \
  --name <subnet-name> \
  --network-security-group <nsg-name>

# Delete subnet
az network vnet subnet delete \
  --resource-group <rg-name> \
  --vnet-name <vnet-name> \
  --name <subnet-name>

# Disable private endpoint network policies
az network vnet subnet update \
  --resource-group <rg-name> \
  --vnet-name <vnet-name> \
  --name <subnet-name> \
  --disable-private-endpoint-network-policies true
```

---

## Networking - Network Security Groups (NSGs)

```bash
# Create NSG
az network nsg create \
  --resource-group <rg-name> \
  --name <nsg-name> \
  --location <location>

# Show NSG details
az network nsg show \
  --resource-group <rg-name> \
  --name <nsg-name>

# List NSGs
az network nsg list --resource-group <rg-name> --output table

# Delete NSG
az network nsg delete \
  --resource-group <rg-name> \
  --name <nsg-name>
```

---

## Networking - NSG Rules

```bash
# Create NSG rule (inbound)
az network nsg rule create \
  --resource-group <rg-name> \
  --nsg-name <nsg-name> \
  --name <rule-name> \
  --priority <100-4096> \
  --source-address-prefixes <cidr-or-tag> \
  --destination-address-prefixes <cidr-or-tag> \
  --destination-port-ranges <port-or-range> \
  --protocol <Tcp|Udp|*> \
  --access <Allow|Deny> \
  --direction Inbound

# Create NSG rule (outbound)
az network nsg rule create \
  --resource-group <rg-name> \
  --nsg-name <nsg-name> \
  --name <rule-name> \
  --priority <100-4096> \
  --direction Outbound \
  --source-address-prefixes <cidr-or-tag> \
  --destination-address-prefixes <cidr-or-tag> \
  --destination-port-ranges <port-or-range> \
  --protocol <Tcp|Udp|*> \
  --access <Allow|Deny>

# List NSG rules
az network nsg rule list \
  --resource-group <rg-name> \
  --nsg-name <nsg-name> \
  --output table

# Show NSG rule
az network nsg rule show \
  --resource-group <rg-name> \
  --nsg-name <nsg-name> \
  --name <rule-name>

# Delete NSG rule
az network nsg rule delete \
  --resource-group <rg-name> \
  --nsg-name <nsg-name> \
  --name <rule-name>
```

---

## Networking - VNet Peering
