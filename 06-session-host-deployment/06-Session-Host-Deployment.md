# Session Host Deployment from Golden Images

**Purpose:** Deploy AVD session hosts from captured golden images

**Prerequisites:**
- Golden images in Azure Compute Gallery
- Host pool: `Pool-Pooled-Prod`
- VNet and subnets created
- PowerShell with Az.DesktopVirtualization and Az.Compute modules

---

## Automated Deployment (Recommended)

### Using the Automation Script

**Script:** `06-Session-Host-Deployment.ps1` (PowerShell)

**Quick Start:**

```powershell
# 1. Login to Azure
Connect-AzAccount

# 2. Find your golden image ID first (from Guide 05)
$imageId = "/subscriptions/{subscriptionId}/resourceGroups/RG-Azure-VDI-01/providers/Microsoft.Compute/galleries/AVD_Image_Gallery/images/Win11-AVD-Pooled/versions/1.0.0"

# 3. Run the script with defaults (deploys 10 session hosts)
.\06-Session-Host-Deployment.ps1 `
  -ResourceGroupName "RG-Azure-VDI-01" `
  -HostPoolName "Pool-Pooled-Prod" `
  -GalleryImageId $imageId `
  -VNetName "vnet-avd-prod" `
  -SubnetName "snet-avd-sessionhosts"

# 4. Or customize number of VMs, sizing, naming
.\06-Session-Host-Deployment.ps1 `
  -ResourceGroupName "RG-Azure-VDI-01" `
  -HostPoolName "Pool-Pooled-Prod" `
  -GalleryImageId $imageId `
  -VNetName "vnet-avd-prod" `
  -SubnetName "snet-avd-sessionhosts" `
  -NumberOfVMs 10 `
  -VmPrefix "avd-pool" `
  -VmSize "Standard_D4s_v6"
```

**What the script does:**
1. Validates prerequisites (host pool exists, image accessible)
2. Generates host pool registration token (24-hour validity)
3. Creates N session host VMs with zero-padded naming (avd-pool-001, avd-pool-002, etc.)
4. Joins session hosts to VNet in private subnet (no public IPs)
5. Registers session hosts to host pool using registration token
6. Validates all session hosts available and ready
7. Updates dynamic device groups (devices matching "avd-pool-*" will auto-join)

**Expected Runtime:** 15-20 minutes for 10 VMs

**Important Notes:**
- Session hosts are created without public IPs (secure, private deployment)
- Naming pattern `avd-pool-*` ensures automatic membership in Entra device groups
- Registration token is valid for 24 hours; script runs within this window
- VMs auto-join Entra ID via Intune enrollment setting

**Verification:**
```powershell
# Check session hosts registered
Get-AzWvdSessionHost -ResourceGroupName "RG-Azure-VDI-01" -HostPoolName "Pool-Pooled-Prod"

# Verify all are "Available"
Get-AzWvdSessionHost -ResourceGroupName "RG-Azure-VDI-01" -HostPoolName "Pool-Pooled-Prod" | Select-Object Name, Status

# Check in Entra ID - devices should appear with avd-pool-* naming
# Navigate to: Devices > All devices (filter: avd-pool-)
```

---

## Manual Deployment (Alternative)

### Deploy via Host Pool

### Azure Portal

1. Azure Virtual Desktop → Host pools → `Pool-Pooled-Prod`
2. **Session hosts** → **+ Add**
3. **Virtual machines:**
   - Name prefix: `avd-pool-`
   - Image: **Browse all** → My Items → Gallery → `Win11-AVD-Pooled`
   - Size: `Standard_D4ds_v6` (10 sessions)
   - Number of VMs: `10`
4. **Network:**
   - VNet: `vnet-avd-prod`
   - Subnet: `snet-avd-sessionhosts`
   - Public IP: **No**
5. **Domain:**
   - Microsoft Entra ID: **Yes**
   - Enroll with Intune: **Yes** ⚠️ CRITICAL
6. Admin account: `entra-admin` / klsdf0j2;3s(fjls)
7. **Review + create**
8. Wait 15-20 minutes

---

## Verification

### Check Session Hosts

```powershell
Get-AzWvdSessionHost -ResourceGroupName "RG-Azure-VDI-01" -HostPoolName "Pool-Pooled-Prod"
# Status should be: Available
```

### Check Entra Join

1. Microsoft Entra admin center → **Devices** → Search `avd-pool-`
2. Join type: **Microsoft Entra joined**

### Check Intune Enrollment

1. Intune admin center → **Devices** → Search `avd-pool-`
2. Managed by: **Intune**

### On Session Host (RDP in)

```powershell
# Entra join
dsregcmd /status
# AzureAdJoined: YES

# FSLogix
Get-ItemProperty -Path "HKLM:\SOFTWARE\FSLogix\Profiles" -Name "Enabled"

# UDP disabled
Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" -Name "SelectTransport"

# Storage connectivity (replace YOUR_STORAGE_ACCOUNT with your storage account name from Guide 02)
Test-NetConnection -ComputerName YOUR_STORAGE_ACCOUNT.file.core.windows.net -Port 445

# Kerberos
klist get cifs/YOUR_STORAGE_ACCOUNT.file.core.windows.net
```

---

## Post-Deployment Golden Image Validation

Run this validation script on deployed session hosts to verify that all golden image optimizations from Guide 05 persisted through Sysprep and deployment.

### On Session Host (RDP in)

```powershell
Write-Host "`n=== Session Host Golden Image Validation ===" -ForegroundColor Cyan

