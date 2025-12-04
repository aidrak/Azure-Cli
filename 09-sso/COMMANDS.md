# Step 09 - SSO Configuration Commands Reference

Quick reference for Single Sign-On (SSO) and passwordless sign-in configuration.

## Prerequisites

```bash
# Ensure authenticated
az account show

# Verify you have Global Administrator or Hybrid Identity Administrator role
```

## Windows Cloud Login (Preferred Modern Approach)

### Enable Windows Cloud Login via Azure CLI

```bash
# Note: Windows Cloud Login is primarily configured via:
# 1. Group Policy (for domain-joined machines)
# 2. Intune (for cloud-native machines)
# 3. PowerShell on individual machines

# Via PowerShell on session host (recommended):
```

### PowerShell: Enable Windows Cloud Login

```powershell
# Run on AVD session host

# Install Windows Cloud Login module
Install-Module -Name WindowsCloudLoginModule -Force

# Enable Windows Cloud Login
Enable-WindowsCloudLogin

# Configure passwordless sign-in
Set-WindowsCloudLoginPolicy -EnablePasswordlessSignin $true

# Verify configuration
Get-WindowsCloudLoginStatus
```

## Modern Authentication (Azure AD Authentication)

### Check Current Authentication Status

```bash
# List authentication methods
az rest --method GET \
  --uri "https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy" \
  --output json | jq .
```

### Enable Modern Authentication via PowerShell

```powershell
# Connect to Azure AD
Connect-AzureAD

# Get tenant details
$tenantId = (Get-AzureADCurrentSessionInfo).TenantId
$tenantName = (Get-AzureADTenantDetail).VerifiedDomains | Where-Object {$_.Initial -eq $true} | Select-Object -ExpandProperty Name

Write-Host "Tenant: $tenantName"
Write-Host "Tenant ID: $tenantId"
```

## Windows Hello Configuration

### PowerShell: Enable Windows Hello

```powershell
# Run on session host VM

# Enable Windows Hello for Business
$registryPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Hello for Business"
New-Item -Path $registryPath -Force
Set-ItemProperty -Path $registryPath -Name "Enabled" -Value 1

# Enable Windows Hello for Business sign-in
Set-ItemProperty -Path $registryPath -Name "UseWindowsHelloForBusinessSignIn" -Value 1

# Require PIN with Windows Hello
Set-ItemProperty -Path $registryPath -Name "MinimumPinLength" -Value 6

# Enable facial recognition
Set-ItemProperty -Path $registryPath -Name "UseFacialRecognition" -Value 1

# Enable fingerprint
Set-ItemProperty -Path $registryPath -Name "UseFingerprint" -Value 1
```

## FIDO2 Security Keys

### PowerShell: Enable FIDO2 Key Support

```powershell
# Enable FIDO2 for Azure AD
Connect-AzureAD
Set-AzureADPolicy -Definition @('{"Name":"RestrictPasswordResetTokenLifetime","Value":{"RestrictPasswordResetTokenLifetime":"true","MaxTokenDuration":"900"}}') -DisplayName "Restrict password reset token lifetime" -Type "PasswordResetPolicy"
```

### Configure FIDO2 Policy

```powershell
# Via Graph API to enable FIDO2 authentication methods
$body = @{
    "@odata.type" = "#microsoft.graph.fido2AuthenticationMethodConfiguration"
    "id" = "fido2"
    "state" = "enabled"
    "isRegistrationRequired" = $false
}

# Enable FIDO2
Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/policies/authenticationMethodsPolicy/authenticationMethodConfigurations/fido2" `
  -Method PATCH `
  -ContentType "application/json" `
  -Body ($body | ConvertTo-Json) `
  -Headers @{"Authorization" = "Bearer $($token)"}
```

## Group Policy Configuration

### Create Group Policy for Modern Authentication

```powershell
# GPO for Windows Cloud Login
$gpoName = "AVD-Modern-Authentication"

# Create GPO
New-GPO -Name $gpoName -DisplayName "AVD Modern Authentication"

# Link to AVD OU (example: OU=AVD,DC=contoso,DC=com)
New-GPLink -Name $gpoName -Target "OU=AVD,DC=contoso,DC=com" -Enforced Yes

# Set registry values via GPO
# Computer Configuration > Preferences > Windows Settings > Registry
# Path: HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\Windows Hello for Business
# Name: Enabled
# Value: 1
# Type: REG_DWORD
```

## Intune Configuration

### PowerShell: Create Modern Authentication Policy in Intune

```powershell
# Connect to Intune
Connect-MgGraph -Scopes "DeviceManagementConfiguration.ReadWrite.All"

# Create authentication methods policy
$params = @{
    displayName = "AVD Modern Authentication Policy"
    description = "Enable Windows Hello and passwordless sign-in"
    policyMigrationState = "migrationInProgress"
} | ConvertTo-Json

New-MgPolicyAuthenticationMethodPolicy -BodyParameter $params
```

### PowerShell: Deploy Windows Hello Policy to Group

