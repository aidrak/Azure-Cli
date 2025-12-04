# Step 01 - Networking Commands Reference

Quick reference for all Azure CLI commands used in networking setup.

## Prerequisites

```bash
# Login to Azure
az login

# Set subscription
az account set --subscription "<subscription-id>"

# Create resource group (if needed)
az group create \
  --name "RG-Azure-VDI-01" \
  --location "centralus"
```

## VNet Operations

### Create Virtual Network

```bash
az network vnet create \
  --resource-group "RG-Azure-VDI-01" \
  --name "avd-vnet" \
  --address-prefix "10.0.0.0/16" \
  --location "centralus"
```

**Parameters:**
- `--address-prefix`: VNet address space (CIDR notation)
- `--location`: Azure region

### Create Subnet

```bash
# Session hosts subnet
az network vnet subnet create \
  --resource-group "RG-Azure-VDI-01" \
  --vnet-name "avd-vnet" \
  --name "session-hosts" \
  --address-prefix "10.0.1.0/24"

# Private endpoints subnet
az network vnet subnet create \
  --resource-group "RG-Azure-VDI-01" \
  --vnet-name "avd-vnet" \
  --name "private-endpoints" \
  --address-prefix "10.0.2.0/24"

# File server subnet
az network vnet subnet create \
  --resource-group "RG-Azure-VDI-01" \
  --vnet-name "avd-vnet" \
  --name "file-servers" \
  --address-prefix "10.0.3.0/24"
```

**Parameters:**
- `--address-prefix`: Subnet CIDR block
- Must be within VNet address space

### Get VNet Details

```bash
# Show VNet info
az network vnet show \
  --resource-group "RG-Azure-VDI-01" \
  --name "avd-vnet"

# List all subnets
az network vnet subnet list \
  --resource-group "RG-Azure-VDI-01" \
  --vnet-name "avd-vnet"

# Get subnet info
az network vnet subnet show \
  --resource-group "RG-Azure-VDI-01" \
  --vnet-name "avd-vnet" \
  --name "session-hosts"
```

## NSG (Network Security Group) Operations

### Create Network Security Group

```bash
az network nsg create \
  --resource-group "RG-Azure-VDI-01" \
  --name "nsg-session-hosts" \
  --location "centralus"
```

### Add NSG Rules

```bash
# Allow RDP inbound (from admin subnet only)
az network nsg rule create \
  --resource-group "RG-Azure-VDI-01" \
  --nsg-name "nsg-session-hosts" \
  --name "allow-rdp" \
  --priority 100 \
  --source-address-prefixes "10.0.4.0/24" \
  --source-port-ranges "*" \
  --destination-address-prefixes "*" \
  --destination-port-ranges "3389" \
  --access "Allow" \
  --protocol "Tcp"

# Allow DNS outbound
az network nsg rule create \
  --resource-group "RG-Azure-VDI-01" \
  --nsg-name "nsg-session-hosts" \
  --name "allow-dns" \
  --priority 200 \
  --source-address-prefixes "*" \
  --source-port-ranges "*" \
  --destination-address-prefixes "*" \
  --destination-port-ranges "53" \
  --access "Allow" \
  --protocol "Udp"

# Allow HTTPS outbound
az network nsg rule create \
  --resource-group "RG-Azure-VDI-01" \
  --nsg-name "nsg-session-hosts" \
  --name "allow-https" \
  --priority 201 \
  --source-address-prefixes "*" \
  --source-port-ranges "*" \
  --destination-address-prefixes "*" \
  --destination-port-ranges "443" \
  --access "Allow" \
  --protocol "Tcp"

# Allow WinRM (5985, 5986) for remote management
az network nsg rule create \
  --resource-group "RG-Azure-VDI-01" \
  --nsg-name "nsg-session-hosts" \
  --name "allow-winrm" \
  --priority 210 \
  --source-address-prefixes "10.0.0.0/16" \
  --source-port-ranges "*" \
  --destination-address-prefixes "*" \
  --destination-port-ranges "5985" "5986" \
  --access "Allow" \
  --protocol "Tcp"
```

