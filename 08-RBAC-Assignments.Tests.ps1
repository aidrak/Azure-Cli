# Verification Script for RBAC Role Assignments
#
# Purpose: Validate that RBAC role assignments (08-RBAC-Assignments.ps1) were successful
#
# Prerequisites:
# - Must be run after running `08-RBAC-Assignments.ps1`
# - Requires User Access Administrator permission for RBAC checks
# - Requires Group.Read.All for Microsoft Graph
# - Already connected to Azure (Az) and Microsoft Graph
#
# Usage:
# .\08-RBAC-Assignments.Tests.ps1 -ResourceGroupName "RG-Azure-VDI-01" `
#   -StorageAccountName "fslogix37402" -FileShareName "fslogix-profiles" `
#   -ApplicationGroupName "AG-Desktop-Pooled"

[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory=$true)]
    [string]$StorageAccountName,

    [Parameter(Mandatory=$true)]
    [string]$FileShareName,

    [Parameter(Mandatory=$true)]
    [string]$ApplicationGroupName,

    [Parameter(Mandatory=$false)]
    [string]$StandardUsersGroupName = "AVD-Users-Standard",

    [Parameter(Mandatory=$false)]
    [string]$AdminUsersGroupName = "AVD-Users-Admins"
)

$ErrorActionPreference = "Stop"
$testResults = @()

