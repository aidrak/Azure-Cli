# Azure Virtual Desktop Golden Image Creation Guide

**Purpose:** Create and capture optimized golden images for Azure Virtual Desktop

**Prerequisites:**
- Azure subscription with AVD permissions
- VNet with subnet available
- Azure Compute Gallery (or will create)
- Admin credentials

**What This Creates:**
1. Temporary VM for image configuration
2. Fully optimized Windows 11 25H2 AVD image
3. Captured image in Azure Compute Gallery

---

## Automated Deployment (Recommended)

### Using Automation Scripts

This guide provides three automation scripts for creating a golden image:

1. **`05-Golden-Image-VM-Create.sh`** - Creates the temporary VM (run from Azure CLI)
2. **`05-Golden-Image-VM-Configure.ps1`** - Configures the VM with all apps (run inside VM via RDP)
3. **`05-Golden-Image-Capture.sh`** - Captures and generalizes the image (run from Azure CLI)

#### Quick Start

```bash
# Step 1: From your workstation, create the VM
chmod +x ./05-Golden-Image-VM-Create.sh
./05-Golden-Image-VM-Create.sh
# This will output the public IP address

# Step 2: RDP into the VM and run configuration
# Connect to the VM using the public IP
# Open PowerShell as Administrator and run:
.\05-Golden-Image-VM-Configure.ps1
# This will take 20-40 minutes and may require reboots

# Step 3: After configuration completes, run capture from your workstation
chmod +x ./05-Golden-Image-Capture.sh
./05-Golden-Image-Capture.sh
# This will sysprep, generalize, and capture the image
```

**What the scripts do:**

| Script | Runs Where | Purpose | Time |
|--------|------------|---------|------|
| VM-Create.sh | Workstation (Azure CLI) | Creates temporary VM with public IP | 5-10 min |
| VM-Configure.ps1 | Inside VM (RDP) | Installs all applications and optimizations | 20-40 min |
| Capture.sh | Workstation (Azure CLI) | Syspreps, generalizes, and captures image | 10-30 min |

**Verification Checklist:**

After running the scripts, verify:
- [ ] VM was created successfully
- [ ] Configuration script completed without errors
- [ ] All applications installed (Chrome, Adobe Reader, Office)
- [ ] Image captured in Compute Gallery
- [ ] Image version available for session host deployment

---

## Manual Deployment (Alternative)

If you prefer manual deployment or need to troubleshoot, follow the step-by-step instructions below:

---

## Step 0: Determine Image Type

**❓ Which type of golden image are you creating?**

### Option A: Pooled Host Pool Image
- **Use Case:** Multiple users share VMs, users log in to any available session host
- **User Profiles:** FSLogix profile containers (roaming profiles)
- **Best For:** Task workers, call centers, general office workers
- **Cost:** Lower per-user cost (multiple users per VM)
- **Configuration:** Includes FSLogix, optimized for multi-session

### Option B: Personal Host Pool Image
- **Use Case:** Each user has a dedicated VM (persistent desktop)
- **User Profiles:** Local profiles stored on VM disk
- **Best For:** Power users, developers, users needing admin rights
- **Cost:** Higher per-user cost (one user per VM)
- **Configuration:** No FSLogix needed, optimized for single-session

---

**👉 Make your selection and proceed to the appropriate section below:**

---

## Part 1: Create Temporary VM

### For POOLED Host Pool Image

```bash
resourceGroup="RG-Azure-VDI-01"
vmName="avd-gold-pool-25h2"
vnetName="vnet-vdi-centralus"
subnetName="subnet-vdi-hosts"
location="centralus"
imageType="POOLED"

# Create VM with public IP for configuration
az vm create \
  --resource-group $resourceGroup \
  --name $vmName \
  --image "MicrosoftWindowsDesktop:windows-11:win11-25h2-avd:latest" \
  --size "Standard_D4s_v3" \
  --admin-username "avd-admin" \
  --admin-password "YourSecureP@ssw0rd123!" \
  --vnet-name $vnetName \
  --subnet $subnetName \
  --public-ip-sku Standard \
  --security-type TrustedLaunch \
  --enable-secure-boot true \
  --enable-vtpm true \
  --location $location

# Get public IP for RDP
az vm show -g $resourceGroup -n $vmName -d --query publicIps -o tsv
```

### For PERSONAL Host Pool Image

