# Step 07 - Intune Configuration Commands Reference

Quick reference for Intune management for AVD.

## Prerequisites

```bash
# Install Intune CLI extension
az extension add --name microsoft-intune

# Ensure authenticated
az account show
```

## Device Compliance Policies

### Create Device Compliance Policy

```bash
# Note: Most Intune operations require Microsoft Graph or Intune API
# Azure CLI has limited support; use PowerShell or Graph API for full control

# Create compliance policy via Graph API
az rest --method POST \
  --uri "https://graph.microsoft.com/beta/deviceManagement/deviceCompliancePolicies" \
  --body '{
    "@odata.type": "#microsoft.graph.iosCompliancePolicy",
    "displayName": "iOS Compliance Policy",
    "description": "AVD session host compliance requirements",
    "requireEncryptionOnDevice": true,
    "requireSmartLockEnabled": false,
    "codeSystemSecurityPatchLevel": "2023-01-01"
  }'
```

## Using Microsoft Graph PowerShell (Recommended Alternative)

### PowerShell: Create Device Compliance Policy

```powershell
# Install Graph module
Install-Module Microsoft.Graph -Scope CurrentUser

# Connect to Graph
Connect-MgGraph -Scopes "DeviceManagementConfiguration.ReadWrite.All"

# Create compliance policy
$body = @{
    displayName = "AVD Device Compliance"
    description = "Compliance policy for AVD session hosts"
    isScheduledActionEnabled = $true
} | ConvertTo-Json

New-MgDeviceManagementCompliancePolicy -BodyParameter $body
```

### PowerShell: Create Windows Update Configuration

```powershell
$params = @{
    id = (New-Guid).Guid
    displayName = "AVD Windows Update Policy"
    description = "Windows Update policy for session hosts"
    allowAutoUpdate = $true
    autoRestartNotificationDismissal = "notConfigured"
    businessReadyUpdatesOnly = $false
    deadlineForFeatureUpdatesInDays = 7
    deadlineForQualityUpdatesInDays = 1
}

New-MgDeviceManagementDeviceConfiguration -BodyParameter $params
```

### PowerShell: Assign Policy to Group

```powershell
# Get device group
$deviceGroup = Get-MgGroup -Filter "displayName eq 'AVD-Devices'"

# Get policy
$policy = Get-MgDeviceManagementCompliancePolicy -Filter "displayName eq 'AVD Device Compliance'"

# Assign policy to group
New-MgDeviceManagementCompliancePolicyAssignment `
  -DeviceCompliancePolicyId $policy.Id `
  -BodyParameter @{
    target = @{
      "@odata.type" = "#microsoft.graph.allDevicesAssignmentTarget"
    }
  }
```

## Intune Administrative Templates

### PowerShell: Configure Windows Settings via Intune

```powershell
# Windows Security policy for AVD
$params = @{
    displayName = "AVD Windows Security Policy"
    description = "Security hardening for session hosts"
    templateId = "eb2e7a8f-4c8d-4f41-868f-b7e2a3d1a4b5"
}

New-MgDeviceManagementGroupPolicyConfiguration -BodyParameter $params
```

## Defender Configuration

### PowerShell: Configure Windows Defender

```powershell
$defenderConfig = @{
    displayName = "AVD Defender Configuration"
    description = "Defender settings for AVD"
    allowArchiveScanning = $true
    allowBehaviorMonitoring = $true
    allowCloudProtection = $true
    allowFullScanRemovableDriveScanning = $true
    allowOnAccessProtection = $true
    allowRealtimeMonitoring = $true
    allowScanNetworkFiles = $true
}

New-MgDeviceManagementDeviceConfiguration -BodyParameter $defenderConfig
```

## Common Patterns

### List Existing Policies

```powershell
# List compliance policies
Get-MgDeviceManagementCompliancePolicy | Select-Object DisplayName, Description

# List device configurations
Get-MgDeviceManagementDeviceConfiguration | Select-Object DisplayName, Description
```

### Get Policy Assignment

```powershell
# Get policy assignments
Get-MgDeviceManagementCompliancePolicyAssignment -DeviceCompliancePolicyId "<policy-id>"
```

### Update Existing Policy

```powershell
Update-MgDeviceManagementCompliancePolicy `
  -DeviceCompliancePolicyId "<policy-id>" `
  -BodyParameter @{
    displayName = "Updated Policy Name"
    description = "Updated description"
  }
```

### Remove Policy

```powershell
Remove-MgDeviceManagementCompliancePolicy -DeviceCompliancePolicyId "<policy-id>"
```

## Template Recommendations for AVD

1. **Encryption**
   - Require BitLocker for OS drives
   - Enable encrypted storage

2. **Antivirus**
   - Windows Defender enabled
   - Real-time protection required
   - Regular scan scheduling

3. **Firewall**
   - Windows Defender Firewall enabled
   - Inbound rules configured
   - Network isolation enabled

4. **Windows Updates**
   - Auto-update enabled
   - Quality updates required
   - Restart notifications enabled

5. **Security Baseline**
   - Device Guard enabled
   - Credential Guard enabled
   - Account lockout policies configured

## Azure CLI Alternative (Limited)

```bash
# List Intune policies (limited support)
az rest --method GET \
  --uri "https://graph.microsoft.com/beta/deviceManagement/deviceCompliancePolicies" \
  --output json | jq '.value[] | {displayName, id}'
```

## Bulk Import via CSV

### PowerShell Script for Bulk Compliance Policy Import

```powershell
$policies = @(
    @{
        displayName = "Encryption Policy"
        requireEncryption = $true
        requireEncryptionOnDevice = $true
    },
    @{
        displayName = "Antivirus Policy"
        requireAntivirus = $true
        requireMalwareProtection = $true
    },
    @{
        displayName = "Windows Update Policy"
        requireWindowsUpdate = $true
        allowAutoUpdate = $true
    }
)

foreach ($policy in $policies) {
    Write-Host "Creating policy: $($policy.displayName)"
    New-MgDeviceManagementCompliancePolicy -BodyParameter $policy
}
```

## Troubleshooting

### Cannot Connect to Intune
- Verify Microsoft Graph permissions
- Check authentication status
- Ensure Intune license is available

### Policy Not Applying to Devices
- Verify group assignment is correct
- Check device group membership
- Ensure device is enrolled in Intune
- Wait up to 24 hours for policy sync

### PowerShell Module Not Found
- Update to latest Az module: `Update-Module Az`
- Install Graph module: `Install-Module Microsoft.Graph`

## References

- [Microsoft Intune Documentation](https://learn.microsoft.com/en-us/mem/intune/)
- [Device Compliance Policies](https://learn.microsoft.com/en-us/mem/intune/protect/device-compliance-get-started)
- [Windows Update for Business](https://learn.microsoft.com/en-us/windows/deployment/update/waas-manage-updates-wufb)
- [Microsoft Graph PowerShell](https://learn.microsoft.com/en-us/graph/powershell/get-started)
