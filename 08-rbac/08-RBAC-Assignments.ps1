# Automates RBAC Role Assignments for Azure Virtual Desktop (AVD)
#
# Purpose: Assign necessary RBAC roles for users to access AVD resources and FSLogix profiles
#
# Prerequisites:
# - Entra ID user groups created (Guide 03):
#   - AVD-Users-Standard (standard users)
#   - AVD-Users-Admins (admin users)
# - FSLogix storage account and file share created (Guide 02)
# - Host pools and application groups created (Guide 04)
# - Resource group RG-Azure-VDI-01 exists
# - Already connected to Azure (Az) and Microsoft Graph
#
# Permissions required:
# - User Access Administrator (for RBAC assignments)
# - Group.Read.All (for Microsoft Graph)
#
# Usage:
# .\08-RBAC-Assignments.ps1 -ResourceGroupName "RG-Azure-VDI-01" `
#   -StorageAccountName "fslogix37402" -FileShareName "fslogix-profiles" `
#   -ApplicationGroupName "AG-Desktop-Pooled"

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
    [string]$StorageAccountName = $(if ($Global:AVD_CONFIG) { $Global:AVD_CONFIG.Storage.StorageAccountName } else { "" }),

    [Parameter(Mandatory=$false)]
    [string]$FileShareName = $(if ($Global:AVD_CONFIG) { $Global:AVD_CONFIG.Storage.FileShareName } else { "fslogix-profiles" }),

    [Parameter(Mandatory=$false)]
    [string]$ApplicationGroupName = $(if ($Global:AVD_CONFIG) { $Global:AVD_CONFIG.ApplicationGroup.ApplicationGroupName } else { "AG-Desktop-Pooled" }),

    [Parameter(Mandatory=$false)]
    [string]$StandardUsersGroupName = $(if ($Global:AVD_CONFIG) { $Global:AVD_CONFIG.EntraGroups.StandardUsersGroupName } else { "AVD-Users-Standard" }),

    [Parameter(Mandatory=$false)]
    [string]$AdminUsersGroupName = $(if ($Global:AVD_CONFIG) { $Global:AVD_CONFIG.EntraGroups.AdminUsersGroupName } else { "AVD-Users-Admins" }),

    [Parameter(Mandatory=$false)]
    [switch]$IncludePowerManagement
)

$ErrorActionPreference = "Stop"

function Get-StorageAccountAndFileShare {
    Write-Host "`n=== Retrieving Storage Account and File Share Details ===" -ForegroundColor Blue
    try {
        Write-Host "Getting storage account '$StorageAccountName' in resource group '$ResourceGroupName'..." -ForegroundColor Yellow
        $storageAccount = Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName -ErrorAction Stop
        if (-not $storageAccount) {
            throw "Storage account '$StorageAccountName' not found!"
        }
        Write-Host "Found storage account: $($storageAccount.StorageAccountName)" -ForegroundColor Green

        $fileShareResourceId = "$($storageAccount.Id)/fileServices/default/fileshares/$FileShareName"
        Write-Host "File share resource ID: $fileShareResourceId" -ForegroundColor Gray

        return @{
            StorageAccount = $storageAccount
            FileShareResourceId = $fileShareResourceId
        }
    }
    catch {
        Write-Error "Failed to retrieve storage account and file share details. Error: $($_.Exception.Message)"
        exit 1
    }
}

function Assign-StandardUserStoragePermissions {
    param(
        [string]$FileShareResourceId
    )

    Write-Host "`n=== Assigning Standard User Storage Permissions ===" -ForegroundColor Blue
    try {
        Write-Host "Retrieving user group '$StandardUsersGroupName'..." -ForegroundColor Yellow
        $standardGroup = Get-MgGroup -Filter "displayName eq '$StandardUsersGroupName'" -ErrorAction Stop
        if (-not $standardGroup) {
            throw "User group '$StandardUsersGroupName' not found!"
        }
        Write-Host "Found user group ID: $($standardGroup.Id)" -ForegroundColor Green

        Write-Host "Checking if 'Storage File Data SMB Share Contributor' role is already assigned..." -ForegroundColor Yellow
        $existingAssignment = Get-AzRoleAssignment `
            -ObjectId $standardGroup.Id `
            -Scope $FileShareResourceId `
            -RoleDefinitionName "Storage File Data SMB Share Contributor" -ErrorAction SilentlyContinue

        if ($existingAssignment) {
            Write-Host "✓ 'Storage File Data SMB Share Contributor' is already assigned to '$StandardUsersGroupName'" -ForegroundColor Green
        } else {
            Write-Host "Assigning 'Storage File Data SMB Share Contributor' to '$StandardUsersGroupName'..." -ForegroundColor Yellow
            New-AzRoleAssignment `
                -ObjectId $standardGroup.Id `
                -RoleDefinitionName "Storage File Data SMB Share Contributor" `
                -Scope $FileShareResourceId -ErrorAction Stop
            Write-Host "✓ 'Storage File Data SMB Share Contributor' assigned successfully" -ForegroundColor Green
        }
    }
    catch {
        Write-Error "Failed to assign standard user storage permissions. Error: $($_.Exception.Message)"
        exit 1
    }
}