```powershell
$deviceGroup = Get-MgGroup -Filter "displayName eq 'AVD-Devices'"

# Assign policy to device group
New-MgDeviceManagementConfigurationPolicy -BodyParameter @{
    name = "AVD-Windows-Hello-Policy"
    description = "Windows Hello and passwordless sign-in"
    templateId = "<template-id>"
    platforms = "windows10"
    technologies = "mdm,windowsConfig"
    assignments = @(
        @{
            target = @{
                "@odata.type" = "#microsoft.graph.allDevicesAssignmentTarget"
            }
        }
    )
} | Add-MgDeviceManagementConfigurationPolicyAssignment -Assignments @{
    target = @{
        "@odata.type" = "#microsoft.graph.groupAssignmentTarget"
        groupId = $deviceGroup.Id
    }
}
```

## Conditional Access Configuration

### PowerShell: Create Conditional Access for AVD Users

```powershell
# Ensure Azure AD Preview module
Install-Module AzureADPreview -Force

# Connect to Azure AD
Connect-AzureAD

# Get AVD Users group
$group = Get-AzureADGroup -Filter "displayName eq 'AVD-Users'"

# Create Conditional Access Policy
$conditions = New-Object -TypeName Microsoft.Open.MSGraph.Model.ConditionalAccessConditionSet
$conditions.Applications = New-Object -TypeName Microsoft.Open.MSGraph.Model.ConditionalAccessApplications
$conditions.Applications.IncludeApplications = "All"

# Require MFA or compliant device
$grantControls = New-Object -TypeName Microsoft.Open.MSGraph.Model.ConditionalAccessGrantControls
$grantControls.Operator = "OR"
$grantControls.BuiltInControls = @("mfa", "compliantDevice")

$caPolicy = New-AzureADMSConditionalAccessPolicy `
  -DisplayName "AVD Users MFA Required" `
  -Conditions $conditions `
  -GrantControls $grantControls `
  -State "Enabled"

Write-Host "Conditional Access Policy created: $($caPolicy.Id)"
```

## MFA Configuration

### Enable MFA for AVD Users

```powershell
# Get AVD Users group
$group = Get-AzureADGroup -Filter "displayName eq 'AVD-Users'"

# Get members
$members = Get-AzureADGroupMember -ObjectId $group.ObjectId

# Enable MFA for each user (example - use Conditional Access for better approach)
foreach ($user in $members) {
    # Enable MFA registration requirement
    Set-MsolUser -ObjectId $user.ObjectId -StrongAuthenticationRequirements `
      @(@{
          RelyingParty = "*"
          State = "Enabled"
      })

    Write-Host "MFA enabled for $($user.UserPrincipalName)"
}
```

## Troubleshooting Commands

### Check Current Authentication Methods

```powershell
# Get all authentication methods
Get-AzureADUser -ObjectId "user@contoso.com" | Select-Object *Auth*

# Check MFA status
Get-MsolUser -UserPrincipalName "user@contoso.com" | Select-Object UserPrincipalName, StrongAuthenticationRequirements
```

### Verify Windows Hello Readiness

```powershell
# Check on session host
certutil -silent -delreg "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\WindowsHelloForBusiness"

# Or use PowerShell
$HelloPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Hello for Business"
Get-ItemProperty -Path $HelloPath -ErrorAction SilentlyContinue
```

### Check FIDO2 Status

```powershell
# Via PowerShell
Get-MsGraphApiVersion
Get-MsFidoDevices -UserObjectId "user-object-id"
```

## Complete SSO Setup Script

```bash
#!/bin/bash

# Variables
TENANT_ID="<tenant-id>"
AVD_GROUP="AVD-Users"

# Get group ID
GROUP_ID=$(az ad group show --group "$AVD_GROUP" --query id -o tsv)

echo "=== AVD Modern Authentication Setup ==="
echo "Tenant ID: $TENANT_ID"
echo "Group: $AVD_GROUP ($GROUP_ID)"

# Via Azure CLI (limited support)
echo "Note: Full SSO configuration requires PowerShell"
echo "Proceed with PowerShell script below..."

cat << 'EOF'
# PowerShell script to run on administrator machine:

Connect-AzureAD -TenantId "$TENANT_ID"

# Enable Windows Cloud Login
# (Run on each session host)

# Enable MFA for group
$group = Get-AzureADGroup -Filter "displayName eq 'AVD-Users'"
$members = Get-AzureADGroupMember -ObjectId $group.ObjectId

foreach ($user in $members) {
    Set-MsolUser -ObjectId $user.ObjectId -StrongAuthenticationRequirements `
      @(@{
          RelyingParty = "*"
          State = "Enabled"
      })
    Write-Host "MFA enabled for $($user.UserPrincipalName)"
}
EOF
```

## References

- [Windows Cloud Login](https://learn.microsoft.com/en-us/windows-server/identity/ad-fs/deployment/windows-cloud-login)
- [Windows Hello for Business](https://learn.microsoft.com/en-us/windows/security/identity-protection/hello-for-business/hello-overview)
- [Azure AD Authentication Methods](https://learn.microsoft.com/en-us/azure/active-directory/authentication/concept-authentication-methods)
- [FIDO2 Security Keys](https://learn.microsoft.com/en-us/azure/active-directory/authentication/concept-authentication-passwordless#fido2-security-keys)
- [Conditional Access Policies](https://learn.microsoft.com/en-us/azure/active-directory/conditional-access/overview)
- [Multi-Factor Authentication](https://learn.microsoft.com/en-us/azure/active-directory/authentication/concept-mfa-howitworks)
