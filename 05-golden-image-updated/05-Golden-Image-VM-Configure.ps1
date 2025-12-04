# Automates Golden Image VM Configuration for Azure Virtual Desktop (AVD)
#
# Purpose: Configures Windows VM with all required applications, optimizations,
# and settings for AVD golden image. THIS SCRIPT MUST RUN INSIDE THE VM VIA RDP.
#
# Prerequisites:
# - Run this script INSIDE the VM via PowerShell (not from your local machine)
# - VM must have internet access to download installers
# - Administrator privileges required
# - At least 30 GB free disk space recommended
#
# Usage:
# 1. RDP into the golden image VM
# 2. Open PowerShell as Administrator
# 3. Run: .\05-Golden-Image-VM-Configure.ps1
#
# Notes:
# - This script is NOT idempotent (applications may fail if already installed)
# - Expected runtime: 20-40 minutes (includes Windows updates)
# - The VM will NOT reboot automatically - you may need to reboot during steps
# - Expected after script completion: 30-50 GB disk used

Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope CurrentUser -Force

$ErrorActionPreference = "Stop"

# Color codes for output
$Colors = @{
    Header = "Cyan"
    Success = "Green"
    Warning = "Yellow"
    Error = "Red"
    Info = "Yellow"
}

# ============================================================================
# Helper Functions
# ============================================================================

function Write-LogSection {
    param([string]$Message)
    Write-Host ""
    Write-Host "=== $Message ===" -ForegroundColor $Colors.Header
}

function Write-LogSuccess {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor $Colors.Success
}

function Write-LogError {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor $Colors.Error
}

function Write-LogWarning {
    param([string]$Message)
    Write-Host "⚠ $Message" -ForegroundColor $Colors.Warning
}

function Write-LogInfo {
    param([string]$Message)
    Write-Host "ℹ $Message" -ForegroundColor $Colors.Info
}

# ============================================================================
# System Configuration
# ============================================================================

function Disable-BitLocker {
    Write-LogSection "Disabling BitLocker"

    Write-LogInfo "Disabling BitLocker to prevent sysprep issues"
    try {
        Disable-BitLocker -MountPoint "C:" -ErrorAction SilentlyContinue | Out-Null
        Write-LogSuccess "BitLocker disabled"
    }
    catch {
        Write-LogWarning "BitLocker already disabled or error: $_"
    }
}

function Create-TempDirectory {
    Write-LogSection "Creating Temporary Directory"

    $tempPath = "C:\Temp"
    if (!(Test-Path $tempPath)) {
        New-Item -Path $tempPath -ItemType Directory -Force | Out-Null
        Write-LogSuccess "Temporary directory created: $tempPath"
    }
    else {
        Write-LogWarning "Temporary directory already exists"
    }
}

# ============================================================================
# Windows Updates
# ============================================================================

function Install-WindowsUpdates {
    Write-LogSection "Installing Windows Updates"

    Write-LogWarning "Windows Updates requires user interaction"
    Write-LogInfo "Opening Windows Update settings..."
    Write-LogInfo "Please manually:"
    Write-Host "  1. Click 'Check for updates'"
    Write-Host "  2. Install all available updates"
    Write-Host "  3. Restart if prompted"
    Write-Host "  4. Return to PowerShell when complete"

    Start-Process ms-settings:windowsupdate

    Write-LogInfo "Waiting for Windows Update to complete..."
    Read-Host "Press Enter when Windows Updates are complete and you've restarted"

    Write-LogSuccess "Windows Updates installed"
}

# ============================================================================
# FSLogix Installation
# ============================================================================