function Assign-AdminUserStoragePermissions {
    param(
        [string]$FileShareResourceId
    )

    Write-Host "`n=== Assigning Admin User Storage Permissions (Elevated) ===" -ForegroundColor Blue
    try {
        Write-Host "Retrieving admin group '$AdminUsersGroupName'..." -ForegroundColor Yellow
        $adminGroup = Get-MgGroup -Filter "displayName eq '$AdminUsersGroupName'" -ErrorAction Stop
        if (-not $adminGroup) {
            throw "Admin group '$AdminUsersGroupName' not found!"
        }
        Write-Host "Found admin group ID: $($adminGroup.Id)" -ForegroundColor Green

        Write-Host "Checking if 'Storage File Data SMB Share Elevated Contributor' role is already assigned..." -ForegroundColor Yellow
        $existingAssignment = Get-AzRoleAssignment `
            -ObjectId $adminGroup.Id `
            -Scope $FileShareResourceId `
            -RoleDefinitionName "Storage File Data SMB Share Elevated Contributor" -ErrorAction SilentlyContinue

        if ($existingAssignment) {
            Write-Host "✓ 'Storage File Data SMB Share Elevated Contributor' is already assigned to '$AdminUsersGroupName'" -ForegroundColor Green
        } else {
            Write-Host "Assigning 'Storage File Data SMB Share Elevated Contributor' to '$AdminUsersGroupName'..." -ForegroundColor Yellow
            New-AzRoleAssignment `
                -ObjectId $adminGroup.Id `
                -RoleDefinitionName "Storage File Data SMB Share Elevated Contributor" `
                -Scope $FileShareResourceId -ErrorAction Stop
            Write-Host "✓ 'Storage File Data SMB Share Elevated Contributor' assigned successfully" -ForegroundColor Green
        }
    }
    catch {
        Write-Error "Failed to assign admin user storage permissions. Error: $($_.Exception.Message)"
        exit 1
    }
}

function Assign-StandardUserVmLoginPermissions {
    param(
        [string]$ResourceGroupId
    )

    Write-Host "`n=== Assigning Standard User VM Login Permissions ===" -ForegroundColor Blue
    try {
        Write-Host "Retrieving user group '$StandardUsersGroupName'..." -ForegroundColor Yellow
        $standardGroup = Get-MgGroup -Filter "displayName eq '$StandardUsersGroupName'" -ErrorAction Stop
        if (-not $standardGroup) {
            throw "User group '$StandardUsersGroupName' not found!"
        }
        Write-Host "Found user group ID: $($standardGroup.Id)" -ForegroundColor Green

        Write-Host "Checking if 'Virtual Machine User Login' role is already assigned..." -ForegroundColor Yellow
        $existingAssignment = Get-AzRoleAssignment `
            -ObjectId $standardGroup.Id `
            -Scope $ResourceGroupId `
            -RoleDefinitionName "Virtual Machine User Login" -ErrorAction SilentlyContinue

        if ($existingAssignment) {
            Write-Host "✓ 'Virtual Machine User Login' is already assigned to '$StandardUsersGroupName'" -ForegroundColor Green
        } else {
            Write-Host "Assigning 'Virtual Machine User Login' to '$StandardUsersGroupName'..." -ForegroundColor Yellow
            New-AzRoleAssignment `
                -ObjectId $standardGroup.Id `
                -RoleDefinitionName "Virtual Machine User Login" `
                -Scope $ResourceGroupId -ErrorAction Stop
            Write-Host "✓ 'Virtual Machine User Login' assigned successfully" -ForegroundColor Green
        }
    }
    catch {
        Write-Error "Failed to assign standard user VM login permissions. Error: $($_.Exception.Message)"
        exit 1
    }
}

