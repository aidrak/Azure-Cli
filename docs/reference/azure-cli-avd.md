# Azure CLI Reference - Azure Virtual Desktop

Host Pools, Workspaces, Application Groups, and Scaling Plans.

> **Part of Azure CLI Reference Series:**
> - [Core](azure-cli-core.md) - Auth, Resource Groups
> - [Networking](azure-cli-networking.md) - VNets, Subnets, NSGs
> - [Storage](azure-cli-storage.md) - Storage Accounts, File Shares
> - [Compute](azure-cli-compute.md) - VMs, Disks, Images
> - **AVD** (this file) - Host Pools, Workspaces
> - [Identity](azure-cli-identity.md) - RBAC, Entra ID
> - [Management](azure-cli-management.md) - Monitoring, Tags, Locks

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

