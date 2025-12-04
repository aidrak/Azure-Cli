# Automates Host Pool & Workspace Setup for Azure Virtual Desktop (AVD)
#
# Purpose: Creates AVD workspace, host pool, and application group with proper
# RDP configuration and SSO settings.
#
# Prerequisites:
# - Azure PowerShell module (Az.Desktopvirtualization) installed
# - Logged into Azure (Connect-AzAccount)
# - Resource group must exist
# - Resource provider Microsoft.DesktopVirtualization must be registered
#
# Permissions Required:
# - Desktop Virtualization Contributor
# - Contributor on resource group
#
# Usage:
# Connect-AzAccount
# .\04-Host-Pool-Workspace-Setup.ps1 -ResourceGroupName "RG-Azure-VDI-01" -Location "centralus"
#
# Example with custom names:
# .\04-Host-Pool-Workspace-Setup.ps1 `
#   -ResourceGroupName "RG-Azure-VDI-01" `
#   -Location "centralus" `
#   -WorkspaceName "My-AVD-Workspace" `
#   -HostPoolName "My-Host-Pool"
#
# Parameters:
# - ResourceGroupName: Name of resource group (required)
# - Location: Azure region (required)
# - WorkspaceName: Workspace name (default: AVD-Workspace-Prod)
# - HostPoolName: Host pool name (default: Pool-Pooled-Prod)
# - MaxSessionLimit: Max concurrent sessions per host (default: 12)
# - LoadBalancerType: BreadthFirst or DepthFirst (default: BreadthFirst)
# - EnableValidationEnvironment: Use validation environment (default: false)
#
# Notes:
# - This script is idempotent - safe to run multiple times
# - Expected runtime: 2-3 minutes

[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory=$true)]
    [string]$Location,

    [Parameter(Mandatory=$false)]
    [string]$WorkspaceName = "AVD-Workspace-Prod",

    [Parameter(Mandatory=$false)]
    [string]$HostPoolName = "Pool-Pooled-Prod",

    [Parameter(Mandatory=$false)]
    [int]$MaxSessionLimit = 12,

    [Parameter(Mandatory=$false)]
    [ValidateSet("BreadthFirst", "DepthFirst")]
    [string]$LoadBalancerType = "BreadthFirst",

    [Parameter(Mandatory=$false)]
    [switch]$EnableValidationEnvironment
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

function Test-Prerequisites {
    Write-LogSection "Validating Prerequisites"

    # Check Azure context
    try {
        $azContext = Get-AzContext
        if ($null -eq $azContext) {
            Write-LogError "Not logged into Azure. Run 'Connect-AzAccount' first"
            exit 1
        }
        Write-LogSuccess "Logged into Azure subscription: $($azContext.Subscription.Name)"
    }
    catch {
        Write-LogError "Failed to get Azure context: $_"
        exit 1
    }

    # Verify resource group exists
    try {
        $rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
        if ($null -eq $rg) {
            Write-LogError "Resource group '$ResourceGroupName' not found"
            exit 1
        }
        Write-LogSuccess "Resource group '$ResourceGroupName' exists"
    }
    catch {
        Write-LogError "Failed to verify resource group: $_"
        exit 1
    }

    # Register resource provider if needed
    Write-LogInfo "Registering DesktopVirtualization resource provider"
    try {
        Register-AzResourceProvider -ProviderNamespace "Microsoft.DesktopVirtualization" -ErrorAction SilentlyContinue
        Write-LogSuccess "Resource provider registered"
    }
    catch {
        Write-LogWarning "Could not register resource provider: $_"
    }
}

# ============================================================================
# Workspace Creation
# ============================================================================

function New-AvdWorkspace {
    Write-LogSection "Creating Workspace"

    Write-LogInfo "Creating workspace '$WorkspaceName'"
    try {
        # Check if workspace already exists
        $existingWorkspace = Get-AzWvdWorkspace -ResourceGroupName $ResourceGroupName -Name $WorkspaceName -ErrorAction SilentlyContinue
        if ($null -ne $existingWorkspace) {
            Write-LogWarning "Workspace '$WorkspaceName' already exists"
            return $existingWorkspace
        }

        $workspace = New-AzWvdWorkspace `
            -ResourceGroupName $ResourceGroupName `
            -Name $WorkspaceName `
            -Location $Location `
            -ErrorAction Stop

        Write-LogSuccess "Workspace '$WorkspaceName' created"
        return $workspace
    }
    catch {
        Write-LogError "Failed to create workspace: $_"
        throw
    }
}