function Install-FslogixAgent {
    Write-LogSection "Installing FSLogix Agent"

    Write-LogInfo "Downloading FSLogix latest release"
    try {
        $tempPath = "C:\Temp"
        $fslogixZip = "$tempPath\FSLogix.zip"
        $fslogixPath = "$tempPath\FSLogix"

        if (Test-Path $fslogixZip) {
            Write-LogWarning "FSLogix.zip already exists, using cached version"
        }
        else {
            Invoke-WebRequest -Uri "https://aka.ms/fslogix-latest" -OutFile $fslogixZip -ErrorAction Stop
            Write-LogSuccess "FSLogix downloaded"
        }

        # Extract
        Write-LogInfo "Extracting FSLogix"
        Expand-Archive -Path $fslogixZip -DestinationPath $fslogixPath -Force

        # Install
        Write-LogInfo "Installing FSLogix Setup.exe"
        $installerPath = "$fslogixPath\x64\Release\FSLogixAppsSetup.exe"
        Start-Process -FilePath $installerPath -ArgumentList "/install /quiet /norestart" -Wait -ErrorAction Stop

        Write-LogSuccess "FSLogix agent installed"
    }
    catch {
        Write-LogError "Failed to install FSLogix: $_"
        throw
    }
}

# ============================================================================
# Application Installation
# ============================================================================

function Install-GoogleChrome {
    Write-LogSection "Installing Google Chrome"

    Write-LogInfo "Downloading Chrome Enterprise installer"
    try {
        $tempPath = "C:\Temp"
        $chromeUrl = "https://dl.google.com/dl/chrome/install/googlechromestandaloneenterprise64.msi"
        $chromeMsi = "$tempPath\Chrome.msi"

        if (Test-Path $chromeMsi) {
            Write-LogWarning "Chrome.msi already exists, using cached version"
        }
        else {
            Invoke-WebRequest -Uri $chromeUrl -OutFile $chromeMsi -ErrorAction Stop
            Write-LogSuccess "Chrome downloaded"
        }

        # Install
        Write-LogInfo "Installing Chrome"
        Start-Process "msiexec.exe" -ArgumentList "/i $chromeMsi /quiet /norestart" -Wait -ErrorAction Stop
        Write-LogSuccess "Google Chrome installed"
    }
    catch {
        Write-LogError "Failed to install Chrome: $_"
        throw
    }
}

function Install-AdobeReader {
    Write-LogSection "Installing Adobe Acrobat Reader DC"

    Write-LogInfo "Downloading Adobe Reader"
    try {
        $tempPath = "C:\Temp"
        $adobeUrl = "https://ardownload2.adobe.com/pub/adobe/reader/win/AcrobatDC/2300320201/AcroRdrDC2300320201_en_US.exe"
        $adobeExe = "$tempPath\AdobeReader.exe"

        if (Test-Path $adobeExe) {
            Write-LogWarning "AdobeReader.exe already exists, using cached version"
        }
        else {
            Invoke-WebRequest -Uri $adobeUrl -OutFile $adobeExe -ErrorAction Stop
            Write-LogSuccess "Adobe Reader downloaded"
        }

        # Install
        Write-LogInfo "Installing Adobe Reader"
        Start-Process $adobeExe -ArgumentList "/sAll /rs /msi EULA_ACCEPT=YES" -Wait -ErrorAction Stop
        Write-LogSuccess "Adobe Reader installed"
    }
    catch {
        Write-LogError "Failed to install Adobe Reader: $_"
        throw
    }
}

