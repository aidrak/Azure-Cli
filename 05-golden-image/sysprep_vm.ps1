# This script prepares the VM for image capture by running cleanup tasks and Sysprep.
# It should be the LAST script executed by the Custom Script Extension before capture.

# --- 1. SCRIPT SETUP AND LOGGING ---
$ErrorActionPreference = "Stop"
$LogPath = "C:\Temp\GoldenImageSysprep.log"
Start-Transcript -Path $LogPath -Append

Write-Host "--- Sysprep and Cleanup Started ---"
Write-Host "Log file located at: $LogPath"

try {
    # --- 2. CLEANUP ---
    Write-Host "Clearing temporary files..."
    Remove-Item -Path "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "C:\Windows\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue

    Write-Host "Clearing Windows Event Logs..."
    wevtutil el | ForEach-Object { 
        try {
            Write-Host "Clearing log: $_"
            wevtutil cl "$_" -ErrorAction Stop
        }
        catch {
            Write-Warning "Could not clear log '$_'. This is often due to permissions and is non-critical. Error: $($_.Exception.Message)"
        }
    }

    Write-Host "Clearing PowerShell history..."
    if (Test-Path $PROFILE) { Clear-Content $PROFILE }
    if (Get-PSReadlineOption | Get-Member -Name HistorySavePath) {
        Remove-Item (Get-PSReadlineOption).HistorySavePath -Force -ErrorAction SilentlyContinue
    }
    
    Write-Host "Cleanup tasks complete."
}
catch {
    Write-Error "An error occurred during cleanup. See log for details."
    exit 1
}

# --- 3. SYSPREP ---
# This is the final step. The VM will shut down after this command completes.
Write-Host "Executing Sysprep... The VM will shut down upon completion."
Write-Host "The Custom Script Extension may show a timeout error after this, which is expected as the VM will not report back."

try {
    $sysprepPath = "$env:SystemRoot\System32\Sysprep\sysprep.exe"
    if (!(Test-Path $sysprepPath)) {
        throw "Sysprep.exe not found at $sysprepPath"
    }
    
    # Execute Sysprep to generalize the OS and shut down the VM.
    Start-Process -FilePath $sysprepPath -ArgumentList "/oobe /generalize /shutdown /quiet" -Wait
}
catch {
    Write-Error "Sysprep execution failed. This is a critical error. The VM may be in an un-capturable state."
    Stop-Transcript
    exit 1
}

# The script will likely terminate here as the VM shuts down.
Stop-Transcript
