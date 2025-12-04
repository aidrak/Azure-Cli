# Automates Configuration Validation for Azure Virtual Desktop (AVD)
#
# Purpose: Validates AVD configuration file before deployment to catch errors early
#
# Prerequisites:
# - PowerShell 5.0 or later
# - Configuration file (avd-config.ps1) must exist
#
# Permissions Required:
# - None (read-only validation)
#
# Usage:
# .\validate-config.ps1 -ConfigFile ".\config\avd-config.ps1"
#
# Example:
# .\validate-config.ps1 -ConfigFile ".\config\avd-config.ps1" -Verbose
#
# Notes:
# - This script is read-only and performs no changes
# - Validates configuration structure and common errors
# - Returns $true if valid, $false if errors found
# - Expected runtime: < 1 second

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true, HelpMessage="Path to configuration file")]
    [string]$ConfigFile
)

$ErrorActionPreference = "Stop"

# Color codes for output
$Colors = @{
    Header = "Cyan"
    Success = "Green"
    Warning = "Yellow"
    Error = "Red"
    Info = "Gray"
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

function Test-ConfigFileExists {
    Write-LogSection "Validating Configuration File"

    if (-not (Test-Path $ConfigFile)) {
        Write-LogError "Configuration file not found: $ConfigFile"
        Write-LogInfo "Please create configuration file from example:"
        Write-LogInfo "  cp config/avd-config.example.ps1 config/avd-config.ps1"
        return $false
    }

    Write-LogSuccess "Configuration file found: $ConfigFile"
    return $true
}

function Test-ConfigStructure {
    Write-LogSection "Validating Configuration Structure"

    # Load configuration
    $null = . $ConfigFile

    if (-not $Global:AVD_CONFIG) {
        Write-LogError "Configuration not loaded: \$Global:AVD_CONFIG not found"
        return $false
    }

    Write-LogSuccess "Configuration hashtable loaded successfully"

    # Validate required root properties
    $requiredRootProps = @("SubscriptionId", "TenantId", "Location", "ResourceGroup", "Environment")
    foreach ($prop in $requiredRootProps) {
        if (-not $Global:AVD_CONFIG.ContainsKey($prop)) {
            Write-LogError "Missing required property: $prop"
            return $false
        }
        Write-LogSuccess "Property present: $prop"
    }

    # Validate required nested sections
    $requiredSections = @("Network", "Storage", "Groups", "HostPool", "Image", "SessionHosts", "Scaling", "Tags")
    foreach ($section in $requiredSections) {
        if (-not $Global:AVD_CONFIG.ContainsKey($section)) {
            Write-LogError "Missing required section: $section"
            return $false
        }
        Write-LogSuccess "Section present: $section"
    }

    return $true
}

function Test-ConfigValues {
    Write-LogSection "Validating Configuration Values"

    $errors = @()
    $warnings = @()

    # Validate global settings
    if ([string]::IsNullOrWhiteSpace($Global:AVD_CONFIG.SubscriptionId) -or $Global:AVD_CONFIG.SubscriptionId -eq "00000000-0000-0000-0000-000000000000") {
        $errors += "SubscriptionId must be set (current: $($Global:AVD_CONFIG.SubscriptionId))"
    } else {
        Write-LogSuccess "SubscriptionId is set"
    }

    if ([string]::IsNullOrWhiteSpace($Global:AVD_CONFIG.TenantId) -or $Global:AVD_CONFIG.TenantId -eq "00000000-0000-0000-0000-000000000000") {
        $errors += "TenantId must be set (current: $($Global:AVD_CONFIG.TenantId))"
    } else {
        Write-LogSuccess "TenantId is set"
    }

    if ([string]::IsNullOrWhiteSpace($Global:AVD_CONFIG.ResourceGroup)) {
        $errors += "ResourceGroup must be set"
    } else {
        Write-LogSuccess "ResourceGroup is set: $($Global:AVD_CONFIG.ResourceGroup)"
    }

    if ([string]::IsNullOrWhiteSpace($Global:AVD_CONFIG.Location)) {
        $errors += "Location must be set"
    } else {
        Write-LogSuccess "Location is set: $($Global:AVD_CONFIG.Location)"
    }

    # Validate environment value
    if ($Global:AVD_CONFIG.Environment -notin @("prod", "dev", "test")) {
        $errors += "Environment must be 'prod', 'dev', or 'test' (current: $($Global:AVD_CONFIG.Environment))"
    } else {
        Write-LogSuccess "Environment is valid: $($Global:AVD_CONFIG.Environment)"
    }

    # Validate network configuration
    if ($Global:AVD_CONFIG.Network.VNetPrefix -notmatch '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/\d{1,2}$') {
        $errors += "Invalid VNet CIDR: $($Global:AVD_CONFIG.Network.VNetPrefix)"
    } else {
        Write-LogSuccess "VNet CIDR valid: $($Global:AVD_CONFIG.Network.VNetPrefix)"
    }

    # Validate subnet CIDRs
    $subnets = @("SessionHosts", "PrivateEndpoints", "FileServer")
    foreach ($subnet in $subnets) {
        $prefix = $Global:AVD_CONFIG.Network.Subnets[$subnet].Prefix
        if ($prefix -notmatch '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/\d{1,2}$') {
            $errors += "Invalid subnet CIDR for $subnet : $prefix"
        } else {
            Write-LogSuccess "Subnet CIDR valid for $subnet : $prefix"
        }
    }

    # Validate VM sizes (common Azure VM sizes)
    $validVMSizes = @("Standard_D2s_v5", "Standard_D4s_v5", "Standard_D8s_v5", "Standard_D2s_v4", "Standard_D4s_v4", "Standard_D8s_v4")
    if ($Global:AVD_CONFIG.SessionHosts.VMSize -notin $validVMSizes) {
        $warnings += "VM size may be invalid: $($Global:AVD_CONFIG.SessionHosts.VMSize) (common sizes: D2s_v5, D4s_v5, D8s_v5)"
    } else {
        Write-LogSuccess "Session Host VM size valid: $($Global:AVD_CONFIG.SessionHosts.VMSize)"
    }

    if ($Global:AVD_CONFIG.Image.VMSize -notin $validVMSizes) {
        $warnings += "Golden Image VM size may be invalid: $($Global:AVD_CONFIG.Image.VMSize)"
    } else {
        Write-LogSuccess "Golden Image VM size valid: $($Global:AVD_CONFIG.Image.VMSize)"
    }

    # Validate VM count
    if ($Global:AVD_CONFIG.SessionHosts.VMCount -lt 1 -or $Global:AVD_CONFIG.SessionHosts.VMCount -gt 500) {
        $errors += "SessionHosts.VMCount must be between 1 and 500 (current: $($Global:AVD_CONFIG.SessionHosts.VMCount))"
    } else {
        Write-LogSuccess "Session Host VM count valid: $($Global:AVD_CONFIG.SessionHosts.VMCount)"
    }

    # Validate max sessions
    if ($Global:AVD_CONFIG.HostPool.MaxSessions -lt 1 -or $Global:AVD_CONFIG.HostPool.MaxSessions -gt 100) {
        $warnings += "HostPool.MaxSessions should be between 1 and 100 (current: $($Global:AVD_CONFIG.HostPool.MaxSessions))"
    } else {
        Write-LogSuccess "Host Pool max sessions valid: $($Global:AVD_CONFIG.HostPool.MaxSessions)"
    }

    # Validate load balancer type
    if ($Global:AVD_CONFIG.HostPool.LoadBalancer -notin @("BreadthFirst", "DepthFirst")) {
        $errors += "LoadBalancer must be 'BreadthFirst' or 'DepthFirst' (current: $($Global:AVD_CONFIG.HostPool.LoadBalancer))"
    } else {
        Write-LogSuccess "Load balancer type valid: $($Global:AVD_CONFIG.HostPool.LoadBalancer)"
    }

    # Display warnings
    if ($warnings.Count -gt 0) {
        Write-Host ""
        Write-LogSection "Configuration Warnings"
        foreach ($warning in $warnings) {
            Write-LogWarning $warning
        }
    }

    # Display errors
    if ($errors.Count -gt 0) {
        Write-Host ""
        Write-LogSection "Configuration Errors"
        foreach ($error in $errors) {
            Write-LogError $error
        }
        return $false
    }

    return $true
}

# ============================================================================
# Main Execution
# ============================================================================

Write-LogSection "AVD Configuration Validation"
Write-LogInfo "Validating configuration file: $ConfigFile"
Write-Host ""

$valid = $true

# Test file exists
if (-not (Test-ConfigFileExists)) {
    exit 1
}

# Test structure
if (-not (Test-ConfigStructure)) {
    $valid = $false
}

# Test values
if (-not (Test-ConfigValues)) {
    $valid = $false
}

# Summary
Write-Host ""
Write-LogSection "Validation Summary"

if ($valid) {
    Write-LogSuccess "Configuration validation PASSED"
    Write-LogInfo "Ready to deploy. All configuration values are valid."
    exit 0
} else {
    Write-LogError "Configuration validation FAILED"
    Write-LogInfo "Please fix the errors above and try again."
    exit 1
}