```bash
resourceGroup="RG-Azure-VDI-01"
vmName="avd-gold-personal-25h2"
vnetName="vnet-vdi-centralus"
subnetName="subnet-vdi-hosts"
location="centralus"
imageType="PERSONAL"

# Create VM with public IP for configuration
az vm create \
  --resource-group $resourceGroup \
  --name $vmName \
  --image "MicrosoftWindowsDesktop:windows-11:win11-25h2-ent:latest" \
  --size "Standard_D4s_v3" \
  --admin-username "avd-admin" \
  --admin-password "YourSecureP@ssw0rd123!" \
  --vnet-name $vnetName \
  --subnet $subnetName \
  --public-ip-sku Standard \
  --security-type TrustedLaunch \
  --enable-secure-boot true \
  --enable-vtpm true \
  --location $location

# Get public IP for RDP
az vm show -g $resourceGroup -n $vmName -d --query publicIps -o tsv
```

**⚠️ Note the differences:**
- **Pooled:** Uses `win11-25h2-avd` (multi-session) image
- **Personal:** Uses `win11-25h2-ent` (single-session Enterprise) image

---

## Part 2: Configure VM (RDP Connection Required)

### Connect via RDP
Use the public IP from above to connect via Remote Desktop with your admin credentials.

---

### Step 1: Initial Setup

```powershell
# Disable BitLocker (required for sysprep)
Disable-BitLocker -MountPoint "C:"

# Create working directory
New-Item -Path "C:\Temp" -ItemType Directory -Force

Write-Host "Initial setup complete. Install Windows Updates next." -ForegroundColor Green
```

---

### Step 2: Install Windows Updates

```powershell
# Open Windows Update
Start-Process ms-settings:windowsupdate

# Manually install all available updates
# Reboot as needed, then reconnect via RDP
```

⚠️ **Important:** Install ALL updates before proceeding. Reboot as needed.

---

### Step 3: Install FSLogix Agent (POOLED ONLY)

**⚠️ Skip this step if creating a PERSONAL image** - FSLogix is not needed for personal desktops

```powershell
Write-Host "Installing FSLogix Agent..." -ForegroundColor Cyan

# Download latest FSLogix
Invoke-WebRequest -Uri "https://aka.ms/fslogix-latest" -OutFile "C:\Temp\FSLogix.zip"

# Extract and install
Expand-Archive -Path "C:\Temp\FSLogix.zip" -DestinationPath "C:\Temp\FSLogix" -Force
Set-Location "C:\Temp\FSLogix\x64\Release"
Start-Process ".\FSLogixAppsSetup.exe" -ArgumentList "/install /quiet /norestart" -Wait

# Verify installation
if (Test-Path "C:\Program Files\FSLogix\Apps\frx.exe") {
    Write-Host "✓ FSLogix installed successfully" -ForegroundColor Green
} else {
    Write-Warning "FSLogix installation failed!"
}
```

⚠️ **Do NOT configure FSLogix registry settings** - Intune/GPO will handle configuration

---

### Step 4: Install Applications

#### Google Chrome

```powershell
Write-Host "Installing Google Chrome..." -ForegroundColor Cyan

$chromeUrl = "https://dl.google.com/dl/chrome/install/googlechromestandaloneenterprise64.msi"
Invoke-WebRequest -Uri $chromeUrl -OutFile "C:\Temp\Chrome.msi"
Start-Process "msiexec.exe" -ArgumentList "/i C:\Temp\Chrome.msi /quiet /norestart" -Wait

# Verify
if (Test-Path "C:\Program Files\Google\Chrome\Application\chrome.exe") {
    Write-Host "✓ Chrome installed successfully" -ForegroundColor Green
}
```

#### Adobe Acrobat Reader DC

```powershell
Write-Host "Installing Adobe Acrobat Reader DC..." -ForegroundColor Cyan

# Download latest version (check Adobe site for current URL)
$adobeUrl = "https://ardownload2.adobe.com/pub/adobe/reader/win/AcrobatDC/2300320201/AcroRdrDC2300320201_en_US.exe"
Invoke-WebRequest -Uri $adobeUrl -OutFile "C:\Temp\AdobeReader.exe"
Start-Process "C:\Temp\AdobeReader.exe" -ArgumentList "/sAll /rs /msi EULA_ACCEPT=YES" -Wait

# Verify (check both possible paths)
$adobePath = "C:\Program Files\Adobe\Acrobat DC\Acrobat\Acrobat.exe"
if (!(Test-Path $adobePath)) {
    $adobePath = "C:\Program Files (x86)\Adobe\Acrobat Reader DC\Reader\AcroRd32.exe"
}

if (Test-Path $adobePath) {
    Write-Host "✓ Adobe Reader installed successfully" -ForegroundColor Green
}
```

