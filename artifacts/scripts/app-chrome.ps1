# ==============================================================================
# Install Google Chrome Enterprise
# ==============================================================================

Write-Host "[START] Installing Google Chrome Enterprise: $(Get-Date -Format 'HH:mm:ss')"

$tempDir = "C:\Temp"
$installer = "$tempDir\Chrome.msi"
$url = "https://dl.google.com/dl/chrome/install/googlechromestandaloneenterprise64.msi"

try {
    # Ensure temp directory exists
    if (-not (Test-Path $tempDir)) {
        New-Item -Path $tempDir -ItemType Directory -Force | Out-Null
    }

    # Download
    Write-Host "[i] Downloading Chrome from $url..."
    Invoke-WebRequest -Uri $url -OutFile $installer -UseBasicParsing -TimeoutSec 300

    if (-not (Test-Path $installer)) {
        throw "Download failed: installer not found"
    }

    $fileSize = [math]::Round((Get-Item $installer).Length / 1MB, 2)
    Write-Host "[i] Download complete: $fileSize MB"

    # Install
    Write-Host "[i] Installing Chrome..."
    $proc = Start-Process -FilePath "msiexec.exe" `
        -ArgumentList "/i `"$installer`" /quiet /norestart ALLUSERS=1" `
        -Wait -PassThru

    if ($proc.ExitCode -notin @(0, 3010)) {
        throw "Installation failed with exit code $($proc.ExitCode)"
    }

    # Validate
    Write-Host "[i] Validating installation..."
    $chromePath = "C:\Program Files\Google\Chrome\Application\chrome.exe"
    if (-not (Test-Path $chromePath)) {
        throw "Validation failed: Chrome executable not found"
    }

    # Cleanup
    Remove-Item $installer -Force -ErrorAction SilentlyContinue

    Write-Host "[v] Google Chrome installed successfully"
    exit 0

} catch {
    Write-Host "[x] Error: $($_.Exception.Message)"
    exit 1
}

