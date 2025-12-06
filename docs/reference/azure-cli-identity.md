# Azure CLI Reference - Identity & Access

RBAC and Entra ID (Azure Active Directory) operations.

> **Part of Azure CLI Reference Series:**
> - [Core](azure-cli-core.md) - Auth, Resource Groups
> - [Networking](azure-cli-networking.md) - VNets, Subnets, NSGs
> - [Storage](azure-cli-storage.md) - Storage Accounts, File Shares
> - [Compute](azure-cli-compute.md) - VMs, Disks, Images
> - [AVD](azure-cli-avd.md) - Host Pools, Workspaces
> - **Identity** (this file) - RBAC, Entra ID
> - [Management](azure-cli-management.md) - Monitoring, Tags, Locks

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