#### Microsoft Office 365

```powershell
Write-Host "Installing Microsoft Office 365..." -ForegroundColor Cyan

# Create Office directory
New-Item -Path "C:\Temp\Office" -ItemType Directory -Force

# Download Office Deployment Tool
$odtUrl = "https://download.microsoft.com/download/2/7/A/27AF1BE6-DD20-4CB4-B154-EBAB8A7D4A7E/officedeploymenttool_17328-20162.exe"
Invoke-WebRequest -Uri $odtUrl -OutFile "C:\Temp\Office\ODT.exe"

# Extract ODT
Start-Process -FilePath "C:\Temp\Office\ODT.exe" -ArgumentList "/quiet /extract:C:\Temp\Office" -Wait

# Create configuration XML
$configXml = @"
<Configuration ID="d473a46c-9126-4f5a-99d8-af03586a67bc">
  <Add OfficeClientEdition="64" Channel="Current">
    <Product ID="O365ProPlusEEANoTeamsRetail">
      <Language ID="en-us" />
      <ExcludeApp ID="Groove" />
      <ExcludeApp ID="Lync" />
      <ExcludeApp ID="OneDrive" />
      <ExcludeApp ID="OneNote" />
      <ExcludeApp ID="Teams" />
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

# Install Office (this takes 10-20 minutes)
Set-Location "C:\Temp\Office"
Write-Host "Installing Office 365... (this may take 10-20 minutes)" -ForegroundColor Yellow
Start-Process ".\setup.exe" -ArgumentList "/configure Configuration.xml" -Wait

# Verify installation
if (Test-Path "C:\Program Files\Microsoft Office\root\Office16\WINWORD.EXE") {
    Write-Host "✓ Office 365 installed successfully" -ForegroundColor Green
} else {
    Write-Warning "Office installation may have failed!"
}
```

---

### Step 5: Configure Default Applications & Desktop Shortcuts

```powershell
Write-Host "Configuring default applications and desktop shortcuts..." -ForegroundColor Cyan

# Set Adobe Reader as default PDF handler for all new users
$xmlPath = "C:\Temp\DefaultApps.xml"
$xmlContent = @"
<?xml version="1.0" encoding="UTF-8"?>
<DefaultAssociations>
  <Association Identifier=".pdf" ProgId="AcroExch.Document.DC" ApplicationName="Adobe Acrobat Reader DC" />
</DefaultAssociations>
"@
$xmlContent | Out-File -FilePath $xmlPath -Encoding UTF8
Dism.exe /Online /Import-DefaultAppAssociations:$xmlPath

Write-Host "✓ Default PDF handler set to Adobe Reader" -ForegroundColor Green

# Create desktop shortcuts on Public Desktop (available to all users)
$publicDesktop = "C:\Users\Public\Desktop"
$shell = New-Object -ComObject WScript.Shell

function Create-Shortcut {
    param($Name, $Target, $Description)
    
    if (Test-Path $Target) {
        $shortcutPath = Join-Path $publicDesktop "$Name.lnk"
        $shortcut = $shell.CreateShortcut($shortcutPath)
        $shortcut.TargetPath = $Target
        $shortcut.Description = $Description
        $shortcut.Save()
        Write-Host "  ✓ Created shortcut: $Name" -ForegroundColor Green
    } else {
        Write-Warning "  ✗ Target not found: $Target"
    }
}

# Determine Adobe Reader path (32-bit or 64-bit)
$adobePath = "C:\Program Files\Adobe\Acrobat DC\Acrobat\Acrobat.exe"
if (!(Test-Path $adobePath)) {
    $adobePath = "C:\Program Files (x86)\Adobe\Acrobat Reader DC\Reader\AcroRd32.exe"
}

# Create shortcuts
Create-Shortcut "Adobe Acrobat Reader" $adobePath "Adobe Acrobat Reader DC"
Create-Shortcut "Google Chrome" "C:\Program Files\Google\Chrome\Application\chrome.exe" "Google Chrome"
Create-Shortcut "Microsoft Outlook" "C:\Program Files\Microsoft Office\root\Office16\OUTLOOK.EXE" "Microsoft Outlook"
Create-Shortcut "Microsoft Word" "C:\Program Files\Microsoft Office\root\Office16\WINWORD.EXE" "Microsoft Word"
Create-Shortcut "Microsoft Excel" "C:\Program Files\Microsoft Office\root\Office16\EXCEL.EXE" "Microsoft Excel"

Write-Host "`n✓ Desktop shortcuts configured" -ForegroundColor Green
```

---

### Step 6: Run WDOT (Windows Desktop Optimization Tool)

```powershell
Write-Host "Downloading and running WDOT..." -ForegroundColor Cyan

