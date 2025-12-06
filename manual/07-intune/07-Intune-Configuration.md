# Intune Configuration for AVD

**Purpose:** Configure FSLogix and disable UDP via Intune Settings Catalog

**Prerequisites:**
- Session hosts Entra-joined and Intune-enrolled
- FSLogix storage: Use the storage account name you created in Guide 02 (pattern: `fslogix<random-5-digits>`, e.g., `fslogix52847`)
- Entra ID groups created (Guide 03)
- Device dynamic groups created and populated with session hosts
- Intune admin access

**Configuring:**
1. FSLogix profile containers
2. UDP disable (session hosts)
3. UDP disable (client devices)
4. Suppress Windows Hello & Getting Started (session hosts)

---

## Automated Deployment (Recommended)

### Using the Automation Script

**Script:** `07-Intune-Configuration.ps1` (PowerShell)

**Quick Start:**

```powershell
# 1. Login to Microsoft Graph
Connect-MgGraph -Scopes "DeviceManagementConfiguration.ReadWrite.All", "Group.Read.All"

# 2. Run the script with your storage account details
.\07-Intune-Configuration.ps1 `
  -StorageAccountName "fslogix52847" `
  -FileShareName "fslogix-profiles" `
  -DeviceGroupName "AVD-Devices-Pooled-FSLogix"

# 3. Or use all defaults (requires groups exist from Guide 03)
.\07-Intune-Configuration.ps1
```

**What the script does:**
1. Validates FSLogix storage account and file share exist
2. Validates device groups created in Guide 03
3. Creates Intune Settings Catalog policies for:
   - FSLogix profile container configuration
   - RDP TCP-only transport (disable UDP) for session hosts
   - RDP TCP-only transport (disable UDP) for client devices
   - Windows Hello and tips suppression
4. Assigns policies to respective device groups:
   - FSLogix policy → `AVD-Devices-Pooled-FSLogix`
   - Session host TCP policy → `AVD-Devices-Pooled-Network`
   - Client TCP policy → `AVD-Devices-Clients-Corporate`
   - Suppression policy → `AVD-Devices-Pooled-*` (all session hosts)
5. Validates all policies created and assigned successfully

**Expected Runtime:** 3-5 minutes

**Important Notes:**
- Policies will apply to devices within 15-30 minutes of Intune sync
- FSLogix cache is 20 GB, adjustable via script parameter
- Policies take precedence over host pool RDP settings
- Device groups must exist and have devices before policy assignment (Groups auto-populate when session hosts are deployed with "avd-pool-*" naming)

**Verification:**
```powershell
# Check policies created
Get-MgDeviceManagementConfigurationPolicy | Where-Object { $_.Name -like "AVD*" }

# Check policy assignments
$policies = Get-MgDeviceManagementConfigurationPolicy | Where-Object { $_.Name -like "AVD*" }
foreach ($policy in $policies) {
    Get-MgDeviceManagementConfigurationPolicyAssignment -DeviceManagementConfigurationPolicyId $policy.Id
}