# ============================================================================
# Host Pool Creation
# ============================================================================

function New-AvdHostPool {
    Write-LogSection "Creating Host Pool"

    Write-LogInfo "Creating host pool '$HostPoolName' (pooled, load balancer: $LoadBalancerType)"
    try {
        # Check if host pool already exists
        $existingHostPool = Get-AzWvdHostPool -ResourceGroupName $ResourceGroupName -Name $HostPoolName -ErrorAction SilentlyContinue
        if ($null -ne $existingHostPool) {
            Write-LogWarning "Host pool '$HostPoolName' already exists"
            return $existingHostPool
        }

        $hostPool = New-AzWvdHostPool `
            -ResourceGroupName $ResourceGroupName `
            -Name $HostPoolName `
            -Location $Location `
            -HostPoolType "Pooled" `
            -LoadBalancerType $LoadBalancerType `
            -MaxSessionLimit $MaxSessionLimit `
            -ValidationEnvironment:$EnableValidationEnvironment `
            -ErrorAction Stop

        Write-LogSuccess "Host pool '$HostPoolName' created"
        Write-LogInfo "Configuration:"
        Write-Host "  Type: Pooled"
        Write-Host "  Load Balancer: $LoadBalancerType"
        Write-Host "  Max Sessions: $MaxSessionLimit"
        return $hostPool
    }
    catch {
        Write-LogError "Failed to create host pool: $_"
        throw
    }
}

# ============================================================================
# Application Group Creation
# ============================================================================

function New-AvdApplicationGroup {
    param([PSObject]$HostPool)

    Write-LogSection "Creating Application Group"

    $appGroupName = "$HostPoolName-DAG"

    Write-LogInfo "Creating desktop application group '$appGroupName'"
    try {
        # Check if app group already exists
        $existingAppGroup = Get-AzWvdApplicationGroup -ResourceGroupName $ResourceGroupName -Name $appGroupName -ErrorAction SilentlyContinue
        if ($null -ne $existingAppGroup) {
            Write-LogWarning "Application group '$appGroupName' already exists"
            return $existingAppGroup
        }

        $appGroup = New-AzWvdApplicationGroup `
            -ResourceGroupName $ResourceGroupName `
            -Name $appGroupName `
            -Location $Location `
            -ApplicationGroupType "Desktop" `
            -HostPoolArmPath $HostPool.Id `
            -ErrorAction Stop

        Write-LogSuccess "Application group '$appGroupName' created"
        return $appGroup
    }
    catch {
        Write-LogError "Failed to create application group: $_"
        throw
    }
}

# ============================================================================
# Workspace and App Group Registration
# ============================================================================

function Register-ApplicationGroupToWorkspace {
    param(
        [PSObject]$Workspace,
        [PSObject]$ApplicationGroup
    )

    Write-LogSection "Registering Application Group to Workspace"

    Write-LogInfo "Linking application group to workspace"
    try {
        # Check if already registered
        $registration = Get-AzWvdWorkspace -ResourceGroupName $ResourceGroupName -Name $Workspace.Name |
            Get-AzWvdApplicationGroup |
            Where-Object { $_.Id -eq $ApplicationGroup.Id }

        if ($null -ne $registration) {
            Write-LogWarning "Application group already registered to workspace"
            return
        }

        # Register application group
        Update-AzWvdWorkspace `
            -ResourceGroupName $ResourceGroupName `
            -Name $Workspace.Name `
            -ApplicationGroupReference @($ApplicationGroup.Id) `
            -ErrorAction Stop

        Write-LogSuccess "Application group registered to workspace"
    }
    catch {
        Write-LogError "Failed to register application group: $_"
        throw
    }
}

# ============================================================================
# RDP Properties Configuration
# ============================================================================