# Download WDOT
$wdotUrl = "https://github.com/The-Virtual-Desktop-Team/Windows-Desktop-Optimization-Tool/archive/refs/heads/main.zip"
Invoke-WebRequest -Uri $wdotUrl -OutFile "C:\Temp\WDOT.zip"
Expand-Archive -Path "C:\Temp\WDOT.zip" -DestinationPath "C:\Temp" -Force

# Run WDOT optimizations
Set-Location "C:\Temp\Windows-Desktop-Optimization-Tool-main"

Write-Host "Running WDOT optimizations (this may take 5-10 minutes)..." -ForegroundColor Yellow
.\Windows_Optimization.ps1 -ConfigProfile "Windows11_24H2" -Optimizations All -AcceptEULA

Write-Host "`n✓ WDOT optimizations complete" -ForegroundColor Green
```

---

### Step 7: Apply AVD-Specific Optimizations

Create and run this script to add the settings that WDOT doesn't include:

```powershell
# AVD_Optimizations.ps1
Write-Host "Applying AVD-specific optimizations..." -ForegroundColor Cyan

# === PROMPT FOR IMAGE TYPE ===
Write-Host "`nWhich image type are you creating?" -ForegroundColor Yellow
Write-Host "1. POOLED (multi-session with FSLogix)" -ForegroundColor Cyan
Write-Host "2. PERSONAL (single-session without FSLogix)" -ForegroundColor Cyan
$imageTypeChoice = Read-Host "Enter 1 or 2"

$isPooled = ($imageTypeChoice -eq "1")

if ($isPooled) {
    Write-Host "`n✓ Configuring for POOLED host pool" -ForegroundColor Green
} else {
    Write-Host "`n✓ Configuring for PERSONAL host pool" -ForegroundColor Green
}

# === RDP TIMEZONE REDIRECTION ===
Write-Host "  Enabling RDP timezone redirection..." -ForegroundColor Gray
$rdpPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server"
if (!(Test-Path $rdpPath)) { New-Item -Path $rdpPath -Force | Out-Null }
Set-ItemProperty -Path $rdpPath -Name "fEnableTimeZoneRedirection" -Value 1 -Type DWord -Force

# === FSLOGIX DEFENDER EXCLUSIONS (POOLED ONLY) ===
if ($isPooled) {
    Write-Host "  Adding FSLogix Defender exclusions..." -ForegroundColor Gray
    Add-MpPreference -ExclusionPath "C:\Program Files\FSLogix" -ErrorAction SilentlyContinue
    Add-MpPreference -ExclusionPath "C:\ProgramData\FSLogix" -ErrorAction SilentlyContinue
    Add-MpPreference -ExclusionProcess "frx.exe" -ErrorAction SilentlyContinue
    Add-MpPreference -ExclusionExtension "vhd" -ErrorAction SilentlyContinue
    Add-MpPreference -ExclusionExtension "vhdx" -ErrorAction SilentlyContinue
}

# === LOCALE SETTINGS ===
Write-Host "  Setting locale to en-US..." -ForegroundColor Gray
Set-WinSystemLocale -SystemLocale "en-US" -ErrorAction SilentlyContinue
Set-Culture -CultureInfo "en-US" -ErrorAction SilentlyContinue
Set-WinHomeLocation -GeoId 244 -ErrorAction SilentlyContinue
Set-WinUserLanguageList (New-WinUserLanguageList "en-US") -Force -ErrorAction SilentlyContinue

