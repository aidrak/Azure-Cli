# Azure CLI Command Reference for AVD Deployments

This document provides a comprehensive list of Azure CLI commands relevant to Azure Virtual Desktop (AVD) deployments. AI assistants and users can reference these commands when working with AVD infrastructure.

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

## Azure Virtual Desktop (AVD) - Desktop Virtualization

```bash
# Create workspace
az desktopvirtualization workspace create \
  --resource-group <rg-name> \
  --name <workspace-name> \
  --location <location> \
  --friendly-name "<Friendly Name>"

# Create host pool (Pooled)
az desktopvirtualization hostpool create \
  --resource-group <rg-name> \
  --name <hostpool-name> \
  --location <location> \
  --host-pool-type Pooled \
  --load-balancer-type BreadthFirst \
  --max-session-limit 10 \
  --preferred-app-group-type Desktop

# Create host pool (Personal)
az desktopvirtualization hostpool create \
  --resource-group <rg-name> \
  --name <hostpool-name> \
  --location <location> \
  --host-pool-type Personal \
  --load-balancer-type Persistent \
  --preferred-app-group-type Desktop

# Create application group (Desktop)
az desktopvirtualization applicationgroup create \
  --resource-group <rg-name> \
  --name <appgroup-name> \
  --location <location> \
  --application-group-type Desktop \
  --host-pool-arm-path <hostpool-id>

# Create application group (RemoteApp)
az desktopvirtualization applicationgroup create \
  --resource-group <rg-name> \
  --name <appgroup-name> \
  --location <location> \
  --application-group-type RemoteApp \
  --host-pool-arm-path <hostpool-id>

# Add application to RemoteApp group
az desktopvirtualization application create \
  --resource-group <rg-name> \
  --application-group-name <appgroup-name> \
  --name <app-name> \
  --file-path "<C:\Path\To\App.exe>" \
  --command-line-arguments "<args>" \
  --icon-path "<icon-path>" \
  --icon-index 0

# Register application group to workspace
az desktopvirtualization workspace update \
  --resource-group <rg-name> \
  --name <workspace-name> \
  --application-group-references <appgroup-id>

# List workspaces
az desktopvirtualization workspace list \
  --resource-group <rg-name> \
  --output table

# List host pools
az desktopvirtualization hostpool list \
  --resource-group <rg-name> \
  --output table

# List application groups
az desktopvirtualization applicationgroup list \
  --resource-group <rg-name> \
  --output table

# List session hosts
az desktopvirtualization sessionhost list \
  --resource-group <rg-name> \
  --host-pool-name <hostpool-name> \
  --output table

# Show session host
az desktopvirtualization sessionhost show \
  --resource-group <rg-name> \
  --host-pool-name <hostpool-name> \
  --name <session-host-name>

# Delete session host
az desktopvirtualization sessionhost delete \
  --resource-group <rg-name> \
  --host-pool-name <hostpool-name> \
  --name <session-host-name>

# Get host pool registration token
az desktopvirtualization hostpool update \
  --resource-group <rg-name> \
  --name <hostpool-name> \
  --registration-info expiration-time="<iso-timestamp>" registration-token-operation="Update"
```

---

## AVD - Scaling Plans

```bash
# Create scaling plan
az desktopvirtualization scaling-plan create \
  --resource-group <rg-name> \
  --name <scaling-plan-name> \
  --location <location> \
  --time-zone "<Time Zone>" \
  --host-pool-type Pooled

# Show scaling plan
az desktopvirtualization scaling-plan show \
  --resource-group <rg-name> \
  --name <scaling-plan-name>

# List scaling plans
az desktopvirtualization scaling-plan list \
  --resource-group <rg-name> \
  --output table

# Delete scaling plan
az desktopvirtualization scaling-plan delete \
  --resource-group <rg-name> \
  --name <scaling-plan-name>
```

---

## Role-Based Access Control (RBAC)

```bash
# List role definitions
az role definition list --output table

# Show specific role definition
az role definition list \
  --name "Desktop Virtualization User" \
  --output json

# Create role assignment (user to resource group)
az role assignment create \
  --assignee <user-principal-name> \
  --role "Desktop Virtualization User" \
  --resource-group <rg-name>

# Create role assignment (group to application group)
az role assignment create \
  --assignee <group-object-id> \
  --role "Desktop Virtualization User" \
  --scope <application-group-id>

# Create role assignment (service principal)
az role assignment create \
  --assignee <service-principal-id> \
  --role "Desktop Virtualization Power On Off Contributor" \
  --scope <subscription-id>

# List role assignments
az role assignment list \
  --resource-group <rg-name> \
  --output table

# List role assignments for user
az role assignment list \
  --assignee <user-principal-name> \
  --output table

# Delete role assignment
az role assignment delete \
  --assignee <principal> \
  --role <role-name> \
  --resource-group <rg-name>
```

---

## Azure Active Directory / Entra ID (requires Azure AD CLI extension)

```bash
# Install Azure AD extension
az extension add --name azure-devops

# List users
az ad user list --output table

# Show user details
az ad user show --id <user-principal-name>

# Create user
az ad user create \
  --display-name "<Display Name>" \
  --user-principal-name <upn> \
  --password <password> \
  --force-change-password-next-sign-in false

# List groups
az ad group list --output table

# Show group details
az ad group show --group <group-name-or-id>

# Create security group
az ad group create \
  --display-name "<Group Name>" \
  --mail-nickname <nickname>

# Add member to group
az ad group member add \
  --group <group-name-or-id> \
  --member-id <user-object-id>

# List group members
az ad group member list \
  --group <group-name-or-id> \
  --output table

# Remove member from group
az ad group member remove \
  --group <group-name-or-id> \
  --member-id <user-object-id>

# List service principals
az ad sp list --output table

# Show service principal
az ad sp show --id <service-principal-id>
```

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

