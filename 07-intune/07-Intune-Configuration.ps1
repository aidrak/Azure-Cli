# Automates Intune Configuration for Azure Virtual Desktop (AVD)
#
# Purpose: Creates Intune configuration profiles for FSLogix and Windows settings
# on AVD session hosts.
#
# Prerequisites:
# - Microsoft.Graph PowerShell module
# - Connected to Microsoft Graph with DeviceManagementConfiguration scope
# - Device group must exist (created in Step 03)
# - Intune licenses required
#
# Usage:
# Connect-MgGraph -Scopes "DeviceManagementConfiguration.ReadWrite.All"
# .\07-Intune-Configuration.ps1 -StorageAccountName "fslogix37402" -DeviceGroupName "AVD-Devices-Pooled-SSO"
#
# Parameters:
# - StorageAccountName: FSLogix storage account name (required)
# - FileShareName: FSLogix file share name (default: fslogix-profiles)
# - DeviceGroupName: Device group for policy assignment (default: AVD-Devices-Pooled-SSO)
# - PolicyProfileName: Configuration profile name (default: FSLogix-Pooled-Configuration)

# ============================================================================
# Configuration Loading
# ============================================================================
# Load configuration from file if it exists
# Script parameters and environment variables override config file values

$ConfigFile = $env:AVD_CONFIG_FILE
if (-not $ConfigFile) {
    $ConfigFile = Join-Path $PSScriptRoot ".." "config" "avd-config.ps1"
}

if (Test-Path $ConfigFile) {
    Write-Host "ℹ Loading configuration from: $ConfigFile" -ForegroundColor Cyan
    . $ConfigFile
}

[CmdletBinding()]
param (
    [Parameter(Mandatory=$false)]
    [string]$StorageAccountName = $(if ($Global:AVD_CONFIG) { $Global:AVD_CONFIG.Storage.StorageAccountName } else { "" }),

    [Parameter(Mandatory=$false)]
    [string]$FileShareName = $(if ($Global:AVD_CONFIG) { $Global:AVD_CONFIG.Storage.FileShareName } else { "fslogix-profiles" }),

    [Parameter(Mandatory=$false)]
    [string]$DeviceGroupName = $(if ($Global:AVD_CONFIG) { $Global:AVD_CONFIG.EntraGroups.DeviceDynamicGroupName } else { "AVD-Devices-Pooled-SSO" }),

    [Parameter(Mandatory=$false)]
    [string]$PolicyProfileName = $(if ($Global:AVD_CONFIG) { $Global:AVD_CONFIG.Intune.PolicyProfileName } else { "FSLogix-Pooled-Configuration" })
)

$ErrorActionPreference = "Stop"

$Colors = @{
    Header = "Cyan"
    Success = "Green"
    Warning = "Yellow"
    Error = "Red"
    Info = "Yellow"
}

function Write-LogSection {
    param([string]$Message)
    Write-Host ""
    Write-Host "=== $Message ===" -ForegroundColor $Colors.Header
}

function Write-LogSuccess {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor $Colors.Success
}

function Write-LogError {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor $Colors.Error
}

function Write-LogWarning {
    param([string]$Message)
    Write-Host "⚠ $Message" -ForegroundColor $Colors.Warning
}

function Write-LogInfo {
    param([string]$Message)
    Write-Host "ℹ $Message" -ForegroundColor $Colors.Info
}

function Test-MgGraphConnection {
    Write-LogSection "Validating Microsoft Graph Connection"

    try {
        $context = Get-MgContext
        if ($null -eq $context) {
            Write-LogError "Not connected to Microsoft Graph"
            Write-LogInfo "Run: Connect-MgGraph -Scopes 'DeviceManagementConfiguration.ReadWrite.All'"
            exit 1
        }
        Write-LogSuccess "Connected to Microsoft Graph"
        return $true
    }
    catch {
        Write-LogError "Failed to get Graph context: $_"
        exit 1
    }
}

function New-FslogixConfigurationProfile {
    Write-LogSection "Creating FSLogix Configuration Profile"

    Write-LogInfo "Creating Intune configuration profile for FSLogix"

    $profileBody = @{
        displayName = $PolicyProfileName
        description = "Configuration profile for FSLogix on AVD pooled hosts"
        platforms = "windows10"
        technologies = "mdm"
        templateReference = @{
            templateId = "6d4a8250-8215-47a7-8699-5426cf830638_1"
        }
    }

    try {
        # This would create a configuration profile
        # For now, document the configuration
        Write-LogWarning "Manual Intune profile creation required"
        Write-LogInfo "Create a profile with these settings:"
        Write-Host "  Name: $PolicyProfileName"
        Write-Host "  Platform: Windows 10+"
        Write-Host "  Profile type: Settings Catalog"
        Write-Host ""
        Write-Host "  FSLogix Settings:"
        Write-Host "    - Enabled: True"
        Write-Host "    - VHD Profile Path: \\\\$StorageAccountName.file.core.windows.net\\$FileShareName\\%username%"
        Write-Host "    - VHD Locations: (same as profile path)"
        Write-LogSuccess "Configuration documented"
    }
    catch {
        Write-LogWarning "Could not create profile: $_"
    }
}

