# Disable BitLocker (prevent issues during sysprep/capture)
Disable-BitLocker -MountPoint "C:" -ErrorAction SilentlyContinue

# Create Temp Directory
New-Item -Path "C:\Temp" -ItemType Directory -Force | Out-Null

# --- 1. Install Updates ---
Write-Host "Triggering Windows Update..."
# Note: Full Windows Update via CLI is complex and usually requires reboots. 
# We will trigger the service to scan, but a full update cycle often needs manual intervention or specialized modules (PSWindowsUpdate).
# For this script, we will ensure the service is running.
Start-Service wuauserv

# --- 2. Install FSLogix ---
Write-Host "Installing FSLogix..."
Invoke-WebRequest -Uri "https://aka.ms/fslogix-latest" -OutFile "C:\Temp\FSLogix.zip"
Expand-Archive -Path "C:\Temp\FSLogix.zip" -DestinationPath "C:\Temp\FSLogix" -Force
Set-Location "C:\Temp\FSLogix\x64\Release"
.\FSLogixAppsSetup.exe /install /quiet /norestart

# --- 3. Install Chocolatey ---
Write-Host "Installing Chocolatey..."
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# Refresh environment variables to use 'choco' immediately
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

# --- 4. Install Applications (Choco) ---
Write-Host "Installing Adobe Reader and Chrome..."
choco install adobereader -y --no-progress
choco install googlechrome -y --no-progress

# --- 5. Install Office 365 ---
Write-Host "Downloading Office Deployment Tool..."
New-Item -Path "C:\Temp\Office" -ItemType Directory -Force | Out-Null
Invoke-WebRequest `
  -Uri "https://download.microsoft.com/download/2/7/A/27AF1BE6-DD20-4CB4-B154-EBAB8A7D4A7E/officedeploymenttool_17328-20162.exe" `
  -OutFile "C:\Temp\Office\ODT.exe"

Write-Host "Extracting ODT..."
Start-Process -FilePath "C:\Temp\Office\ODT.exe" -ArgumentList "/quiet /extract:C:\Temp\Office" -Wait

Write-Host "Creating Office Configuration..."
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

Write-Host "Installing Office 365 (This may take 10-20 mins)..."
Set-Location "C:\Temp\Office"
# Start-Process with -Wait ensures we don't move on until Office is installed
Start-Process -FilePath ".\setup.exe" -ArgumentList "/configure Configuration.xml" -Wait

# --- 6. Shortcuts & Defaults ---
Write-Host "Configuring Shortcuts & Defaults..."
cmd /c assoc .pdf=AcroExch.Document.DC

$publicDesktop = "C:\Users\Public\Desktop"
$shell = New-Object -ComObject WScript.Shell

# Function to create shortcut
function Create-Shortcut {
    param($Path, $Target, $Desc)
    if (Test-Path $Target) {
        $s = $shell.CreateShortcut($Path)
        $s.TargetPath = $Target
        $s.Description = $Desc
        $s.Save()
        Write-Host "Created: $Path"
    } else {
        Write-Warning "Target not found: $Target"
    }
}

Create-Shortcut "$publicDesktop\Adobe Acrobat Reader.lnk" "C:\Program Files (x86)\Adobe\Acrobat Reader DC\Reader\AcroRd32.exe" "Adobe Acrobat Reader DC"
Create-Shortcut "$publicDesktop\Google Chrome.lnk" "C:\Program Files\Google\Chrome\Application\chrome.exe" "Google Chrome"
Create-Shortcut "$publicDesktop\Microsoft Outlook.lnk" "C:\Program Files\Microsoft Office\root\Office16\OUTLOOK.EXE" "Microsoft Outlook"
Create-Shortcut "$publicDesktop\Microsoft Word.lnk" "C:\Program Files\Microsoft Office\root\Office16\WINWORD.EXE" "Microsoft Word"
Create-Shortcut "$publicDesktop\Microsoft Excel.lnk" "C:\Program Files\Microsoft Office\root\Office16\EXCEL.EXE" "Microsoft Excel"
Create-Shortcut "$publicDesktop\Microsoft Access.lnk" "C:\Program Files\Microsoft Office\root\Office16\MSACCESS.EXE" "Microsoft Access"

# --- 7. VDOT Optimizations ---
Write-Host "Running VDOT Optimizations..."
Invoke-WebRequest `
  -Uri "https://github.com/The-Virtual-Desktop-Team/Virtual-Desktop-Optimization-Tool/archive/refs/heads/main.zip" `
  -OutFile "C:\Temp\VDOT.zip"
Expand-Archive -Path "C:\Temp\VDOT.zip" -DestinationPath "C:\Temp\VDOT" -Force
Set-Location "C:\Temp\VDOT\Virtual-Desktop-Optimization-Tool-main"
.\Windows_VDOT.ps1 -Optimizations All -AcceptEULA -Verbose

# --- 8. Registry & Security Settings ---
Write-Host "Applying Registry Settings..."

# Cloud Kerberos
$kerbPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\Kerberos\Parameters"
if (!(Test-Path $kerbPath)) { New-Item -Path $kerbPath -Force | Out-Null }
Set-ItemProperty -Path $kerbPath -Name "CloudKerberosTicketRetrievalEnabled" -Value 1 -Type DWord -Force

# Azure AD Account
$azurePath = "HKLM:\Software\Policies\Microsoft\AzureADAccount"
if (!(Test-Path $azurePath)) { New-Item -Path $azurePath -Force | Out-Null }
Set-ItemProperty -Path $azurePath -Name "LoadCredKeyFromProfile" -Value 1 -Type DWord -Force

# Windows Hello / Getting Started Suppression
$helloPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"
if (!(Test-Path $helloPath)) { New-Item -Path $helloPath -Force | Out-Null }
Set-ItemProperty -Path $helloPath -Name "NoStartupApp" -Value 1 -Type DWord -Force

$bioPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Biometrics"
if (!(Test-Path $bioPath)) { New-Item -Path $bioPath -Force | Out-Null }
Set-ItemProperty -Path $bioPath -Name "Enabled" -Value 0 -Type DWord -Force

$appPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Tips"
if (!(Test-Path $appPath)) { New-Item -Path $appPath -Force | Out-Null }
Set-ItemProperty -Path $appPath -Name "DisableTipsOnLogon" -Value 1 -Type DWord -Force

$cloudPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent"
if (!(Test-Path $cloudPath)) { New-Item -Path $cloudPath -Force | Out-Null }
Set-ItemProperty -Path $cloudPath -Name "DisableWindowsConsumerFeatures" -Value 1 -Type DWord -Force

# Clean temp
Remove-Item -Path "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "C:\Windows\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "Configuration Complete! Ready for manual review or Sysprep."