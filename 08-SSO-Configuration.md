# Microsoft Entra SSO Configuration for AVD

**Purpose:** Enable passwordless Single Sign-On for Entra-only AVD environment

**Prerequisites:**
- Entra ID P1 or P2 licenses
- Host pool created with `enablerdsaadauth:i:1` in RDP properties
- Session hosts Entra-joined
- PowerShell: `Microsoft.Graph` modules

**Overview:** 5-step process:
1. Enable RDP authentication on service principal
2. Configure trusted device groups
3. Review Conditional Access policies
4. Verify host pool RDP properties
5. Assign RBAC roles

⚠️ **No Kerberos server object needed for Entra-only environments**

---

## Step 1: Enable RDP Authentication

### PowerShell

```powershell
# Install modules if needed
Install-Module Microsoft.Graph.Authentication -Force
Install-Module Microsoft.Graph.Applications -Force

# Connect
Connect-MgGraph -Scopes "Application.Read.All","Application-RemoteDesktopConfig.ReadWrite.All"

# Get Windows Cloud Login service principal
$WCLspId = (Get-MgServicePrincipal -Filter "AppId eq '270efc09-cd0d-444b-a71f-39af4910ec45'").Id

# Enable RDP protocol
Update-MgServicePrincipalRemoteDesktopSecurityConfiguration `
    -ServicePrincipalId $WCLspId `
    -IsRemoteDesktopProtocolEnabled

# Verify
$config = Get-MgServicePrincipalRemoteDesktopSecurityConfiguration -ServicePrincipalId $WCLspId
if ($config.IsRemoteDesktopProtocolEnabled) {
    Write-Host "✓ RDP protocol enabled" -ForegroundColor Green
} else {
    Write-Host "✗ Failed to enable RDP protocol" -ForegroundColor Red
}
```

---

## Step 2: Configure Trusted Device Groups

**Purpose:** Eliminates consent prompts when connecting to session hosts

### Create Dynamic Device Group

1. **Microsoft Entra admin center** → **Groups** → **New group**
2. Group type: **Security**
3. Group name: `AVD-SessionHosts-Devices`
4. Membership type: **Dynamic Device**
5. **Add dynamic query:**
   ```
   (device.displayName -startsWith "avd-pool-")
   ```
6. **Save**
7. Wait 5-10 minutes for group to populate

### Add Group to Service Principal

```powershell
# Get device group
$deviceGroup = Get-MgGroup -Filter "displayName eq 'AVD-SessionHosts-Devices'"

# Create target device group object
$tdg = New-Object -TypeName Microsoft.Graph.PowerShell.Models.MicrosoftGraphTargetDeviceGroup
$tdg.Id = $deviceGroup.Id
$tdg.DisplayName = $deviceGroup.DisplayName

# Add to service principal
New-MgServicePrincipalRemoteDesktopSecurityConfigurationTargetDeviceGroup `
    -ServicePrincipalId $WCLspId `
    -BodyParameter $tdg

Write-Host "✓ Trusted device group configured" -ForegroundColor Green
Write-Host "  Users will not see consent prompts" -ForegroundColor Gray
```

**Note:** Max 10 device groups allowed

---

## Step 3: Configure Conditional Access

**Three cloud apps must be configured:**

| App | App ID | Purpose |
|-----|--------|---------|
| Azure Virtual Desktop | `9cdead84-a844-4324-93f2-b2e6bb768d07` | Gateway auth |
| Windows Cloud Login | `270efc09-cd0d-444b-a71f-39af4910ec45` | Session host SSO |
| Microsoft Remote Desktop | `a4a365df-50f1-4397-bc59-1a1564b8bb9c` | Client auth |

### Key Rules:

1. **Match policies across all three apps** with one exception:
   - ⚠️ **Do NOT apply sign-in frequency policies to Windows Cloud Login**
   
2. **If using passwordless without restrictions:**
   - Exclude "Azure Windows VM Sign-In" (`372140e0-b3b7-4226-8ef9-d57986796201`) from MFA requirements

### Example CA Policy Setup

**Policy: AVD - Require MFA**

