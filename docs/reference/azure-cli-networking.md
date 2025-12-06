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


```bash
# Create VNet peering
az network vnet peering create \
  --resource-group <rg-name> \
  --name <peering-name> \
  --vnet-name <vnet-name> \
  --remote-vnet <remote-vnet-id> \
  --allow-vnet-access \
  --allow-forwarded-traffic

# Create VNet peering with gateway transit
az network vnet peering create \
  --resource-group <rg-name> \
  --name <peering-name> \
  --vnet-name <vnet-name> \
  --remote-vnet <remote-vnet-id> \
  --allow-vnet-access \
  --allow-forwarded-traffic \
  --allow-gateway-transit

# Create VNet peering using remote gateways
az network vnet peering create \
  --resource-group <rg-name> \
  --name <peering-name> \
  --vnet-name <vnet-name> \
  --remote-vnet <remote-vnet-id> \
  --allow-vnet-access \
  --allow-forwarded-traffic \
  --use-remote-gateways

# List VNet peerings
az network vnet peering list \
  --resource-group <rg-name> \
  --vnet-name <vnet-name> \
  --output table

# Show VNet peering
az network vnet peering show \
  --resource-group <rg-name> \
  --vnet-name <vnet-name> \
  --name <peering-name>

# Delete VNet peering
az network vnet peering delete \
  --resource-group <rg-name> \
  --vnet-name <vnet-name> \
  --name <peering-name>
```

---

## Networking - Public IPs

```bash
# Create public IP
az network public-ip create \
  --resource-group <rg-name> \
  --name <pip-name> \
  --location <location> \
  --sku Standard \
  --allocation-method Static

# Show public IP
az network public-ip show \
  --resource-group <rg-name> \
  --name <pip-name>

# List public IPs
az network public-ip list \
  --resource-group <rg-name> \
  --output table

# Delete public IP
az network public-ip delete \
  --resource-group <rg-name> \
  --name <pip-name>

# Get public IP address
az network public-ip show \
  --resource-group <rg-name> \
  --name <pip-name> \
  --query ipAddress -o tsv
```

---

## Networking - Network Interfaces (NICs)

```bash
# Create NIC
az network nic create \
  --resource-group <rg-name> \
  --name <nic-name> \
  --vnet-name <vnet-name> \
  --subnet <subnet-name> \
  --location <location>

# Create NIC with static private IP
az network nic create \
  --resource-group <rg-name> \
  --name <nic-name> \
  --vnet-name <vnet-name> \
  --subnet <subnet-name> \
  --private-ip-address <ip-address>

# Create NIC with public IP
az network nic create \
  --resource-group <rg-name> \
  --name <nic-name> \
  --vnet-name <vnet-name> \
  --subnet <subnet-name> \
  --public-ip-address <pip-name>

# Show NIC
az network nic show \
  --resource-group <rg-name> \
  --name <nic-name>

# List NICs
az network nic list \
  --resource-group <rg-name> \
  --output table

# Delete NIC
az network nic delete \
  --resource-group <rg-name> \
  --name <nic-name>
```

---

## Networking - Private Endpoints

```bash
# Create private endpoint
az network private-endpoint create \
  --resource-group <rg-name> \
  --name <pe-name> \
  --vnet-name <vnet-name> \
  --subnet <subnet-name> \
  --private-connection-resource-id <resource-id> \
  --group-id <sub-resource> \
  --connection-name <connection-name>

# List private endpoints
az network private-endpoint list \
  --resource-group <rg-name> \
  --output table

# Delete private endpoint
az network private-endpoint delete \
  --resource-group <rg-name> \
  --name <pe-name>
```

---

## Networking - Private DNS Zones

```bash
# Create private DNS zone
az network private-dns zone create \
  --resource-group <rg-name> \
  --name <zone-name>

# Link private DNS zone to VNet
az network private-dns link vnet create \
  --resource-group <rg-name> \
  --zone-name <zone-name> \
  --name <link-name> \
  --virtual-network <vnet-name> \
  --registration-enabled false

# List private DNS zones
az network private-dns zone list \
  --resource-group <rg-name> \
  --output table

# Delete private DNS zone
az network private-dns zone delete \
  --resource-group <rg-name> \
  --name <zone-name>
```

---

