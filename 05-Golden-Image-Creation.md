# Golden Image Creation for AVD

**Purpose:** Create and capture optimized golden images for pooled and personal host pools

**Prerequisites:**
- VNet with subnet available
- Azure Compute Gallery (or will create)
- Admin credentials

**Creating:**
1. Temporary VM for image creation
2. Configured and optimized OS
3. Captured image in gallery

---

## Part 1: Create Temporary VM

### Azure CLI

```bash
resourceGroup="RG-Azure-VDI-01"
vmName="avd-gold-pool"
vnetName="vnet-vdi-centralus"
subnetName="subnet-vdi-hosts"

# Create VM with public IP for configuration
az vm create \
  --resource-group $resourceGroup \
  --name $vmName \
  --image "MicrosoftWindowsDesktop:windows-11:win11-25h2-avd:latest" \
  --size "Standard_D2ds_v4" \
  --admin-username "entra-admin" \
  --admin-password "ComplexP@ss123!" \
  --vnet-name $vnetName \
  --subnet $subnetName \
  --public-ip-sku Standard

# Get IP for RDP
az vm show -g $resourceGroup -n $vmName -d --query publicIps -o tsv
```

---

## Part 2: Configure VM (RDP In)

### 1. Disable BitLocker

```powershell
Disable-BitLocker -MountPoint "C:"
```

### 2. Install Updates

```powershell
Start-Process ms-settings:windowsupdate
# Install all updates, reboot as needed
```

### 3. Install FSLogix Agent

```powershell
New-Item -Path "C:\Temp" -ItemType Directory -Force
Invoke-WebRequest -Uri "https://aka.ms/fslogix-latest" -OutFile "C:\Temp\FSLogix.zip"
Expand-Archive -Path "C:\Temp\FSLogix.zip" -DestinationPath "C:\Temp\FSLogix" -Force
Set-Location "C:\Temp\FSLogix\x64\Release"
.\FSLogixAppsSetup.exe /install /quiet /norestart

# Verify
Test-Path "C:\Program Files\FSLogix\Apps\frx.exe"
```

⚠️ **Do NOT configure FSLogix settings** - Intune will do this

### 4. Install Chocolatey Package Manager

```powershell
# Install Chocolatey package manager
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# Verify installation
choco --version

# Close and reopen PowerShell for path updates
```

### 5. Install Adobe Acrobat Reader DC

```powershell
# Install Adobe Acrobat Reader DC via Chocolatey
choco install adobereader -y

# Verify installation
Test-Path "C:\Program Files\Adobe\Acrobat DC\Acrobat\Acrobat.exe"
# or
Test-Path "C:\Program Files (x86)\Adobe\Acrobat Reader DC\Reader\AcroRd32.exe"
```

### 6. Install Microsoft Office 365

```powershell
# Download Office Deployment Tool
New-Item -Path "C:\Temp\Office" -ItemType Directory -Force
Invoke-WebRequest `
  -Uri "https://download.microsoft.com/download/2/7/A/27AF1BE6-DD20-4CB4-B154-EBAB8A7D4A7E/officedeploymenttool_17328-20162.exe" `
  -OutFile "C:\Temp\Office\ODT.exe"

# Extract Office Deployment Tool
Start-Process -FilePath "C:\Temp\Office\ODT.exe" -ArgumentList "/quiet /extract:C:\Temp\Office" -Wait

# Create configuration file
$configXml = @"
<Configuration ID="d473a46c-9126-4f5a-99d8-af03586a67bc">
  <Add OfficeClientEdition="64" Channel="Current">
    <Product ID="O365ProPlusEEANoTeamsRetail">
      <Language ID="en-us" />
      <ExcludeApp ID="Groove" />
      <ExcludeApp ID="Lync" />
      <ExcludeApp ID="OneDrive" />
      <ExcludeApp ID="OneNote" />
      <ExcludeApp ID="OutlookForWindows" />
    </Product>
  </Add>
  <Property Name="SharedComputerLicensing" Value="1" />
  <Property Name="FORCEAPPSHUTDOWN" Value="FALSE" />
  <Property Name="DeviceBasedLicensing" Value="0" />
  <Property Name="SCLCacheOverride" Value="0" />
  <Updates Enabled="FALSE" />
  <RemoveMSI />
  <Display Level="None" AcceptEULA="TRUE" />
</Configuration>
"@

$configXml | Out-File -FilePath "C:\Temp\Office\Configuration.xml" -Encoding UTF8

# Install Office 365
Set-Location "C:\Temp\Office"
.\setup.exe /configure Configuration.xml

# Wait for installation (may take 10-20 minutes)
# Verify installation
Test-Path "C:\Program Files\Microsoft Office\root\Office16\WINWORD.EXE"
```

