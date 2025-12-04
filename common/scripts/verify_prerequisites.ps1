# Verifies Prerequisites for Azure Virtual Desktop (AVD) Deployment
#
# Purpose: Validates that all required tools, permissions, and resources are
# in place before beginning AVD deployment.
#
# Prerequisites:
# - PowerShell 7+ (or PowerShell 5.1 with .NET 4.7.2+)
# - Internet connection
# - Logged into Azure (Connect-AzAccount)
#
# Usage:
# .\verify_prerequisites.ps1

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$Colors = @{
    Header = "Cyan"
    Success = "Green"
    Warning = "Yellow"
    Error = "Red"
    Info = "Yellow"
}

$checksPerformed = 0
$checksPassed = 0
$checksFailed = 0

function Write-LogSection {
    param([string]$Message)
    Write-Host ""
    Write-Host "=== $Message ===" -ForegroundColor $Colors.Header
}

function Write-LogSuccess {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor $Colors.Success
    $script:checksPassed++
}

function Write-LogError {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor $Colors.Error
    $script:checksFailed++
}

function Write-LogWarning {
    param([string]$Message)
    Write-Host "⚠ $Message" -ForegroundColor $Colors.Warning
}

function Write-LogInfo {
    param([string]$Message)
    Write-Host "ℹ $Message" -ForegroundColor $Colors.Info
}

function Test-PowerShell {
    Write-LogSection "Checking PowerShell Version"

    $script:checksPerformed++
    $psVersion = $PSVersionTable.PSVersion

    if ($psVersion.Major -ge 7) {
        Write-LogSuccess "PowerShell $psVersion (Recommended: PS 7+)"
    }
    elseif ($psVersion.Major -eq 5 -and $psVersion.Minor -ge 1) {
        Write-LogWarning "PowerShell $psVersion (PS 5.1 supported but PS 7+ recommended)"
        $script:checksPassed++
    }
    else {
        Write-LogError "PowerShell $psVersion (Minimum: PS 5.1 required)"
    }
}

function Test-AzModules {
    Write-LogSection "Checking Azure PowerShell Modules"

    $requiredModules = @(
        "Az.Accounts"
        "Az.Compute"
        "Az.DesktopVirtualization"
        "Az.Network"
        "Az.Storage"
    )

    foreach ($module in $requiredModules) {
        $script:checksPerformed++
        $installedModule = Get-Module -ListAvailable -Name $module | Sort-Object Version -Descending | Select-Object -First 1

        if ($installedModule) {
            Write-LogSuccess "$module ($($installedModule.Version))"
        }
        else {
            Write-LogError "$module (not installed)"
            Write-LogInfo "Install with: Install-Module -Name $module -Force"
        }
    }
}

function Test-MgModules {
    Write-LogSection "Checking Microsoft Graph Modules"

    $script:checksPerformed++
    $mgModule = Get-Module -ListAvailable -Name "Microsoft.Graph" | Sort-Object Version -Descending | Select-Object -First 1

    if ($mgModule) {
        Write-LogSuccess "Microsoft.Graph ($($mgModule.Version))"
    }
    else {
        Write-LogWarning "Microsoft.Graph (optional but recommended)"
        Write-LogInfo "Install with: Install-Module -Name Microsoft.Graph -Force"
    }
}

function Test-AzureContext {
    Write-LogSection "Checking Azure Login"

    $script:checksPerformed++
    try {
        $context = Get-AzContext
        if ($context) {
            Write-LogSuccess "Logged into Azure"
            Write-LogInfo "Subscription: $($context.Subscription.Name)"
            Write-LogInfo "Account: $($context.Account.Id)"
        }
        else {
            Write-LogError "Not logged into Azure"
            Write-LogInfo "Login with: Connect-AzAccount"
        }
    }
    catch {
        Write-LogError "Error checking Azure context: $_"
    }
}

function Test-AzurePermissions {
    Write-LogSection "Checking Azure Permissions"

    $script:checksPerformed++
    try {
        $context = Get-AzContext
        if ($context) {
            Write-LogSuccess "Azure permissions accessible"
        }
    }
    catch {
        Write-LogError "Cannot access Azure permissions: $_"
    }
}

function Test-InternetConnectivity {
    Write-LogSection "Checking Internet Connectivity"

    $script:checksPerformed++
    try {
        $testUrl = "https://aka.ms/fslogix-latest"
        $response = Invoke-WebRequest -Uri $testUrl -Method Head -TimeoutSec 5 -ErrorAction SilentlyContinue
        if ($response.StatusCode -eq 200) {
            Write-LogSuccess "Internet connectivity verified"
        }
        else {
            Write-LogWarning "Internet connectivity test inconclusive"
        }
    }
    catch {
        Write-LogWarning "Could not verify internet connectivity: $_"
    }
}

function main {
    Write-Host ""
    Write-LogSection "AVD Deployment Prerequisites Check"

    Test-PowerShell
    Test-AzModules
    Test-MgModules
    Test-AzureContext
    Test-AzurePermissions
    Test-InternetConnectivity

    # Summary
    Write-LogSection "Summary"

    Write-Host ""
    Write-LogSuccess "Passed: $checksPassed"
    if ($checksFailed -gt 0) {
        Write-LogError "Failed: $checksFailed"
    }
    Write-Host ""

    if ($checksFailed -eq 0) {
        Write-LogSuccess "All prerequisites verified! Ready to deploy AVD."
    }
    else {
        Write-LogWarning "Some prerequisites missing or invalid. Please review above."
    }

    Write-Host ""
}

main