function Assign-AdminUserVmLoginPermissions {
    param(
        [string]$ResourceGroupId
    )

    Write-Host "`n=== Assigning Admin User VM Login Permissions ===" -ForegroundColor Blue
    try {
        Write-Host "Retrieving admin group '$AdminUsersGroupName'..." -ForegroundColor Yellow
        $adminGroup = Get-MgGroup -Filter "displayName eq '$AdminUsersGroupName'" -ErrorAction Stop
        if (-not $adminGroup) {
            throw "Admin group '$AdminUsersGroupName' not found!"
        }
        Write-Host "Found admin group ID: $($adminGroup.Id)" -ForegroundColor Green

        Write-Host "Checking if 'Virtual Machine Administrator Login' role is already assigned..." -ForegroundColor Yellow
        $existingAssignment = Get-AzRoleAssignment `
            -ObjectId $adminGroup.Id `
            -Scope $ResourceGroupId `
            -RoleDefinitionName "Virtual Machine Administrator Login" -ErrorAction SilentlyContinue

        if ($existingAssignment) {
            Write-Host "✓ 'Virtual Machine Administrator Login' is already assigned to '$AdminUsersGroupName'" -ForegroundColor Green
        } else {
            Write-Host "Assigning 'Virtual Machine Administrator Login' to '$AdminUsersGroupName'..." -ForegroundColor Yellow
            New-AzRoleAssignment `
                -ObjectId $adminGroup.Id `
                -RoleDefinitionName "Virtual Machine Administrator Login" `
                -Scope $ResourceGroupId -ErrorAction Stop
            Write-Host "✓ 'Virtual Machine Administrator Login' assigned successfully" -ForegroundColor Green
        }
    }
    catch {
        Write-Error "Failed to assign admin user VM login permissions. Error: $($_.Exception.Message)"
        exit 1
    }
}

function Assign-AdminUserPowerManagementPermissions {
    param(
        [string]$ResourceGroupId
    )

    Write-Host "`n=== Assigning Admin User Power Management Permissions (Optional) ===" -ForegroundColor Blue
    try {
        Write-Host "Retrieving admin group '$AdminUsersGroupName'..." -ForegroundColor Yellow
        $adminGroup = Get-MgGroup -Filter "displayName eq '$AdminUsersGroupName'" -ErrorAction Stop
        if (-not $adminGroup) {
            throw "Admin group '$AdminUsersGroupName' not found!"
        }
        Write-Host "Found admin group ID: $($adminGroup.Id)" -ForegroundColor Green

        Write-Host "Checking if 'Desktop Virtualization Power On Off Contributor' role is already assigned..." -ForegroundColor Yellow
        $existingAssignment = Get-AzRoleAssignment `
            -ObjectId $adminGroup.Id `
            -Scope $ResourceGroupId `
            -RoleDefinitionName "Desktop Virtualization Power On Off Contributor" -ErrorAction SilentlyContinue

        if ($existingAssignment) {
            Write-Host "✓ 'Desktop Virtualization Power On Off Contributor' is already assigned to '$AdminUsersGroupName'" -ForegroundColor Green
        } else {
            Write-Host "Assigning 'Desktop Virtualization Power On Off Contributor' to '$AdminUsersGroupName'..." -ForegroundColor Yellow
            New-AzRoleAssignment `
                -ObjectId $adminGroup.Id `
                -RoleDefinitionName "Desktop Virtualization Power On Off Contributor" `
                -Scope $ResourceGroupId -ErrorAction Stop
            Write-Host "✓ 'Desktop Virtualization Power On Off Contributor' assigned successfully" -ForegroundColor Green
        }
    }
    catch {
        Write-Error "Failed to assign admin user power management permissions. Error: $($_.Exception.Message)"
        exit 1
    }
}