function Set-HostPoolRdpProperties {
    param([PSObject]$HostPool)

    Write-LogSection "Configuring RDP Properties"

    Write-LogInfo "Setting SSO and security settings"
    try {
        # Configure RDP properties for SSO and security
        $rdpProperties = @{
            "audiocapturemode" = "0"  # Disable microphone
            "audiomode" = "0"          # Disable audio
            "camerastoredirect" = "*"  # Redirect all cameras
            "clipboardredirect" = "1"  # Enable clipboard
            "drivestoredirect" = ""    # Disable drives
            "usbdevicestoredirect" = "*" # Redirect USB devices
            "use multimon" = "1"       # Enable multi-monitor
            "promptcredentialonce" = "0" # SSO
            "promptfordestinationcert" = "1" # Verify RDP certificate
            "devicestoredirect" = "*"  # Redirect all devices
        }

        # Build RDP string
        $rdpString = ($rdpProperties.GetEnumerator() | ForEach-Object { "$($_.Key):i:$($_.Value)" }) -join ";"

        Update-AzWvdHostPool `
            -ResourceGroupName $ResourceGroupName `
            -Name $HostPool.Name `
            -CustomRdpProperty $rdpString `
            -ErrorAction Stop

        Write-LogSuccess "RDP properties configured"
        Write-LogInfo "Settings:"
        Write-Host "  SSO: Enabled"
        Write-Host "  Clipboard: Enabled"
        Write-Host "  Camera Redirect: Enabled"
        Write-Host "  USB Redirect: Enabled"
    }
    catch {
        Write-LogError "Failed to configure RDP properties: $_"
        throw
    }
}

# ============================================================================
# Verification
# ============================================================================

function Test-HostPoolConfiguration {
    param(
        [PSObject]$Workspace,
        [PSObject]$HostPool,
        [PSObject]$AppGroup
    )

    Write-LogSection "Verifying Configuration"

    $allValid = $true

    # Verify workspace
    $verified = Get-AzWvdWorkspace -ResourceGroupName $ResourceGroupName -Name $Workspace.Name -ErrorAction SilentlyContinue
    if ($null -ne $verified) {
        Write-LogSuccess "Workspace verified"
    }
    else {
        Write-LogError "Workspace not found"
        $allValid = $false
    }

    # Verify host pool
    $verified = Get-AzWvdHostPool -ResourceGroupName $ResourceGroupName -Name $HostPool.Name -ErrorAction SilentlyContinue
    if ($null -ne $verified) {
        Write-LogSuccess "Host pool verified"
    }
    else {
        Write-LogError "Host pool not found"
        $allValid = $false
    }

    # Verify application group
    $verified = Get-AzWvdApplicationGroup -ResourceGroupName $ResourceGroupName -Name $AppGroup.Name -ErrorAction SilentlyContinue
    if ($null -ne $verified) {
        Write-LogSuccess "Application group verified"
    }
    else {
        Write-LogError "Application group not found"
        $allValid = $false
    }

    if ($allValid) {
        Write-LogSuccess "All resources verified"
    }

    return $allValid
}

# ============================================================================
# Main Execution
# ============================================================================

function main {
    Write-Host ""
    Write-LogSection "AVD Host Pool & Workspace Setup"

    # Validate prerequisites
    Test-Prerequisites

    # Create workspace
    $workspace = New-AvdWorkspace

    # Create host pool
    $hostPool = New-AvdHostPool

    # Create application group
    $appGroup = New-AvdApplicationGroup -HostPool $hostPool

    # Register application group to workspace
    Register-ApplicationGroupToWorkspace -Workspace $workspace -ApplicationGroup $appGroup

    # Configure RDP properties
    Set-HostPoolRdpProperties -HostPool $hostPool

    # Verify configuration
    Test-HostPoolConfiguration -Workspace $workspace -HostPool $hostPool -AppGroup $appGroup

    Write-Host ""
    Write-LogSuccess "Host Pool & Workspace Setup Complete!"
    Write-Host ""
    Write-LogInfo "Summary:"
    Write-Host "  Workspace: $($workspace.Name)"
    Write-Host "  Host Pool: $($hostPool.Name)"
    Write-Host "    Type: Pooled"
    Write-Host "    Load Balancer: $LoadBalancerType"
    Write-Host "    Max Sessions: $MaxSessionLimit"
    Write-Host "  Application Group: $($appGroup.Name)"
    Write-Host ""
    Write-LogInfo "Next steps:"
    Write-Host "  1. Create golden image (Step 05)"
    Write-Host "  2. Deploy session hosts (Step 06)"
    Write-Host "  3. Assign RBAC permissions (Step 08)"
    Write-Host ""
}

main