# Verify policy deployment on device (RDP into session host)
# Look for Intune settings in: Settings > System > About > Device manager
```

---

## Manual Deployment (Alternative)

### Part 1: FSLogix Configuration

### Intune Admin Center

1. https://intune.microsoft.com → **Devices** → **Configuration** → **+ Create**
2. Platform: **Windows 10 and later**
3. Profile type: **Settings catalog** → **Create**
4. Name: `AVD - FSLogix Configuration`
5. Click **+ Add settings** → Search: `FSLogix`
6. Navigate: **Administrative Templates > FSLogix > Profile Containers**

**Select and configure:**

| Setting | Value |
|---------|-------|
| Enabled | Enabled, Value: `1` |
| VHD Locations | Enabled, Value: `\\YOUR_STORAGE_ACCOUNT.file.core.windows.net\fslogix-profiles` (replace YOUR_STORAGE_ACCOUNT with your storage account name from Guide 02, e.g., `fslogix52847`) |
| Size in MBs | Enabled, Value: `20000` |
| Is Dynamic (VHD) | Enabled, Value: `1` |
| Profile Type | Enabled, Select: `Normal Profile` |
| VHDX Sector Size | Enabled, Value: `4096` |

7. **Assignments:** Assign to device group: `AVD-Devices-Pooled-FSLogix` (created in Guide 03)
8. **Review + create**

---

## Part 2: Disable UDP - Session Hosts

### Intune Admin Center

1. **Devices** → **Configuration** → **+ Create** → **Settings catalog**
2. Name: `AVD - Force TCP Only - Session Hosts`
3. **+ Add settings** → Search: `RDP transport`
4. Path: **Admin Templates > Windows Components > Remote Desktop Services > Remote Desktop Session Host > Connections**
5. Check: **Select RDP transport protocols**
6. Configure:
   - Toggle: **Enabled**
   - Dropdown: **Use only TCP**
7. Assign to device group: `AVD-Devices-Pooled-Network` (created in Guide 03)
8. **Review + create**

---

## Part 3: Disable UDP - Client Devices

### Intune Admin Center

1. **Devices** → **Configuration** → **+ Create** → **Settings catalog**
2. Name: `AVD - Force TCP Only - Clients`
3. **+ Add settings** → Search: `Turn Off UDP`
4. Path: **Admin Templates > Windows Components > Remote Desktop Services > Remote Desktop Connection Client**
5. Check: **Turn Off UDP On Client**
6. Configure:
   - Toggle: **Enabled**
7. Assign to device group: `AVD-Devices-Clients-Corporate` (created in Guide 03 - for corporate workstations/laptops)
8. **Review + create**

---

## Part 4: Suppress Windows Hello & Getting Started

### Purpose
Disable Windows Hello setup prompts and Getting Started tips on first login for all users. This complements the registry settings in the golden image (Guide 05) with Intune-level enforcement.

### Intune Admin Center

1. **Devices** → **Configuration** → **+ Create** → **Settings catalog**
2. Name: `AVD - Suppress Hello & Getting Started`
3. **+ Add settings** → Search for each of the following settings:

#### Setting 1: Disable Windows Hello Sign-in Wizard
- Search: `hello`
- Path: **User Configuration > Policies > Administrative Templates > Windows Components > Windows Logon Options**
- Setting: **Disable the Windows Hello sign-in wizard**
- Configure:
   - Toggle: **Enabled**

#### Setting 2: Disable Windows Tips
- Search: `tips`
- Path: **Computer Configuration > Policies > Administrative Templates > Windows Components > Windows Tips**
- Setting: **Disable Tips on Logon**
- Configure:
   - Toggle: **Enabled**

#### Setting 3: Disable Biometrics Setup
- Search: `biometric`
- Path: **Computer Configuration > Policies > Administrative Templates > Windows Components > Biometrics**
- Setting: **Allow the use of biometric devices**
- Configure:
   - Toggle: **Disabled**

#### Setting 4: Disable Cloud Content on Lock Screen
- Search: `cloud content`
- Path: **Computer Configuration > Policies > Administrative Templates > Windows Components > Cloud Content**
- Setting: **Turn off Microsoft consumer experiences**
- Configure:
   - Toggle: **Enabled**

#### Setting 5: Disable Getting Started
- Search: `Getting Started`
- Path: **Computer Configuration > Policies > Administrative Templates > System > Logon/Logoff**
- Setting: **Don't display Getting Started page**
- Configure:
   - Toggle: **Enabled**

4. **Assignments:** Assign to device group: `AVD-Devices-Pooled-SSO` (created in Guide 03)
   - Alternative: Create new device group `AVD-Devices-Pooled-FirstLogin` if you want separate targeting
5. **Review + create**

### Notes
- These settings enforce the registry configurations already set in the golden image (Guide 05)
- Intune policy applies at machine level for all users
- Combined with golden image registry settings = belt-and-suspenders approach
- Settings sync within 15 minutes of session host Intune enrollment
- If users somehow reset these, Intune policy will re-apply on next sync

---

## Part 5: Hide Shutdown Button from Start Menu

### Purpose
Prevents users from shutting down AVD session hosts via the Start menu. Users can still disconnect, sign out, or end sessions appropriately. This is important in pooled deployments where shutdown would affect other connected users.

### Intune Admin Center

#### Option 1: Settings Catalog (Recommended)
1. **Devices** → **Configuration** → **+ Create** → **Settings catalog**
2. Name: `AVD - Hide Shutdown Button`
3. Description: `Prevents shutdown option in Start menu for AVD session hosts`
4. **+ Add settings** → Search: `Start`
5. Find and select: **Hide Shutdown**
6. Configure:
   - Toggle: **Enabled** or **Block**
7. **Assignments:** Assign to device group: `AVD-Devices-Pooled-Network` (or your session host device groups)
8. **Review + create**

#### Option 2: Device Restrictions (Alternative)
1. **Devices** → **Configuration** → **+ Create** → **Device restrictions**
2. Name: `AVD - Hide Shutdown Button (Device Restrictions)`
3. Platform: **Windows 10 and later**
4. Under **Start** section:
   - **Shut Down**: Set to **Block**
5. **Assignments:** Assign to session host device groups
6. **Review + create**

### Verification

```powershell
# On session host, verify registry setting
Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" `
  -Name "NoClose" -ErrorAction SilentlyContinue

