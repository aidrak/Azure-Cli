# ============================================================================
# Step 7: Apply AVD-Specific Optimizations
# ============================================================================
#
# Purpose: Apply registry optimizations specific to Azure Virtual Desktop
# for Pooled (multi-session) environments with FSLogix.
#
# This script is designed to run remotely via:
# az vm run-command invoke --command-id RunPowerShellScript --scripts @avd-registry-optimizations.ps1
#
# Optimizations Applied:
# - RDP timezone redirection
# - FSLogix Defender exclusions (Pooled only)
# - Locale settings (en-US)
# - Disable System Restore and VSS
# - Black screen fix (disable first logon animation)
# - OOBE privacy suppression
# - Windows Hello suppression
# - Default User profile configuration
#

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

# ============================================================================
# Logging Functions
# ============================================================================

function Write-LogSection {
    param([string]$Message)
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host " $($Message.PadRight(56))" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Write-LogSuccess {
    param([string]$Message)
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-LogError {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Write-LogWarning {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Write-LogInfo {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Gray
}

# ============================================================================
# Configuration
# ============================================================================

# Image type is always POOLED for this script
$isPooled = $true

# ============================================================================
# Step 7: AVD-Specific Registry Optimizations
# ============================================================================

function Configure-RegistryForAvd {
    Write-LogSection "Configuring Registry for AVD"

    # === RDP TIMEZONE REDIRECTION ===
    Write-LogInfo "Enabling RDP timezone redirection..."
    $rdpPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server"
    if (!(Test-Path $rdpPath)) { New-Item -Path $rdpPath -Force | Out-Null }
    Set-ItemProperty -Path $rdpPath -Name "fEnableTimeZoneRedirection" -Value 1 -Type DWord -Force
    Write-LogSuccess "RDP timezone redirection enabled"

    # === FSLOGIX DEFENDER EXCLUSIONS (POOLED ONLY) ===
    if ($isPooled) {
        Write-LogInfo "Adding FSLogix Defender exclusions..."
        Add-MpPreference -ExclusionPath "C:\Program Files\FSLogix" -ErrorAction SilentlyContinue
        Add-MpPreference -ExclusionPath "C:\ProgramData\FSLogix" -ErrorAction SilentlyContinue
        Add-MpPreference -ExclusionProcess "frx.exe" -ErrorAction SilentlyContinue
        Add-MpPreference -ExclusionExtension "vhd" -ErrorAction SilentlyContinue
        Add-MpPreference -ExclusionExtension "vhdx" -ErrorAction SilentlyContinue
        Write-LogSuccess "FSLogix Defender exclusions added"
    }

    # === LOCALE SETTINGS ===
    Write-LogInfo "Setting locale to en-US..."
    Set-WinSystemLocale -SystemLocale "en-US" -ErrorAction SilentlyContinue
    Set-Culture -CultureInfo "en-US" -ErrorAction SilentlyContinue
    Set-WinHomeLocation -GeoId 244 -ErrorAction SilentlyContinue
    Set-WinUserLanguageList (New-WinUserLanguageList "en-US") -Force -ErrorAction SilentlyContinue
    Write-LogSuccess "Locale set to en-US"

    # === DISABLE SYSTEM RESTORE & VSS ===
    Write-LogInfo "Disabling System Restore and VSS..."
    Disable-ComputerRestore -Drive "C:\" -ErrorAction SilentlyContinue
    vssadmin delete shadows /all /quiet | Out-Null
    Stop-Service -Name VSS -Force -ErrorAction SilentlyContinue
    Set-Service -Name VSS -StartupType Disabled -ErrorAction SilentlyContinue
    Write-LogSuccess "System Restore and VSS disabled"

    # === BLACK SCREEN FIX (First Logon Animation) ===
    Write-LogInfo "Disabling first logon animation (black screen fix)..."
    $winlogonPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
    if (!(Test-Path $winlogonPath)) { New-Item -Path $winlogonPath -Force | Out-Null }
    Set-ItemProperty -Path $winlogonPath -Name "EnableFirstLogonAnimation" -Value 0 -Type DWord -Force

    $policySysPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
    if (!(Test-Path $policySysPath)) { New-Item -Path $policySysPath -Force | Out-Null }
    Set-ItemProperty -Path $policySysPath -Name "EnableFirstLogonAnimation" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $policySysPath -Name "DelayedDesktopSwitchTimeout" -Value 0 -Type DWord -Force
    Write-LogSuccess "First logon animation disabled (black screen fix applied)"

    # === OOBE PRIVACY EXPERIENCE SUPPRESSION ===
    Write-LogInfo "Disabling OOBE privacy screens..."
    $oobePath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OOBE"
    if (!(Test-Path $oobePath)) { New-Item -Path $oobePath -Force | Out-Null }
    Set-ItemProperty -Path $oobePath -Name "DisablePrivacyExperience" -Value 1 -Type DWord -Force
    Write-LogSuccess "OOBE privacy screens disabled"

    # === WINDOWS HELLO SUPPRESSION ===
    Write-LogInfo "Disabling Windows Hello for Business..."
    $passportPath = "HKLM:\SOFTWARE\Policies\Microsoft\PassportForWork"
    if (!(Test-Path $passportPath)) { New-Item -Path $passportPath -Force | Out-Null }
    Set-ItemProperty -Path $passportPath -Name "Enabled" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $passportPath -Name "DisablePostLogonProvisioning" -Value 1 -Type DWord -Force
    Write-LogSuccess "Windows Hello for Business disabled"

    # === BIOMETRICS SUPPRESSION ===
    Write-LogInfo "Disabling biometrics..."
    $biometricsPath = "HKLM:\SOFTWARE\Policies\Microsoft\Biometrics"
    if (!(Test-Path $biometricsPath)) { New-Item -Path $biometricsPath -Force | Out-Null }
    Set-ItemProperty -Path $biometricsPath -Name "Enabled" -Value 0 -Type DWord -Force
    Write-LogSuccess "Biometrics disabled"

    # === WELCOME SCREEN SUPPRESSION ===
    Write-LogInfo "Disabling Welcome screen..."
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "DisableLockScreenAppNotifications" -Value 1 -Type DWord -Force
    Write-LogSuccess "Welcome screen disabled"

    Write-LogSuccess "Registry configuration completed"
}

# ============================================================================
# Default User Profile Configuration
# ============================================================================

function Configure-DefaultUserProfile {
    Write-LogSection "Configuring Default User Profile"

    Write-LogInfo "Loading and configuring Default User hive..."
    try {
        reg load "HKU\DefaultUser" "C:\Users\Default\NTUSER.DAT" | Out-Null

        # Disable "Let's finish setting up your device"
        $contentDelivery = "Registry::HKU\DefaultUser\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
        if (!(Test-Path $contentDelivery)) { New-Item -Path $contentDelivery -Force | Out-Null }
        Set-ItemProperty -Path $contentDelivery -Name "OemPreInstalledAppsEnabled" -Value 0 -Type DWord -Force
        Set-ItemProperty -Path $contentDelivery -Name "PreInstalledAppsEnabled" -Value 0 -Type DWord -Force
        Set-ItemProperty -Path $contentDelivery -Name "SilentInstalledAppsEnabled" -Value 0 -Type DWord -Force
        Set-ItemProperty -Path $contentDelivery -Name "SubscribedContent-310093Enabled" -Value 0 -Type DWord -Force
        Set-ItemProperty -Path $contentDelivery -Name "SubscribedContent-338387Enabled" -Value 0 -Type DWord -Force
        Set-ItemProperty -Path $contentDelivery -Name "SystemPaneSuggestionsEnabled" -Value 0 -Type DWord -Force

        # Disable user engagement prompts
        $userEngagement = "Registry::HKU\DefaultUser\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement"
        if (!(Test-Path $userEngagement)) { New-Item -Path $userEngagement -Force | Out-Null }
        Set-ItemProperty -Path $userEngagement -Name "ScoobeSystemSettingEnabled" -Value 0 -Type DWord -Force

        # Unload hive
        [gc]::Collect()
        Start-Sleep -Seconds 2
        reg unload "HKU\DefaultUser" | Out-Null

        Write-LogSuccess "Default User profile configured"
    }
    catch {
        Write-LogError "Failed to configure Default User profile: $($_.Exception.ToString())"
        throw
    }
}

# ============================================================================
# Main Execution
# ============================================================================

Write-Host ""
Write-LogSection "AVD-Specific Optimizations - Step 7"
Write-LogInfo "Image Type: POOLED (with FSLogix)"
Write-LogInfo "Starting at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

try {
    Configure-RegistryForAvd
    Configure-DefaultUserProfile

    Write-Host ""
    Write-LogSection "Step 7 Complete"
    Write-LogSuccess "All AVD-specific optimizations applied successfully!"
    Write-Host ""
    Write-LogInfo "Completed at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Write-LogWarning "IMPORTANT: Next step is Step 8 - Final Cleanup & Sysprep Preparation"
    Write-Host ""

    exit 0
}
catch {
    Write-Host ""
    Write-LogError "Step 7 failed with error:"
    Write-Host "$($_.Exception.ToString())" -ForegroundColor Red
    Write-Host ""
    exit 1
}
