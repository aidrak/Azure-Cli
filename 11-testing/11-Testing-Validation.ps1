# Validates Azure Virtual Desktop (AVD) Deployment
#
# Purpose: Comprehensive validation of entire AVD infrastructure and configuration
#
# Prerequisites:
# - All previous steps must be completed
# - Logged into Azure (Connect-AzAccount)
#
# Usage:
# Connect-AzAccount
# .\11-Testing-Validation.ps1 -ResourceGroupName "RG-Azure-VDI-01" -HostPoolName "Pool-Pooled-Prod"

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
    [string]$WorkspaceName = $(if ($Global:AVD_CONFIG) { $Global:AVD_CONFIG.Workspace.WorkspaceName } else { "AVD-Workspace-Prod" }),

    [Parameter(Mandatory=$false)]
    [string]$StorageAccountName = $(if ($Global:AVD_CONFIG) { $Global:AVD_CONFIG.Storage.StorageAccountName } else { "" })
)

$ErrorActionPreference = "Stop"

$Colors = @{
    Header = "Cyan"
    Success = "Green"
    Warning = "Yellow"
    Error = "Red"
    Info = "Yellow"
}

$testResults = @()

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

function Test-ResourceGroup {
    Write-LogSection "Testing Resource Group"

    try {
        $rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
        if ($null -ne $rg) {
            Write-LogSuccess "Resource group exists"
            $script:testResults += "PASS"
            return $true
        }
        else {
            Write-LogError "Resource group not found"
            $script:testResults += "FAIL"
            return $false
        }
    }
    catch {
        Write-LogError "Error testing resource group: $_"
        $script:testResults += "FAIL"
        return $false
    }
}

function Test-HostPool {
    Write-LogSection "Testing Host Pool"

    try {
        $hp = Get-AzWvdHostPool -ResourceGroupName $ResourceGroupName -Name $HostPoolName -ErrorAction SilentlyContinue
        if ($null -ne $hp) {
            Write-LogSuccess "Host pool exists: $($hp.Name)"
            Write-LogInfo "Type: $($hp.HostPoolType)"
            Write-LogInfo "Max Session Limit: $($hp.MaxSessionLimit)"
            $script:testResults += "PASS"
            return $true
        }
        else {
            Write-LogError "Host pool not found"
            $script:testResults += "FAIL"
            return $false
        }
    }
    catch {
        Write-LogError "Error testing host pool: $_"
        $script:testResults += "FAIL"
        return $false
    }
}

function Test-SessionHosts {
    Write-LogSection "Testing Session Hosts"

    try {
        $hosts = Get-AzWvdSessionHost -ResourceGroupName $ResourceGroupName -HostPoolName $HostPoolName -ErrorAction SilentlyContinue

        if ($null -ne $hosts) {
            $count = $hosts | Measure-Object | Select-Object -ExpandProperty Count
            Write-LogSuccess "Found $count session host(s)"

            $availableCount = $hosts | Where-Object { $_.Status -eq "Available" } | Measure-Object | Select-Object -ExpandProperty Count
            Write-LogInfo "$availableCount available, $(($count - $availableCount)) unavailable"

            if ($availableCount -gt 0) {
                $script:testResults += "PASS"
            }
            else {
                Write-LogWarning "No available session hosts"
                $script:testResults += "WARN"
            }
            return $true
        }
        else {
            Write-LogWarning "No session hosts found"
            $script:testResults += "WARN"
            return $false
        }
    }
    catch {
        Write-LogError "Error testing session hosts: $_"
        $script:testResults += "FAIL"
        return $false
    }
}

function Test-Workspace {
    Write-LogSection "Testing Workspace"

    try {
        $ws = Get-AzWvdWorkspace -ResourceGroupName $ResourceGroupName -Name $WorkspaceName -ErrorAction SilentlyContinue

        if ($null -ne $ws) {
            Write-LogSuccess "Workspace exists: $($ws.Name)"
            $script:testResults += "PASS"
            return $true
        }
        else {
            Write-LogError "Workspace not found"
            $script:testResults += "FAIL"
            return $false
        }
    }
    catch {
        Write-LogError "Error testing workspace: $_"
        $script:testResults += "FAIL"
        return $false
    }
}

function Test-ApplicationGroup {
    Write-LogSection "Testing Application Group"

    try {
        $appGroups = Get-AzWvdApplicationGroup -ResourceGroupName $ResourceGroupName -HostPoolName $HostPoolName -ErrorAction SilentlyContinue

        if ($null -ne $appGroups) {
            $count = $appGroups | Measure-Object | Select-Object -ExpandProperty Count
            Write-LogSuccess "Found $count application group(s)"
            $script:testResults += "PASS"
            return $true
        }
        else {
            Write-LogWarning "No application groups found"
            $script:testResults += "WARN"
            return $false
        }
    }
    catch {
        Write-LogError "Error testing application groups: $_"
        $script:testResults += "FAIL"
        return $false
    }
}

function Test-Storage {
    Write-LogSection "Testing Storage"

    if ([string]::IsNullOrEmpty($StorageAccountName)) {
        Write-LogWarning "Storage account name not provided, skipping"
        return
    }

    try {
        $sa = Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName -ErrorAction SilentlyContinue

        if ($null -ne $sa) {
            Write-LogSuccess "Storage account exists: $($sa.StorageAccountName)"
            $script:testResults += "PASS"
            return $true
        }
        else {
            Write-LogError "Storage account not found"
            $script:testResults += "FAIL"
            return $false
        }
    }
    catch {
        Write-LogError "Error testing storage: $_"
        $script:testResults += "FAIL"
        return $false
    }
}

function main {
    Write-Host ""
    Write-LogSection "AVD Deployment Validation"

    Test-ResourceGroup
    Test-HostPool
    Test-SessionHosts
    Test-Workspace
    Test-ApplicationGroup
    Test-Storage

    # Summary
    Write-LogSection "Validation Summary"

    $passed = ($testResults | Where-Object { $_ -eq "PASS" }).Count
    $failed = ($testResults | Where-Object { $_ -eq "FAIL" }).Count
    $warned = ($testResults | Where-Object { $_ -eq "WARN" }).Count

    Write-Host ""
    Write-LogSuccess "Passed: $passed"
    if ($warned -gt 0) { Write-LogWarning "Warnings: $warned" }
    if ($failed -gt 0) { Write-LogError "Failed: $failed" }
    Write-Host ""

    if ($failed -eq 0) {
        Write-LogSuccess "Validation Complete - All critical components verified!"
    }
    else {
        Write-LogWarning "Validation Complete - Some issues found, review above"
    }
}

main
