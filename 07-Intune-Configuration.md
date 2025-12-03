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
