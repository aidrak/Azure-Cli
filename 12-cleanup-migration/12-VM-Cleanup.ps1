# Automates Cleanup of Temporary Resources for Azure Virtual Desktop (AVD)
#
# Purpose: Deletes temporary VMs and associated resources to clean up after
# golden image creation and testing.
#
# Prerequisites:
# - Azure PowerShell modules
# - Logged into Azure (Connect-AzAccount)
# - Identify temporary VMs to delete (golden image, test VMs, etc.)
#
# Usage:
# Connect-AzAccount
# .\12-VM-Cleanup.ps1 -ResourceGroupName "RG-Azure-VDI-01" -VmNamesToDelete "avd-gold-pool"
#
# Parameters:
# - ResourceGroupName: Resource group name (required)
# - VmNamesToDelete: VM names to delete (array, supports wildcards)
# - DeleteDisks: Delete orphaned disks (default: true)
# - DeleteNics: Delete orphaned NICs (default: true)
# - WhatIf: Show what would be deleted without deleting (default: false)

[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory=$false)]
    [string[]]$VmNamesToDelete = @(),

    [Parameter(Mandatory=$false)]
    [switch]$DeleteDisks = $true,

    [Parameter(Mandatory=$false)]
    [switch]$DeleteNics = $true,

    [Parameter(Mandatory=$false)]
    [switch]$WhatIf
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

function Get-TemporaryVMs {
    Write-LogSection "Finding Temporary VMs"

    if ($VmNamesToDelete.Count -eq 0) {
        Write-LogWarning "No VMs specified for deletion"
        Write-LogInfo "Usage: -VmNamesToDelete 'avd-gold-*' or -VmNamesToDelete 'avd-test-01','avd-test-02'"
        return @()
    }

    $vmsToDelete = @()

    foreach ($vmPattern in $VmNamesToDelete) {
        $vms = Get-AzVm -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like $vmPattern }

        if ($vms) {
            $vmsToDelete += $vms
            foreach ($vm in $vms) {
                Write-LogInfo "Found: $($vm.Name)"
            }
        }
        else {
            Write-LogWarning "No VMs matching pattern: $vmPattern"
        }
    }

    return $vmsToDelete
}

function Remove-TemporaryVm {
    param([PSObject]$Vm)

    Write-LogInfo "Removing VM: $($Vm.Name)"

    if ($WhatIf) {
        Write-LogWarning "[WhatIf] Would delete VM: $($Vm.Name)"
        return
    }

    try {
        Write-Host "Deleting VM and associated resources..."
        Remove-AzVm -ResourceGroupName $ResourceGroupName -Name $Vm.Name -Force -ErrorAction Stop | Out-Null
        Write-LogSuccess "VM '$($Vm.Name)' deleted"
    }
    catch {
        Write-LogError "Failed to delete VM: $_"
    }
}

function Remove-OrphanedDisks {
    Write-LogSection "Removing Orphaned Disks"

    if (!$DeleteDisks) {
        Write-LogWarning "Disk deletion disabled"
        return
    }

    try {
        $disks = Get-AzDisk -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue |
            Where-Object { $_.ManagedBy -eq $null }

        if ($disks) {
            foreach ($disk in $disks) {
                Write-LogInfo "Found orphaned disk: $($disk.Name)"

                if ($WhatIf) {
                    Write-LogWarning "[WhatIf] Would delete disk: $($disk.Name)"
                    continue
                }

                Remove-AzDisk -ResourceGroupName $ResourceGroupName -DiskName $disk.Name -Force -ErrorAction SilentlyContinue | Out-Null
                Write-LogSuccess "Disk '$($disk.Name)' deleted"
            }
        }
        else {
            Write-LogWarning "No orphaned disks found"
        }
    }
    catch {
        Write-LogError "Error removing disks: $_"
    }
}

function Remove-OrphanedNics {
    Write-LogSection "Removing Orphaned NICs"

    if (!$DeleteNics) {
        Write-LogWarning "NIC deletion disabled"
        return
    }

    try {
        $nics = Get-AzNetworkInterface -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue |
            Where-Object { $_.VirtualMachine -eq $null }

        if ($nics) {
            foreach ($nic in $nics) {
                Write-LogInfo "Found orphaned NIC: $($nic.Name)"

                if ($WhatIf) {
                    Write-LogWarning "[WhatIf] Would delete NIC: $($nic.Name)"
                    continue
                }

                Remove-AzNetworkInterface -ResourceGroupName $ResourceGroupName -Name $nic.Name -Force -ErrorAction SilentlyContinue | Out-Null
                Write-LogSuccess "NIC '$($nic.Name)' deleted"
            }
        }
        else {
            Write-LogWarning "No orphaned NICs found"
        }
    }
    catch {
        Write-LogError "Error removing NICs: $_"
    }
}

function main {
    Write-Host ""
    Write-LogSection "AVD VM Cleanup"

    if ($WhatIf) {
        Write-LogWarning "WhatIf mode enabled - showing what would be deleted without deleting"
    }

    # Find VMs
    $vms = Get-TemporaryVMs

    if ($vms.Count -eq 0) {
        Write-LogWarning "No VMs to delete"
        return
    }

    # Confirm deletion
    Write-LogWarning "About to delete $($vms.Count) VM(s)"
    if (!$WhatIf) {
        $confirm = Read-Host "Are you sure you want to delete these VMs? (yes/no)"
        if ($confirm -ne "yes") {
            Write-LogWarning "Cleanup cancelled"
            return
        }
    }

    # Delete VMs
    Write-LogSection "Deleting VMs"
    foreach ($vm in $vms) {
        Remove-TemporaryVm -Vm $vm
    }

    # Cleanup orphaned resources
    Remove-OrphanedDisks
    Remove-OrphanedNics

    Write-Host ""
    Write-LogSuccess "Cleanup Complete!"
    Write-Host ""
}

main