# === DISABLE SYSTEM RESTORE & VSS ===
Write-Host "  Disabling System Restore and VSS..." -ForegroundColor Gray
Disable-ComputerRestore -Drive "C:\" -ErrorAction SilentlyContinue
vssadmin delete shadows /all /quiet | Out-Null
Stop-Service -Name VSS -Force -ErrorAction SilentlyContinue
Set-Service -Name VSS -StartupType Disabled -ErrorAction SilentlyContinue

# === BLACK SCREEN FIX (First Logon Animation) ===
Write-Host "  Disabling first logon animation (black screen fix)..." -ForegroundColor Gray
$winlogonPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
if (!(Test-Path $winlogonPath)) { New-Item -Path $winlogonPath -Force | Out-Null }
Set-ItemProperty -Path $winlogonPath -Name "EnableFirstLogonAnimation" -Value 0 -Type DWord -Force

$policySysPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
if (!(Test-Path $policySysPath)) { New-Item -Path $policySysPath -Force | Out-Null }
Set-ItemProperty -Path $policySysPath -Name "DelayedDesktopSwitchTimeout" -Value 0 -Type DWord -Force

# === OOBE PRIVACY EXPERIENCE SUPPRESSION ===
Write-Host "  Disabling OOBE privacy screens..." -ForegroundColor Gray
$oobePath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OOBE"
if (!(Test-Path $oobePath)) { New-Item -Path $oobePath -Force | Out-Null }
Set-ItemProperty -Path $oobePath -Name "DisablePrivacyExperience" -Value 1 -Type DWord -Force

# === WINDOWS HELLO SUPPRESSION ===
Write-Host "  Disabling Windows Hello for Business..." -ForegroundColor Gray
$passportPath = "HKLM:\SOFTWARE\Policies\Microsoft\PassportForWork"
if (!(Test-Path $passportPath)) { New-Item -Path $passportPath -Force | Out-Null }
Set-ItemProperty -Path $passportPath -Name "Enabled" -Value 0 -Type DWord -Force

# === DEFAULT USER PROFILE CONFIGURATION ===
if ($isPooled) {
    Write-Host "  Configuring Default User profile (for FSLogix containers)..." -ForegroundColor Gray
} else {
    Write-Host "  Configuring Default User profile..." -ForegroundColor Gray
}

# Load Default User hive
$defaultUserPath = "C:\Users\Default\NTUSER.DAT"
if (Test-Path $defaultUserPath) {
    reg load "HKU\DefaultUser" $defaultUserPath | Out-Null
    Start-Sleep -Seconds 2
    
    # Content Delivery Manager - Suppress "Let's finish setting up"
    $contentDelivery = "Registry::HKU\DefaultUser\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
    if (!(Test-Path $contentDelivery)) { New-Item -Path $contentDelivery -Force | Out-Null }
    Set-ItemProperty -Path $contentDelivery -Name "OemPreInstalledAppsEnabled" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $contentDelivery -Name "PreInstalledAppsEnabled" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $contentDelivery -Name "SilentInstalledAppsEnabled" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $contentDelivery -Name "SubscribedContent-310093Enabled" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $contentDelivery -Name "SubscribedContent-338387Enabled" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $contentDelivery -Name "SystemPaneSuggestionsEnabled" -Value 0 -Type DWord -Force
    
    # User Profile Engagement - Suppress suggestions
    $userEngagement = "Registry::HKU\DefaultUser\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement"
    if (!(Test-Path $userEngagement)) { New-Item -Path $userEngagement -Force | Out-Null }
    Set-ItemProperty -Path $userEngagement -Name "ScoobeSystemSettingEnabled" -Value 0 -Type DWord -Force
    
    # Unload Default User hive
    [gc]::Collect()
    Start-Sleep -Seconds 2
    reg unload "HKU\DefaultUser" | Out-Null
}

# === CLEANUP ===
Write-Host "  Cleaning temporary files..." -ForegroundColor Gray
Remove-Item -Path "C:\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "`n✓ AVD optimizations complete!" -ForegroundColor Green
Write-Host "  - RDP timezone redirection enabled" -ForegroundColor Green
if ($isPooled) {
    Write-Host "  - FSLogix Defender exclusions added" -ForegroundColor Green
}
Write-Host "  - OOBE privacy screens disabled" -ForegroundColor Green
Write-Host "  - Windows Hello disabled" -ForegroundColor Green
Write-Host "  - Default User profile configured" -ForegroundColor Green
Write-Host "  - Black screen fix applied" -ForegroundColor Green
```

