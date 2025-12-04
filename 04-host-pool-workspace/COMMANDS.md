# Step 04 - Host Pool & Workspace Commands Reference

Quick reference for creating AVD host pools and workspaces.

## Prerequisites

```bash
# Install AVD provider (if needed)
az provider register --namespace Microsoft.DesktopVirtualization

# Verify provider is registered
az provider show --namespace Microsoft.DesktopVirtualization
```

## Host Pool Operations

### Create Host Pool

```bash
# Create pooled host pool (shared sessions)
az desktopvirtualization hostpool create \
  --name "avd-hostpool" \
  --resource-group "RG-Azure-VDI-01" \
  --host-pool-type "Pooled" \
  --load-balancer-type "BreadthFirst" \
  --location "centralus" \
  --registration-info expiration-time="2025-12-11T00:00:00Z" registration-token-operation="Update" \
  --friendly-name "AVD Host Pool" \
  --description "Production AVD host pool" \
  --max-session-limit 5
```

**Parameters:**
- `--host-pool-type`: "Pooled" (shared) or "Personal" (dedicated)
- `--load-balancer-type`:
  - "BreadthFirst" (distribute evenly)
  - "DepthFirst" (fill capacity before new)
- `--max-session-limit`: Max sessions per host (1-999, default 999)

### Create Personal Host Pool

```bash
az desktopvirtualization hostpool create \
  --name "avd-personal-pool" \
  --resource-group "RG-Azure-VDI-01" \
  --host-pool-type "Personal" \
  --personal-desktop-assignment-type "Direct" \
  --location "centralus" \
  --friendly-name "Personal Desktops"
```

**Parameters:**
- `--personal-desktop-assignment-type`: "Direct" (automatic) or "Automatic"

### List Host Pools

```bash
# List all host pools
az desktopvirtualization hostpool list \
  --resource-group "RG-Azure-VDI-01" \
  --output table

# Get specific host pool
az desktopvirtualization hostpool show \
  --name "avd-hostpool" \
  --resource-group "RG-Azure-VDI-01"
```

### Update Host Pool

```bash
# Update max session limit
az desktopvirtualization hostpool update \
  --name "avd-hostpool" \
  --resource-group "RG-Azure-VDI-01" \
  --max-session-limit 10

# Update friendly name
az desktopvirtualization hostpool update \
  --name "avd-hostpool" \
  --resource-group "RG-Azure-VDI-01" \
  --friendly-name "Updated AVD Host Pool"

# Update load balancer type
az desktopvirtualization hostpool update \
  --name "avd-hostpool" \
  --resource-group "RG-Azure-VDI-01" \
  --load-balancer-type "DepthFirst"
```

### Delete Host Pool

```bash
az desktopvirtualization hostpool delete \
  --name "avd-hostpool" \
  --resource-group "RG-Azure-VDI-01"
```

## Application Group Operations

### Create Application Group (Desktop)

```bash
# Create RemoteApp application group
az desktopvirtualization applicationgroup create \
  --name "avd-appgroup-desktop" \
  --resource-group "RG-Azure-VDI-01" \
  --application-group-type "Desktop" \
  --host-pool-arm-path "/subscriptions/<sub-id>/resourcegroups/RG-Azure-VDI-01/providers/Microsoft.DesktopVirtualization/hostpools/avd-hostpool" \
  --location "centralus" \
  --friendly-name "Desktop"
```

**Parameters:**
- `--application-group-type`: "Desktop" or "RemoteApp"

### Create Application Group (RemoteApp)

```bash
az desktopvirtualization applicationgroup create \
  --name "avd-appgroup-remoteapp" \
  --resource-group "RG-Azure-VDI-01" \
  --application-group-type "RemoteApp" \
  --host-pool-arm-path "/subscriptions/<sub-id>/resourcegroups/RG-Azure-VDI-01/providers/Microsoft.DesktopVirtualization/hostpools/avd-hostpool" \
  --location "centralus" \
  --friendly-name "Remote Apps"
```

### List Application Groups

```bash
az desktopvirtualization applicationgroup list \
  --resource-group "RG-Azure-VDI-01" \
  --output table
```

### Assign Application Group to Users

```bash
# Get application group resource ID
APP_GROUP_ID=$(az desktopvirtualization applicationgroup show \
  --name "avd-appgroup-desktop" \
  --resource-group "RG-Azure-VDI-01" \
  --query id -o tsv)

# Assign to security group
az role assignment create \
  --assignee "<avd-users-group-object-id>" \
  --role "Desktop Virtualization User" \
  --scope "$APP_GROUP_ID"
```

## Workspace Operations

### Create Workspace

```bash
az desktopvirtualization workspace create \
  --name "avd-workspace" \
  --resource-group "RG-Azure-VDI-01" \
  --location "centralus" \
  --friendly-name "AVD Workspace" \
  --description "Production AVD workspace"
```

### Add Application Groups to Workspace

```bash
# Get application group ID
APP_GROUP_ID=$(az desktopvirtualization applicationgroup show \
  --name "avd-appgroup-desktop" \
  --resource-group "RG-Azure-VDI-01" \
  --query id -o tsv)

# Update workspace with application group
az desktopvirtualization workspace update \
  --name "avd-workspace" \
  --resource-group "RG-Azure-VDI-01" \
  --application-groups "$APP_GROUP_ID"
```

### List Workspaces