1. Entra admin center → **Protection** → **Conditional Access** → **New policy**
2. Name: `AVD - Require MFA`
3. **Users:** Select `AVD-Users` group
4. **Cloud apps:**
   - Select apps:
     - Azure Virtual Desktop
     - Windows Cloud Login
     - Microsoft Remote Desktop
5. **Conditions:**
   - Locations: Any location OR Trusted locations only
6. **Grant:**
   - Require multifactor authentication
7. **Session:**
   - ⚠️ Do NOT set sign-in frequency
8. **Enable policy** → **Create**

---

## Step 4: Verify Host Pool RDP Properties

### Check via Portal

1. Azure Virtual Desktop → Host pools → `Pool-Pooled-Prod`
2. **RDP Properties** → **Connection information**
3. **Microsoft Entra single sign-on** should show:
   - "Connections will use Microsoft Entra authentication to provide single sign-on"

### Check via PowerShell

```powershell
$hostPool = Get-AzWvdHostPool `
    -ResourceGroupName "RG-Azure-VDI-01" `
    -Name "Pool-Pooled-Prod"

$rdpProperties = $hostPool.CustomRdpProperty

# Check for SSO enabled
if ($rdpProperties -match "enablerdsaadauth:i:1") {
    Write-Host "✓ SSO enabled in RDP properties" -ForegroundColor Green
} else {
    Write-Host "✗ SSO NOT enabled" -ForegroundColor Red
    Write-Host "  Run this command to fix:" -ForegroundColor Yellow
    Write-Host "  Update-AzWvdHostPool -ResourceGroupName 'RG-Azure-VDI-01' -Name 'Pool-Pooled-Prod' -CustomRdpProperty 'enablerdsaadauth:i:1;use udp:i:0;'" -ForegroundColor Gray
}

# Also verify UDP disabled
if ($rdpProperties -match "use udp:i:0") {
    Write-Host "✓ UDP disabled (TCP only)" -ForegroundColor Green
} else {
    Write-Host "⚠ UDP setting not found" -ForegroundColor Yellow
}
```

### Enable SSO if Missing

```powershell
# If SSO not enabled, add it
Update-AzWvdHostPool `
    -ResourceGroupName "RG-Azure-VDI-01" `
    -Name "Pool-Pooled-Prod" `
    -CustomRdpProperty "enablerdsaadauth:i:1;use udp:i:0;audiocapturemode:i:1;audiomode:i:0;"

Write-Host "✓ RDP properties updated" -ForegroundColor Green
```

---

## Step 5: Assign RBAC Roles

### Virtual Machine User Login

```powershell
# Required for SSO to VMs
$resourceGroup = "RG-Azure-VDI-01"
$avdGroup = Get-MgGroup -Filter "displayName eq 'AVD-Users'"
$rg = Get-AzResourceGroup -Name $resourceGroup

New-AzRoleAssignment `
    -ObjectId $avdGroup.Id `
    -RoleDefinitionName "Virtual Machine User Login" `
    -Scope $rg.ResourceId

Write-Host "✓ VM User Login role assigned" -ForegroundColor Green
```

---

## Testing SSO

### Test 1: No Credential Prompt

1. User launches Windows App
2. Signs in with Entra ID (once)
3. Desktop should launch **without** additional credential prompt
4. ✓ SSO is working

**If credential prompt appears:** SSO not configured correctly

### Test 2: Session Host Check

```powershell
# Run on session host after user logs in
dsregcmd /status
# Should show:
#   AzureAdJoined : YES
#   AzureAdPrt : YES

# Check SSO token
klist
# Should show tickets for AVD services
```

### Test 3: Verify Lock Screen Behavior

**Default behavior:** Session disconnects instead of showing lock screen
- This is by design for passwordless auth
- Conditional Access policies re-evaluated on reconnect

**If traditional lock screen needed:** Configure separately via policy

---

## Troubleshooting

### Issue: Users still see credential prompt

**Checks:**
1. RDP properties include `enablerdsaadauth:i:1`
2. Windows Cloud Login service principal has `IsRemoteDesktopProtocolEnabled: True`
3. Trusted device groups configured
4. Wait 10-15 minutes for changes to propagate

### Issue: "Your credentials are incorrect"

**Cause:** Missing RBAC assignment

