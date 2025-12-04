# Step 03 - Entra ID & Service Principal Commands Reference

Quick reference for creating security groups and service principals for AVD deployment.

## Prerequisites

```bash
# Ensure authenticated to Azure
az account show

# Install Microsoft Graph CLI (optional, alternative to Azure AD CLI)
az extension add --name "microsoft-graph"
```

## Security Group Operations

### Create Security Group

```bash
# Create AVD-Users group
az ad group create \
  --display-name "AVD-Users" \
  --mail-nickname "avd-users"

# Create AVD-Admins group
az ad group create \
  --display-name "AVD-Admins" \
  --mail-nickname "avd-admins"
```

**Parameters:**
- `--display-name`: Human-readable name in Azure AD
- `--mail-nickname`: Email prefix (must be unique)

### List Security Groups

```bash
# List all security groups
az ad group list --output table

# Find specific group
az ad group list --filter "displayName eq 'AVD-Users'" --output json
```

### Get Group Details

```bash
az ad group show --group "AVD-Users" --output json

# Get group object ID
az ad group show \
  --group "AVD-Users" \
  --query id -o tsv
```

### Add User to Group

```bash
# Add user by UPN
az ad group member add \
  --group "AVD-Users" \
  --member-id "<user-object-id>"

# Or use member UPN
az ad group member add \
  --group "AVD-Users" \
  --member-id "user@contoso.com"
```

### List Group Members

```bash
az ad group member list \
  --group "AVD-Users" \
  --output table
```

### Remove User from Group

```bash
az ad group member remove \
  --group "AVD-Users" \
  --member-id "<user-object-id>"
```

### Delete Security Group

```bash
az ad group delete --group "AVD-Users"
```

## Service Principal Operations

### Create Service Principal

```bash
# Create service principal for automation
az ad sp create-for-rbac \
  --name "AVD-Automation-SP" \
  --role "Contributor" \
  --scopes "/subscriptions/<subscription-id>/resourceGroups/RG-Azure-VDI-01"
```

**Output includes:**
- `appId`: Client ID
- `password`: Client secret (save securely!)
- `tenant`: Tenant ID

### Create Service Principal (with specific credentials)

```bash
# Create with certificate
az ad sp create-for-rbac \
  --name "AVD-Automation-SP" \
  --cert "<certificate-data>" \
  --role "Contributor" \
  --scopes "/subscriptions/<subscription-id>"
```

### List Service Principals

```bash
# List all service principals
az ad sp list --output table

# Find specific SP
az ad sp list --filter "displayName eq 'AVD-Automation-SP'" --output json
```

### Get Service Principal Details

```bash
az ad sp show --id "<app-id>" --output json
```

### Create Client Secret for Service Principal

```bash
az ad sp credential reset \
  --id "<app-id>" \
  --credential-description "AVD-Secret-2024" \
  --years 2
```

### List Service Principal Credentials

```bash
az ad app credential list --id "<app-id>"
```

### Delete Service Principal

```bash
az ad sp delete --id "<app-id>"
```

## Role-Based Access Control (RBAC)

### Assign Role to Service Principal

```bash
# Assign Contributor role
az role assignment create \
  --assignee "<sp-app-id>" \
  --role "Contributor" \
  --scope "/subscriptions/<subscription-id>"

# Assign at resource group level
az role assignment create \
  --assignee "<sp-app-id>" \
  --role "Contributor" \
  --resource-group "RG-Azure-VDI-01"
```

### Assign Role to Security Group

```bash
# Assign Desktop Virtualization User role
az role assignment create \
  --assignee "<group-object-id>" \
  --role "Desktop Virtualization User" \
  --scope "/subscriptions/<subscription-id>"

# By resource group
az role assignment create \
  --assignee "<group-object-id>" \
  --role "Desktop Virtualization User" \
  --resource-group "RG-Azure-VDI-01"
```

### List Role Assignments

```bash
# For specific principal
az role assignment list --assignee "<principal-id>" --output table

# For resource group
az role assignment list \
  --resource-group "RG-Azure-VDI-01" \
  --output table
```

### Remove Role Assignment

```bash
az role assignment delete \
  --assignee "<principal-id>" \
  --role "Contributor" \
  --resource-group "RG-Azure-VDI-01"
```

## Common Patterns

### Get All AVD-Related Groups

```bash
az ad group list --filter "startswith(displayName, 'AVD')" --output json
```

### Export Security Group Members to File

```bash
az ad group member list \
  --group "AVD-Users" \
  --output json > avd-users-members.json
```

### Check if User is in Group