# Expected: NoClose = 1 (if policy applied)
# Result: Users should not see shutdown option in Start menu
```

### Expected Behavior
- Users can still disconnect from AVD session
- Users can still sign out
- Users cannot directly shutdown the VM via Start menu
- Session continues to run for other users

---

## Part 6: Auto-Close Applications on Logoff (AutoEndTasks)

### Purpose
⚠️ **IMPORTANT**: This setting automatically closes applications when users log off, without prompting to save work. **Use with caution and clear user communication.**

**Benefits:**
- Prevents sessions from remaining connected when users click logoff and walk away
- Eliminates "save your work?" prompts that can prolong logoff
- Ensures clean logoff for multi-session pooled environments

**Risks:**
- Unsaved work will be lost without warning
- Users must understand to save work BEFORE logging off

### Intune Admin Center

1. **Devices** → **Configuration** → **+ Create** → **Settings catalog**
2. Name: `AVD - Auto End Tasks on Logoff`
3. Description: `Automatically closes applications on logoff without prompting`
4. **+ Add settings** → Search: `AutoEndTasks` (or navigate to User Configuration section below)
5. Path: **User Configuration > Administrative Templates > System > Logon/Logoff**
6. Find and select: **AutoEndTasks** (alternative search terms: "Auto close," "End Tasks")
7. Configure:
   - Toggle: **Enabled**
8. **Optional:** Add additional setting for timeout
   - Search: `WaitToKillAppTimeout`
   - Path: Same as above
   - Value: `5000` (milliseconds = 5 seconds)
9. **Assignments:** Assign to user groups (not device groups) - e.g., `AVD-Users-Pooled`, `AVD-Users-Pooled-Multi-Session`
10. **Review + create**

### Alternative: Group Policy (for reference)

If using traditional Group Policy instead of Intune:

1. Open **Group Policy Management Console**
2. Edit GPO for AVD session hosts
3. Navigate to: **User Configuration > Preferences > Windows Settings > Registry**
4. Right-click → **New → Registry Item**
5. Configure:
   - Action: **Update**
   - Hive: **HKEY_CURRENT_USER**
   - Key Path: `Control Panel\Desktop`
   - Value name: `AutoEndTasks`
   - Value type: **REG_SZ**
   - Value data: `1`
6. Optional: Add second registry item for timeout
   - Same path
   - Value name: `WaitToKillAppTimeout`
   - Value type: **REG_SZ**
   - Value data: `5000`

### Registry Path (for verification)

```
User Configuration:
HKEY_CURRENT_USER\Control Panel\Desktop
- AutoEndTasks (REG_SZ) = "1"           [Enabled = 1, Disabled = 0]

Optional timeout setting:
HKEY_CURRENT_USER\Control Panel\Desktop
- WaitToKillAppTimeout (REG_SZ) = "5000"  [in milliseconds]
```

### Deployment Considerations

1. **User Communication**: Inform users that unsaved work will be lost on logoff
2. **Application Impact**: Consider applications with auto-save features
   - OneDrive, Google Drive: Auto-save enabled
   - Office: May lose unsaved docs
   - Browsers: Session restore varies
3. **User Training**: Train users to save work BEFORE logging off
4. **Alternative**: Consider longer timeout values for grace period
   - Default: 3000 ms (3 seconds)
   - Recommended: 5000 ms (5 seconds)
   - Maximum: 10000 ms (10 seconds)
5. **Scope**: User-based policy (applies per user, not per device)
6. **Timing**: Takes effect on next user logon after policy application

### Verification

```powershell
# On session host (after user logs in with policy applied)

# Check if policy applied
dsregcmd /status | Select-String "Intune"

# Verify registry setting (in user's session)
Get-ItemProperty -Path "HKCU:\Control Panel\Desktop" `
  -Name "AutoEndTasks" -ErrorAction SilentlyContinue

# Expected result: AutoEndTasks = 1

# Check timeout setting (optional)
Get-ItemProperty -Path "HKCU:\Control Panel\Desktop" `
  -Name "WaitToKillAppTimeout" -ErrorAction SilentlyContinue