function Install-Office365 {
    Write-LogSection "Installing Microsoft Office 365"

    Write-LogInfo "Downloading Office Deployment Tool"
    try {
        $tempPath = "C:\Temp"
        $officePath = "$tempPath\Office"
        $odtUrl = "https://download.microsoft.com/download/2/7/A/27AF1BE6-DD20-4CB4-B154-EBAB8A7D4A7E/officedeploymenttool_17328-20162.exe"
        $odtExe = "$officePath\ODT.exe"

        if (!(Test-Path $officePath)) {
            New-Item -Path $officePath -ItemType Directory -Force | Out-Null
        }

        if (Test-Path $odtExe) {
            Write-LogWarning "ODT.exe already exists, using cached version"
        }
        else {
            Invoke-WebRequest -Uri $odtUrl -OutFile $odtExe -ErrorAction Stop
            Write-LogSuccess "Office Deployment Tool downloaded"
        }

        # Extract ODT
        Write-LogInfo "Extracting Office Deployment Tool"
        Start-Process -FilePath $odtExe -ArgumentList "/quiet /extract:$officePath" -Wait -ErrorAction Stop

        # Create configuration
        Write-LogInfo "Creating Office configuration file"
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

        $configXml | Out-File -FilePath "$officePath\Configuration.xml" -Encoding UTF8

        # Install Office
        Write-LogInfo "Installing Office 365 (this may take 10-20 minutes)"
        Set-Location $officePath
        Start-Process -FilePath ".\setup.exe" -ArgumentList "/configure Configuration.xml" -Wait -ErrorAction Stop

        Write-LogSuccess "Office 365 installed"
    }
    catch {
        Write-LogError "Failed to install Office: $_"
        throw
    }
}

# ============================================================================
# Desktop Configuration
# ============================================================================

function Set-DefaultApplications {
    Write-LogSection "Configuring Default Applications"

    Write-LogInfo "Setting Adobe Reader as default PDF application"
    try {
        # Set via Registry
        cmd /c assoc .pdf=AcroExch.Document.DC

        # Create XML for DISM (for new user profiles)
        $xmlPath = "C:\Temp\AdobeDefaults.xml"
        $xmlContent = @"
<?xml version="1.0" encoding="UTF-8"?>
<DefaultAssociations>
  <Association Identifier=".pdf" ProgId="AcroExch.Document.DC" ApplicationName="Adobe Acrobat Reader DC" />
  <Association Identifier=".pdfxml" ProgId="AcroExch.Document.DC" ApplicationName="Adobe Acrobat Reader DC" />
  <Association Identifier=".acrobatsecuritysettings" ProgId="AcroExch.Document.DC" ApplicationName="Adobe Acrobat Reader DC" />
  <Association Identifier=".fdf" ProgId="AcroExch.Document.DC" ApplicationName="Adobe Acrobat Reader DC" />
  <Association Identifier=".xfdf" ProgId="AcroExch.Document.DC" ApplicationName="Adobe Acrobat Reader DC" />
</DefaultAssociations>
"@

        $xmlContent | Out-File -FilePath $xmlPath -Encoding UTF8
        dism.exe /Online /Import-DefaultAppAssociations:$xmlPath

        Write-LogSuccess "Default applications configured"
    }
    catch {
        Write-LogWarning "Could not set all defaults: $_"
    }
}

function Create-PublicDesktopShortcuts {
    Write-LogSection "Creating Desktop Shortcuts"

    Write-LogInfo "Creating application shortcuts on public desktop"
    try {
        $publicDesktop = "C:\Users\Public\Desktop"
        $shell = New-Object -ComObject WScript.Shell

        function Create-Shortcut {
            param($Path, $Target, $Desc)
            if (Test-Path $Target) {
                $s = $shell.CreateShortcut($Path)
                $s.TargetPath = $Target
                $s.Description = $Desc
                $s.Save()
                Write-LogSuccess "Created: $Desc"
            }
            else {
                Write-LogWarning "Target not found: $Target"
            }
        }

        # Check both Adobe paths
        $adobePath = "C:\Program Files\Adobe\Acrobat DC\Acrobat\Acrobat.exe"
        if (!(Test-Path $adobePath)) {
            $adobePath = "C:\Program Files (x86)\Adobe\Acrobat Reader DC\Reader\AcroRd32.exe"
        }

        Create-Shortcut "$publicDesktop\Adobe Acrobat Reader.lnk" $adobePath "Adobe Acrobat Reader DC"
        Create-Shortcut "$publicDesktop\Google Chrome.lnk" "C:\Program Files\Google\Chrome\Application\chrome.exe" "Google Chrome"
        Create-Shortcut "$publicDesktop\Microsoft Outlook.lnk" "C:\Program Files\Microsoft Office\root\Office16\OUTLOOK.EXE" "Microsoft Outlook"
        Create-Shortcut "$publicDesktop\Microsoft Word.lnk" "C:\Program Files\Microsoft Office\root\Office16\WINWORD.EXE" "Microsoft Word"
        Create-Shortcut "$publicDesktop\Microsoft Excel.lnk" "C:\Program Files\Microsoft Office\root\Office16\EXCEL.EXE" "Microsoft Excel"

        Write-LogSuccess "Desktop shortcuts created"
    }
    catch {
        Write-LogError "Failed to create shortcuts: $_"
        throw
    }
}