```bash
az desktopvirtualization workspace list \
  --resource-group "RG-Azure-VDI-01" \
  --output table
```

### Update Workspace

```bash
az desktopvirtualization workspace update \
  --name "avd-workspace" \
  --resource-group "RG-Azure-VDI-01" \
  --friendly-name "Updated Workspace" \
  --description "Updated description"
```

## Host Pool Token Operations

### Get Registration Token

```bash
az desktopvirtualization hostpool update \
  --name "avd-hostpool" \
  --resource-group "RG-Azure-VDI-01" \
  --registration-info expiration-time="2025-12-11T00:00:00Z" registration-token-operation="Update"
```

### Retrieve Token Value

```bash
# Note: Token is returned in update output
az desktopvirtualization hostpool update \
  --name "avd-hostpool" \
  --resource-group "RG-Azure-VDI-01" \
  --registration-info expiration-time="2025-12-11T23:59:59Z" registration-token-operation="Update" \
  --query "registrationInfo.token" -o tsv
```

## Common Patterns

### Get Host Pool ID

```bash
az desktopvirtualization hostpool show \
  --name "avd-hostpool" \
  --resource-group "RG-Azure-VDI-01" \
  --query id -o tsv
```

### Get Host Pool Details in JSON

```bash
az desktopvirtualization hostpool show \
  --name "avd-hostpool" \
  --resource-group "RG-Azure-VDI-01" \
  --output json > hostpool-details.json
```

### Export Host Pool Configuration

```bash
#!/bin/bash

RG="RG-Azure-VDI-01"
HP_NAME="avd-hostpool"

echo "=== Host Pool Configuration ==="
az desktopvirtualization hostpool show \
  --name "$HP_NAME" \
  --resource-group "$RG" \
  --output json | jq '{
    name: .name,
    type: .hostPoolType,
    loadBalancer: .loadBalancerType,
    maxSessions: .maxSessionLimit,
    friendlyName: .friendlyName
  }'
```

## Complete Scripting Example

```bash
#!/bin/bash

# Variables
SUBSCRIPTION_ID="<subscription-id>"
RG_NAME="RG-Azure-VDI-01"
LOCATION="centralus"
HOSTPOOL_NAME="avd-hostpool"
APPGROUP_NAME="avd-appgroup-desktop"
WORKSPACE_NAME="avd-workspace"
AVD_USERS_GROUP_ID="<group-object-id>"

# Set subscription
az account set --subscription "$SUBSCRIPTION_ID"

# Create host pool
echo "Creating host pool..."
az desktopvirtualization hostpool create \
  --name "$HOSTPOOL_NAME" \
  --resource-group "$RG_NAME" \
  --host-pool-type "Pooled" \
  --load-balancer-type "BreadthFirst" \
  --location "$LOCATION" \
  --max-session-limit 5

# Get host pool ID
HOSTPOOL_ID=$(az desktopvirtualization hostpool show \
  --name "$HOSTPOOL_NAME" \
  --resource-group "$RG_NAME" \
  --query id -o tsv)

echo "Host Pool ID: $HOSTPOOL_ID"

# Create application group
echo "Creating application group..."
az desktopvirtualization applicationgroup create \
  --name "$APPGROUP_NAME" \
  --resource-group "$RG_NAME" \
  --application-group-type "Desktop" \
  --host-pool-arm-path "$HOSTPOOL_ID" \
  --location "$LOCATION"

# Get application group ID
APPGROUP_ID=$(az desktopvirtualization applicationgroup show \
  --name "$APPGROUP_NAME" \
  --resource-group "$RG_NAME" \
  --query id -o tsv)

echo "Application Group ID: $APPGROUP_ID"

# Create workspace
echo "Creating workspace..."
az desktopvirtualization workspace create \
  --name "$WORKSPACE_NAME" \
  --resource-group "$RG_NAME" \
  --location "$LOCATION"

# Add application group to workspace
echo "Adding application group to workspace..."
az desktopvirtualization workspace update \
  --name "$WORKSPACE_NAME" \
  --resource-group "$RG_NAME" \
  --application-groups "$APPGROUP_ID"

# Assign users
echo "Assigning AVD-Users group to application group..."
az role assignment create \
  --assignee "$AVD_USERS_GROUP_ID" \
  --role "Desktop Virtualization User" \
  --scope "$APPGROUP_ID"

echo "Host pool setup complete!"
```

## Troubleshooting

### Host Pool Creation Fails
- Verify provider is registered: `az provider show --namespace Microsoft.DesktopVirtualization`
- Check resource group exists
- Ensure location is valid and has AVD support

### Cannot Find Application Group
- Verify host pool exists first
- Check application group resource group
- Verify correct resource group name

### Token Expiration Issues
- Tokens expire after specified time
- Re-run update command to generate new token
- Keep token in secure location (Key Vault recommended)

### Application Group Not Appearing in Workspace
- Verify both resources exist
- Check resource IDs are correct
- Ensure proper RBAC permissions

## References

- [AVD Host Pool Documentation](https://learn.microsoft.com/en-us/azure/virtual-desktop/create-host-pools-azure-marketplace)
- [Application Groups](https://learn.microsoft.com/en-us/azure/virtual-desktop/manage-app-groups)
- [Workspace Concepts](https://learn.microsoft.com/en-us/azure/virtual-desktop/environment-setup)
- [AVD Pricing](https://azure.microsoft.com/en-us/pricing/details/virtual-desktop/)
