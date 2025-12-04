# Exports AVD Deployment Configuration for Documentation
#
# Purpose: Exports all deployed resources and configuration to a JSON file
# for reference, backup, and troubleshooting.
#
# Prerequisites:
# - Azure PowerShell modules
# - Logged into Azure (Connect-AzAccount)
# - AVD deployment must be complete
#
# Usage:
# Connect-AzAccount
# .\export_deployment_config.ps1 -ResourceGroupName "RG-Azure-VDI-01" -OutputFile "avd-config.json"

[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory=$false)]
    [string]$OutputFile = "avd-deployment-config.json"
)

$ErrorActionPreference = "Stop"

function Export-DeploymentConfig {
    Write-Host "Exporting AVD deployment configuration..." -ForegroundColor Yellow

    $config = @{
        ExportDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        ResourceGroup = $ResourceGroupName
        Resources = @{}
    }

    # Export resource group info
    try {
        $rg = Get-AzResourceGroup -Name $ResourceGroupName
        $config.Resources.ResourceGroup = @{
            Name = $rg.ResourceGroupName
            Location = $rg.Location
            Tags = $rg.Tags
        }
        Write-Host "✓ Resource group exported" -ForegroundColor Green
    }
    catch {
        Write-Host "✗ Failed to export resource group: $_" -ForegroundColor Red
    }

    # Export VNets
    try {
        $vnets = Get-AzVirtualNetwork -ResourceGroupName $ResourceGroupName
        $config.Resources.VirtualNetworks = @($vnets | ForEach-Object {
            @{
                Name = $_.Name
                AddressSpace = $_.AddressSpace.AddressPrefixes
                Subnets = @($_.Subnets | ForEach-Object { @{
                    Name = $_.Name
                    AddressPrefix = $_.AddressPrefix
                }})
            }
        })
        Write-Host "✓ Virtual networks exported" -ForegroundColor Green
    }
    catch {
        Write-Host "⚠ Could not export virtual networks: $_" -ForegroundColor Yellow
    }

    # Export Storage Accounts
    try {
        $storageAccounts = Get-AzStorageAccount -ResourceGroupName $ResourceGroupName
        $config.Resources.StorageAccounts = @($storageAccounts | ForEach-Object {
            @{
                Name = $_.StorageAccountName
                Type = $_.Kind
                SKU = $_.Sku.Name
            }
        })
        Write-Host "✓ Storage accounts exported" -ForegroundColor Green
    }
    catch {
        Write-Host "⚠ Could not export storage accounts: $_" -ForegroundColor Yellow
    }

    # Export Host Pools
    try {
        $hostPools = Get-AzWvdHostPool -ResourceGroupName $ResourceGroupName
        $config.Resources.HostPools = @($hostPools | ForEach-Object {
            @{
                Name = $_.Name
                Type = $_.HostPoolType
                LoadBalancerType = $_.LoadBalancerType
                MaxSessionLimit = $_.MaxSessionLimit
            }
        })
        Write-Host "✓ Host pools exported" -ForegroundColor Green
    }
    catch {
        Write-Host "⚠ Could not export host pools: $_" -ForegroundColor Yellow
    }

    # Export Application Groups
    try {
        $appGroups = Get-AzWvdApplicationGroup -ResourceGroupName $ResourceGroupName
        $config.Resources.ApplicationGroups = @($appGroups | ForEach-Object {
            @{
                Name = $_.Name
                Type = $_.ApplicationGroupType
                HostPoolName = $_.HostPoolArmPath -split "/" | Select-Object -Last 1
            }
        })
        Write-Host "✓ Application groups exported" -ForegroundColor Green
    }
    catch {
        Write-Host "⚠ Could not export application groups: $_" -ForegroundColor Yellow
    }

    # Export Workspaces
    try {
        $workspaces = Get-AzWvdWorkspace -ResourceGroupName $ResourceGroupName
        $config.Resources.Workspaces = @($workspaces | ForEach-Object {
            @{
                Name = $_.Name
            }
        })
        Write-Host "✓ Workspaces exported" -ForegroundColor Green
    }
    catch {
        Write-Host "⚠ Could not export workspaces: $_" -ForegroundColor Yellow
    }

    # Export VMs
    try {
        $vms = Get-AzVm -ResourceGroupName $ResourceGroupName
        $config.Resources.VirtualMachines = @($vms | ForEach-Object {
            @{
                Name = $_.Name
                Size = $_.HardwareProfile.VmSize
                Status = (Get-AzVm -ResourceGroupName $_.ResourceGroupName -Name $_.Name -Status).Statuses | Where-Object { $_.Code -like "PowerState/*" } | Select-Object -ExpandProperty DisplayStatus
            }
        })
        Write-Host "✓ Virtual machines exported" -ForegroundColor Green
    }
    catch {
        Write-Host "⚠ Could not export virtual machines: $_" -ForegroundColor Yellow
    }

    # Export to JSON
    Write-Host ""
    Write-Host "Exporting to JSON..." -ForegroundColor Yellow

    try {
        $config | ConvertTo-Json -Depth 10 | Out-File -FilePath $OutputFile -Encoding UTF8
        Write-Host "✓ Configuration exported to: $OutputFile" -ForegroundColor Green
        Write-Host ""
        Write-Host "File location: $(Get-Item $OutputFile | Select-Object -ExpandProperty FullName)" -ForegroundColor Cyan
    }
    catch {
        Write-Host "✗ Failed to export JSON: $_" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "=== AVD Deployment Configuration Export ===" -ForegroundColor Cyan
Write-Host ""

Export-DeploymentConfig

Write-Host ""
Write-Host "Export complete!" -ForegroundColor Green
Write-Host ""