function Assign-ApplicationGroupPermissions {
    param(
        [string]$ApplicationGroupId
    )

    Write-Host "`n=== Assigning Application Group Permissions ===" -ForegroundColor Blue
    try {
        Write-Host "Retrieving user group '$StandardUsersGroupName'..." -ForegroundColor Yellow
        $standardGroup = Get-MgGroup -Filter "displayName eq '$StandardUsersGroupName'" -ErrorAction Stop
        if (-not $standardGroup) {
            throw "User group '$StandardUsersGroupName' not found!"
        }
        Write-Host "Found standard user group ID: $($standardGroup.Id)" -ForegroundColor Green

        Write-Host "Checking if 'Desktop Virtualization User' role is assigned to standard users..." -ForegroundColor Yellow
        $standardAssignment = Get-AzRoleAssignment `
            -ObjectId $standardGroup.Id `
            -Scope $ApplicationGroupId `
            -RoleDefinitionName "Desktop Virtualization User" -ErrorAction SilentlyContinue

        if ($standardAssignment) {
            Write-Host "✓ 'Desktop Virtualization User' is already assigned to '$StandardUsersGroupName'" -ForegroundColor Green
        } else {
            Write-Host "Assigning 'Desktop Virtualization User' to '$StandardUsersGroupName'..." -ForegroundColor Yellow
            New-AzRoleAssignment `
                -ObjectId $standardGroup.Id `
                -RoleDefinitionName "Desktop Virtualization User" `
                -Scope $ApplicationGroupId -ErrorAction Stop
            Write-Host "✓ 'Desktop Virtualization User' assigned to standard users" -ForegroundColor Green
        }

        Write-Host "Retrieving admin group '$AdminUsersGroupName'..." -ForegroundColor Yellow
        $adminGroup = Get-MgGroup -Filter "displayName eq '$AdminUsersGroupName'" -ErrorAction Stop
        if (-not $adminGroup) {
            throw "Admin group '$AdminUsersGroupName' not found!"
        }
        Write-Host "Found admin group ID: $($adminGroup.Id)" -ForegroundColor Green

        Write-Host "Checking if 'Desktop Virtualization User' role is assigned to admin users..." -ForegroundColor Yellow
        $adminAssignment = Get-AzRoleAssignment `
            -ObjectId $adminGroup.Id `
            -Scope $ApplicationGroupId `
            -RoleDefinitionName "Desktop Virtualization User" -ErrorAction SilentlyContinue

        if ($adminAssignment) {
            Write-Host "✓ 'Desktop Virtualization User' is already assigned to '$AdminUsersGroupName'" -ForegroundColor Green
        } else {
            Write-Host "Assigning 'Desktop Virtualization User' to '$AdminUsersGroupName'..." -ForegroundColor Yellow
            New-AzRoleAssignment `
                -ObjectId $adminGroup.Id `
                -RoleDefinitionName "Desktop Virtualization User" `
                -Scope $ApplicationGroupId -ErrorAction Stop
            Write-Host "✓ 'Desktop Virtualization User' assigned to admin users" -ForegroundColor Green
        }
    }
    catch {
        Write-Error "Failed to assign application group permissions. Error: $($_.Exception.Message)"
        exit 1
    }
}

# --- Main Execution ---
Write-Host "Starting RBAC Role Assignments for Azure AVD..." -ForegroundColor Green

try {
    # Get resource group
    Write-Host "`nRetrieving resource group '$ResourceGroupName'..." -ForegroundColor Yellow
    $rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction Stop
    Write-Host "Found resource group: $($rg.ResourceGroupName)" -ForegroundColor Green

    # Get application group
    Write-Host "Retrieving application group '$ApplicationGroupName'..." -ForegroundColor Yellow
    $appGroup = Get-AzWvdApplicationGroup -ResourceGroupName $ResourceGroupName -Name $ApplicationGroupName -ErrorAction Stop
    Write-Host "Found application group ID: $($appGroup.Id)" -ForegroundColor Green

    # Get storage account and file share
    $storageInfo = Get-StorageAccountAndFileShare

    # Assign storage permissions
    Assign-StandardUserStoragePermissions -FileShareResourceId $storageInfo.FileShareResourceId
    Assign-AdminUserStoragePermissions -FileShareResourceId $storageInfo.FileShareResourceId

    # Assign VM login permissions
    Assign-StandardUserVmLoginPermissions -ResourceGroupId $rg.ResourceId
    Assign-AdminUserVmLoginPermissions -ResourceGroupId $rg.ResourceId

    # Assign power management permissions (if requested)
    if ($IncludePowerManagement) {
        Assign-AdminUserPowerManagementPermissions -ResourceGroupId $rg.ResourceId
    } else {
        Write-Host "`nSkipping power management permissions (use -IncludePowerManagement switch to enable)" -ForegroundColor Gray
    }

    # Assign application group permissions
    Assign-ApplicationGroupPermissions -ApplicationGroupId $appGroup.Id

    Write-Host "`nAll RBAC role assignments completed successfully!" -ForegroundColor Green
}
catch {
    Write-Error "An unexpected error occurred. Error: $($_.Exception.Message)"
    exit 1
}