**Save this script** and run it to complete the configuration.

---

### Step 8: Final Cleanup & Sysprep Preparation

```powershell
Write-Host "Preparing for sysprep..." -ForegroundColor Cyan

# Remove any user-specific data
Remove-Item -Path "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "C:\Windows\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue

# Clear event logs
wevtutil el | Foreach-Object { wevtutil cl $_ }

# Clear Recycle Bin
Clear-RecycleBin -Force -ErrorAction SilentlyContinue

Write-Host "`n✓ VM ready for sysprep and capture" -ForegroundColor Green
Write-Host "`nNext steps:" -ForegroundColor Yellow
Write-Host "1. Disconnect from RDP" -ForegroundColor Yellow
Write-Host "2. Run Azure CLI commands to generalize and capture" -ForegroundColor Yellow
```

⚠️ **Do NOT run sysprep manually** - Azure will handle this

---

## Part 3: Generalize and Capture Image

**From your local machine** (not the VM), run these Azure CLI commands:

### For POOLED Image

```bash
resourceGroup="RG-Azure-VDI-01"
vmName="avd-gold-pool-25h2"
galleryName="AVD_Image_Gallery"
location="centralus"

# Stop and deallocate VM
echo "Deallocating VM..."
az vm deallocate -g $resourceGroup -n $vmName

# Generalize VM (sysprepped state)
echo "Generalizing VM..."
az vm generalize -g $resourceGroup -n $vmName

# Get VM ID
vmId=$(az vm show -g $resourceGroup -n $vmName --query id -o tsv)
echo "VM ID: $vmId"

# Create Azure Compute Gallery if it doesn't exist
echo "Creating/verifying Azure Compute Gallery..."
az sig create \
  -g $resourceGroup \
  --gallery-name $galleryName \
  --location $location

# Create image definition
echo "Creating image definition..."
az sig image-definition create \
  -g $resourceGroup \
  --gallery-name $galleryName \
  --gallery-image-definition "Win11-25H2-AVD-Pooled" \
  --publisher "YourCompany" \
  --offer "AVD" \
  --sku "Win11-25H2-Pooled-FSLogix" \
  --os-type Windows \
  --os-state Generalized \
  --hyper-v-generation V2 \
  --features SecurityType=TrustedLaunch

# Create image version
echo "Creating image version (this takes 10-15 minutes)..."
az sig image-version create \
  -g $resourceGroup \
  --gallery-name $galleryName \
  --gallery-image-definition "Win11-25H2-AVD-Pooled" \
  --gallery-image-version "1.0.0" \
  --managed-image $vmId \
  --replica-count 1 \
  --storage-account-type Standard_LRS

echo "✓ Pooled image captured successfully!"
```

### For PERSONAL Image

```bash
resourceGroup="RG-Azure-VDI-01"
vmName="avd-gold-personal-25h2"
galleryName="AVD_Image_Gallery"
location="centralus"

# Stop and deallocate VM
echo "Deallocating VM..."
az vm deallocate -g $resourceGroup -n $vmName

# Generalize VM (sysprepped state)
echo "Generalizing VM..."
az vm generalize -g $resourceGroup -n $vmName

# Get VM ID
vmId=$(az vm show -g $resourceGroup -n $vmName --query id -o tsv)
echo "VM ID: $vmId"

# Create Azure Compute Gallery if it doesn't exist
echo "Creating/verifying Azure Compute Gallery..."
az sig create \
  -g $resourceGroup \
  --gallery-name $galleryName \
  --location $location

# Create image definition
echo "Creating image definition..."
az sig image-definition create \
  -g $resourceGroup \
  --gallery-name $galleryName \
  --gallery-image-definition "Win11-25H2-AVD-Personal" \
  --publisher "YourCompany" \
  --offer "AVD" \
  --sku "Win11-25H2-Personal-Enterprise" \
  --os-type Windows \
  --os-state Generalized \
  --hyper-v-generation V2 \
  --features SecurityType=TrustedLaunch

# Create image version
echo "Creating image version (this takes 10-15 minutes)..."
az sig image-version create \
  -g $resourceGroup \
  --gallery-name $galleryName \
  --gallery-image-definition "Win11-25H2-AVD-Personal" \
  --gallery-image-version "1.0.0" \
  --managed-image $vmId \
  --replica-count 1 \
  --storage-account-type Standard_LRS