# ============================================================================
# Windows Optimization
# ============================================================================

function Run-VdotOptimizations {
    Write-LogSection "Running Virtual Desktop Optimization Tool (VDOT)"

    Write-LogInfo "Downloading VDOT"
    try {
        $tempPath = "C:\Temp"
        $vdotZip = "$tempPath\VDOT.zip"

        if (Test-Path $vdotZip) {
            Write-LogWarning "VDOT.zip already exists, using cached version"
        }
        else {
            Invoke-WebRequest -Uri "https://github.com/The-Virtual-Desktop-Team/Virtual-Desktop-Optimization-Tool/archive/refs/heads/main.zip" -OutFile $vdotZip -ErrorAction Stop
            Write-LogSuccess "VDOT downloaded"
        }

        # Extract
        Write-LogInfo "Extracting VDOT"
        Expand-Archive -Path $vdotZip -DestinationPath "$tempPath\VDOT" -Force

        # Run optimizations
        Write-LogInfo "Running VDOT optimizations (this may take 5-10 minutes)"
        $vdotPath = "$tempPath\VDOT\Virtual-Desktop-Optimization-Tool-main"
        Set-Location $vdotPath
        & ".\Windows_VDOT.ps1" -Optimizations All -AcceptEULA -Verbose

        Write-LogSuccess "VDOT optimizations completed"
    }
    catch {
        Write-LogError "Failed to run VDOT: $_"
        throw
    }
}

# ============================================================================
# Registry Configuration
# ============================================================================

function Configure-RegistryForAvd {
    Write-LogSection "Configuring Windows Registry for AVD"

    Write-LogInfo "Configuring RDP timezone redirection"
    $rdpPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server"
    if (!(Test-Path $rdpPath)) {
        New-Item -Path $rdpPath -Force | Out-Null
    }
    Set-ItemProperty -Path $rdpPath -Name "fEnableTimeZoneRedirection" -Value 1 -Type DWord

    Write-LogInfo "Configuring FSLogix Defender exclusions"
    Add-MpPreference -ExclusionPath "C:\Program Files\FSLogix"
    Add-MpPreference -ExclusionPath "C:\ProgramData\FSLogix"
    Add-MpPreference -ExclusionProcess "frx.exe"
    Add-MpPreference -ExclusionExtension "vhd"
    Add-MpPreference -ExclusionExtension "vhdx"

    Write-LogInfo "Disabling System Restore and VSS"
    Disable-ComputerRestore -Drive "C:\" -ErrorAction SilentlyContinue
    vssadmin delete shadows /all /quiet
    Stop-Service -Name VSS -Force -ErrorAction SilentlyContinue
    Set-Service -Name VSS -StartupType Disabled

    Write-LogInfo "Disabling OOBE and first logon animation"
    $winlogonPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
    Set-ItemProperty -Path $winlogonPath -Name "EnableFirstLogonAnimation" -Value 0 -Type DWord -Force

    $policySysPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
    if (!(Test-Path $policySysPath)) {
        New-Item -Path $policySysPath -Force | Out-Null
    }
    Set-ItemProperty -Path $policySysPath -Name "DelayedDesktopSwitchTimeout" -Value 0 -Type DWord -Force

    Write-LogInfo "Disabling OOBE privacy experience"
    $oobePath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OOBE"
    if (!(Test-Path $oobePath)) {
        New-Item -Path $oobePath -Force | Out-Null
    }
    Set-ItemProperty -Path $oobePath -Name "DisablePrivacyExperience" -Value 1 -Type DWord -Force

    Write-LogInfo "Disabling Windows Hello for Business"
    $passportPath = "HKLM:\SOFTWARE\Policies\Microsoft\PassportForWork"
    if (!(Test-Path $passportPath)) {
        New-Item -Path $passportPath -Force | Out-Null
    }
    Set-ItemProperty -Path $passportPath -Name "Enabled" -Value 0 -Type DWord -Force

    Write-LogSuccess "Registry configuration completed"
}

