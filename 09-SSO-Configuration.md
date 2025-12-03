# Microsoft Entra SSO Configuration for AVD

**Purpose:** Enable passwordless Single Sign-On for Entra-only AVD environment

**Prerequisites:**
- Entra ID P1 or P2 licenses
- Host pool created with `enablerdsaadauth:i:1` in RDP properties
- Session hosts Entra-joined
- Device dynamic group `AVD-Devices-Pooled-SSO` created (Guide 03)
- PowerShell: `Microsoft.Graph` modules

**Overview:** 5-step process:
1. Enable RDP authentication on service principal
2. Configure trusted device groups
3. Review Conditional Access policies
4. Verify host pool RDP properties
5. Assign RBAC roles

⚠️ **No Kerberos server object needed for Entra-only environments**

---

## Automated Configuration

We have provided PowerShell scripts to automate Steps 1, 2, 4, and 5. Step 3 (Conditional Access) must still be performed manually.

### 1. Run Configuration Script

This script enables RDP auth, configures trusted device groups, updates host pool properties, and assigns RBAC roles.

```powershell
.\09-SSO-Configuration.ps1 `
    -ResourceGroupName "RG-Azure-VDI-01" `
    -HostPoolName "Pool-Pooled-Prod" `
    -AvdUsersGroupName "AVD-Users" `
    -AvdDevicesPooledSSOGroupName "AVD-Devices-Pooled-SSO"
```

### 2. Run Verification Script

Verify that all settings were applied correctly.

```powershell
.\09-SSO-Configuration.Tests.ps1 `
    -ResourceGroupName "RG-Azure-VDI-01" `
    -HostPoolName "Pool-Pooled-Prod" `
    -AvdUsersGroupName "AVD-Users" `
    -AvdDevicesPooledSSOGroupName "AVD-Devices-Pooled-SSO"
```

---

## Step 1: Enable RDP Authentication (Automated)

The script enables the RDP protocol on the "Windows Cloud Login" service principal (`270efc09-cd0d-444b-a71f-39af4910ec45`).

## Step 2: Configure Trusted Device Groups (Automated)

The script adds your dynamic device group (`AVD-Devices-Pooled-SSO`) to the trusted list of the Windows Cloud Login service principal. This eliminates consent prompts for users connecting from these devices.

**Note:** Max 10 device groups allowed.

---

## Step 3: Configure Conditional Access (Manual)

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

## Step 4: Verify Host Pool RDP Properties (Automated)

The script checks and updates the host pool RDP properties to include:
- `enablerdsaadauth:i:1` (Enables Entra ID SSO)
- `use udp:i:0` (Disables UDP, often recommended for troubleshooting/compatibility)

---

## Step 5: Assign RBAC Roles (Automated)

The script assigns the **Virtual Machine User Login** role to your AVD users group (`AVD-Users`) on the resource group. This allows users to log in to the VMs.

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

**Solution:** Run the configuration script again to ensure the "Virtual Machine User Login" role is assigned.

### Issue: "Sign-in method not allowed"

**Cause:** Conditional Access enforcing MFA on Azure Windows VM Sign-in app

**Solution:** Exclude this app from MFA requirements:
- App ID: `372140e0-b3b7-4226-8ef9-d57986796201`

### Issue: Per-user MFA conflicts

**Solution:** Disable per-user MFA, use Conditional Access MFA only

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

**Document Version:** 1.1
**Last Updated:** December 3, 2025
