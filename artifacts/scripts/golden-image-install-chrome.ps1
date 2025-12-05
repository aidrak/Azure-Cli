# ==============================================================================
# Install Google Chrome on Golden Image VM
# ==============================================================================

Write-Host "[START] Chrome installation: $(Get-Date -Format 'HH:mm:ss')"

# Configuration
$chromeUrl = "https://dl.google.com/dl/chrome/install/googlechromestandaloneenterprise64.msi"
$tempPath = "C:\Temp"
$chromeMsi = "$tempPath\Chrome.msi"

try {
    # Step 1: Check for cached installer
    Write-Host "[PROGRESS] Step 1/4: Checking for cached installer..."

    if (Test-Path $chromeMsi) {
        Write-Host "[PROGRESS] Chrome.msi already exists, using cached version"
    }
    else {
        # Step 2: Download Chrome
        Write-Host "[PROGRESS] Step 2/4: Downloading Chrome Enterprise..."
        Invoke-WebRequest -Uri $chromeUrl -OutFile $chromeMsi -UseBasicParsing -TimeoutSec 120 -ErrorAction Stop

        if (-not (Test-Path $chromeMsi)) {
            Write-Host "[ERROR] Download failed: File not found"
            exit 1
        }

        Write-Host "[PROGRESS] Download complete ($($(Get-Item $chromeMsi).Length / 1MB) MB)"
    }

    # Step 3: Install Chrome
    Write-Host "[PROGRESS] Step 3/4: Installing Chrome..."
    $process = Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$chromeMsi`" /quiet /norestart" -Wait -PassThru -ErrorAction Stop

    if ($process.ExitCode -ne 0 -and $process.ExitCode -ne 3010) {
        Write-Host "[ERROR] Installation failed (exit code: $($process.ExitCode))"
        exit 1
    }

    Write-Host "[PROGRESS] Installation complete"

    # Step 4: Validate installation
    Write-Host "[PROGRESS] Step 4/4: Validating installation..."

    Write-Host "[VALIDATE] Checking Chrome executable..."
    if (-not (Test-Path "C:\Program Files\Google\Chrome\Application\chrome.exe")) {
        Write-Host "[ERROR] Chrome executable not found"
        exit 1
    }

    # Cleanup (optional - keep for cache)
    # Write-Host "[PROGRESS] Cleaning up installer..."
    # Remove-Item -Path $chromeMsi -Force -ErrorAction SilentlyContinue

    Write-Host "[SUCCESS] Google Chrome installed successfully"
    exit 0

} catch {
    Write-Host "[ERROR] Exception occurred: $($_.Exception.Message)"
    Write-Host "[ERROR] Stack trace: $($_.ScriptStackTrace)"
    exit 1
}

