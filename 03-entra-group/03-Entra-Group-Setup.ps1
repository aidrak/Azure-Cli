# Automates Entra Group Setup for Azure Virtual Desktop (AVD)
#
# Purpose: Creates security groups and dynamic device groups required for AVD user
# access and device management.
#
# Prerequisites:
# - Microsoft.Graph PowerShell module installed
# - Logged into Microsoft Graph (Connect-MgGraph)
# - Tenant Admin or User Administrator role
# - Directory.ReadWrite.All permission
#
# Permissions Required:
# - Directory.ReadWrite.All (Microsoft Graph)
# - User.Read (Microsoft Graph)
#
# Usage:
# Connect-MgGraph -Scopes "Directory.ReadWrite.All"
# .\03-Entra-Group-Setup.ps1
#
# Example with custom group names:
# .\03-Entra-Group-Setup.ps1 -StandardUsersGroupName "My-AVD-Users" -AdminUsersGroupName "My-AVD-Admins"
#
# Parameters:
# - StandardUsersGroupName: Name of group for standard AVD users (default: AVD-Users-Standard)
# - AdminUsersGroupName: Name of group for AVD administrators (default: AVD-Users-Admins)
# - DeviceDynamicGroupName: Name of dynamic device group (default: AVD-Devices-Pooled-SSO)
# - DeviceDynamicGroupRule: Dynamic membership rule for devices (default: displayName starts with "avd-pool")
#
# Notes:
# - This script is idempotent - safe to run multiple times
# - Dynamic device groups require Azure AD Premium P1 license
# - Expected runtime: 1-2 minutes

[CmdletBinding()]
param (
    [Parameter(Mandatory=$false)]
    [string]$StandardUsersGroupName = "AVD-Users-Standard",

    [Parameter(Mandatory=$false)]
    [string]$AdminUsersGroupName = "AVD-Users-Admins",

    [Parameter(Mandatory=$false)]
    [string]$DeviceDynamicGroupName = "AVD-Devices-Pooled-SSO",

    [Parameter(Mandatory=$false)]
    [string]$DeviceDynamicGroupRule = '(device.displayName -startsWith "avd-pool")'
)

$ErrorActionPreference = "Stop"

# Color codes for output
$Colors = @{
    Header = "Cyan"
    Success = "Green"
    Warning = "Yellow"
    Error = "Red"
    Info = "Yellow"
}

# ============================================================================
# Helper Functions
# ============================================================================

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

# ============================================================================
# Validation Functions
# ============================================================================

function Test-MgGraphConnection {
    Write-LogSection "Validating Microsoft Graph Connection"

    try {
        $context = Get-MgContext
        if ($null -eq $context) {
            Write-LogError "Not connected to Microsoft Graph. Run 'Connect-MgGraph -Scopes Directory.ReadWrite.All' first"
            exit 1
        }
        Write-LogSuccess "Connected to Microsoft Graph"
        Write-LogInfo "Tenant: $($context.TenantId)"
        return $true
    }
    catch {
        Write-LogError "Failed to get Graph context: $_"
        exit 1
    }
}

# ============================================================================
# Group Creation
# ============================================================================