function Configure-DefaultUserProfile {
    Write-LogSection "Configuring Default User Profile for FSLogix"

    Write-LogInfo "Loading and configuring Default User hive"
    try {
        reg load "HKU\DefaultUser" "C:\Users\Default\NTUSER.DAT" | Out-Null

        # Disable "Let's finish setting up your device"
        $contentDelivery = "Registry::HKU\DefaultUser\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
        if (!(Test-Path $contentDelivery)) {
            New-Item -Path $contentDelivery -Force | Out-Null
        }
        Set-ItemProperty -Path $contentDelivery -Name "OemPreInstalledAppsEnabled" -Value 0 -Type DWord -Force
        Set-ItemProperty -Path $contentDelivery -Name "PreInstalledAppsEnabled" -Value 0 -Type DWord -Force
        Set-ItemProperty -Path $contentDelivery -Name "SilentInstalledAppsEnabled" -Value 0 -Type DWord -Force

        # Disable user engagement prompts
        $userEngagement = "Registry::HKU\DefaultUser\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement"
        if (!(Test-Path $userEngagement)) {
            New-Item -Path $userEngagement -Force | Out-Null
        }
        Set-ItemProperty -Path $userEngagement -Name "ScoobeSystemSettingEnabled" -Value 0 -Type DWord -Force

        # Unload hive
        [gc]::Collect()
        Start-Sleep -Seconds 2
        reg unload "HKU\DefaultUser"

        Write-LogSuccess "Default User profile configured"
    }
    catch {
        Write-LogError "Failed to configure Default User profile: $_"
        throw
    }
}

# ============================================================================
# Cleanup
# ============================================================================

function Clean-TemporaryFiles {
    Write-LogSection "Cleaning Temporary Files"

    Write-LogInfo "Removing temporary files"
    Remove-Item -Path "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "C:\Windows\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue

    Write-LogSuccess "Temporary files cleaned"
}

# ============================================================================
# Main Execution
# ============================================================================

function main {
    Write-Host ""
    Write-LogSection "AVD Golden Image VM Configuration"

    Disable-BitLocker
    Create-TempDirectory
    Install-WindowsUpdates
    Install-FslogixAgent
    Install-GoogleChrome
    Install-AdobeReader
    Install-Office365
    Set-DefaultApplications
    Create-PublicDesktopShortcuts
    Run-VdotOptimizations
    Configure-RegistryForAvd
    Configure-DefaultUserProfile
    Clean-TemporaryFiles

    Write-Host ""
    Write-LogSuccess "VM Configuration Complete!"
    Write-Host ""
    Write-LogWarning "IMPORTANT NEXT STEPS:"
    Write-Host "  1. Review the installed applications and settings"
    Write-Host "  2. Perform any final manual tweaks needed"
    Write-Host "  3. Test application functionality"
    Write-Host "  4. Close all applications"
    Write-Host "  5. Run the sysprep script: .\05-Golden-Image-Sysprep.ps1 (if available)"
    Write-Host "  6. Or follow manual steps to run sysprep and capture the image"
    Write-Host ""
    Write-LogInfo "DO NOT USE THIS VM FOR PRODUCTION - it is a template only"
    Write-Host ""
}

main
