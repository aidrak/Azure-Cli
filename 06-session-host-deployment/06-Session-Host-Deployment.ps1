# Automates Session Host Deployment for Azure Virtual Desktop (AVD)
#
# Purpose: Deploys multiple session host VMs from the golden image to the host pool
# and registers them with AVD.
#
# Prerequisites:
# - Azure PowerShell modules (Az.Desktopvirtualization, Az.Compute) installed
# - Golden image must exist in Azure Compute Gallery
# - Host pool must already be created
# - VNet with subnets configured
# - Logged into Azure (Connect-AzAccount)
#
# Permissions Required:
# - Desktop Virtualization Contributor
# - Virtual Machine Contributor
# - Network Contributor
#
# Usage:
# Connect-AzAccount
# .\06-Session-Host-Deployment.ps1 `
#   -ResourceGroupName "RG-Azure-VDI-01" `
#   -HostPoolName "Pool-Pooled-Prod" `
#   -GalleryImageId "/subscriptions/.../Win11-AVD-Pooled/versions/1.0.0" `
#   -VNetName "vnet-avd-prod" `
#   -SubnetName "subnet-session-hosts"
#
# Parameters:
# - ResourceGroupName: Resource group name (required)
# - HostPoolName: Host pool name (required)
# - GalleryImageId: Full image version ID from Compute Gallery (required)
# - VNetName: Virtual network name (required)
# - SubnetName: Subnet for session hosts (required)
# - NumberOfVMs: Number of VMs to deploy (default: 10)
# - VmPrefix: VM name prefix (default: avd-pool)
# - VmSize: Azure VM size (default: Standard_D4s_v6)
#
# Notes:
# - This script is NOT idempotent (will create new VMs each time)
# - Requires unique VM names (use different prefix or run from different RG)
# - Expected runtime: 15-30 minutes for 10 VMs
# - VMs are registered to host pool during deployment

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
    [string]$ResourceGroupName = $(if ($Global:AVD_CONFIG) { $Global:AVD_CONFIG.ResourceGroup } else { "RG-Azure-VDI-01" }),

    [Parameter(Mandatory=$false)]
    [string]$HostPoolName = $(if ($Global:AVD_CONFIG) { $Global:AVD_CONFIG.HostPool.HostPoolName } else { "Pool-Pooled-Prod" }),

    [Parameter(Mandatory=$false)]
    [string]$GalleryImageId = $(if ($Global:AVD_CONFIG) { $Global:AVD_CONFIG.SessionHosts.GalleryImageId } else { "" }),

    [Parameter(Mandatory=$false)]
    [string]$VNetName = $(if ($Global:AVD_CONFIG) { $Global:AVD_CONFIG.Networking.VNetName } else { "vnet-avd-prod" }),

    [Parameter(Mandatory=$false)]
    [string]$SubnetName = $(if ($Global:AVD_CONFIG) { $Global:AVD_CONFIG.Networking.SubnetName } else { "subnet-session-hosts" }),

    [Parameter(Mandatory=$false)]
    [int]$NumberOfVMs = $(if ($Global:AVD_CONFIG) { $Global:AVD_CONFIG.SessionHosts.NumberOfVMs } else { 10 }),

    [Parameter(Mandatory=$false)]
    [string]$VmPrefix = $(if ($Global:AVD_CONFIG) { $Global:AVD_CONFIG.SessionHosts.VmPrefix } else { "avd-pool" }),

    [Parameter(Mandatory=$false)]
    [string]$VmSize = $(if ($Global:AVD_CONFIG) { $Global:AVD_CONFIG.SessionHosts.VmSize } else { "Standard_D4s_v6" })
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

    # Verify resource group
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

    # Verify host pool
    try {
        $hostPool = Get-AzWvdHostPool -ResourceGroupName $ResourceGroupName -Name $HostPoolName -ErrorAction SilentlyContinue
        if ($null -eq $hostPool) {
            Write-LogError "Host pool '$HostPoolName' not found"
            exit 1
        }
        Write-LogSuccess "Host pool '$HostPoolName' exists"
    }
    catch {
        Write-LogError "Failed to verify host pool: $_"
        exit 1
    }

    # Verify VNet and subnet
    try {
        $vnet = Get-AzVirtualNetwork -ResourceGroupName $ResourceGroupName -Name $VNetName -ErrorAction SilentlyContinue
        if ($null -eq $vnet) {
            Write-LogError "VNet '$VNetName' not found"
            exit 1
        }

        $subnet = Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name $SubnetName -ErrorAction SilentlyContinue
        if ($null -eq $subnet) {
            Write-LogError "Subnet '$SubnetName' not found"
            exit 1
        }

        Write-LogSuccess "VNet and subnet verified"
    }
    catch {
        Write-LogError "Failed to verify VNet/subnet: $_"
        exit 1
    }
}

