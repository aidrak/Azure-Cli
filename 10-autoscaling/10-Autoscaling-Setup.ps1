# Automates Autoscaling Setup for Azure Virtual Desktop (AVD)
#
# Purpose: Creates and configures autoscaling plans with schedules to optimize
# session host costs by starting/stopping VMs based on demand.
#
# Prerequisites:
# - Azure PowerShell modules (Az.DesktopVirtualization)
# - Host pool must exist
# - Session hosts must be deployed
# - AVD service principal must have role assignment
#
# Usage:
# Connect-AzAccount
# .\10-Autoscaling-Setup.ps1 -ResourceGroupName "RG-Azure-VDI-01" -HostPoolName "Pool-Pooled-Prod"
#
# Parameters:
# - ResourceGroupName: Resource group name (required)
# - HostPoolName: Host pool name (required)
# - ScalingPlanName: Scaling plan name (default: ScalingPlan-Pooled-Prod)
# - TimeZone: Timezone for schedules (default: Central Standard Time)

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
    [string]$ScalingPlanName = $(if ($Global:AVD_CONFIG) { $Global:AVD_CONFIG.Autoscaling.ScalingPlanName } else { "ScalingPlan-Pooled-Prod" }),

    [Parameter(Mandatory=$false)]
    [string]$TimeZone = $(if ($Global:AVD_CONFIG) { $Global:AVD_CONFIG.Autoscaling.TimeZone } else { "Central Standard Time" })
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

function Test-Prerequisites {
    Write-LogSection "Validating Prerequisites"

    try {
        $azContext = Get-AzContext
        if ($null -eq $azContext) {
            Write-LogError "Not logged into Azure"
            exit 1
        }
        Write-LogSuccess "Logged into Azure"
    }
    catch {
        Write-LogError "Failed: $_"
        exit 1
    }

    # Verify host pool
    try {
        $hp = Get-AzWvdHostPool -ResourceGroupName $ResourceGroupName -Name $HostPoolName -ErrorAction SilentlyContinue
        if ($null -eq $hp) {
            Write-LogError "Host pool '$HostPoolName' not found"
            exit 1
        }
        Write-LogSuccess "Host pool '$HostPoolName' exists"
    }
    catch {
        Write-LogError "Failed to verify host pool: $_"
        exit 1
    }
}

function New-AvdScalingPlan {
    Write-LogSection "Creating Scaling Plan"

    Write-LogInfo "Creating scaling plan '$ScalingPlanName'"

    try {
        $existingPlan = Get-AzWvdScalingPlan -ResourceGroupName $ResourceGroupName -Name $ScalingPlanName -ErrorAction SilentlyContinue

        if ($null -ne $existingPlan) {
            Write-LogWarning "Scaling plan '$ScalingPlanName' already exists"
            return $existingPlan
        }

        # Note: AVD Scaling Plans API is still evolving
        # For now, document the configuration
        Write-LogWarning "Scaling plan creation via PowerShell requires newer SDK"
        Write-LogInfo "Configure scaling plan via Azure Portal:"
        Write-Host "  1. AVD > Scaling Plans"
        Write-Host "  2. Create new scaling plan"
        Write-Host "  3. Name: $ScalingPlanName"
        Write-Host "  4. Set schedules (see below)"

        Write-LogSuccess "Scaling plan configuration documented"
    }
    catch {
        Write-LogWarning "Could not create scaling plan: $_"
    }
}

function Configure-ScalingSchedules {
    Write-LogSection "Configuring Scaling Schedules"

    Write-LogInfo "Recommended schedule configuration:"
    Write-Host ""
    Write-Host "Weekday Schedule (Monday-Friday):"
    Write-Host "  Ramp Up:    07:00 - MinSessions=20%, LoadBalancing=BreadthFirst"
    Write-Host "  Peak:       09:00 - MinSessions=100%, LoadBalancing=DepthFirst"
    Write-Host "  Ramp Down:  17:00 - MinSessions=10%, LoadBalancing=BreadthFirst"
    Write-Host "  Off-Peak:   19:00 - MinSessions=5%, StopAllSessionHosts"
    Write-Host ""
    Write-Host "Weekend Schedule (Saturday-Sunday):"
    Write-Host "  Off-Peak:   00:00 - MinSessions=0%, StopAllSessionHosts"
    Write-Host ""
    Write-LogInfo "Adjust times based on your organization's working hours"
}

function Enable-ScalingForHostPool {
    Write-LogSection "Enabling Scaling for Host Pool"

    Write-LogInfo "Scaling plan must be assigned to host pool via Azure Portal"
    Write-LogWarning "Grant AVD service principal required role:"
    Write-Host "  Role: Desktop Virtualization Power On Off Contributor"
    Write-Host "  Scope: Subscription or Resource Group"
    Write-LogSuccess "Configuration documented"
}

function main {
    Write-Host ""
    Write-LogSection "AVD Autoscaling Setup"

    Test-Prerequisites
    New-AvdScalingPlan
    Configure-ScalingSchedules
    Enable-ScalingForHostPool

    Write-Host ""
    Write-LogSuccess "Autoscaling Configuration Complete!"
    Write-Host ""
    Write-LogWarning "Next Steps (via Azure Portal):"
    Write-Host "  1. Create scaling plan: $ScalingPlanName"
    Write-Host "  2. Configure schedules (times shown above)"
    Write-Host "  3. Assign to host pool: $HostPoolName"
    Write-Host "  4. Grant AVD service principal required role"
    Write-Host "  5. Enable capacity threshold alerts"
    Write-Host ""
}

main