**Configuration Notes:**
- **SharedComputerLicensing=1:** Required for AVD multi-user environments (allows multiple users to activate Office on shared VMs)
- **Product:** O365ProPlusEEANoTeamsRetail = Office 365 without Teams
- **Channel:** Current = Monthly Enterprise Channel (latest features)
- **Excluded Apps:** Groove (OneDrive for Business), Lync (Skype), OneDrive, OneNote, OutlookForWindows
- **Updates:** Disabled (managed via Windows Update/Intune in deployed environments)

### 6b. Install Google Chrome

```powershell
# Install Google Chrome via Chocolatey
choco install googlechrome -y

# Verify installation
Test-Path "C:\Program Files\Google\Chrome\Application\chrome.exe"
```

### 7. Configure Default Applications & Desktop Shortcuts

```powershell
# Set Adobe Reader as default PDF opener
cmd /c assoc .pdf=AcroExch.Document.DC

# Create public desktop shortcuts
$publicDesktop = "C:\Users\Public\Desktop"
$shell = New-Object -ComObject WScript.Shell

# Adobe Acrobat Reader
$shortcut = $shell.CreateShortcut("$publicDesktop\Adobe Acrobat Reader.lnk")
$shortcut.TargetPath = "C:\Program Files (x86)\Adobe\Acrobat Reader DC\Reader\AcroRd32.exe"
$shortcut.Description = "Adobe Acrobat Reader DC"
$shortcut.Save()

# Google Chrome
$shortcut = $shell.CreateShortcut("$publicDesktop\Google Chrome.lnk")
$shortcut.TargetPath = "C:\Program Files\Google\Chrome\Application\chrome.exe"
$shortcut.Description = "Google Chrome"
$shortcut.Save()

# Microsoft Outlook
$shortcut = $shell.CreateShortcut("$publicDesktop\Microsoft Outlook.lnk")
$shortcut.TargetPath = "C:\Program Files\Microsoft Office\root\Office16\OUTLOOK.EXE"
$shortcut.Description = "Microsoft Outlook"
$shortcut.Save()

# Microsoft Word
$shortcut = $shell.CreateShortcut("$publicDesktop\Microsoft Word.lnk")
$shortcut.TargetPath = "C:\Program Files\Microsoft Office\root\Office16\WINWORD.EXE"
$shortcut.Description = "Microsoft Word"
$shortcut.Save()

# Microsoft Excel
$shortcut = $shell.CreateShortcut("$publicDesktop\Microsoft Excel.lnk")
$shortcut.TargetPath = "C:\Program Files\Microsoft Office\root\Office16\EXCEL.EXE"
$shortcut.Description = "Microsoft Excel"
$shortcut.Save()

# Microsoft Access
$shortcut = $shell.CreateShortcut("$publicDesktop\Microsoft Access.lnk")
$shortcut.TargetPath = "C:\Program Files\Microsoft Office\root\Office16\MSACCESS.EXE"
$shortcut.Description = "Microsoft Access"
$shortcut.Save()

Write-Host "✓ Adobe set as default PDF opener" -ForegroundColor Green
Write-Host "✓ Public desktop shortcuts created for 6 applications" -ForegroundColor Green

# Verify shortcuts created
Get-ChildItem "$publicDesktop\*.lnk" | Select-Object Name
```

### 8. OS Optimizations

```powershell
# Download VDOT
Invoke-WebRequest `
  -Uri "https://github.com/The-Virtual-Desktop-Team/Virtual-Desktop-Optimization-Tool/archive/refs/heads/main.zip" `
  -OutFile "C:\Temp\VDOT.zip"
Expand-Archive -Path "C:\Temp\VDOT.zip" -DestinationPath "C:\Temp\VDOT"

# Run optimizations
Set-Location "C:\Temp\VDOT\Virtual-Desktop-Optimization-Tool-main"
.\Windows_VDOT.ps1 -Optimizations All -AcceptEULA
```

