# ============================================================================
# Step 8: Final Cleanup & Sysprep Preparation
# ============================================================================
#
# Purpose: Clean up temporary files and prepare VM for sysprep
#
# This script is designed to run remotely via:
# az vm run-command invoke --command-id RunPowerShellScript --scripts @final-cleanup-sysprep.ps1
#
# Actions:
# - Remove temporary files from user temp and system temp
# - Clear Windows event logs
# - Clear Recycle Bin
#

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

# ============================================================================
# Logging Functions
# ============================================================================

function Write-LogSection {
    param([string]$Message)
    Write-Host ""
    Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║ $($Message.PadRight(56)) ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
}

function Write-LogSuccess {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor Green
}

function Write-LogError {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor Red
}

function Write-LogWarning {
    param([string]$Message)
    Write-Host "⚠ $Message" -ForegroundColor Yellow
}

function Write-LogInfo {
    param([string]$Message)
    Write-Host "ℹ $Message" -ForegroundColor Gray
}

# ============================================================================
# Main Execution
# ============================================================================

Write-Host ""
Write-LogSection "Step 8: Final Cleanup & Sysprep Preparation"
Write-LogInfo "Starting at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

try {
    # === REMOVE TEMPORARY FILES ===
    Write-LogSection "Removing Temporary Files"

    Write-LogInfo "Removing user temp directory..."
    Remove-Item -Path "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
    Write-LogSuccess "User temp directory cleaned"

    Write-LogInfo "Removing system temp directory..."
    Remove-Item -Path "C:\Windows\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue
    Write-LogSuccess "System temp directory cleaned"

    # === CLEAR EVENT LOGS ===
    Write-LogSection "Clearing Event Logs"

    Write-LogInfo "Enumerating and clearing all event logs..."
    $logCount = 0
    wevtutil el | ForEach-Object {
        try {
            wevtutil cl "$_" 2>/dev/null
            $logCount++
        }
        catch {
            # Some logs may fail, that's okay
        }
    }
    Write-LogSuccess "Cleared $logCount event logs"

    # === CLEAR RECYCLE BIN ===
    Write-LogSection "Clearing Recycle Bin"

    Write-LogInfo "Clearing Recycle Bin..."
    Clear-RecycleBin -Force -ErrorAction SilentlyContinue
    Write-LogSuccess "Recycle Bin cleared"

    # === FINAL SUMMARY ===
    Write-Host ""
    Write-LogSection "Step 8 Complete"
    Write-LogSuccess "VM successfully prepared for sysprep!"
    Write-Host ""
    Write-LogInfo "Completed at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Write-LogWarning "NEXT STEPS:"
    Write-Host "  1. Disconnect RDP (if connected)"
    Write-Host "  2. Run Task 04: Sysprep VM"
    Write-Host "  3. Run Task 05: Capture Image"
    Write-Host "  4. Run Task 06: Cleanup resources"
    Write-Host ""

    exit 0
}
catch {
    Write-Host ""
    Write-LogError "Step 8 failed with error:"
    Write-Host "$($_.Exception.ToString())" -ForegroundColor Red
    Write-Host ""
    exit 1
}