# Check 1: Windows Defender FSLogix Exclusions
$exclusions = Get-MpPreference | Select-Object -ExpandProperty ExclusionPath
if ($exclusions -contains "C:\Program Files\FSLogix") {
    Write-Host "✓ Defender FSLogix exclusions present" -ForegroundColor Green
} else {
    Write-Host "✗ Defender exclusions missing" -ForegroundColor Yellow
}

# Check 2: System Locale
$locale = Get-WinSystemLocale
Write-Host "✓ System locale: $($locale.Name)" -ForegroundColor Green

# Check 3: VSS Disabled
$vss = Get-Service VSS -ErrorAction SilentlyContinue
if ($vss.StartType -eq 'Disabled') {
    Write-Host "✓ VSS disabled (storage optimized)" -ForegroundColor Green
} else {
    Write-Host "✗ VSS still enabled" -ForegroundColor Yellow
}

# Check 4: Windows Search Disabled (VDOT verification)
$wsearch = Get-Service WSearch -ErrorAction SilentlyContinue
if ($wsearch.Status -eq 'Stopped' -and $wsearch.StartType -eq 'Disabled') {
    Write-Host "✓ Windows Search disabled (VDOT applied)" -ForegroundColor Green
} else {
    Write-Host "✗ Windows Search enabled" -ForegroundColor Yellow
}

# Check 5: RDP Timezone Redirection
$rdpReg = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" -Name "fEnableTimeZoneRedirection" -ErrorAction SilentlyContinue
if ($rdpReg.fEnableTimeZoneRedirection -eq 1) {
    Write-Host "✓ Timezone redirection enabled" -ForegroundColor Green
} else {
    Write-Host "✗ Timezone redirection missing" -ForegroundColor Yellow
}

Write-Host "`nValidation complete. Yellow warnings indicate settings that may need investigation." -ForegroundColor Cyan
```

**Purpose:** Confirms that Sysprep preserved all golden image optimizations from Guide 05. Yellow warnings indicate settings that may not have persisted and should be investigated before deploying the image fleet-wide.

---

## Scaling
```

---

## Post-Deployment Golden Image Validation

Run this validation script on deployed session hosts to verify that all golden image optimizations from Guide 05 persisted through Sysprep and deployment.

### On Session Host (RDP in)

```powershell
Write-Host "`n=== Session Host Golden Image Validation ===" -ForegroundColor Cyan

# Check 1: Windows Defender FSLogix Exclusions
$exclusions = Get-MpPreference | Select-Object -ExpandProperty ExclusionPath
if ($exclusions -contains "C:\Program Files\FSLogix") {
    Write-Host "✓ Defender FSLogix exclusions present" -ForegroundColor Green
} else {
    Write-Host "✗ Defender exclusions missing" -ForegroundColor Yellow
}

# Check 2: System Locale
$locale = Get-WinSystemLocale
Write-Host "✓ System locale: $($locale.Name)" -ForegroundColor Green

# Check 3: VSS Disabled
$vss = Get-Service VSS -ErrorAction SilentlyContinue
if ($vss.StartType -eq 'Disabled') {
    Write-Host "✓ VSS disabled (storage optimized)" -ForegroundColor Green
} else {
    Write-Host "✗ VSS still enabled" -ForegroundColor Yellow
}

# Check 4: Windows Search Disabled (VDOT verification)
$wsearch = Get-Service WSearch -ErrorAction SilentlyContinue
if ($wsearch.Status -eq 'Stopped' -and $wsearch.StartType -eq 'Disabled') {
    Write-Host "✓ Windows Search disabled (VDOT applied)" -ForegroundColor Green
} else {
    Write-Host "✗ Windows Search enabled" -ForegroundColor Yellow
}

# Check 5: RDP Timezone Redirection
$rdpReg = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" -Name "fEnableTimeZoneRedirection" -ErrorAction SilentlyContinue
if ($rdpReg.fEnableTimeZoneRedirection -eq 1) {
    Write-Host "✓ Timezone redirection enabled" -ForegroundColor Green
} else {
    Write-Host "✗ Timezone redirection missing" -ForegroundColor Yellow
}

Write-Host "`nValidation complete. Yellow warnings indicate settings that may need investigation." -ForegroundColor Cyan
```

**Purpose:** Confirms that Sysprep preserved all golden image optimizations from Guide 05. Yellow warnings indicate settings that may not have persisted and should be investigated before deploying the image fleet-wide.

---

## Scaling

### Calculate VMs Needed

```
Users: 400
Sessions per VM: 12
Buffer: 20%

Required: (400 / 12) * 1.2 = 40 VMs
```

### Add More VMs

1. Host pool → Session hosts → **+ Add**
2. Number of VMs: `10`
3. Same settings as initial deployment

**Strategy:**
- Deploy 10 → Test
- Add 10 more → Validate
- Continue to 40 total
- Use autoscaling for power management

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Status "Unavailable" | Regenerate registration token, reinstall AVD agent |
| Not in Entra ID | Check managed identity, install AADLoginForWindows extension |
| FSLogix not working | Verify Intune enrollment, check policy assignment |
| Defender exclusions missing | Run Post-Deployment Golden Image Validation script; if missing, verify Section 8c in Guide 05, re-capture golden image |
| VSS still enabled | Run Post-Deployment Golden Image Validation script; check Section 8e in Guide 05, may need manual disable on session host |
| Locale incorrect | Run Post-Deployment Golden Image Validation script; verify Section 8d in Guide 05, restart required before Sysprep |
| VDOT optimizations lost | Run Post-Deployment Golden Image Validation script; likely Sysprep issue - re-run VDOT on deployed host and update golden image |

---

**Next:** Configure Intune policies (Guide 07), then RBAC (Guide 08)
