# Step 08 - RBAC Assignment Commands Reference

Quick reference for RBAC role assignments for AVD deployment.

## AVD-Specific Roles

### Built-in AVD Roles

- **Desktop Virtualization User** - Users who access AVD desktops
- **Desktop Virtualization Power User** - Power users with elevated permissions
- **Desktop Virtualization Host Pool Operator** - Manage host pools
- **Desktop Virtualization Session Host Operator** - Manage session hosts

### Role Assignment by Scope

```bash
# Resource Group Scope
SCOPE="/subscriptions/<sub-id>/resourceGroups/RG-Azure-VDI-01"

# Host Pool Scope
SCOPE="/subscriptions/<sub-id>/resourceGroups/RG-Azure-VDI-01/providers/Microsoft.DesktopVirtualization/hostpools/avd-hostpool"

# Application Group Scope
SCOPE="/subscriptions/<sub-id>/resourceGroups/RG-Azure-VDI-01/providers/Microsoft.DesktopVirtualization/applicationgroups/avd-appgroup"

# Storage Account Scope
SCOPE="/subscriptions/<sub-id>/resourceGroups/RG-Azure-VDI-01/providers/Microsoft.Storage/storageAccounts/avdfslogix001"
```

## Assign Roles to Security Groups

### Desktop Virtualization User

```bash
# Get group object ID
GROUP_ID=$(az ad group show \
  --group "AVD-Users" \
  --query id -o tsv)

# Assign role at application group level
az role assignment create \
  --assignee "$GROUP_ID" \
  --role "Desktop Virtualization User" \
  --scope "/subscriptions/<sub-id>/resourceGroups/RG-Azure-VDI-01/providers/Microsoft.DesktopVirtualization/applicationgroups/avd-appgroup"
```

### Desktop Virtualization Power User

```bash
GROUP_ID=$(az ad group show \
  --group "AVD-Admins" \
  --query id -o tsv)

az role assignment create \
  --assignee "$GROUP_ID" \
  --role "Desktop Virtualization Power User" \
  --scope "/subscriptions/<sub-id>/resourceGroups/RG-Azure-VDI-01"
```

### Virtual Machine Contributor

```bash
# For managing session host VMs
GROUP_ID=$(az ad group show \
  --group "AVD-Admins" \
  --query id -o tsv)

az role assignment create \
  --assignee "$GROUP_ID" \
  --role "Virtual Machine Contributor" \
  --resource-group "RG-Azure-VDI-01"
```

## Assign Roles to Service Principals

### Service Principal for Automation

```bash
# Get service principal app ID
SP_ID=$(az ad sp list \
  --filter "displayName eq 'AVD-Automation-SP'" \
  --query "[0].appId" -o tsv)

# Assign Contributor role
az role assignment create \
  --assignee "$SP_ID" \
  --role "Contributor" \
  --scope "/subscriptions/<sub-id>/resourceGroups/RG-Azure-VDI-01"

# Assign specific roles
az role assignment create \
  --assignee "$SP_ID" \
  --role "Desktop Virtualization Host Pool Operator" \
  --scope "/subscriptions/<sub-id>/resourceGroups/RG-Azure-VDI-01"

az role assignment create \
  --assignee "$SP_ID" \
  --role "Virtual Machine Contributor" \
  --scope "/subscriptions/<sub-id>/resourceGroups/RG-Azure-VDI-01"
```

## Assign Storage Roles

### Storage Account Administrator

```bash
GROUP_ID=$(az ad group show \
  --group "AVD-Admins" \
  --query id -o tsv)

# Storage Account Contributor
az role assignment create \
  --assignee "$GROUP_ID" \
  --role "Storage Account Contributor" \
  --scope "/subscriptions/<sub-id>/resourceGroups/RG-Azure-VDI-01/providers/Microsoft.Storage/storageAccounts/avdfslogix001"
```

### Storage File Data SMB Share Contributor

```bash
# For FSLogix profile share access
GROUP_ID=$(az ad group show \
  --group "AVD-Users" \
  --query id -o tsv)

az role assignment create \
  --assignee "$GROUP_ID" \
  --role "Storage File Data SMB Share Contributor" \
  --scope "/subscriptions/<sub-id>/resourceGroups/RG-Azure-VDI-01/providers/Microsoft.Storage/storageAccounts/avdfslogix001"
```

### Storage File Data SMB Share Elevated Contributor

```bash
# For admin access to file share
GROUP_ID=$(az ad group show \
  --group "AVD-Admins" \
  --query id -o tsv)

az role assignment create \
  --assignee "$GROUP_ID" \
  --role "Storage File Data SMB Share Elevated Contributor" \
  --scope "/subscriptions/<sub-id>/resourceGroups/RG-Azure-VDI-01/providers/Microsoft.Storage/storageAccounts/avdfslogix001"
```

## List and Query Roles

### List Built-in Roles

```bash
# List all roles
az role definition list --output table

# Find specific role
az role definition list \
  --query "[?roleName == 'Desktop Virtualization User']" \
  --output json

# Search roles
az role definition list \
  --query "[?contains(roleName, 'Virtual Machine')]" \
  --output table
```

### List Role Assignments

