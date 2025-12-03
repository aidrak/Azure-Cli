# Intune Configuration for AVD

**Purpose:** Configure FSLogix and disable UDP via Intune Settings Catalog

**Prerequisites:**
- Session hosts Entra-joined and Intune-enrolled
- FSLogix storage: `fslogix37402` (or your storage account name)
- Entra ID groups created (Guide 03)
- Device dynamic groups created and populated with session hosts

**Configuring:**
1. FSLogix profile containers
2. UDP disable (session hosts)
3. UDP disable (client devices)
4. Suppress Windows Hello & Getting Started (session hosts)

---

## Part 1: FSLogix Configuration

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
| VHD Locations | Enabled, Value: `\\fslogix37402.file.core.windows.net\fslogix-profiles` |
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

## Verification

### On Session Host

```powershell
# Check FSLogix
$fslogixPath = "HKLM:\SOFTWARE\FSLogix\Profiles"
Get-ItemProperty -Path $fslogixPath -Name "Enabled", "VHDLocations", "SizeInMBs"

# Check UDP disabled
Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" -Name "SelectTransport"
# Should return: SelectTransport : 1 (TCP only)

# Test FSLogix connectivity
Test-NetConnection -ComputerName fslogix37402.file.core.windows.net -Port 445

# Test Kerberos
klist get cifs/fslogix37402.file.core.windows.net
```

### After User Login

```powershell
# Check if profile VHD attached
frxcmd.exe list-vhds

# Check for user's VHD file
Get-ChildItem "\\fslogix37402.file.core.windows.net\fslogix-profiles" -Filter "*$env:USERNAME*.vhdx"
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
$path = "HKLM:\SOFTWARE\FSLogix\Profiles"
New-Item -Path $path -Force | Out-Null
Set-ItemProperty -Path $path -Name "Enabled" -Value 1 -Type DWord
Set-ItemProperty -Path $path -Name "VHDLocations" -Value "\\fslogix37402.file.core.windows.net\fslogix-profiles" -Type MultiString
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
