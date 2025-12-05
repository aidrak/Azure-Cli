# ==============================================================================
# Install FSLogix on Golden Image VM
# ==============================================================================

Write-Host "[START] FSLogix installation: $(Get-Date -Format 'HH:mm:ss')"

# Configuration
$downloadUrl = "https://aka.ms/fslogix_download"
$installerPath = "$env:TEMP\FSLogix.zip"
$extractPath = "$env:TEMP\FSLogix"

try {
    # Step 1: Download FSLogix
    Write-Host "[PROGRESS] Step 1/5: Downloading FSLogix..."
    Invoke-WebRequest -Uri $downloadUrl -OutFile $installerPath -UseBasicParsing -TimeoutSec 120

    if (-not (Test-Path $installerPath)) {
        Write-Host "[ERROR] Download failed: File not found"
        exit 1
    }

    Write-Host "[PROGRESS] Download complete ($($(Get-Item $installerPath).Length / 1MB) MB)"

    # Step 2: Extract archive
    Write-Host "[PROGRESS] Step 2/5: Extracting archive..."
    Expand-Archive -Path $installerPath -DestinationPath $extractPath -Force

    # Step 3: Locate installer
    Write-Host "[PROGRESS] Step 3/5: Locating installer..."
    $installer = Get-ChildItem -Path $extractPath -Filter "FSLogixAppsSetup.exe" -Recurse | Select-Object -First 1

    if (-not $installer) {
        Write-Host "[ERROR] Installer not found in archive"
        exit 1
    }

    Write-Host "[PROGRESS] Found installer: $($installer.FullName)"

    # Step 4: Install FSLogix
    Write-Host "[PROGRESS] Step 4/5: Installing FSLogix..."
    $process = Start-Process -FilePath $installer.FullName -ArgumentList "/install", "/quiet", "/norestart" -Wait -PassThru

    if ($process.ExitCode -ne 0) {
        Write-Host "[ERROR] Installation failed (exit code: $($process.ExitCode))"
        exit 1
    }

    Write-Host "[PROGRESS] Installation complete"

    # Step 5: Validate installation
    Write-Host "[PROGRESS] Step 5/5: Validating installation..."

    Write-Host "[VALIDATE] Checking executable..."
    if (-not (Test-Path "C:\Program Files\FSLogix\Apps\frx.exe")) {
        Write-Host "[ERROR] FSLogix executable not found"
        exit 1
    }

    Write-Host "[VALIDATE] Checking registry key..."
    if (-not (Test-Path "HKLM:\SOFTWARE\FSLogix")) {
        Write-Host "[ERROR] FSLogix registry key not found"
        exit 1
    }

    Write-Host "[VALIDATE] Checking Apps registry key..."
    if (-not (Test-Path "HKLM:\SOFTWARE\FSLogix\Apps")) {
        Write-Host "[ERROR] FSLogix Apps registry key not found"
        exit 1
    }

    # Cleanup
    Write-Host "[PROGRESS] Cleaning up temporary files..."
    Remove-Item -Path $installerPath -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $extractPath -Recurse -Force -ErrorAction SilentlyContinue

    Write-Host "[SUCCESS] FSLogix installed successfully"
    exit 0

} catch {
    Write-Host "[ERROR] Exception occurred: $($_.Exception.Message)"
    Write-Host "[ERROR] Stack trace: $($_.ScriptStackTrace)"
    exit 1
}