echo "✓ Personal image captured successfully!"
```

---

## Part 4: Cleanup Temporary Resources

### For POOLED Image

```bash
resourceGroup="RG-Azure-VDI-01"
vmName="avd-gold-pool-25h2"

# Delete VM
echo "Deleting VM..."
az vm delete -g $resourceGroup -n $vmName --yes --no-wait

# Delete NIC
echo "Deleting NIC..."
az network nic delete -g $resourceGroup -n "${vmName}VMNic" --no-wait

# Delete Public IP
echo "Deleting Public IP..."
az network public-ip delete -g $resourceGroup -n "${vmName}PublicIP" --no-wait

# Delete OS Disk (find by name pattern)
echo "Deleting OS disk..."
diskName=$(az disk list -g $resourceGroup --query "[?contains(name, '$vmName')].name" -o tsv)
if [ ! -z "$diskName" ]; then
    az disk delete -g $resourceGroup -n $diskName --yes --no-wait
fi

echo "✓ Cleanup complete!"
```

### For PERSONAL Image

```bash
resourceGroup="RG-Azure-VDI-01"
vmName="avd-gold-personal-25h2"

# Delete VM
echo "Deleting VM..."
az vm delete -g $resourceGroup -n $vmName --yes --no-wait

# Delete NIC
echo "Deleting NIC..."
az network nic delete -g $resourceGroup -n "${vmName}VMNic" --no-wait

# Delete Public IP
echo "Deleting Public IP..."
az network public-ip delete -g $resourceGroup -n "${vmName}PublicIP" --no-wait

# Delete OS Disk (find by name pattern)
echo "Deleting OS disk..."
diskName=$(az disk list -g $resourceGroup --query "[?contains(name, '$vmName')].name" -o tsv)
if [ ! -z "$diskName" ]; then
    az disk delete -g $resourceGroup -n $diskName --yes --no-wait
fi

echo "✓ Cleanup complete!"
```

---

## Part 5: Deploy Session Hosts from Golden Image

Once your image is captured, deploy session hosts:

### For POOLED Host Pool

```bash
resourceGroup="RG-Azure-VDI-01"
galleryName="AVD_Image_Gallery"
imageDefinition="Win11-25H2-AVD-Pooled"
imageVersion="1.0.0"
hostPoolName="avd-pool-centralus"
vnetName="vnet-vdi-centralus"
subnetName="subnet-vdi-hosts"

# Get image ID
imageId=$(az sig image-version show \
  -g $resourceGroup \
  --gallery-name $galleryName \
  --gallery-image-definition $imageDefinition \
  --gallery-image-version $imageVersion \
  --query id -o tsv)

# Deploy session hosts (example: 3 hosts for pooled)
for i in {1..3}; do
  vmName="avd-pool-host-$i"
  
  az vm create \
    --resource-group $resourceGroup \
    --name $vmName \
    --image $imageId \
    --size "Standard_D4s_v3" \
    --admin-username "avd-admin" \
    --admin-password "YourSecureP@ssw0rd123!" \
    --vnet-name $vnetName \
    --subnet $subnetName \
    --public-ip-address "" \
    --nsg "" \
    --security-type TrustedLaunch \
    --enable-secure-boot true \
    --enable-vtpm true
done

echo "✓ Pooled session hosts deployed"
# Join to host pool using Azure portal or AVD PowerShell module
```

### For PERSONAL Host Pool

```bash
resourceGroup="RG-Azure-VDI-01"
galleryName="AVD_Image_Gallery"
imageDefinition="Win11-25H2-AVD-Personal"
imageVersion="1.0.0"
hostPoolName="avd-personal-centralus"
vnetName="vnet-vdi-centralus"
subnetName="subnet-vdi-hosts"

# Get image ID
imageId=$(az sig image-version show \
  -g $resourceGroup \
  --gallery-name $galleryName \
  --gallery-image-definition $imageDefinition \
  --gallery-image-version $imageVersion \
  --query id -o tsv)