# Expected result: WaitToKillAppTimeout = 5000
```

### Expected Behavior

**When enabled and working correctly:**
1. User opens application with unsaved work (e.g., Notepad with text, Word document)
2. User clicks "Sign Out" on AVD session
3. Application closes immediately WITHOUT "Save your work?" prompt
4. Session ends
5. No pending app saves or hanging processes

**Testing Steps:**
1. Deploy policy to test user group
2. User signs in to AVD session
3. Open application with unsaved work (Notepad, Word, VS Code, etc.)
4. Type some text/make changes
5. Click Start → Sign Out
6. Verify: Application closes immediately without save prompt
7. Verify: Session ends cleanly
8. Verify registry: `Get-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name AutoEndTasks`

### Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| Policy not applying | User group not assigned or incorrect | Verify assignment to correct user group, wait 15-30 min for sync |
| AutoEndTasks not set to 1 | Policy didn't apply | Check device Intune enrollment: `dsregcmd /status` |
| Apps still prompt to save | Policy not applied yet | Wait 15-30 minutes, restart session host, user re-login |
| Timeout too short | Apps killed before proper shutdown | Increase WaitToKillAppTimeout to 10000 |
| Users complain of lost work | Expected behavior of AutoEndTasks | User communication and training needed |

### Rollback

If issues occur:
1. Remove policy assignment from user group
2. Or delete the policy entirely
3. Wait 15-30 minutes for sync
4. Users' next logon will not have AutoEndTasks enforced

---

## Verification

### On Session Host

```powershell
# Check FSLogix
$fslogixPath = "HKLM:\SOFTWARE\FSLogix\Profiles"
Get-ItemProperty -Path $fslogixPath -Name "Enabled", "VHDLocations", "SizeInMBs"

# Check UDP disabled
Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" -Name "SelectTransport"
# Should return: SelectTransport : 1 (TCP only)

# Test FSLogix connectivity (replace YOUR_STORAGE_ACCOUNT with your storage account name)
Test-NetConnection -ComputerName YOUR_STORAGE_ACCOUNT.file.core.windows.net -Port 445

# Test Kerberos
klist get cifs/YOUR_STORAGE_ACCOUNT.file.core.windows.net
```

### After User Login

```powershell
# Check if profile VHD attached
frxcmd.exe list-vhds

# Check for user's VHD file (replace YOUR_STORAGE_ACCOUNT with your storage account name)
Get-ChildItem "\\YOUR_STORAGE_ACCOUNT.file.core.windows.net\fslogix-profiles" -Filter "*$env:USERNAME*.vhdx"
```

### In Active Session

- Click connection info icon in toolbar
- Transport should show: **TCP** (not UDP)

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Policy not applying | Check device is Entra-joined and Intune-enrolled via `dsregcmd /status` |
| FSLogix profile fails | Verify RBAC: "Storage File Data SMB Share Contributor" assigned to users |
| Kerberos auth fails | Verify Entra Kerberos enabled on storage account |
| DNS resolves to public IP | Check private DNS zone linked to VNet |
| UDP still used | Wait 15 mins for policy, restart session host, check registry values |

---

## Manual Registry (Testing Only)

```powershell
# FSLogix
# Replace YOUR_STORAGE_ACCOUNT with your storage account name from Guide 02
$path = "HKLM:\SOFTWARE\FSLogix\Profiles"
New-Item -Path $path -Force | Out-Null
Set-ItemProperty -Path $path -Name "Enabled" -Value 1 -Type DWord
Set-ItemProperty -Path $path -Name "VHDLocations" -Value "\\YOUR_STORAGE_ACCOUNT.file.core.windows.net\fslogix-profiles" -Type MultiString
Set-ItemProperty -Path $path -Name "SizeInMBs" -Value 20000 -Type DWord
Set-ItemProperty -Path $path -Name "IsDynamic" -Value 1 -Type DWord

# UDP disable
$path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services"
New-Item -Path $path -Force | Out-Null
Set-ItemProperty -Path $path -Name "SelectTransport" -Value 1 -Type DWord

Write-Host "✓ Manual config complete. Restart required."
```

---

**Next:** Assign RBAC roles (Guide 08), then configure SSO (Guide 09)

---

## Verification for Hello & Getting Started Suppression

### On Session Host (after Part 4 policy applies)

```powershell
# Verify Intune policy applied (wait 15 mins after enrollment)
dsregcmd /status | Select-String "Intune"

# Check registry keys set by policy
Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "NoStartupApp"
Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Tips" -Name "DisableTipsOnLogon"
Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Biometrics" -Name "Enabled"

# Verify no Hello prompts appear on next login
# Expected: Clean login without any setup wizards
```

### After User Login

1. Logon should complete without Hello sign-in wizard
2. No "Getting Started" tips should appear
3. No biometric/PIN setup prompts
4. No cloud content suggestions on lock screen

### Troubleshooting

| Issue | Solution |
|-------|----------|
| Hello wizard still appears | Wait 15-30 mins for policy sync, restart session host |
| Tips still shown | Verify policy assigned to correct device group, check Intune enrollment |
| Biometric prompt appears | Ensure Biometrics setting is set to **Disabled** (not Enabled) |
