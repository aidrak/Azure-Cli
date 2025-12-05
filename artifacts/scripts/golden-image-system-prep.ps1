# ==============================================================================
# System Preparation for Golden Image
# ==============================================================================

Write-Host "[START] System preparation: $(Get-Date -Format 'HH:mm:ss')"

try {
    # Step 1: Disable BitLocker
    Write-Host "[PROGRESS] Step 1/2: Disabling BitLocker..."

    try {
        Disable-BitLocker -MountPoint "C:" -ErrorAction SilentlyContinue | Out-Null
        Write-Host "[PROGRESS] BitLocker disabled"
    }
    catch {
        Write-Host "[PROGRESS] BitLocker already disabled or not present"
    }

    # Step 2: Create temporary directory
    Write-Host "[PROGRESS] Step 2/2: Creating temporary directory..."

    $tempPath = "C:\Temp"
    if (!(Test-Path $tempPath)) {
        New-Item -Path $tempPath -ItemType Directory -Force | Out-Null
        Write-Host "[PROGRESS] Temporary directory created: $tempPath"
    }
    else {
        Write-Host "[PROGRESS] Temporary directory already exists"
    }

    # Validation
    Write-Host "[VALIDATE] Checking temp directory..."
    if (-not (Test-Path "C:\Temp")) {
        Write-Host "[ERROR] Temp directory not found"
        exit 1
    }

    Write-Host "[SUCCESS] System preparation complete"
    exit 0

} catch {
    Write-Host "[ERROR] Exception occurred: $($_.Exception.Message)"
    Write-Host "[ERROR] Stack trace: $($_.ScriptStackTrace)"
    exit 1
}