```bash
USER_ID=$(az ad user show --id "user@contoso.com" --query id -o tsv)
az ad group member check \
  --group "AVD-Users" \
  --member-id "$USER_ID" \
  --output json
```

### Get Service Principal App ID from Name

```bash
az ad sp list \
  --filter "displayName eq 'AVD-Automation-SP'" \
  --query "[0].appId" \
  --output tsv
```

### Bulk Add Users to Group

```bash
#!/bin/bash

# Read user IDs from file
while IFS= read -r user_id; do
  az ad group member add \
    --group "AVD-Users" \
    --member-id "$user_id"
done < users.txt
```

## Scripting Example

```bash
#!/bin/bash

# Set variables
SUBSCRIPTION_ID="<subscription-id>"
RG_NAME="RG-Azure-VDI-01"

# Create security groups
echo "Creating security groups..."
AVD_USERS_ID=$(az ad group create \
  --display-name "AVD-Users" \
  --mail-nickname "avd-users" \
  --query id -o tsv)

AVD_ADMINS_ID=$(az ad group create \
  --display-name "AVD-Admins" \
  --mail-nickname "avd-admins" \
  --query id -o tsv)

echo "AVD-Users ID: $AVD_USERS_ID"
echo "AVD-Admins ID: $AVD_ADMINS_ID"

# Create service principal
echo "Creating service principal..."
SP_OUTPUT=$(az ad sp create-for-rbac \
  --name "AVD-Automation-SP" \
  --role "Contributor" \
  --scopes "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME")

SP_APP_ID=$(echo "$SP_OUTPUT" | jq -r '.appId')
SP_SECRET=$(echo "$SP_OUTPUT" | jq -r '.password')
SP_TENANT=$(echo "$SP_OUTPUT" | jq -r '.tenant')

echo "Service Principal created:"
echo "  App ID: $SP_APP_ID"
echo "  Tenant: $SP_TENANT"

# Save credentials securely (example - use Azure Key Vault in production)
echo "IMPORTANT: Save these credentials securely:"
echo "APP_ID=$SP_APP_ID"
echo "SECRET=$SP_SECRET"
echo "TENANT=$SP_TENANT"
```

## Using Service Principal for Authentication

### Bash Example

```bash
#!/bin/bash

# Set variables from saved credentials
APP_ID="<saved-app-id>"
SECRET="<saved-secret>"
TENANT_ID="<saved-tenant-id>"

# Login as service principal
az login \
  --service-principal \
  --username "$APP_ID" \
  --password "$SECRET" \
  --tenant "$TENANT_ID"

# Now run Azure CLI commands as service principal
az vm list --output table
```

### PowerShell Example

```powershell
# Set variables
$AppID = "<saved-app-id>"
$Secret = "<saved-secret>"
$TenantID = "<saved-tenant-id>"

# Convert secret to secure string
$SecureSecret = ConvertTo-SecureString -String $Secret -AsPlainText -Force

# Create credential
$Credential = New-Object System.Management.Automation.PSCredential($AppID, $SecureSecret)

# Connect as service principal
Connect-AzAccount -ServicePrincipal -Credential $Credential -Tenant $TenantID

# Run Azure PowerShell commands
Get-AzVM
```

## Security Best Practices

1. **Store Credentials Securely**
   - Use Azure Key Vault for service principal secrets
   - Never commit credentials to source control
   - Rotate secrets regularly

2. **Use Managed Identity Where Possible**
   - Prefer Azure Managed Identity over service principal credentials
   - No need to store/rotate secrets

3. **Least Privilege**
   - Assign minimal required roles
   - Use custom roles if built-in roles are too permissive

4. **Audit and Monitor**
   - Review group memberships regularly
   - Monitor service principal usage
   - Enable logging on RBAC changes

## Troubleshooting

### Group Already Exists
- Check existing group: `az ad group show --group "AVD-Users"`
- Retry with different name or check mail-nickname uniqueness

### Service Principal Creation Fails
- Verify subscription exists and is accessible
- Check RBAC permissions
- Ensure service principal name is unique

### Cannot Add User to Group
- Verify user exists: `az ad user show --id "user@contoso.com"`
- Check group exists: `az ad group show --group "AVD-Users"`
- Verify permissions to manage group

## References

- [Azure AD Groups Documentation](https://learn.microsoft.com/en-us/azure/active-directory/fundamentals/concept-learn-about-groups)
- [Service Principals Documentation](https://learn.microsoft.com/en-us/azure/active-directory/develop/app-objects-and-service-principals)
- [RBAC Documentation](https://learn.microsoft.com/en-us/azure/role-based-access-control/overview)
- [AVD Identity Requirements](https://learn.microsoft.com/en-us/azure/virtual-desktop/prerequisites)