### 8b. Enable RDP Client Timezone Redirection

```powershell
# Enable timezone redirection from RDP client to session host
# This allows the session to use the client's local timezone
$rdpPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server"
New-Item -Path $rdpPath -Force | Out-Null
Set-ItemProperty -Path $rdpPath -Name "fEnableTimeZoneRedirection" -Value 1 -Type DWord

Write-Host "✓ RDP timezone redirection enabled" -ForegroundColor Green

# Verify registry setting
Get-ItemProperty -Path $rdpPath -Name "fEnableTimeZoneRedirection"
```

**How it works:**
- Clients connecting to the session host send their timezone information via RDP
- Session time is calculated as: server base time + client timezone
- The client's RDP application must have timezone redirection enabled (default in modern RDP clients: Remote Desktop Connection, Microsoft Remote Desktop app, Citrix Receiver)
- Requires RDP 5.1 or later (all modern clients)

### 8c. Configure Windows Defender FSLogix Exclusions

```powershell
# Add Windows Defender exclusions for FSLogix
# Critical for performance - prevents Defender from scanning profile VHDs
Add-MpPreference -ExclusionPath "C:\Program Files\FSLogix"
Add-MpPreference -ExclusionPath "C:\ProgramData\FSLogix"
Add-MpPreference -ExclusionProcess "frx.exe"
Add-MpPreference -ExclusionProcess "frxdrvvt.sys"
Add-MpPreference -ExclusionProcess "frxsvc.exe"
Add-MpPreference -ExclusionExtension "vhd"
Add-MpPreference -ExclusionExtension "vhdx"

Write-Host "✓ Windows Defender FSLogix exclusions configured" -ForegroundColor Green

# Verify exclusions
Get-MpPreference | Select-Object -ExpandProperty ExclusionPath
Get-MpPreference | Select-Object -ExpandProperty ExclusionProcess
```

**Performance Impact:**
- **Without exclusions:** User login 3-5 minutes (Defender scanning profile VHD on every access)
- **With exclusions:** User login 30-45 seconds (instant profile access)
- **Security:** Safe exclusion - profile files stored on protected Azure Files, not system files

### 8d. Configure Language & Locale Settings

```powershell
# Set system locale and regional formats (en-US baseline)
Set-WinSystemLocale -SystemLocale "en-US"
Set-Culture -CultureInfo "en-US"
Set-WinHomeLocation -GeoId 244  # United States (244)

# Set user language list
$languages = New-WinUserLanguageList "en-US"
Set-WinUserLanguageList $languages -Force

Write-Host "✓ Language and locale configured for en-US" -ForegroundColor Green
Write-Host "⚠️  Restart required for system locale changes to take effect" -ForegroundColor Yellow

# Verify settings
Get-WinSystemLocale
Get-Culture
```

**Regional GeoId Reference:**
- 39 = Canada (CA)
- 94 = India (IN)
- 242 = United Kingdom (UK)
- 244 = United States (US)
- Update the GeoId value above if your deployment is in a different region

**Important Notes:**
- System locale changes require restart before Sysprep (will take effect next)
- Intune policies can override locale settings per user/group post-deployment
- To change to different locale, update GeoId and CultureInfo values above

### 8e. Disable System Restore & Volume Shadow Copy

```powershell
# Disable System Restore on all drives
Disable-ComputerRestore -Drive "C:\"

# Delete existing restore points
vssadmin delete shadows /all /quiet

# Disable Volume Shadow Copy Service
Set-Service -Name VSS -StartupType Disabled
Stop-Service -Name VSS -Force

Write-Host "✓ System Restore and VSS disabled" -ForegroundColor Green

# Verify
Get-Service VSS | Select-Object Status, StartType
```

**Why This Matters:**
- FSLogix profile containers (VHD files) change constantly with user profile updates
- Windows VSS creates snapshots of all changed files automatically
- Result: 50GB profile container can consume 150GB+ storage with VSS history
- **No value in VDI:** User profiles stored on Azure Files (already backed up by Azure), session hosts are stateless
- **Cost savings:** 67% reduction in Azure storage costs by disabling VSS

### 8f. Verify VDOT Optimizations Applied

