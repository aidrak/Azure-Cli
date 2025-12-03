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
$rdpPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services"
New-Item -Path $rdpPath -Force | Out-Null
Set-ItemProperty -Path $rdpPath -Name "fEnableTimeZoneRedirection" -Value 1 -Type DWord

Write-Host "✓ RDP timezone redirection enabled" -ForegroundColor Green

# Verify registry setting
Get-ItemProperty -Path $rdpPath -Name "fEnableTimeZoneRedirection"
```

**Note:** This setting enables the RDP protocol to redirect the client's timezone to the session host. The client's RDP application must also have timezone redirection enabled (default in modern RDP clients like Remote Desktop Connection, Microsoft Remote Desktop app, and Citrix Receiver).

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