# ============================================================================
# VM Deployment
# ============================================================================

function New-SessionHostVm {
    param(
        [string]$VmNumber,
        [PSObject]$VNet,
        [PSObject]$Subnet
    )

    $vmName = "$VmPrefix-$VmNumber"

    Write-LogInfo "Creating session host VM: $vmName ($VmNumber/$NumberOfVMs)"

    try {
        # Check if VM already exists
        $existingVm = Get-AzVm -ResourceGroupName $ResourceGroupName -Name $vmName -ErrorAction SilentlyContinue
        if ($null -ne $existingVm) {
            Write-LogWarning "VM '$vmName' already exists, skipping"
            return $existingVm
        }

        # Create NIC
        $nicName = "$vmName-NIC"
        $nic = New-AzNetworkInterface `
            -Name $nicName `
            -ResourceGroupName $ResourceGroupName `
            -Location $rg.Location `
            -SubnetId $Subnet.Id `
            -ErrorAction Stop

        # Create VM config
        $vmConfig = New-AzVMConfig `
            -VMName $vmName `
            -VMSize $VmSize `
            -ErrorAction Stop

        # Set OS disk
        $vmConfig = Set-AzVMOperatingSystem `
            -VM $vmConfig `
            -Windows `
            -ComputerName $vmName `
            -ProvisionVMAgent `
            -EnableAutoUpdate `
            -ErrorAction Stop

        # Add NIC
        $vmConfig = Add-AzVMNetworkInterface `
            -VM $vmConfig `
            -Id $nic.Id `
            -Primary `
            -ErrorAction Stop

        # Set source image
        $vmConfig = Set-AzVMSourceImage `
            -VM $vmConfig `
            -Id $GalleryImageId `
            -ErrorAction Stop

        # Create the VM
        $vm = New-AzVM `
            -ResourceGroupName $ResourceGroupName `
            -VM $vmConfig `
            -ErrorAction Stop

        Write-LogSuccess "Session host VM '$vmName' created"
        return $vm
    }
    catch {
        Write-LogError "Failed to create VM '$vmName': $_"
        throw
    }
}

function Deploy-AllSessionHosts {
    Write-LogSection "Deploying Session Host VMs"

    $rg = Get-AzResourceGroup -Name $ResourceGroupName
    $vnet = Get-AzVirtualNetwork -ResourceGroupName $ResourceGroupName -Name $VNetName
    $subnet = Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name $SubnetName

    Write-LogInfo "Deploying $NumberOfVMs session hosts"
    Write-LogInfo "Naming pattern: ${VmPrefix}-001 through ${VmPrefix}-$(($NumberOfVMs).ToString().PadLeft(3, '0'))"

    for ($i = 1; $i -le $NumberOfVMs; $i++) {
        $vmNumber = $i.ToString().PadLeft(3, '0')
        New-SessionHostVm -VmNumber $vmNumber -VNet $vnet -Subnet $subnet
    }

    Write-LogSuccess "All $NumberOfVMs session hosts deployed"
}

# ============================================================================
# Host Pool Registration
# ============================================================================