function New-AvdSecurityGroup {
    param([string]$GroupName)

    Write-LogInfo "Creating security group '$GroupName'"

    try {
        # Check if group already exists
        $existingGroup = Get-MgGroup -Filter "displayName eq '$GroupName'" -ErrorAction SilentlyContinue
        if ($null -ne $existingGroup) {
            Write-LogWarning "Group '$GroupName' already exists"
            return $existingGroup
        }

        # Create the group
        $group = New-MgGroup `
            -DisplayName $GroupName `
            -MailEnabled $false `
            -SecurityEnabled $true `
            -MailNickname ($GroupName -replace " ", "") `
            -ErrorAction Stop

        Write-LogSuccess "Security group '$GroupName' created (ID: $($group.Id))"
        return $group
    }
    catch {
        Write-LogError "Failed to create security group: $_"
        throw
    }
}

function New-AvdDynamicDeviceGroup {
    param(
        [string]$GroupName,
        [string]$MembershipRule
    )

    Write-LogInfo "Creating dynamic device group '$GroupName'"

    try {
        # Check if group already exists
        $existingGroup = Get-MgGroup -Filter "displayName eq '$GroupName'" -ErrorAction SilentlyContinue
        if ($null -ne $existingGroup) {
            Write-LogWarning "Group '$GroupName' already exists"
            return $existingGroup
        }

        # Create the dynamic group
        $group = New-MgGroup `
            -DisplayName $GroupName `
            -MailEnabled $false `
            -SecurityEnabled $true `
            -MailNickname ($GroupName -replace " ", "") `
            -GroupTypes "DynamicMembership" `
            -MembershipRule $MembershipRule `
            -MembershipRuleProcessingState "On" `
            -ErrorAction Stop

        Write-LogSuccess "Dynamic device group '$GroupName' created (ID: $($group.Id))"
        Write-LogInfo "Membership rule: $MembershipRule"
        return $group
    }
    catch {
        Write-LogError "Failed to create dynamic device group: $_"
        throw
    }
}

# ============================================================================
# Group Configuration
# ============================================================================

function Set-AdminGroupLocalAdminConfig {
    param([PSObject]$AdminGroup)

    Write-LogSection "Configuring Admin Group for Local Admin Rights"

    Write-LogInfo "Configuring group '$($AdminGroup.DisplayName)' for local admin"
    try {
        # This is typically configured via policies or role assignments
        # Document the configuration requirement
        Write-LogWarning "Local admin configuration requires additional setup via:"
        Write-Host "  1. Azure AD P2 license on members"
        Write-Host "  2. Configure via Windows MDM/Intune policies"
        Write-Host "  3. Or use Restricted Admin mode in Group Policy"

        Write-LogSuccess "Admin group '$($AdminGroup.DisplayName)' documented for admin configuration"
    }
    catch {
        Write-LogWarning "Could not automatically configure admin rights: $_"
    }
}

# ============================================================================
# Verification
# ============================================================================

function Test-EntraGroupConfiguration {
    param(
        [PSObject]$StandardUsersGroup,
        [PSObject]$AdminUsersGroup,
        [PSObject]$DeviceGroup
    )

    Write-LogSection "Verifying Group Configuration"

    $allValid = $true

    # Verify standard users group
    $verified = Get-MgGroup -GroupId $StandardUsersGroup.Id -ErrorAction SilentlyContinue
    if ($null -ne $verified) {
        Write-LogSuccess "Standard Users group verified"
    }
    else {
        Write-LogError "Standard Users group not found"
        $allValid = $false
    }

    # Verify admin users group
    $verified = Get-MgGroup -GroupId $AdminUsersGroup.Id -ErrorAction SilentlyContinue
    if ($null -ne $verified) {
        Write-LogSuccess "Admin Users group verified"
    }
    else {
        Write-LogError "Admin Users group not found"
        $allValid = $false
    }

    # Verify device group
    $verified = Get-MgGroup -GroupId $DeviceGroup.Id -ErrorAction SilentlyContinue
    if ($null -ne $verified) {
        Write-LogSuccess "Device group verified"
    }
    else {
        Write-LogError "Device group not found"
        $allValid = $false
    }

    if ($allValid) {
        Write-LogSuccess "All groups verified"
    }

    return $allValid
}

# ============================================================================
# Main Execution
# ============================================================================

function main {
    Write-Host ""
    Write-LogSection "AVD Entra Group Setup"

    # Validate Graph connection
    Test-MgGraphConnection

    # Create security groups
    $standardUsersGroup = New-AvdSecurityGroup -GroupName $StandardUsersGroupName
    $adminUsersGroup = New-AvdSecurityGroup -GroupName $AdminUsersGroupName

    # Create dynamic device group
    $deviceGroup = New-AvdDynamicDeviceGroup -GroupName $DeviceDynamicGroupName -MembershipRule $DeviceDynamicGroupRule

    # Configure admin group
    Set-AdminGroupLocalAdminConfig -AdminGroup $adminUsersGroup

    # Verify configuration
    Test-EntraGroupConfiguration -StandardUsersGroup $standardUsersGroup -AdminUsersGroup $adminUsersGroup -DeviceGroup $deviceGroup

    Write-Host ""
    Write-LogSuccess "Entra Group Setup Complete!"
    Write-Host ""
    Write-LogInfo "Summary:"
    Write-Host "  Standard Users Group: $($standardUsersGroup.DisplayName)"
    Write-Host "    ID: $($standardUsersGroup.Id)"
    Write-Host "  Admin Users Group: $($adminUsersGroup.DisplayName)"
    Write-Host "    ID: $($adminUsersGroup.Id)"
    Write-Host "  Device Group: $($deviceGroup.DisplayName)"
    Write-Host "    ID: $($deviceGroup.Id)"
    Write-Host "    Type: Dynamic"
    Write-Host "    Rule: $DeviceDynamicGroupRule"
    Write-Host ""
    Write-LogInfo "Next steps:"
    Write-Host "  1. Add users to appropriate groups"
    Write-Host "  2. Configure RBAC assignments for groups (Step 08)"
    Write-Host "  3. Configure admin rights via Intune or Group Policy"
    Write-Host ""
}

main