function Test-StandardUserStoragePermissions {
    Write-Host "`n[Test 1] Verifying Standard User Storage Permissions..." -ForegroundColor Yellow
    try {
        $standardGroup = Get-MgGroup -Filter "displayName eq '$StandardUsersGroupName'" -ErrorAction Stop
        if (-not $standardGroup) {
            Write-Host "FAIL: User group '$StandardUsersGroupName' not found." -ForegroundColor Red
            $testResults += "FAIL"
            return
        }

        $storageAccount = Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName -ErrorAction Stop
        $fileShareResourceId = "$($storageAccount.Id)/fileServices/default/fileshares/$FileShareName"

        $assignment = Get-AzRoleAssignment `
            -ObjectId $standardGroup.Id `
            -Scope $fileShareResourceId `
            -RoleDefinitionName "Storage File Data SMB Share Contributor" -ErrorAction SilentlyContinue

        if ($assignment) {
            Write-Host "PASS: 'Storage File Data SMB Share Contributor' is assigned to '$StandardUsersGroupName'" -ForegroundColor Green
            $testResults += "PASS"
        } else {
            Write-Host "FAIL: 'Storage File Data SMB Share Contributor' is NOT assigned to '$StandardUsersGroupName'" -ForegroundColor Red
            $testResults += "FAIL"
        }
    }
    catch {
        Write-Host "FAIL: Error during verification. $($_.Exception.Message)" -ForegroundColor Red
        $testResults += "FAIL"
    }
}

function Test-AdminUserStoragePermissions {
    Write-Host "`n[Test 2] Verifying Admin User Storage Permissions (Elevated)..." -ForegroundColor Yellow
    try {
        $adminGroup = Get-MgGroup -Filter "displayName eq '$AdminUsersGroupName'" -ErrorAction Stop
        if (-not $adminGroup) {
            Write-Host "FAIL: Admin group '$AdminUsersGroupName' not found." -ForegroundColor Red
            $testResults += "FAIL"
            return
        }

        $storageAccount = Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName -ErrorAction Stop
        $fileShareResourceId = "$($storageAccount.Id)/fileServices/default/fileshares/$FileShareName"

        $assignment = Get-AzRoleAssignment `
            -ObjectId $adminGroup.Id `
            -Scope $fileShareResourceId `
            -RoleDefinitionName "Storage File Data SMB Share Elevated Contributor" -ErrorAction SilentlyContinue

        if ($assignment) {
            Write-Host "PASS: 'Storage File Data SMB Share Elevated Contributor' is assigned to '$AdminUsersGroupName'" -ForegroundColor Green
            $testResults += "PASS"
        } else {
            Write-Host "FAIL: 'Storage File Data SMB Share Elevated Contributor' is NOT assigned to '$AdminUsersGroupName'" -ForegroundColor Red
            $testResults += "FAIL"
        }
    }
    catch {
        Write-Host "FAIL: Error during verification. $($_.Exception.Message)" -ForegroundColor Red
        $testResults += "FAIL"
    }
}

function Test-StandardUserVmLoginPermissions {
    Write-Host "`n[Test 3] Verifying Standard User VM Login Permissions..." -ForegroundColor Yellow
    try {
        $standardGroup = Get-MgGroup -Filter "displayName eq '$StandardUsersGroupName'" -ErrorAction Stop
        if (-not $standardGroup) {
            Write-Host "FAIL: User group '$StandardUsersGroupName' not found." -ForegroundColor Red
            $testResults += "FAIL"
            return
        }

        $rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction Stop

        $assignment = Get-AzRoleAssignment `
            -ObjectId $standardGroup.Id `
            -Scope $rg.ResourceId `
            -RoleDefinitionName "Virtual Machine User Login" -ErrorAction SilentlyContinue

        if ($assignment) {
            Write-Host "PASS: 'Virtual Machine User Login' is assigned to '$StandardUsersGroupName'" -ForegroundColor Green
            $testResults += "PASS"
        } else {
            Write-Host "FAIL: 'Virtual Machine User Login' is NOT assigned to '$StandardUsersGroupName'" -ForegroundColor Red
            $testResults += "FAIL"
        }
    }
    catch {
        Write-Host "FAIL: Error during verification. $($_.Exception.Message)" -ForegroundColor Red
        $testResults += "FAIL"
    }
}

function Test-AdminUserVmLoginPermissions {
    Write-Host "`n[Test 4] Verifying Admin User VM Login Permissions..." -ForegroundColor Yellow
    try {
        $adminGroup = Get-MgGroup -Filter "displayName eq '$AdminUsersGroupName'" -ErrorAction Stop
        if (-not $adminGroup) {
            Write-Host "FAIL: Admin group '$AdminUsersGroupName' not found." -ForegroundColor Red
            $testResults += "FAIL"
            return
        }

        $rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction Stop

        $assignment = Get-AzRoleAssignment `
            -ObjectId $adminGroup.Id `
            -Scope $rg.ResourceId `
            -RoleDefinitionName "Virtual Machine Administrator Login" -ErrorAction SilentlyContinue

        if ($assignment) {
            Write-Host "PASS: 'Virtual Machine Administrator Login' is assigned to '$AdminUsersGroupName'" -ForegroundColor Green
            $testResults += "PASS"
        } else {
            Write-Host "FAIL: 'Virtual Machine Administrator Login' is NOT assigned to '$AdminUsersGroupName'" -ForegroundColor Red
            $testResults += "FAIL"
        }
    }
    catch {
        Write-Host "FAIL: Error during verification. $($_.Exception.Message)" -ForegroundColor Red
        $testResults += "FAIL"
    }
}

function Test-AdminUserPowerManagementPermissions {
    Write-Host "`n[Test 5] Verifying Admin User Power Management Permissions (Optional)..." -ForegroundColor Yellow
    try {
        $adminGroup = Get-MgGroup -Filter "displayName eq '$AdminUsersGroupName'" -ErrorAction Stop
        if (-not $adminGroup) {
            Write-Host "WARN: Admin group '$AdminUsersGroupName' not found." -ForegroundColor Yellow
            $testResults += "WARN"
            return
        }

        $rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction Stop

        $assignment = Get-AzRoleAssignment `
            -ObjectId $adminGroup.Id `
            -Scope $rg.ResourceId `
            -RoleDefinitionName "Desktop Virtualization Power On Off Contributor" -ErrorAction SilentlyContinue

        if ($assignment) {
            Write-Host "PASS: 'Desktop Virtualization Power On Off Contributor' is assigned to '$AdminUsersGroupName'" -ForegroundColor Green
            $testResults += "PASS"
        } else {
            Write-Host "WARN: 'Desktop Virtualization Power On Off Contributor' is NOT assigned (optional feature)" -ForegroundColor Yellow
            $testResults += "WARN"
        }
    }
    catch {
        Write-Host "WARN: Error during verification. $($_.Exception.Message)" -ForegroundColor Yellow
        $testResults += "WARN"
    }
}

function Test-StandardUserApplicationGroupPermissions {
    Write-Host "`n[Test 6] Verifying Standard User Application Group Permissions..." -ForegroundColor Yellow
    try {
        $standardGroup = Get-MgGroup -Filter "displayName eq '$StandardUsersGroupName'" -ErrorAction Stop
        if (-not $standardGroup) {
            Write-Host "FAIL: User group '$StandardUsersGroupName' not found." -ForegroundColor Red
            $testResults += "FAIL"
            return
        }

        $appGroup = Get-AzWvdApplicationGroup -ResourceGroupName $ResourceGroupName -Name $ApplicationGroupName -ErrorAction Stop

        $assignment = Get-AzRoleAssignment `
            -ObjectId $standardGroup.Id `
            -Scope $appGroup.Id `
            -RoleDefinitionName "Desktop Virtualization User" -ErrorAction SilentlyContinue

        if ($assignment) {
            Write-Host "PASS: 'Desktop Virtualization User' is assigned to '$StandardUsersGroupName' on application group" -ForegroundColor Green
            $testResults += "PASS"
        } else {
            Write-Host "FAIL: 'Desktop Virtualization User' is NOT assigned to '$StandardUsersGroupName' on application group" -ForegroundColor Red
            $testResults += "FAIL"
        }
    }
    catch {
        Write-Host "FAIL: Error during verification. $($_.Exception.Message)" -ForegroundColor Red
        $testResults += "FAIL"
    }
}

function Test-AdminUserApplicationGroupPermissions {
    Write-Host "`n[Test 7] Verifying Admin User Application Group Permissions..." -ForegroundColor Yellow
    try {
        $adminGroup = Get-MgGroup -Filter "displayName eq '$AdminUsersGroupName'" -ErrorAction Stop
        if (-not $adminGroup) {
            Write-Host "FAIL: Admin group '$AdminUsersGroupName' not found." -ForegroundColor Red
            $testResults += "FAIL"
            return
        }

        $appGroup = Get-AzWvdApplicationGroup -ResourceGroupName $ResourceGroupName -Name $ApplicationGroupName -ErrorAction Stop

        $assignment = Get-AzRoleAssignment `
            -ObjectId $adminGroup.Id `
            -Scope $appGroup.Id `
            -RoleDefinitionName "Desktop Virtualization User" -ErrorAction SilentlyContinue

        if ($assignment) {
            Write-Host "PASS: 'Desktop Virtualization User' is assigned to '$AdminUsersGroupName' on application group" -ForegroundColor Green
            $testResults += "PASS"
        } else {
            Write-Host "FAIL: 'Desktop Virtualization User' is NOT assigned to '$AdminUsersGroupName' on application group" -ForegroundColor Red
            $testResults += "FAIL"
        }
    }
    catch {
        Write-Host "FAIL: Error during verification. $($_.Exception.Message)" -ForegroundColor Red
        $testResults += "FAIL"
    }
}

# --- Main Execution ---
Write-Host "Starting RBAC Role Assignments Verification..." -ForegroundColor Green

Test-StandardUserStoragePermissions
Test-AdminUserStoragePermissions
Test-StandardUserVmLoginPermissions
Test-AdminUserVmLoginPermissions
Test-AdminUserPowerManagementPermissions
Test-StandardUserApplicationGroupPermissions
Test-AdminUserApplicationGroupPermissions

# --- Summary ---
Write-Host "`n=== VERIFICATION SUMMARY ===" -ForegroundColor Cyan
$passCount = ($testResults | Where-Object { $_ -eq "PASS" }).Count
$failCount = ($testResults | Where-Object { $_ -eq "FAIL" }).Count
$warnCount = ($testResults | Where-Object { $_ -eq "WARN" }).Count
$totalTests = $testResults.Count

Write-Host "Total Tests: $totalTests" -ForegroundColor White
Write-Host "Passed: $passCount" -ForegroundColor Green
Write-Host "Failed: $failCount" -ForegroundColor $(if ($failCount -gt 0) { "Red" } else { "Green" })
Write-Host "Warnings: $warnCount" -ForegroundColor Yellow

if ($failCount -eq 0) {
    Write-Host "`nAll critical RBAC assignments verified successfully!" -ForegroundColor Green
} else {
    Write-Host "`nSome RBAC assignments are missing. Please run 08-RBAC-Assignments.ps1 to configure them." -ForegroundColor Red
}