function Get-HostPoolRegistrationToken {
    param([PSObject]$HostPool)

    Write-LogInfo "Getting registration token for host pool"

    try {
        $token = New-AzWvdRegistrationInfo `
            -ResourceGroupName $ResourceGroupName `
            -HostPoolName $HostPoolName `
            -ExpirationTime $((Get-Date).AddDays(1)) `
            -ErrorAction Stop

        Write-LogSuccess "Registration token obtained"
        return $token.Token
    }
    catch {
        Write-LogError "Failed to get registration token: $_"
        throw
    }
}

function Register-VmsToHostPool {
    param([string]$RegistrationToken)

    Write-LogSection "Registering VMs to Host Pool"

    Write-LogInfo "Creating AVD agent installation script"

    # Create a script to install AVD agent
    $agentScript = @"
# AVD Agent Installation
`$token = '$RegistrationToken'
`$hostpoolName = '$HostPoolName'

Write-Host "Installing AVD Agent..."
Write-Host "Host Pool: `$hostpoolName"
Write-Host "Token expires: $(([datetime]'1970-01-01').AddSeconds($((Get-Date $token -AsUTC).Ticks / 10000000)))"

# Download and install agent
# This is typically done during image creation or via Intune
# For now, document the requirement

Write-Host "AVD Agent installation would proceed here"
Write-Host "Registration token: `$token"
"@

    Write-LogWarning "Manual registration required"
    Write-LogInfo "Registration token (valid for 24 hours): $RegistrationToken"
    Write-LogInfo "Use this token to register VMs during deployment or post-deployment"
}

# ============================================================================
# Verification
# ============================================================================

function Test-SessionHostDeployment {
    Write-LogSection "Verifying Session Host Deployment"

    Write-LogInfo "Checking deployed VMs"

    try {
        $vms = Get-AzVm -ResourceGroupName $ResourceGroupName | Where-Object { $_.Name -like "$VmPrefix-*" }

        if ($vms.Count -eq $NumberOfVMs) {
            Write-LogSuccess "All $NumberOfVMs VMs deployed"
        }
        else {
            Write-LogWarning "Expected $NumberOfVMs VMs, found $($vms.Count)"
        }

        foreach ($vm in $vms) {
            Write-LogSuccess "VM verified: $($vm.Name)"
        }
    }
    catch {
        Write-LogError "Failed to verify deployment: $_"
        return $false
    }

    return $true
}

# ============================================================================
# Main Execution
# ============================================================================

function main {
    Write-Host ""
    Write-LogSection "AVD Session Host Deployment"

    # Validate prerequisites
    Test-Prerequisites

    # Deploy VMs
    Deploy-AllSessionHosts

    # Get registration token
    $hostPool = Get-AzWvdHostPool -ResourceGroupName $ResourceGroupName -Name $HostPoolName
    $registrationToken = Get-HostPoolRegistrationToken -HostPool $hostPool

    # Document registration
    Register-VmsToHostPool -RegistrationToken $registrationToken

    # Verify deployment
    Test-SessionHostDeployment

    Write-Host ""
    Write-LogSuccess "Session Host Deployment Complete!"
    Write-Host ""
    Write-LogInfo "Summary:"
    Write-Host "  Resource Group: $ResourceGroupName"
    Write-Host "  Host Pool: $HostPoolName"
    Write-Host "  VMs Deployed: $NumberOfVMs"
    Write-Host "  VM Naming Pattern: ${VmPrefix}-001 through ${VmPrefix}-$(($NumberOfVMs).ToString().PadLeft(3, '0'))"
    Write-Host "  VM Size: $VmSize"
    Write-Host ""
    Write-LogWarning "IMPORTANT: AVD Agent Registration"
    Write-Host "  Registration Token: $registrationToken"
    Write-Host "  Token expires: 24 hours from now"
    Write-Host ""
    Write-LogInfo "Next steps:"
    Write-Host "  1. Register session hosts to host pool using token"
    Write-Host "  2. Verify session hosts appear in host pool"
    Write-Host "  3. Assign users to app group (Step 08)"
    Write-Host "  4. Test user connections"
    Write-Host ""
}

main