function Assign-ProfileToDeviceGroup {
    Write-LogSection "Assigning Profile to Device Group"

    Write-LogInfo "Profile should be assigned to: $DeviceGroupName"

    try {
        $group = Get-MgGroup -Filter "displayName eq '$DeviceGroupName'" -ErrorAction SilentlyContinue

        if ($null -eq $group) {
            Write-LogWarning "Device group '$DeviceGroupName' not found"
            Write-LogInfo "Create the group first in Step 03"
            return
        }

        Write-LogSuccess "Device group found: $($group.DisplayName)"
        Write-LogInfo "Assign the configuration profile to this group in Intune portal"
    }
    catch {
        Write-LogError "Failed to find device group: $_"
    }
}

function Document-ShutdownButtonPolicy {
    Write-LogSection "Part 5: Hide Shutdown Button from Start Menu"

    Write-LogInfo "Policy Name: AVD - Hide Shutdown Button"
    Write-LogInfo "Type: Settings Catalog or Device Restrictions"
    Write-LogInfo "Target Group: AVD session host device groups (e.g., AVD-Devices-Pooled-Network)"
    Write-Host ""

    Write-Host "Settings Catalog Configuration:" -ForegroundColor Cyan
    Write-Host "  1. Devices > Configuration > + Create > Settings catalog"
    Write-Host "  2. Name: AVD - Hide Shutdown Button"
    Write-Host "  3. + Add settings → Search: 'Start'"
    Write-Host "  4. Select: Hide Shutdown"
    Write-Host "  5. Enable the setting"
    Write-Host "  6. Assign to: Session host device groups"
    Write-Host ""

    Write-Host "Device Restrictions Alternative:" -ForegroundColor Cyan
    Write-Host "  1. Devices > Configuration > + Create > Device restrictions"
    Write-Host "  2. Start section → Shut Down: Block"
    Write-Host "  3. Assign to: Session host device groups"
    Write-Host ""

    Write-LogInfo "Expected Result: Users cannot shutdown VM via Start menu"
    Write-LogInfo "Users can still: Disconnect, Sign Out, End session"
}

function Document-AutoEndTasksPolicy {
    Write-LogSection "Part 6: Auto-Close Applications on Logoff (AutoEndTasks)"

    Write-LogWarning "IMPORTANT: This closes apps WITHOUT saving work!"
    Write-LogInfo "Policy Name: AVD - Auto End Tasks on Logoff"
    Write-LogInfo "Type: Settings Catalog (User Configuration)"
    Write-LogInfo "Target Group: AVD user groups (NOT device groups)"
    Write-Host ""

    Write-Host "Registry Path (for verification):" -ForegroundColor Cyan
    Write-Host "  HKEY_CURRENT_USER\Control Panel\Desktop"
    Write-Host "    - AutoEndTasks (REG_SZ) = '1'"
    Write-Host "    - WaitToKillAppTimeout (REG_SZ) = '5000' (optional)"
    Write-Host ""

    Write-Host "Settings Catalog Configuration:" -ForegroundColor Cyan
    Write-Host "  1. Devices > Configuration > + Create > Settings catalog"
    Write-Host "  2. Name: AVD - Auto End Tasks on Logoff"
    Write-Host "  3. + Add settings → Search: 'AutoEndTasks'"
    Write-Host "  4. Path: User Configuration > Administrative Templates > System > Logon/Logoff"
    Write-Host "  5. Select: AutoEndTasks"
    Write-Host "  6. Enable the setting"
    Write-Host "  7. Optional: Add WaitToKillAppTimeout setting (value: 5000)"
    Write-Host "  8. IMPORTANT: Assign to USER groups, not device groups"
    Write-Host ""

    Write-Host "Group Policy Alternative (for reference):" -ForegroundColor Cyan
    Write-Host "  User Configuration > Preferences > Windows Settings > Registry"
    Write-Host "    - Hive: HKEY_CURRENT_USER"
    Write-Host "    - Key: Control Panel\Desktop"
    Write-Host "    - Value: AutoEndTasks (REG_SZ) = 1"
    Write-Host ""

    Write-LogWarning "Deployment Considerations:"
    Write-Host "  • Informs users: Unsaved work will be lost on logoff"
    Write-Host "  • Prevents sessions from staying connected after logoff"
    Write-Host "  • Takes effect on next user logon"
    Write-Host "  • Consider user training and communication"
    Write-Host ""

    Write-LogInfo "Expected Behavior: Apps close immediately on logoff without save prompts"
}

function main {
    Write-Host ""
    Write-LogSection "AVD Intune Configuration"

    Test-MgGraphConnection
    New-FslogixConfigurationProfile
    Assign-ProfileToDeviceGroup
    Document-ShutdownButtonPolicy
    Document-AutoEndTasksPolicy

    Write-Host ""
    Write-LogSuccess "Intune Configuration Documented!"
    Write-Host ""
    Write-LogWarning "IMPORTANT: Manual Steps Required"
    Write-Host "  1. Go to Intune admin center"
    Write-Host "  2. Devices > Configuration > Create configuration profile"
    Write-Host "  3. Configure settings documented above"
    Write-Host "  4. Assign to appropriate device/user groups"
    Write-Host "  5. Ensure session hosts are enrolled in Intune"
    Write-Host ""
}

main