```bash
# For specific resource group
az role assignment list \
  --resource-group "RG-Azure-VDI-01" \
  --output table

# For specific principal
GROUP_ID=$(az ad group show --group "AVD-Users" --query id -o tsv)
az role assignment list \
  --assignee "$GROUP_ID" \
  --output table

# For specific scope
az role assignment list \
  --scope "/subscriptions/<sub-id>/resourceGroups/RG-Azure-VDI-01" \
  --output table

# Show detailed role assignments
az role assignment list \
  --resource-group "RG-Azure-VDI-01" \
  --output json | jq '.[] | {principalName, roleDefinitionName, scope}'
```

## Common Patterns

### Get All AVD Users with Roles

```bash
#!/bin/bash

GROUP_ID=$(az ad group show --group "AVD-Users" --query id -o tsv)

echo "=== AVD Users Role Assignments ==="
az role assignment list \
  --assignee "$GROUP_ID" \
  --query "[].[roleDefinitionName, scope]" \
  --output table
```

### Export Role Assignments to CSV

```bash
#!/bin/bash

RG="RG-Azure-VDI-01"

echo "Principal,Role,Scope" > role-assignments.csv

az role assignment list \
  --resource-group "$RG" \
  --output json | jq -r '.[] | [.principalName, .roleDefinitionName, .scope] | @csv' >> role-assignments.csv

echo "Exported to role-assignments.csv"
```

### Audit Role Changes

```bash
#!/bin/bash

RG="RG-Azure-VDI-01"

# Export current assignments
az role assignment list \
  --resource-group "$RG" \
  --output json > role-assignments-$(date +%Y%m%d).json

echo "Exported current role assignments to role-assignments-$(date +%Y%m%d).json"
```

### Remove Role Assignment

```bash
GROUP_ID=$(az ad group show --group "AVD-Users" --query id -o tsv)

az role assignment delete \
  --assignee "$GROUP_ID" \
  --role "Desktop Virtualization User" \
  --resource-group "RG-Azure-VDI-01"
```

## Complete RBAC Setup Script

```bash
#!/bin/bash

# Variables
SUBSCRIPTION_ID="<subscription-id>"
RG_NAME="RG-Azure-VDI-01"
STORAGE_NAME="avdfslogix001"
HOSTPOOL_NAME="avd-hostpool"
APPGROUP_NAME="avd-appgroup"

# Get IDs
AVD_USERS=$(az ad group show --group "AVD-Users" --query id -o tsv)
AVD_ADMINS=$(az ad group show --group "AVD-Admins" --query id -o tsv)
SP_ID=$(az ad sp list --filter "displayName eq 'AVD-Automation-SP'" --query "[0].appId" -o tsv)

echo "=== Assigning RBAC Roles ==="

# Scope variables
RG_SCOPE="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME"
STORAGE_SCOPE="$RG_SCOPE/providers/Microsoft.Storage/storageAccounts/$STORAGE_NAME"
HOSTPOOL_SCOPE="$RG_SCOPE/providers/Microsoft.DesktopVirtualization/hostpools/$HOSTPOOL_NAME"
APPGROUP_SCOPE="$RG_SCOPE/providers/Microsoft.DesktopVirtualization/applicationgroups/$APPGROUP_NAME"

# Assign AVD-Users roles
echo "Assigning AVD-Users roles..."
az role assignment create --assignee "$AVD_USERS" --role "Desktop Virtualization User" --scope "$APPGROUP_SCOPE"
az role assignment create --assignee "$AVD_USERS" --role "Storage File Data SMB Share Contributor" --scope "$STORAGE_SCOPE"

# Assign AVD-Admins roles
echo "Assigning AVD-Admins roles..."
az role assignment create --assignee "$AVD_ADMINS" --role "Desktop Virtualization Power User" --scope "$RG_SCOPE"
az role assignment create --assignee "$AVD_ADMINS" --role "Virtual Machine Contributor" --scope "$RG_SCOPE"
az role assignment create --assignee "$AVD_ADMINS" --role "Storage Account Contributor" --scope "$STORAGE_SCOPE"
az role assignment create --assignee "$AVD_ADMINS" --role "Storage File Data SMB Share Elevated Contributor" --scope "$STORAGE_SCOPE"

# Assign Service Principal roles
echo "Assigning Service Principal roles..."
az role assignment create --assignee "$SP_ID" --role "Contributor" --scope "$RG_SCOPE"
az role assignment create --assignee "$SP_ID" --role "Desktop Virtualization Host Pool Operator" --scope "$RG_SCOPE"

echo "RBAC assignments complete!"

# List all assignments
echo ""
echo "=== Current Role Assignments ==="
az role assignment list --resource-group "$RG_NAME" --output table
```

## Troubleshooting

### Role Assignment Failed
- Verify group/principal exists
- Check correct role name spelling
- Ensure scopes are properly formatted
- Verify permissions to assign roles

### Cannot Find Group
- Check group name: `az ad group show --group "AVD-Users"`
- List all groups: `az ad group list`
- Verify display name matches

### Role Not Appearing
- RBAC changes can take 5-10 minutes to propagate
- Check role assignment list after waiting
- Clear browser cache if using Portal

## References

- [AVD RBAC Roles](https://learn.microsoft.com/en-us/azure/virtual-desktop/rbac)
- [Role Definitions](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles)
- [Storage RBAC Roles](https://learn.microsoft.com/en-us/azure/storage/common/storage-auth-aad-rbac-portal)
- [RBAC Best Practices](https://learn.microsoft.com/en-us/azure/role-based-access-control/best-practices)