```powershell
Write-Host "`n=== VDOT Optimization Verification ===" -ForegroundColor Cyan

# Check Windows Search service disabled
$wsearch = Get-Service WSearch -ErrorAction SilentlyContinue
if ($wsearch.Status -eq 'Stopped' -and $wsearch.StartType -eq 'Disabled') {
    Write-Host "✓ Windows Search: Disabled" -ForegroundColor Green
} else {
    Write-Host "✗ Windows Search: Still enabled (check VDOT)" -ForegroundColor Yellow
}

# Check Superfetch/SysMain disabled
$sysmain = Get-Service SysMain -ErrorAction SilentlyContinue
if ($sysmain.Status -eq 'Stopped' -and $sysmain.StartType -eq 'Disabled') {
    Write-Host "✓ Superfetch (SysMain): Disabled" -ForegroundColor Green
} else {
    Write-Host "✗ Superfetch: Still enabled" -ForegroundColor Yellow
}

# Check scheduled tasks disabled
$tasks = @(
    "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser",
    "\Microsoft\Windows\Autochk\Proxy",
    "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator"
)

foreach ($task in $tasks) {
    $taskState = (Get-ScheduledTask -TaskPath (Split-Path $task) -TaskName (Split-Path $task -Leaf) -ErrorAction SilentlyContinue).State
    if ($taskState -eq 'Disabled') {
        Write-Host "✓ Task disabled: $task" -ForegroundColor Green
    } else {
        Write-Host "✗ Task not disabled: $task" -ForegroundColor Yellow
    }
}

Write-Host "`nVDOT verification complete. Review any yellow warnings." -ForegroundColor Cyan
```

**Purpose:** Validates that VDOT successfully applied key optimizations. Yellow warnings indicate services/tasks that may need manual verification, but don't prevent continuation. Address any red errors before proceeding.

---

### 9. Entra Kerberos & Cloud Login Prerequisites

```powershell
# Cloud Kerberos
$kerbPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\Kerberos\Parameters"
New-Item -Path $kerbPath -Force | Out-Null
Set-ItemProperty -Path $kerbPath -Name "CloudKerberosTicketRetrievalEnabled" -Value 1 -Type DWord

# Credential roaming (OS setting)
$azurePath = "HKLM:\Software\Policies\Microsoft\AzureADAccount"
New-Item -Path $azurePath -Force | Out-Null
Set-ItemProperty -Path $azurePath -Name "LoadCredKeyFromProfile" -Value 1 -Type DWord
```

### 10. Suppress Windows Hello & Getting Started

```powershell
# Disable Windows Hello setup prompt on first login
$helloPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"
New-Item -Path $helloPath -Force | Out-Null
Set-ItemProperty -Path $helloPath -Name "NoStartupApp" -Value 1 -Type DWord

# Disable biometric/PIN prompts
$bioPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Biometrics"
New-Item -Path $bioPath -Force | Out-Null
Set-ItemProperty -Path $bioPath -Name "Enabled" -Value 0 -Type DWord

# Disable "Tips" and "Getting Started" app
$appPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Tips"
New-Item -Path $appPath -Force | Out-Null
Set-ItemProperty -Path $appPath -Name "DisableTipsOnLogon" -Value 1 -Type DWord

# Disable activity history (reduces telemetry)
$activityPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"
Set-ItemProperty -Path $activityPath -Name "PublishUserActivities" -Value 0 -Type DWord

# Disable cloud content suggestions on lock screen
$cloudPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent"
New-Item -Path $cloudPath -Force | Out-Null
Set-ItemProperty -Path $cloudPath -Name "DisableWindowsConsumerFeatures" -Value 1 -Type DWord

Write-Host "✓ Windows Hello and Getting Started suppressed" -ForegroundColor Green

# Verify registry keys
Get-ItemProperty -Path $helloPath -Name "NoStartupApp"
Get-ItemProperty -Path $appPath -Name "DisableTipsOnLogon"
```

### 10b. Golden Image Health Check (Pre-Sysprep Quality Gate)

```powershell
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Golden Image Health Check" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$checksPassed = 0
$checksTotal = 0

# Check 1: FSLogix Agent
$checksTotal++
if (Test-Path "C:\Program Files\FSLogix\Apps\frx.exe") {
    Write-Host "✓ FSLogix Agent installed" -ForegroundColor Green
    $checksPassed++
} else {
    Write-Host "✗ FSLogix Agent NOT found" -ForegroundColor Red
}

