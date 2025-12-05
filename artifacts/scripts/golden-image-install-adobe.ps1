# ==============================================================================
# Install Adobe Acrobat Reader DC on Golden Image VM
# ==============================================================================

Write-Host "[START] Adobe Reader installation: $(Get-Date -Format 'HH:mm:ss')"

# Configuration
$adobeUrl = "https://ardownload2.adobe.com/pub/adobe/reader/win/AcrobatDC/2300320201/AcroRdrDC2300320201_en_US.exe"
$tempPath = "C:\Temp"
$adobeExe = "$tempPath\AdobeReader.exe"

try {
    # Step 1: Check for cached installer
    Write-Host "[PROGRESS] Step 1/4: Checking for cached installer..."

    if (Test-Path $adobeExe) {
        Write-Host "[PROGRESS] AdobeReader.exe already exists, using cached version"
    }
    else {
        # Step 2: Download Adobe Reader
        Write-Host "[PROGRESS] Step 2/4: Downloading Adobe Reader DC..."
        Invoke-WebRequest -Uri $adobeUrl -OutFile $adobeExe -UseBasicParsing -TimeoutSec 180 -ErrorAction Stop

        if (-not (Test-Path $adobeExe)) {
            Write-Host "[ERROR] Download failed: File not found"
            exit 1
        }

        Write-Host "[PROGRESS] Download complete ($($(Get-Item $adobeExe).Length / 1MB) MB)"
    }

    # Step 3: Install Adobe Reader
    Write-Host "[PROGRESS] Step 3/4: Installing Adobe Reader (this may take a few minutes)..."
    $process = Start-Process -FilePath $adobeExe -ArgumentList "/sAll /rs /msi EULA_ACCEPT=YES" -Wait -PassThru -ErrorAction Stop

    if ($process.ExitCode -ne 0) {
        Write-Host "[ERROR] Installation failed (exit code: $($process.ExitCode))"
        exit 1
    }

    Write-Host "[PROGRESS] Installation complete"

    # Step 4: Validate installation
    Write-Host "[PROGRESS] Step 4/4: Validating installation..."

    Write-Host "[VALIDATE] Checking Adobe Reader executable..."
    $adobePath1 = "C:\Program Files\Adobe\Acrobat DC\Acrobat\Acrobat.exe"
    $adobePath2 = "C:\Program Files (x86)\Adobe\Acrobat Reader DC\Reader\AcroRd32.exe"

    if (-not ((Test-Path $adobePath1) -or (Test-Path $adobePath2))) {
        Write-Host "[ERROR] Adobe Reader executable not found in either location"
        Write-Host "[ERROR] Path 1: $adobePath1"
        Write-Host "[ERROR] Path 2: $adobePath2"
        exit 1
    }

    if (Test-Path $adobePath1) {
        Write-Host "[VALIDATE] Found Adobe Acrobat DC at: $adobePath1"
    }
    elseif (Test-Path $adobePath2) {
        Write-Host "[VALIDATE] Found Adobe Reader DC at: $adobePath2"
    }

    # Cleanup (optional - keep for cache)
    # Write-Host "[PROGRESS] Cleaning up installer..."
    # Remove-Item -Path $adobeExe -Force -ErrorAction SilentlyContinue

    Write-Host "[SUCCESS] Adobe Acrobat Reader DC installed successfully"
    exit 0

} catch {
    Write-Host "[ERROR] Exception occurred: $($_.Exception.Message)"
    Write-Host "[ERROR] Stack trace: $($_.ScriptStackTrace)"
    exit 1
}

