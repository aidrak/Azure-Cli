# Identity Capability

## Overview

The Identity capability provides declarative management of Azure identity and access management resources including Entra ID (formerly Azure AD) groups, service principals, managed identities, and RBAC role assignments. This capability is foundational for securing Azure resources and implementing least-privilege access.

## Supported Resource Types

- **Managed Identities** (`Microsoft.ManagedIdentity/userAssignedIdentities`)
  - User-assigned managed identities
  - System-assigned managed identities (via resource configuration)

- **Role Assignments** (`Microsoft.Authorization/roleAssignments`)
  - Built-in role assignments
  - Custom role assignments
  - Scope-based assignments (subscription, resource group, resource)

- **Custom Role Definitions** (`Microsoft.Authorization/roleDefinitions`)
  - Custom RBAC roles
  - Fine-grained permissions

- **Entra ID Groups** (`Microsoft.Graph/groups`)
  - Security groups
  - Microsoft 365 groups
  - Dynamic membership groups

- **Service Principals** (`Microsoft.Graph/servicePrincipals`)
  - Application registrations
  - Managed application identities

- **Applications** (`Microsoft.Graph/applications`)
  - Application registrations
  - API permissions

## Common Operations

The following operations are typically provided by this capability:

1. **managed-identity-create** - Create user-assigned managed identities
2. **managed-identity-delete** - Remove managed identities
3. **rbac-assign** - Assign RBAC roles to principals
4. **rbac-remove** - Remove RBAC role assignments
5. **group-create** - Create Entra ID security groups
6. **group-add-members** - Add members to groups
7. **service-principal-create** - Create service principals
8. **custom-role-create** - Define custom RBAC roles

## Prerequisites

### Required Permissions

- `Microsoft.Authorization/roleAssignments/*` (for RBAC)
- `Microsoft.ManagedIdentity/userAssignedIdentities/*` (for managed identities)
- Graph API permissions:
  - `Group.ReadWrite.All`
  - `Application.ReadWrite.All`
  - `RoleManagement.ReadWrite.Directory`

### Required Providers

```bash
az provider register --namespace Microsoft.ManagedIdentity
az provider register --namespace Microsoft.Authorization
```

### Required Roles

To assign roles, you need one of:
- `Owner` role at the target scope
- `User Access Administrator` role at the target scope
- Custom role with `Microsoft.Authorization/roleAssignments/write`

## Quick Start Examples

### Create User-Assigned Managed Identity

```yaml
operation:
  id: "create-managed-identity"
  capability: "identity"
  action: "managed-identity-create"

  inputs:
    identity_name: "id-avd-prod"
    resource_group: "{{ config.resource_group }}"
    location: "{{ config.location }}"

  outputs:
    identity_id: "{{ outputs.identity_id }}"
    principal_id: "{{ outputs.principal_id }}"
    client_id: "{{ outputs.client_id }}"
```

### Assign RBAC Role to Managed Identity

```yaml
operation:
  id: "assign-storage-role"
  capability: "identity"
  action: "rbac-assign"

  inputs:
    principal_id: "{{ outputs.identity.principal_id }}"
    role_definition: "Storage File Data SMB Share Contributor"
    scope: "/subscriptions/{{ config.subscription_id }}/resourceGroups/{{ config.resource_group }}/providers/Microsoft.Storage/storageAccounts/{{ config.storage_account_name }}"

  outputs:
    assignment_id: "{{ outputs.assignment_id }}"
```

### Create Entra ID Security Group

```yaml
operation:
  id: "create-avd-users-group"
  capability: "identity"
  action: "group-create"

  inputs:
    group_name: "AVD-Users-Production"
    description: "Users with access to production AVD environment"
    mail_enabled: false
    security_enabled: true

    # Optional: Add members
    members:
      - "user1@contoso.com"
      - "user2@contoso.com"

  outputs:
    group_id: "{{ outputs.group_id }}"
    group_name: "{{ outputs.group_name }}"
```

### Assign Multiple RBAC Roles