**Solution:**
```powershell
# Assign Virtual Machine User Login
New-AzRoleAssignment `
    -ObjectId $avdGroup.Id `
    -RoleDefinitionName "Virtual Machine User Login" `
    -Scope $rg.ResourceId
```

### Issue: "Sign-in method not allowed"

**Cause:** Conditional Access enforcing MFA on Azure Windows VM Sign-in app

**Solution:** Exclude this app from MFA requirements:
- App ID: `372140e0-b3b7-4226-8ef9-d57986796201`

### Issue: Per-user MFA conflicts

**Solution:** Disable per-user MFA, use Conditional Access MFA only

---

## Verification Script

```powershell
Write-Host "=== SSO CONFIGURATION VERIFICATION ===" -ForegroundColor Cyan

# Check 1: Service principal
Connect-MgGraph -Scopes "Application.Read.All"
$WCLspId = (Get-MgServicePrincipal -Filter "AppId eq '270efc09-cd0d-444b-a71f-39af4910ec45'").Id
$config = Get-MgServicePrincipalRemoteDesktopSecurityConfiguration -ServicePrincipalId $WCLspId

Write-Host "`n[1] Windows Cloud Login Service Principal..." -ForegroundColor Yellow
if ($config.IsRemoteDesktopProtocolEnabled) {
    Write-Host "✓ RDP protocol enabled" -ForegroundColor Green
} else {
    Write-Host "✗ RDP protocol NOT enabled" -ForegroundColor Red
}

# Check 2: Trusted device group
$deviceGroups = Get-MgServicePrincipalRemoteDesktopSecurityConfigurationTargetDeviceGroup -ServicePrincipalId $WCLspId
Write-Host "`n[2] Trusted Device Groups..." -ForegroundColor Yellow
if ($deviceGroups) {
    Write-Host "✓ $($deviceGroups.Count) device group(s) configured" -ForegroundColor Green
    foreach ($group in $deviceGroups) {
        Write-Host "  - $($group.DisplayName)" -ForegroundColor Gray
    }
} else {
    Write-Host "⚠ No trusted device groups" -ForegroundColor Yellow
    Write-Host "  Users will see consent prompts" -ForegroundColor Gray
}

# Check 3: Host pool RDP properties
Connect-AzAccount -ErrorAction SilentlyContinue | Out-Null
$hostPool = Get-AzWvdHostPool -ResourceGroupName "RG-Azure-VDI-01" -Name "Pool-Pooled-Prod"

Write-Host "`n[3] Host Pool RDP Properties..." -ForegroundColor Yellow
if ($hostPool.CustomRdpProperty -match "enablerdsaadauth:i:1") {
    Write-Host "✓ SSO enabled (enablerdsaadauth:i:1)" -ForegroundColor Green
} else {
    Write-Host "✗ SSO NOT enabled in RDP properties" -ForegroundColor Red
}

# Check 4: RBAC
$avdGroup = Get-MgGroup -Filter "displayName eq 'AVD-Users'"
$rg = Get-AzResourceGroup -Name "RG-Azure-VDI-01"
$rbac = Get-AzRoleAssignment -ObjectId $avdGroup.Id -Scope $rg.ResourceId -RoleDefinitionName "Virtual Machine User Login"

Write-Host "`n[4] RBAC Assignment..." -ForegroundColor Yellow
if ($rbac) {
    Write-Host "✓ Virtual Machine User Login assigned" -ForegroundColor Green
} else {
    Write-Host "✗ Missing VM User Login role" -ForegroundColor Red
}

Write-Host "`n=== VERIFICATION COMPLETE ===" -ForegroundColor Cyan
```

---

## Configuration Summary

**For Entra-only environments:**
1. ✓ Enable RDP on Windows Cloud Login service principal
2. ✓ Configure trusted device groups (optional but recommended)
3. ✓ Match Conditional Access policies across 3 apps
4. ✗ **Skip** Kerberos server object creation (not needed)
5. ✓ Verify `enablerdsaadauth:i:1` in host pool
6. ✓ Assign Virtual Machine User Login RBAC

**Result:** Passwordless SSO with FIDO2, Windows Hello, or passkeys

---

**Document Version:** 1.0  
**Last Updated:** December 2, 2025
