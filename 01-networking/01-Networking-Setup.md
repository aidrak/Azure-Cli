# Networking Setup for AVD

**Purpose:** Create AVD spoke VNet with subnets, NSGs, and peer to existing hub VNet

**Prerequisites:**
- Existing hub VNet with VPN gateway to 10 firewalls
- Resource group: `RG-Azure-VDI-01`
- Azure CLI installed and configured

**Architecture:**
```
Hub VNet (10.0.0.0/16) - Existing
└── VPN Gateway to 10 firewalls

AVD Spoke VNet (10.1.0.0/16) - New
├── Session Hosts (10.1.0.0/22) - 1,022 IPs
├── Private Endpoints (10.1.4.0/24) - 251 IPs
└── File Server (10.1.5.0/24) - 251 IPs
```

---

## Automated Deployment (Recommended)

### Using the Automation Script

**Script:** `01-Networking-Setup.sh` (Bash/Azure CLI)

**Prerequisites for script:**
- Azure CLI installed (`az --version`)
- Logged into Azure (`az login`)
- Existing hub VNet details (name, resource group)

**Quick Start:**

```bash
# 1. Make script executable
chmod +x ./01-Networking-Setup.sh

# 2. Run the script with default settings
./01-Networking-Setup.sh

# 3. Or customize parameters
./01-Networking-Setup.sh \
  --resource-group "RG-Azure-VDI-01" \
  --location "centralus" \
  --vnet-name "vnet-avd-prod" \
  --vnet-prefix "10.1.0.0/16" \
  --hub-rg "RG-HUB" \
  --hub-vnet "vnet-hub-centralus"
```

**What the script does:**
1. Creates AVD spoke VNet with address space 10.1.0.0/16
2. Creates 3 subnets:
   - `snet-avd-sessionhosts`: 10.1.0.0/22 (for session host VMs)
   - `snet-avd-privateendpoints`: 10.1.4.0/24 (for storage private endpoint)
   - `snet-fileserver`: 10.1.5.0/24 (for file server)
3. Creates 3 Network Security Groups with appropriate rules:
   - `nsg-avd-sessionhosts`: Allows AVD Gateway, Azure Cloud, Entra ID, Storage traffic
   - `nsg-avd-privateendpoints`: Allows SMB (445) from session hosts
   - `nsg-fileserver`: Allows SMB (445) from session hosts
4. Attaches NSGs to respective subnets
5. Optional: Creates VNet peering to hub VNet
6. Validates all resources created successfully

**Expected Runtime:** 2-3 minutes

**Verification:**
After running the script, verify creation:
```bash
# Check VNet
az network vnet show --resource-group RG-Azure-VDI-01 --name vnet-avd-prod

# Check subnets
az network vnet subnet list --resource-group RG-Azure-VDI-01 --vnet-name vnet-avd-prod

# Check NSGs
az network nsg list --resource-group RG-Azure-VDI-01

# Check peering (if created)
az network vnet peering list --resource-group RG-Azure-VDI-01 --vnet-name vnet-avd-prod
```

---

## Manual Deployment (Alternative)

### Part 1: Create VNet and Subnets

### Option A: Azure Portal

1. Virtual networks → **+ Create**
2. Resource group: `RG-Azure-VDI-01`
3. Name: `vnet-avd-prod`
4. Region: `Central US`
5. Address space: `10.1.0.0/16`
6. Add 3 subnets:
   - `snet-avd-sessionhosts`: `10.1.0.0/22`
   - `snet-avd-privateendpoints`: `10.1.4.0/24`
   - `snet-fileserver`: `10.1.5.0/24`
7. **Review + create**

### Option B: Azure CLI

```bash
az network vnet create \
  --resource-group RG-Azure-VDI-01 \
  --name vnet-avd-prod \
  --address-prefixes 10.1.0.0/16 \
  --subnet-name snet-avd-sessionhosts \
  --subnet-prefixes 10.1.0.0/22

az network vnet subnet create \
  --resource-group RG-Azure-VDI-01 \
  --vnet-name vnet-avd-prod \
  --name snet-avd-privateendpoints \
  --address-prefixes 10.1.4.0/24

az network vnet subnet create \
  --resource-group RG-Azure-VDI-01 \
  --vnet-name vnet-avd-prod \
  --name snet-fileserver \
  --address-prefixes 10.1.5.0/24
```

---

## Part 2: Create NSGs

### Session Hosts NSG