```yaml
operation:
  id: "configure-avd-rbac"
  capability: "identity"
  action: "rbac-assign-multiple"

  inputs:
    assignments:
      # Users to Desktop Virtualization User role
      - principal_id: "{{ outputs.avd_users_group.group_id }}"
        role_definition: "Desktop Virtualization User"
        scope: "/subscriptions/{{ config.subscription_id }}/resourceGroups/{{ config.resource_group }}/providers/Microsoft.DesktopVirtualization/applicationGroups/{{ config.app_group_name }}"

      # Managed identity to read storage
      - principal_id: "{{ outputs.managed_identity.principal_id }}"
        role_definition: "Storage File Data SMB Share Contributor"
        scope: "/subscriptions/{{ config.subscription_id }}/resourceGroups/{{ config.resource_group }}/providers/Microsoft.Storage/storageAccounts/{{ config.storage_account }}"

      # Service principal to manage VMs
      - principal_id: "{{ config.automation_sp_id }}"
        role_definition: "Virtual Machine Contributor"
        scope: "/subscriptions/{{ config.subscription_id }}/resourceGroups/{{ config.resource_group }}"
```

### Create Custom RBAC Role

```yaml
operation:
  id: "create-custom-role"
  capability: "identity"
  action: "custom-role-create"

  inputs:
    role_name: "AVD Session Host Operator"
    description: "Custom role for AVD session host management"
    assignable_scopes:
      - "/subscriptions/{{ config.subscription_id }}"

    permissions:
      actions:
        - "Microsoft.Compute/virtualMachines/read"
        - "Microsoft.Compute/virtualMachines/start/action"
        - "Microsoft.Compute/virtualMachines/restart/action"
        - "Microsoft.DesktopVirtualization/hostpools/read"
        - "Microsoft.DesktopVirtualization/hostpools/sessionhosts/*"

      not_actions: []

      data_actions:
        - "Microsoft.Storage/storageAccounts/fileServices/readFileBackupSemantics"

      not_data_actions: []
```

## Configuration Variables

Common configuration variables used by identity operations:

```yaml
identity:
  # Managed Identities
  managed_identities:
    - name: "id-avd-sessionhosts"
      resource_group: "{{ config.resource_group }}"
      location: "{{ config.location }}"

    - name: "id-automation"
      resource_group: "{{ config.resource_group }}"
      location: "{{ config.location }}"

  # Entra ID Groups
  groups:
    - name: "AVD-Users-Production"
      description: "Production AVD users"
      type: "Security"

    - name: "AVD-PowerUsers-Production"
      description: "Production AVD power users"
      type: "Security"

    - name: "AVD-Admins"
      description: "AVD administrators"
      type: "Security"

  # RBAC Assignments
  rbac_assignments:
    # Application group access
    - principal_type: "group"
      principal_name: "AVD-Users-Production"
      role: "Desktop Virtualization User"
      scope_type: "application_group"
      scope_name: "{{ config.app_group_name }}"

    # Storage access for profiles
    - principal_type: "managed_identity"
      principal_name: "id-avd-sessionhosts"
      role: "Storage File Data SMB Share Contributor"
      scope_type: "storage_account"
      scope_name: "{{ config.storage_account }}"

    # VM management
    - principal_type: "managed_identity"
      principal_name: "id-automation"
      role: "Virtual Machine Contributor"
      scope_type: "resource_group"
      scope_name: "{{ config.resource_group }}"
```

## RBAC Role Reference

### Common Built-in Roles for AVD

| Role | Scope | Purpose |
|------|-------|---------|
| Desktop Virtualization User | Application Group | End user access to AVD desktops/apps |
| Desktop Virtualization Contributor | Resource Group | Manage AVD resources |
| Virtual Machine Contributor | Resource Group | Manage session host VMs |
| Storage File Data SMB Share Contributor | Storage Account | FSLogix profile access |
| Reader | Subscription/RG | Read-only monitoring access |

### Storage Roles

| Role | Purpose |
|------|---------|
| Storage Blob Data Contributor | Read/write blob data |
| Storage File Data SMB Share Contributor | FSLogix profiles, file shares |
| Storage Account Contributor | Manage storage accounts (not data) |
| Storage Account Key Operator | Access storage account keys |

### Compute Roles

| Role | Purpose |
|------|---------|
| Virtual Machine Contributor | Full VM management |
| Virtual Machine Administrator Login | Login to VMs as admin |
| Virtual Machine User Login | Login to VMs as user |