# Check 2: Defender Exclusions
$checksTotal++
$exclusions = Get-MpPreference | Select-Object -ExpandProperty ExclusionPath
if ($exclusions -contains "C:\Program Files\FSLogix") {
    Write-Host "✓ Windows Defender FSLogix exclusions configured" -ForegroundColor Green
    $checksPassed++
} else {
    Write-Host "✗ Defender exclusions missing" -ForegroundColor Red
}

# Check 3: Office 365 Installed
$checksTotal++
if (Test-Path "C:\Program Files\Microsoft Office\root\Office16\WINWORD.EXE") {
    Write-Host "✓ Office 365 installed" -ForegroundColor Green
    $checksPassed++
} else {
    Write-Host "✗ Office 365 NOT installed" -ForegroundColor Red
}

# Check 4: Chrome Installed
$checksTotal++
if (Test-Path "C:\Program Files\Google\Chrome\Application\chrome.exe") {
    Write-Host "✓ Google Chrome installed" -ForegroundColor Green
    $checksPassed++
} else {
    Write-Host "✗ Chrome NOT installed" -ForegroundColor Red
}

# Check 5: Adobe Reader Installed
$checksTotal++
if (Test-Path "C:\Program Files (x86)\Adobe\Acrobat Reader DC\Reader\AcroRd32.exe") {
    Write-Host "✓ Adobe Reader installed" -ForegroundColor Green
    $checksPassed++
} else {
    Write-Host "✗ Adobe Reader NOT installed" -ForegroundColor Red
}

# Check 6: Public Desktop Shortcuts
$checksTotal++
$shortcuts = Get-ChildItem "C:\Users\Public\Desktop\*.lnk" -ErrorAction SilentlyContinue
if ($shortcuts.Count -ge 6) {
    Write-Host "✓ Public desktop shortcuts created ($($shortcuts.Count) shortcuts)" -ForegroundColor Green
    $checksPassed++
} else {
    Write-Host "✗ Desktop shortcuts missing (found $($shortcuts.Count), expected 6)" -ForegroundColor Red
}

# Check 7: Windows Hello Suppressed
$checksTotal++
$helloReg = Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "NoStartupApp" -ErrorAction SilentlyContinue
if ($helloReg.NoStartupApp -eq 1) {
    Write-Host "✓ Windows Hello suppressed" -ForegroundColor Green
    $checksPassed++
} else {
    Write-Host "✗ Hello suppression NOT configured" -ForegroundColor Red
}

# Check 8: Cloud Kerberos Enabled
$checksTotal++
$kerbReg = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\Kerberos\Parameters" -Name "CloudKerberosTicketRetrievalEnabled" -ErrorAction SilentlyContinue
if ($kerbReg.CloudKerberosTicketRetrievalEnabled -eq 1) {
    Write-Host "✓ Cloud Kerberos enabled" -ForegroundColor Green
    $checksPassed++
} else {
    Write-Host "✗ Cloud Kerberos NOT enabled" -ForegroundColor Red
}

# Check 9: RDP Timezone Redirection
$checksTotal++
$rdpReg = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" -Name "fEnableTimeZoneRedirection" -ErrorAction SilentlyContinue
if ($rdpReg.fEnableTimeZoneRedirection -eq 1) {
    Write-Host "✓ RDP timezone redirection enabled" -ForegroundColor Green
    $checksPassed++
} else {
    Write-Host "✗ Timezone redirection NOT enabled" -ForegroundColor Red
}

# Check 10: System Restore Disabled
$checksTotal++
$vss = Get-Service VSS -ErrorAction SilentlyContinue
if ($vss.StartType -eq 'Disabled') {
    Write-Host "✓ System Restore/VSS disabled" -ForegroundColor Green
    $checksPassed++
} else {
    Write-Host "✗ VSS still enabled" -ForegroundColor Red
}

# Summary
Write-Host "`n========================================" -ForegroundColor Cyan
$percentage = [math]::Round(($checksPassed / $checksTotal) * 100)
Write-Host "Health Check Score: $checksPassed / $checksTotal ($percentage%)" -ForegroundColor Cyan