**Common Rule Parameters:**
- `--priority`: 100-4096 (lower = higher priority)
- `--access`: "Allow" or "Deny"
- `--protocol`: "Tcp", "Udp", "*"
- `--source-port-ranges`: "*" or specific ports like "3389"

### Associate NSG with Subnet

```bash
az network vnet subnet update \
  --resource-group "RG-Azure-VDI-01" \
  --vnet-name "avd-vnet" \
  --name "session-hosts" \
  --network-security-group "nsg-session-hosts"
```

### List NSG Rules

```bash
az network nsg rule list \
  --resource-group "RG-Azure-VDI-01" \
  --nsg-name "nsg-session-hosts"
```

### Delete NSG Rule

```bash
az network nsg rule delete \
  --resource-group "RG-Azure-VDI-01" \
  --nsg-name "nsg-session-hosts" \
  --name "allow-rdp"
```

## Common Patterns

### Check if VNet exists

```bash
az network vnet show \
  --resource-group "RG-Azure-VDI-01" \
  --name "avd-vnet" &>/dev/null && echo "exists" || echo "not found"
```

### Get VNet ID

```bash
az network vnet show \
  --resource-group "RG-Azure-VDI-01" \
  --name "avd-vnet" \
  --query id -o tsv
```

### Get Subnet CIDR

```bash
az network vnet subnet show \
  --resource-group "RG-Azure-VDI-01" \
  --vnet-name "avd-vnet" \
  --name "session-hosts" \
  --query "addressPrefix" -o tsv
```

### List all resources by type

```bash
# List all VNets in resource group
az network vnet list \
  --resource-group "RG-Azure-VDI-01"

# List all NSGs in resource group
az network nsg list \
  --resource-group "RG-Azure-VDI-01"
```

## Useful Flags

- `--output json`: Output as JSON (useful for parsing)
- `--output table`: Output as table (default)
- `--output tsv`: Tab-separated values (useful for scripts)
- `--query`: JMESPath query to extract specific fields

## Example: Complete Scripting Pattern

```bash
#!/bin/bash

# Set variables
RG="RG-Azure-VDI-01"
LOCATION="centralus"
VNET_NAME="avd-vnet"
VNET_CIDR="10.0.0.0/16"

# Create resource group
az group create --name "$RG" --location "$LOCATION"

# Create VNet
az network vnet create \
  --resource-group "$RG" \
  --name "$VNET_NAME" \
  --address-prefix "$VNET_CIDR" \
  --location "$LOCATION"

# Create subnets
az network vnet subnet create \
  --resource-group "$RG" \
  --vnet-name "$VNET_NAME" \
  --name "session-hosts" \
  --address-prefix "10.0.1.0/24"

# Create NSG
az network nsg create \
  --resource-group "$RG" \
  --name "nsg-session-hosts" \
  --location "$LOCATION"

# Associate NSG with subnet
az network vnet subnet update \
  --resource-group "$RG" \
  --vnet-name "$VNET_NAME" \
  --name "session-hosts" \
  --network-security-group "nsg-session-hosts"

# Get VNet ID for later use
VNET_ID=$(az network vnet show \
  --resource-group "$RG" \
  --name "$VNET_NAME" \
  --query id -o tsv)

echo "VNet created: $VNET_ID"
```

## Troubleshooting

### NSG Rule Already Exists
- Delete existing rule first: `az network nsg rule delete ...`
- Or modify with `az network nsg rule update ...`

### Subnet Creation Failed
- Check CIDR is within VNet address space
- Check subnet name doesn't already exist
- Verify permissions on resource group

### VNet Show Returns Empty
- Verify resource group exists
- Check correct region/subscription
- Confirm VNet name spelling

## References

- [Azure CLI Network Documentation](https://learn.microsoft.com/cli/azure/network)
- [VNet Design Best Practices](https://learn.microsoft.com/en-us/azure/virtual-network/virtual-network-vnet-plan-design-arm)
- [Network Security Groups](https://learn.microsoft.com/en-us/azure/virtual-network/network-security-groups-overview)
