# ==============================================================================
# Install Microsoft Office 365 on Golden Image VM
# ==============================================================================

Write-Host "[START] Office 365 installation: $(Get-Date -Format 'HH:mm:ss')"

# Configuration
$odtUrl = "https://download.microsoft.com/download/2/7/A/27AF1BE6-DD20-4CB4-B154-EBAB8A7D4A7E/officedeploymenttool_17328-20162.exe"
$tempPath = "C:\Temp"
$officePath = "$tempPath\Office"
$odtExe = "$officePath\ODT.exe"

try {
    # Step 1: Create Office directory
    Write-Host "[PROGRESS] Step 1/7: Creating Office directory..."

    if (!(Test-Path $officePath)) {
        New-Item -Path $officePath -ItemType Directory -Force | Out-Null
        Write-Host "[PROGRESS] Office directory created"
    }
    else {
        Write-Host "[PROGRESS] Office directory already exists"
    }

    # Step 2: Check for cached ODT
    Write-Host "[PROGRESS] Step 2/7: Checking for cached ODT installer..."

    if (Test-Path $odtExe) {
        Write-Host "[PROGRESS] ODT.exe already exists, using cached version"
    }
    else {
        # Step 3: Download Office Deployment Tool
        Write-Host "[PROGRESS] Step 3/7: Downloading Office Deployment Tool..."
        Invoke-WebRequest -Uri $odtUrl -OutFile $odtExe -UseBasicParsing -TimeoutSec 180 -ErrorAction Stop

        if (-not (Test-Path $odtExe)) {
            Write-Host "[ERROR] Download failed: File not found"
            exit 1
        }

        Write-Host "[PROGRESS] Download complete ($($(Get-Item $odtExe).Length / 1MB) MB)"
    }

    # Step 4: Extract ODT
    Write-Host "[PROGRESS] Step 4/7: Extracting Office Deployment Tool..."
    $process = Start-Process -FilePath $odtExe -ArgumentList "/quiet /extract:`"$officePath`"" -Wait -PassThru -ErrorAction Stop

    if ($process.ExitCode -ne 0) {
        Write-Host "[ERROR] Extraction failed (exit code: $($process.ExitCode))"
        exit 1
    }

    Write-Host "[PROGRESS] Extraction complete"

    # Step 5: Create Configuration XML
    Write-Host "[PROGRESS] Step 5/7: Creating Office configuration file..."

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

    $configPath = "$officePath\Configuration.xml"
    $configXml | Out-File -FilePath $configPath -Encoding UTF8 -ErrorAction Stop

    Write-Host "[PROGRESS] Configuration file created"

    # Step 6: Install Office 365
    Write-Host "[PROGRESS] Step 6/7: Installing Office 365 (this may take 10-30 minutes)..."
    Write-Host "[PROGRESS] Please be patient, no additional output will be shown during installation..."

    $setupPath = "$officePath\setup.exe"
    if (-not (Test-Path $setupPath)) {
        Write-Host "[ERROR] setup.exe not found at: $setupPath"
        exit 1
    }

    $process = Start-Process -FilePath $setupPath -ArgumentList "/configure `"$configPath`"" -Wait -PassThru -WorkingDirectory $officePath -ErrorAction Stop

    if ($process.ExitCode -ne 0) {
        Write-Host "[ERROR] Installation failed (exit code: $($process.ExitCode))"
        exit 1
    }

    Write-Host "[PROGRESS] Installation complete"

    # Step 7: Validate installation
    Write-Host "[PROGRESS] Step 7/7: Validating installation..."

    Write-Host "[VALIDATE] Checking Word executable..."
    if (-not (Test-Path "C:\Program Files\Microsoft Office\root\Office16\WINWORD.EXE")) {
        Write-Host "[ERROR] Word executable not found"
        exit 1
    }

    Write-Host "[VALIDATE] Checking Excel executable..."
    if (-not (Test-Path "C:\Program Files\Microsoft Office\root\Office16\EXCEL.EXE")) {
        Write-Host "[ERROR] Excel executable not found"
        exit 1
    }

    Write-Host "[VALIDATE] Checking Outlook executable..."
    if (-not (Test-Path "C:\Program Files\Microsoft Office\root\Office16\OUTLOOK.EXE")) {
        Write-Host "[ERROR] Outlook executable not found"
        exit 1
    }

    # Cleanup (optional - keep for cache)
    # Write-Host "[PROGRESS] Cleaning up temporary files..."
    # Remove-Item -Path $officePath -Recurse -Force -ErrorAction SilentlyContinue

    Write-Host "[SUCCESS] Microsoft Office 365 installed successfully"
    Write-Host "[SUCCESS] Installed components: Word, Excel, Outlook, PowerPoint (with Shared Computer Licensing)"
    exit 0

} catch {
    Write-Host "[ERROR] Exception occurred: $($_.Exception.Message)"
    Write-Host "[ERROR] Stack trace: $($_.ScriptStackTrace)"
    exit 1
}