## Managed Identity Best Practices

### When to Use System-Assigned vs User-Assigned

**System-Assigned:**
- Simple scenarios with single resource
- Identity lifecycle tied to resource
- Automatic cleanup when resource deleted
- Example: Single VM accessing storage

**User-Assigned:**
- Multiple resources sharing same identity
- Identity needs to persist beyond resource
- Reusable across deployments
- Example: Multiple VMs in scale set

### Implementation Patterns

1. **Single Resource, Single Purpose**
   ```yaml
   # System-assigned identity on VM
   enable_system_identity: true
   ```

2. **Multiple Resources, Shared Access**
   ```yaml
   # User-assigned identity shared across VMs
   user_assigned_identities:
     - "id-avd-sessionhosts"
   ```

3. **Automation and CI/CD**
   ```yaml
   # Service principal for deployment pipelines
   # User-assigned identity for runtime operations
   ```

## Security Best Practices

### Principle of Least Privilege

1. **Scope Assignments Narrowly**
   - Prefer resource scope over resource group
   - Prefer resource group scope over subscription
   - Use management groups for organization-wide policies

2. **Use Built-in Roles First**
   - Custom roles increase complexity
   - Built-in roles are maintained by Microsoft
   - Custom roles only when necessary

3. **Regular Access Reviews**
   - Audit role assignments quarterly
   - Remove unused assignments
   - Review privileged access monthly

### Group-Based Access

- Assign roles to groups, not individual users
- Use descriptive group names
- Document group purpose and membership criteria
- Implement group ownership and access reviews

### Privileged Access

1. **Use PIM (Privileged Identity Management)**
   - Time-bound access to privileged roles
   - Approval workflows for sensitive roles
   - Audit logging of privileged access

2. **Emergency Access Accounts**
   - Break-glass accounts for emergencies
   - Exclude from conditional access
   - Monitor and alert on usage

3. **Service Principal Security**
   - Prefer managed identities over service principals
   - Rotate credentials regularly
   - Use certificate authentication
   - Store secrets in Key Vault

## Troubleshooting

### Common Issues

**Role assignment fails with "insufficient permissions"**
- Verify you have `Owner` or `User Access Administrator` at target scope
- Check if trying to assign higher-privileged role than you have
- Ensure no Azure Policy blocking the assignment

**Managed identity not working for resource access**
- Verify RBAC assignment completed (can take up to 5 minutes)
- Check role is appropriate for operation
- Ensure scope includes the target resource
- Verify resource has identity enabled

**Group membership not effective**
- Entra ID replication can take up to 30 minutes
- Check if conditional access policies blocking
- Verify group type (Security vs M365)
- Check if dynamic membership rules evaluated

**Custom role not appearing**
- Custom roles can take up to 10 minutes to replicate
- Verify assignable scopes include current scope
- Check role definition permissions are valid

## Monitoring and Auditing

### Key Metrics to Monitor

- **Role Assignment Changes**: Track additions/removals
- **Failed Authentication Attempts**: Managed identity auth failures
- **Privileged Role Activations**: PIM activations
- **Group Membership Changes**: User additions/removals

### Audit Queries

```bash
# List all role assignments for a principal
az role assignment list --assignee <principal-id> --all

# List all members of a role at a scope
az role assignment list --role "Contributor" --scope <scope>

# Show managed identity details
az identity show --name <identity-name> --resource-group <rg-name>

# List group members
az ad group member list --group <group-name>
```

### Azure Monitor Alerts

Configure alerts for:
- Privileged role assignments
- Custom role modifications
- Service principal credential changes
- Failed RBAC operations

## Related Documentation

- [Azure RBAC Documentation](https://docs.microsoft.com/azure/role-based-access-control/)
- [Managed Identities](https://docs.microsoft.com/azure/active-directory/managed-identities-azure-resources/)
- [Built-in Roles](https://docs.microsoft.com/azure/role-based-access-control/built-in-roles)
- [Entra ID Groups](https://docs.microsoft.com/azure/active-directory/fundamentals/active-directory-groups-create-azure-portal)
- [Privileged Identity Management](https://docs.microsoft.com/azure/active-directory/privileged-identity-management/)