# Deploy personal desktops (example: 2 VMs for specific users)
for i in {1..2}; do
  vmName="avd-personal-desk-$i"
  
  az vm create \
    --resource-group $resourceGroup \
    --name $vmName \
    --image $imageId \
    --size "Standard_D4s_v3" \
    --admin-username "avd-admin" \
    --admin-password "YourSecureP@ssw0rd123!" \
    --vnet-name $vnetName \
    --subnet $subnetName \
    --public-ip-address "" \
    --nsg "" \
    --security-type TrustedLaunch \
    --enable-secure-boot true \
    --enable-vtpm true
done

echo "✓ Personal desktops deployed"
# Join to host pool and assign to users via Azure portal or AVD PowerShell
```

---

## Troubleshooting

### VM won't generalize
- Ensure BitLocker is disabled: `Get-BitLockerVolume`
- Check for active deployments in Azure portal
- Verify VM is fully stopped and deallocated

### Applications not installing
- Verify internet connectivity from VM
- Check Windows Defender isn't blocking downloads
- Ensure sufficient disk space (minimum 40GB free)

### WDOT errors
- Run PowerShell as Administrator
- Set execution policy: `Set-ExecutionPolicy Bypass -Scope Process`
- Check WDOT logs in Event Viewer (WDOT log)

### Default User hive won't load
- Ensure no users are logged in
- Check file permissions on `C:\Users\Default\NTUSER.DAT`
- Run `reg unload "HKU\DefaultUser"` if stuck

---

## Maintenance & Updates

### Creating New Image Versions

When you need to update the image (monthly patches, app updates):

1. Deploy a new temporary VM from the **existing** golden image
2. Apply updates and changes
3. Capture as a new version (e.g., `1.0.1`, `1.0.2`)
4. Test thoroughly before deploying to production

### Version Naming Convention

- **Major.Minor.Patch** (e.g., `1.0.0`)
- **Major**: Windows version changes (Win10 → Win11)
- **Minor**: Significant app updates or config changes
- **Patch**: Monthly patches, minor fixes

---

## Summary of Optimizations Applied

### From WDOT (Both Image Types):
- ✓ Disabled unnecessary Windows services (~45 services)
- ✓ Removed bloatware AppX packages
- ✓ Disabled scheduled tasks
- ✓ Network optimizations (SMB, etc.)
- ✓ Disk cleanup
- ✓ Privacy/telemetry settings
- ✓ First logon animation disabled

### From Custom Script (Both Image Types):
- ✓ RDP timezone redirection (client timezone matches AVD)
- ✓ OOBE privacy screen suppression
- ✓ Windows Hello disabled
- ✓ Default User profile configured
- ✓ "Let's finish setting up" suppressed
- ✓ System Restore disabled
- ✓ Locale set to en-US
- ✓ Black screen fix applied

### POOLED Image Only:
- ✓ FSLogix Agent installed
- ✓ FSLogix Defender exclusions added
- ✓ Default User profile optimized for FSLogix containers

### PERSONAL Image Only:
- ✓ Single-session Windows 11 Enterprise
- ✓ No FSLogix (local user profiles)
- ✓ Optimized for persistent user desktops

### Applications Installed (Both Image Types):
- ✓ Google Chrome Enterprise
- ✓ Adobe Acrobat Reader DC
- ✓ Microsoft Office 365 (Shared Computer Licensing enabled)

---

## Image Type Decision Matrix

| Requirement | Pooled | Personal |
|------------|--------|----------|
| Multiple users per VM | ✓ | ✗ |
| Roaming profiles (FSLogix) | ✓ | ✗ |
| Lower per-user cost | ✓ | ✗ |
| Task workers, call centers | ✓ | ✗ |
| Dedicated VM per user | ✗ | ✓ |
| Local profiles on VM disk | ✗ | ✓ |
| Admin rights needed | ✗ | ✓ |
| Power users, developers | ✗ | ✓ |
| Higher per-user cost | ✗ | ✓ |

**Choose POOLED if:** Users share VMs, need cost efficiency, task-based work  
**Choose PERSONAL if:** Users need dedicated VMs, admin rights, persistent desktops

---

## References

- [Microsoft AVD Documentation](https://docs.microsoft.com/en-us/azure/virtual-desktop/)
- [FSLogix Documentation](https://docs.microsoft.com/en-us/fslogix/)
- [WDOT GitHub](https://github.com/The-Virtual-Desktop-Team/Windows-Desktop-Optimization-Tool)
- [Azure Compute Gallery](https://docs.microsoft.com/en-us/azure/virtual-machines/shared-image-galleries)