if ($checksPassed -eq $checksTotal) {
    Write-Host "✓ READY FOR SYSPREP" -ForegroundColor Green
} elseif ($checksPassed -ge ($checksTotal * 0.8)) {
    Write-Host "⚠️  MOSTLY READY (review warnings)" -ForegroundColor Yellow
} else {
    Write-Host "✗ NOT READY - Fix errors before Sysprep" -ForegroundColor Red
}
Write-Host "========================================`n" -ForegroundColor Cyan
```

**Purpose:** Final quality gate before Sysprep. Validates all 10 critical configurations:
- Must pass 10/10 for full readiness
- 8/10 (80%) minimum acceptable
- Review any failures and fix before proceeding with Sysprep

---

### 11. Sysprep

```powershell
# Clean temp
Remove-Item -Path "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "C:\Windows\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue

# Clear event logs
wevtutil el | ForEach-Object { wevtutil cl "$_" }

# Sysprep (VM will shutdown)
C:\Windows\System32\Sysprep\sysprep.exe /oobe /generalize /shutdown
```

**Wait 5-10 minutes for shutdown**

---

## Part 3: Capture Image

### Azure Portal

1. VM `avd-gold-pool` → Verify status: **Stopped (deallocated)**
2. Click **Capture**
3. Share to gallery: **Yes**
4. Gallery: Create `AVD_Image_Gallery` or select existing
5. Image definition: Create new
   - Name: `Win11-AVD-Pooled`
   - OS state: **Generalized**
   - Gen: 2
   - Publisher: `YourCompany`
   - Offer: `AVD`
   - SKU: `Win11-Pooled-FSLogix`
6. Version: `1.0.0`
7. Delete VM after: **Yes**
8. **Review + create**

**Wait 10-30 minutes**

### Azure CLI

```bash
resourceGroup="RG-Azure-VDI-01"
vmName="avd-gold-pool"
galleryName="AVD_Image_Gallery"

# Stop & generalize
az vm deallocate -g $resourceGroup -n $vmName
az vm generalize -g $resourceGroup -n $vmName

# Get VM ID
vmId=$(az vm show -g $resourceGroup -n $vmName --query id -o tsv)

# Create gallery if needed
az sig create -g $resourceGroup --gallery-name $galleryName

# Create image definition
az sig image-definition create \
  -g $resourceGroup \
  --gallery-name $galleryName \
  --gallery-image-definition "Win11-AVD-Pooled" \
  --publisher "YourCompany" \
  --offer "AVD" \
  --sku "Win11-Pooled-FSLogix" \
  --os-type Windows \
  --os-state Generalized \
  --hyper-v-generation V2

# Create version
az sig image-version create \
  -g $resourceGroup \
  --gallery-name $galleryName \
  --gallery-image-definition "Win11-AVD-Pooled" \
  --gallery-image-version "1.0.0" \
  --managed-image $vmId

echo "✓ Image capture started"
```

---

## Part 4: Verify and Cleanup

### Verify

```bash
az sig image-version show \
  -g "RG-Azure-VDI-01" \
  --gallery-name "AVD_Image_Gallery" \
  --gallery-image-definition "Win11-AVD-Pooled" \
  --gallery-image-version "1.0.0" \
  --query "provisioningState"
# Should show: Succeeded
```

### Cleanup

```bash
# Delete VM (if not auto-deleted)
az vm delete -g "RG-Azure-VDI-01" -n "avd-gold-pool" --yes

# Delete NIC, public IP
az network nic delete -g "RG-Azure-VDI-01" -n "avd-gold-pool-nic"
az network public-ip delete -g "RG-Azure-VDI-01" -n "avd-gold-pool-pip"
```

---

## Important Notes

**In golden image:**
- ✅ FSLogix agent (not configured)
- ✅ Windows updates
- ✅ Applications
- ✅ OS optimizations
- ✅ Kerberos prerequisites

**NOT in golden image:**
- ❌ FSLogix registry settings → Intune
- ❌ Entra join → Deployment time
- ❌ AVD agent → Deployment time

---

## Monthly Updates

Best practice: Update images monthly
1. Create VM from existing image
2. Install updates
3. Capture new version (1.1.0)
4. Test in non-prod
5. Deploy to production

---

**Next:** Deploy session hosts (Guide 06)