```bash
# Create NSG
az network nsg create \
  --resource-group RG-Azure-VDI-01 \
  --name nsg-avd-sessionhosts

# Inbound: Allow AVD Gateway
az network nsg rule create \
  --resource-group RG-Azure-VDI-01 \
  --nsg-name nsg-avd-sessionhosts \
  --name Allow-AVD-Gateway \
  --priority 100 \
  --source-address-prefixes WindowsVirtualDesktop \
  --destination-port-ranges "*" \
  --access Allow

# Outbound: Allow AVD Services
az network nsg rule create \
  --resource-group RG-Azure-VDI-01 \
  --nsg-name nsg-avd-sessionhosts \
  --name Allow-AVD-Services \
  --priority 100 \
  --direction Outbound \
  --source-address-prefixes 10.1.0.0/22 \
  --destination-address-prefixes WindowsVirtualDesktop \
  --destination-port-ranges 443 \
  --protocol Tcp

# Outbound: Allow Azure Cloud
az network nsg rule create \
  --resource-group RG-Azure-VDI-01 \
  --nsg-name nsg-avd-sessionhosts \
  --name Allow-Azure-Cloud \
  --priority 110 \
  --direction Outbound \
  --source-address-prefixes 10.1.0.0/22 \
  --destination-address-prefixes AzureCloud \
  --destination-port-ranges 443 \
  --protocol Tcp

# Outbound: Allow Entra ID
az network nsg rule create \
  --resource-group RG-Azure-VDI-01 \
  --nsg-name nsg-avd-sessionhosts \
  --name Allow-Entra-ID \
  --priority 120 \
  --direction Outbound \
  --source-address-prefixes 10.1.0.0/22 \
  --destination-address-prefixes AzureActiveDirectory \
  --destination-port-ranges 443 \
  --protocol Tcp

# Outbound: Allow Storage (Private Endpoint)
az network nsg rule create \
  --resource-group RG-Azure-VDI-01 \
  --nsg-name nsg-avd-sessionhosts \
  --name Allow-Storage \
  --priority 130 \
  --direction Outbound \
  --source-address-prefixes 10.1.0.0/22 \
  --destination-address-prefixes 10.1.4.0/24 \
  --destination-port-ranges 445 \
  --protocol Tcp

# Associate to subnet
az network vnet subnet update \
  --resource-group RG-Azure-VDI-01 \
  --vnet-name vnet-avd-prod \
  --name snet-avd-sessionhosts \
  --network-security-group nsg-avd-sessionhosts
```

### Private Endpoints NSG

```bash
az network nsg create \
  --resource-group RG-Azure-VDI-01 \
  --name nsg-avd-privateendpoints

az network nsg rule create \
  --resource-group RG-Azure-VDI-01 \
  --nsg-name nsg-avd-privateendpoints \
  --name Allow-Session-Hosts \
  --priority 100 \
  --source-address-prefixes 10.1.0.0/22 \
  --destination-port-ranges 445 \
  --protocol Tcp

az network vnet subnet update \
  --resource-group RG-Azure-VDI-01 \
  --vnet-name vnet-avd-prod \
  --name snet-avd-privateendpoints \
  --network-security-group nsg-avd-privateendpoints
```

### File Server NSG

```bash
az network nsg create \
  --resource-group RG-Azure-VDI-01 \
  --name nsg-fileserver

az network nsg rule create \
  --resource-group RG-Azure-VDI-01 \
  --nsg-name nsg-fileserver \
  --name Allow-SMB \
  --priority 100 \
  --source-address-prefixes 10.1.0.0/22 \
  --destination-port-ranges 445 \
  --protocol Tcp

az network vnet subnet update \
  --resource-group RG-Azure-VDI-01 \
  --vnet-name vnet-avd-prod \
  --name snet-fileserver \
  --network-security-group nsg-fileserver
```

---

## Part 3: VNet Peering

```bash
# Get VNet IDs
hubVnetId=$(az network vnet show --resource-group RG-HUB --name vnet-hub-centralus --query id -o tsv)
spokeVnetId=$(az network vnet show --resource-group RG-Azure-VDI-01 --name vnet-avd-prod --query id -o tsv)

# Hub → Spoke
az network vnet peering create \
  --resource-group RG-HUB \
  --name hub-to-avd-spoke \
  --vnet-name vnet-hub-centralus \
  --remote-vnet $spokeVnetId \
  --allow-vnet-access \
  --allow-forwarded-traffic \
  --allow-gateway-transit

# Spoke → Hub
az network vnet peering create \
  --resource-group RG-Azure-VDI-01 \
  --name avd-spoke-to-hub \
  --vnet-name vnet-avd-prod \
  --remote-vnet $hubVnetId \
  --allow-vnet-access \
  --allow-forwarded-traffic \
  --use-remote-gateways
```

---

## Verification

```bash
# Check VNet
az network vnet show --resource-group RG-Azure-VDI-01 --name vnet-avd-prod --query "{Name:name, AddressSpace:addressSpace.addressPrefixes}" -o table

# Check subnets
az network vnet subnet list --resource-group RG-Azure-VDI-01 --vnet-name vnet-avd-prod --query "[].{Name:name, AddressPrefix:addressPrefix}" -o table

# Check peering
az network vnet peering list --resource-group RG-Azure-VDI-01 --vnet-name vnet-avd-prod --query "[].{Name:name, State:peeringState}" -o table
```

---

## Next Steps

1. ✓ Networking infrastructure created
2. ⏭ Create FSLogix storage account (Guide 02)
3. ⏭ Create Entra ID security groups (Guide 03)
4. ⏭ Create host pool and workspace (Guide 04)
