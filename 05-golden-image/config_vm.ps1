# This script configures the golden image VM with necessary applications, settings, and optimizations.
# It is designed to be executed by the Azure Custom Script Extension.

# --- 1. SCRIPT SETUP AND LOGGING ---
$ErrorActionPreference = "Stop"
$LogPath = "C:\Temp\GoldenImageConfig.log"

# Create Temp Directory for logs and downloads
if (-not (Test-Path -Path "C:\Temp")) {
    New-Item -Path "C:\Temp" -ItemType Directory -Force | Out-Null
}

# Start logging everything to a transcript
Start-Transcript -Path $LogPath -Append

Write-Host "--- Golden Image Configuration Started ---"
Write-Host "Log file located at: $LogPath"

try {
    # --- 2. PRE-CONFIGURATION ---
    Write-Host "Disabling BitLocker to prevent Sysprep/capture issues..."
    Disable-BitLocker -MountPoint "C:" -ErrorAction SilentlyContinue
}
catch {
    Write-Error "Failed during pre-configuration. See log for details."
    exit 1
}

try {
    # --- 3. INSTALL FSLOGIX ---
    Write-Host "Installing FSLogix..."
    Invoke-WebRequest -Uri "https://aka.ms/fslogix-latest" -OutFile "C:\Temp\FSLogix.zip"
    Expand-Archive -Path "C:\Temp\FSLogix.zip" -DestinationPath "C:\Temp\FSLogix" -Force
    # Using Start-Process to ensure installation completes before moving on
    $fslogixInstaller = Start-Process -FilePath "C:\Temp\FSLogix\x64\Release\FSLogixAppsSetup.exe" -ArgumentList "/install /quiet /norestart" -Wait -PassThru
    if ($fslogixInstaller.ExitCode -ne 0) {
        throw "FSLogix installation failed with exit code $($fslogixInstaller.ExitCode)."
    }
    Write-Host "FSLogix installed successfully."
}
catch {
    Write-Error "Failed to install FSLogix. See log for details."
    exit 1
}

try {
    # --- 4. INSTALL CHOCOLATEY AND APPLICATIONS ---
    Write-Host "Installing Chocolatey package manager..."
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    
    # Refresh environment variables to use 'choco' immediately
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    Write-Host "Chocolatey installed successfully."

    Write-Host "Installing applications via Chocolatey..."
    choco install adobereader -y --no-progress
    choco install googlechrome -y --no-progress
    Write-Host "Base applications installed."
}
catch {
    Write-Error "Failed to install Chocolatey or applications. See log for details."
    exit 1
}

try {
    # --- 5. INSTALL MICROSOFT 365 APPS ---
    Write-Host "Installing Microsoft 365 Apps for Enterprise..."
    $officePath = "C:\Temp\Office"
    New-Item -Path $officePath -ItemType Directory -Force | Out-Null
    Invoke-WebRequest -Uri "https://download.microsoft.com/download/2/7/A/27AF1BE6-DD20-4CB4-B154-EBAB8A7D4A7E/officedeploymenttool_17328-20162.exe" -OutFile "$officePath\ODT.exe"
    
    Start-Process -FilePath "$officePath\ODT.exe" -ArgumentList "/quiet /extract:$officePath" -Wait
    
    $configXml = @"
<Configuration ID="d473a46c-9126-4f5a-99d8-af03586a67bc">
  <Add OfficeClientEdition="64" Channel="Current">
    <Product ID="O365ProPlusRetail">
      <Language ID="en-us" />
      <ExcludeApp ID="Groove" />
      <ExcludeApp ID="Lync" />
      <ExcludeApp ID="OneDrive" />
    </Product>
  </Add>
  <Property Name="SharedComputerLicensing" Value="1" />
  <Property Name="FORCEAPPSHUTDOWN" Value="FALSE" />
  <Updates Enabled="TRUE" />
  <RemoveMSI />
  <Display Level="None" AcceptEULA="TRUE" />
</Configuration>
"@
    $configXml | Out-File -FilePath "$officePath\Configuration.xml" -Encoding UTF8
    
    Write-Host "Running Office Deployment Tool (This may take 10-20 minutes)..."
    $odtInstaller = Start-Process -FilePath "$officePath\setup.exe" -ArgumentList "/configure $officePath\Configuration.xml" -Wait -PassThru
    if ($odtInstaller.ExitCode -ne 0) {
        throw "Microsoft 365 Apps installation failed with exit code $($odtInstaller.ExitCode)."
    }
    Write-Host "Microsoft 365 Apps installed successfully."
}
catch {
    Write-Error "Failed to install Microsoft 365 Apps. See log for details."
    exit 1
}

try {
    # --- 6. RUN VIRTUAL DESKTOP OPTIMIZATION TOOL ---
    Write-Host "Running Virtual Desktop Optimization Tool (VDOT)..."
    Invoke-WebRequest -Uri "https://github.com/The-Virtual-Desktop-Team/Virtual-Desktop-Optimization-Tool/archive/refs/heads/main.zip" -OutFile "C:\Temp\VDOT.zip"
    Expand-Archive -Path "C:\Temp\VDOT.zip" -DestinationPath "C:\Temp\VDOT" -Force
    
    # Important: The VDOT script can be very aggressive. Review its settings if issues arise.
    $vdotPath = "C:\Temp\VDOT\Virtual-Desktop-Optimization-Tool-main"
    & "$vdotPath\Windows_VDOT.ps1" -Optimizations All -AcceptEULA -Verbose -DisableFeatures "User_OneDrive"
    Write-Host "VDOT optimizations applied."
}
catch {
    Write-Error "Failed during Virtual Desktop Optimization. See log for details."
    exit 1
}

try {
    # --- 7. APPLY CUSTOM REGISTRY SETTINGS ---
    Write-Host "Applying custom registry settings..."
    
    # Enable Cloud Kerberos Trust for seamless SSO
    $kerbPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\Kerberos\Parameters"
    if (!(Test-Path $kerbPath)) { New-Item -Path $kerbPath -Force | Out-Null }
    Set-ItemProperty -Path $kerbPath -Name "CloudKerberosTicketRetrievalEnabled" -Value 1 -Type DWord -Force
    
    # Suppress "Getting Started" and "Windows Hello" prompts
    $sysPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"
    if (!(Test-Path $sysPath)) { New-Item -Path $sysPath -Force | Out-Null }
    Set-ItemProperty -Path $sysPath -Name "NoStartupApp" -Value 1 -Type DWord -Force

    $bioPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Biometrics"
    if (!(Test-Path $bioPath)) { New-Item -Path $bioPath -Force | Out-Null }
    Set-ItemProperty -Path $bioPath -Name "Enabled" -Value 0 -Type DWord -Force
    
    Write-Host "Registry settings applied successfully."
}
catch {
    Write-Error "Failed to apply registry settings. See log for details."
    exit 1
}

# --- 8. FINAL CLEANUP ---
Write-Host "Performing final cleanup of temporary files..."
Remove-Item -Path "C:\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "C:\Windows\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "Cleanup complete."

Write-Host "--- Golden Image Configuration Finished Successfully ---"
Stop-Transcript