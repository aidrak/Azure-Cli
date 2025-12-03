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

### 4. Install Applications

Install M365, browsers, line-of-business apps as needed.

### 5. OS Optimizations

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

### 6. Entra Kerberos Prerequisites

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

### 7. Sysprep

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

**Next:** Deploy session hosts (Guide 05)
