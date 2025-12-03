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
  --size "Standard_D4s_v6" \
  --admin-username "entra-admin" \
  --admin-password "ComplexP@ss123!" \
  --vnet-name $vnetName \
  --subnet $subnetName \
  --public-ip-sku Standard \
  --security-type TrustedLaunch \
  --enable-secure-boot true \
  --enable-vtpm true

# Get IP for RDP
az vm show -g $resourceGroup -n $vmName -d --query publicIps -o tsv
```

---

## Part 2: Configure VM (RDP In)

### 1. Disable BitLocker

```powershell
Disable-BitLocker -MountPoint "C:"
New-Item -Path "C:\Temp" -ItemType Directory -Force
```

### 2. Install Updates

```powershell
Start-Process ms-settings:windowsupdate
# Install all updates, reboot as needed
```

### 3. Install FSLogix Agent

```powershell
Write-Host "Installing FSLogix..."
Invoke-WebRequest -Uri "https://aka.ms/fslogix-latest" -OutFile "C:\Temp\FSLogix.zip"
Expand-Archive -Path "C:\Temp\FSLogix.zip" -DestinationPath "C:\Temp\FSLogix" -Force
Set-Location "C:\Temp\FSLogix\x64\Release"
.\FSLogixAppsSetup.exe /install /quiet /norestart

# Verify
Test-Path "C:\Program Files\FSLogix\Apps\frx.exe"
```

⚠️ **Do NOT configure FSLogix settings** - Intune will do this

### 4. Install Google Chrome (Direct)

```powershell
Write-Host "Installing Google Chrome..."
$chromeUrl = "https://dl.google.com/dl/chrome/install/googlechromestandaloneenterprise64.msi"
Invoke-WebRequest -Uri $chromeUrl -OutFile "C:\Temp\Chrome.msi"
Start-Process "msiexec.exe" -ArgumentList "/i C:\Temp\Chrome.msi /quiet /norestart" -Wait

# Verify
Test-Path "C:\Program Files\Google\Chrome\Application\chrome.exe"
```

### 5. Install Adobe Acrobat Reader DC (Direct)

```powershell
Write-Host "Installing Adobe Reader..."
# Note: Link may change, check Adobe Enterprise distribution for latest
$adobeUrl = "https://ardownload2.adobe.com/pub/adobe/reader/win/AcrobatDC/2300320201/AcroRdrDC2300320201_en_US.exe" 
Invoke-WebRequest -Uri $adobeUrl -OutFile "C:\Temp\AdobeReader.exe"
Start-Process "C:\Temp\AdobeReader.exe" -ArgumentList "/sAll /rs /msi EULA_ACCEPT=YES" -Wait

# Verify
Test-Path "C:\Program Files\Adobe\Acrobat DC\Acrobat\Acrobat.exe"
```

### 6. Install Microsoft Office 365

```powershell
# Download Office Deployment Tool
New-Item -Path "C:\Temp\Office" -ItemType Directory -Force
Invoke-WebRequest \
  -Uri "https://download.microsoft.com/download/2/7/A/27AF1BE6-DD20-4CB4-B154-EBAB8A7D4A7E/officedeploymenttool_17328-20162.exe" \
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

### 7. Configure Default Applications & Desktop Shortcuts

```powershell
# Set Adobe Reader as default PDF opener
cmd /c assoc .pdf=AcroExch.Document.DC

# Create public desktop shortcuts
$publicDesktop = "C:\Users\Public\Desktop"
$shell = New-Object -ComObject WScript.Shell

function Create-Shortcut {
    param($Path, $Target, $Desc)
    if (Test-Path $Target) {
        $s = $shell.CreateShortcut($Path)
        $s.TargetPath = $Target
        $s.Description = $Desc
        $s.Save()
        Write-Host "Created: $Path"
    }
}

Create-Shortcut "$publicDesktop\Adobe Acrobat Reader.lnk" "C:\Program Files\Adobe\Acrobat DC\Acrobat\Acrobat.exe" "Adobe Reader"
Create-Shortcut "$publicDesktop\Google Chrome.lnk" "C:\Program Files\Google\Chrome\Application\chrome.exe" "Google Chrome"
Create-Shortcut "$publicDesktop\Microsoft Outlook.lnk" "C:\Program Files\Microsoft Office\root\Office16\OUTLOOK.EXE" "Outlook"
Create-Shortcut "$publicDesktop\Microsoft Word.lnk" "C:\Program Files\Microsoft Office\root\Office16\WINWORD.EXE" "Word"
Create-Shortcut "$publicDesktop\Microsoft Excel.lnk" "C:\Program Files\Microsoft Office\root\Office16\EXCEL.EXE" "Excel"
```

### 8. OS Optimizations

```powershell
# Download VDOT
Invoke-WebRequest \
  -Uri "https://github.com/The-Virtual-Desktop-Team/Virtual-Desktop-Optimization-Tool/archive/refs/heads/main.zip" \
  -OutFile "C:\Temp\VDOT.zip"
Expand-Archive -Path "C:\Temp\VDOT.zip" -DestinationPath "C:\Temp\VDOT"

# Run optimizations
Set-Location "C:\Temp\VDOT\Virtual-Desktop-Optimization-Tool-main"
.\Windows_VDOT.ps1 -Optimizations All -AcceptEULA
```

### 9. Final Configuration & Security

```powershell
# Enable RDP Timezone Redirection
$rdpPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server"
New-Item -Path $rdpPath -Force | Out-Null
Set-ItemProperty -Path $rdpPath -Name "fEnableTimeZoneRedirection" -Value 1 -Type DWord

# Defender FSLogix Exclusions
Add-MpPreference -ExclusionPath "C:\Program Files\FSLogix"
Add-MpPreference -ExclusionPath "C:\ProgramData\FSLogix"
Add-MpPreference -ExclusionProcess "frx.exe"
Add-MpPreference -ExclusionExtension "vhd"
Add-MpPreference -ExclusionExtension "vhdx"

# Set Locale (en-US)
Set-WinSystemLocale -SystemLocale "en-US"
Set-Culture -CultureInfo "en-US"
Set-WinHomeLocation -GeoId 244
Set-WinUserLanguageList (New-WinUserLanguageList "en-US") -Force

# Disable System Restore & VSS
Disable-ComputerRestore -Drive "C:\"
vssadmin delete shadows /all /quiet
Stop-Service -Name VSS -Force
Set-Service -Name VSS -StartupType Disabled

# Suppress Windows Hello/OOBE
$helloPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"
New-Item -Path $helloPath -Force | Out-Null
Set-ItemProperty -Path $helloPath -Name "NoStartupApp" -Value 1 -Type DWord

# Clean Temp
Remove-Item -Path "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
```

---

## Part 3: Capture Image

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
  --hyper-v-generation V2 \
  --features SecurityType=TrustedLaunch

# Create version
az sig image-version create \
  -g $resourceGroup \
  --gallery-name $galleryName \
  --gallery-image-definition "Win11-AVD-Pooled" \
  --gallery-image-version "1.0.0" \
  --managed-image $vmId
```

---

## Part 4: Cleanup

```bash
az vm delete -g $resourceGroup -n $vmName --yes
az network nic delete -g $resourceGroup -n "${vmName}VMNic"
az network public-ip delete -g $resourceGroup -n "${vmName}PublicIP"
az disk delete -g $resourceGroup -n "${vmName}_OsDisk_1_*" --yes
```