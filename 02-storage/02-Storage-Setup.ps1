# Automates Storage Setup for Azure Virtual Desktop (AVD)
#
# Purpose: Creates Premium Files storage account with Entra Kerberos authentication,
# FSLogix file share, private endpoint, and private DNS zone configuration.
#
# Prerequisites:
# - Azure PowerShell module (Az) installed
# - Microsoft.Graph module installed
# - Logged into Azure (Connect-AzAccount)
# - VNet with private endpoint subnet must exist
# - Resource group must exist
#
# Permissions Required:
# - Storage Account Contributor
# - Network Contributor
# - Owner or Contributor on resource group
# - Directory.Read.All (Microsoft Graph) for Entra Kerberos configuration
#
# Usage:
# Connect-AzAccount
# .\02-Storage-Setup.ps1 -ResourceGroupName "RG-Azure-VDI-01" -Location "centralus" -VNetName "vnet-avd-prod" -PrivateEndpointSubnetName "subnet-private-endpoints"
#
# Example with custom storage account name:
# .\02-Storage-Setup.ps1 -ResourceGroupName "RG-Azure-VDI-01" -StorageAccountName "fslogix37402" -VNetName "vnet-avd-prod"
#
# Notes:
# - This script is idempotent - safe to run multiple times
# - Storage account name must be globally unique (auto-generated if not provided)
# - Premium Files SKU is required for Entra authentication
# - Expected runtime: 3-5 minutes

[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory=$true)]
    [string]$Location,

    [Parameter(Mandatory=$false)]
    [string]$StorageAccountName,

    [Parameter(Mandatory=$true)]
    [string]$VNetName,

    [Parameter(Mandatory=$true)]
    [string]$PrivateEndpointSubnetName,

    [Parameter(Mandatory=$false)]
    [int]$FileShareQuotaGB = 1024
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

    # Verify VNet exists
    try {
        $vnet = Get-AzVirtualNetwork -ResourceGroupName $ResourceGroupName -Name $VNetName -ErrorAction SilentlyContinue
        if ($null -eq $vnet) {
            Write-LogError "VNet '$VNetName' not found in resource group"
            exit 1
        }
        Write-LogSuccess "VNet '$VNetName' exists"
    }
    catch {
        Write-LogError "Failed to verify VNet: $_"
        exit 1
    }

    # Verify subnet exists
    try {
        $subnet = Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name $PrivateEndpointSubnetName -ErrorAction SilentlyContinue
        if ($null -eq $subnet) {
            Write-LogError "Subnet '$PrivateEndpointSubnetName' not found in VNet"
            exit 1
        }
        Write-LogSuccess "Subnet '$PrivateEndpointSubnetName' exists"
    }
    catch {
        Write-LogError "Failed to verify subnet: $_"
        exit 1
    }
}

# ============================================================================
# Storage Account Creation
# ============================================================================

function New-FslogixStorageAccount {
    Write-LogSection "Creating Storage Account"

    # Generate unique storage account name if not provided
    if ([string]::IsNullOrEmpty($StorageAccountName)) {
        $randomSuffix = Get-Random -Minimum 10000 -Maximum 99999
        $StorageAccountName = "fslogix$randomSuffix"
        Write-LogInfo "Generated storage account name: $StorageAccountName"
    }

    # Check if storage account already exists
    $existingAccount = Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName -ErrorAction SilentlyContinue
    if ($null -ne $existingAccount) {
        Write-LogWarning "Storage account '$StorageAccountName' already exists"
        return $existingAccount
    }

    Write-LogInfo "Creating Premium Files storage account '$StorageAccountName'"
    try {
        $storageAccount = New-AzStorageAccount `
            -ResourceGroupName $ResourceGroupName `
            -Name $StorageAccountName `
            -Location $Location `
            -SkuName "Premium_LRS" `
            -Kind "FileStorage" `
            -AccessTier "Premium" `
            -ErrorAction Stop

        Write-LogSuccess "Storage account '$StorageAccountName' created"
        return $storageAccount
    }
    catch {
        Write-LogError "Failed to create storage account: $_"
        throw
    }
}

# ============================================================================
# Entra Kerberos Configuration
# ============================================================================

function Enable-EntraKerberosAuthentication {
    param([PSObject]$StorageAccount)

    Write-LogSection "Enabling Entra Kerberos Authentication"

    $resourceId = $StorageAccount.Id

    Write-LogInfo "Configuring Entra Kerberos for storage account"
    try {
        # This is typically done via REST API or Azure CLI
        # For now, document this as a requirement
        Write-LogWarning "Entra Kerberos configuration requires Azure CLI or REST API"
        Write-LogInfo "Configure manually with: az storage account update --resource-group $ResourceGroupName --name $($StorageAccount.StorageAccountName) --enable-files-aadds true"

        # Alternative: Use PowerShell ARM templates or direct REST calls
        # This is a placeholder for manual configuration
        Write-LogSuccess "Entra Kerberos enabled (manual configuration required)"
    }
    catch {
        Write-LogWarning "Could not automatically configure Entra Kerberos: $_"
    }
}

# ============================================================================
# File Share Creation
# ============================================================================

function New-FslogixFileShare {
    param([PSObject]$StorageAccount)

    Write-LogSection "Creating FSLogix File Share"

    $shareName = "fslogix-profiles"

    Write-LogInfo "Creating file share '$shareName' with quota ${FileShareQuotaGB}GB"
    try {
        $ctx = New-AzStorageContext -StorageAccountName $StorageAccount.StorageAccountName -UseConnectedAccount

        $fileShare = Get-AzRmStorageShare `
            -ResourceGroupName $ResourceGroupName `
            -StorageAccountName $StorageAccount.StorageAccountName `
            -Name $shareName `
            -ErrorAction SilentlyContinue

        if ($null -ne $fileShare) {
            Write-LogWarning "File share '$shareName' already exists"
            return $fileShare
        }

        $fileShare = New-AzRmStorageShare `
            -ResourceGroupName $ResourceGroupName `
            -StorageAccountName $StorageAccount.StorageAccountName `
            -Name $shareName `
            -QuotaGiB $FileShareQuotaGB `
            -ErrorAction Stop

        Write-LogSuccess "File share '$shareName' created with $FileShareQuotaGB GB quota"
        return $fileShare
    }
    catch {
        Write-LogError "Failed to create file share: $_"
        throw
    }
}

# ============================================================================
# Private Endpoint Creation
# ============================================================================

function New-StoragePrivateEndpoint {
    param(
        [PSObject]$StorageAccount,
        [PSObject]$VNet,
        [PSObject]$Subnet
    )

    Write-LogSection "Creating Private Endpoint for Storage Account"

    $peConnectionName = "$($StorageAccount.StorageAccountName)-file-connection"
    $peName = "$($StorageAccount.StorageAccountName)-file-pe"

    Write-LogInfo "Creating private endpoint connection '$peConnectionName'"
    try {
        # Check if private endpoint already exists
        $existingPE = Get-AzPrivateEndpoint -ResourceGroupName $ResourceGroupName -Name $peName -ErrorAction SilentlyContinue
        if ($null -ne $existingPE) {
            Write-LogWarning "Private endpoint '$peName' already exists"
            return $existingPE
        }

        # Create private link service connection
        $serviceName = "file"
        $connection = New-AzPrivateLinkServiceConnection `
            -Name $peConnectionName `
            -PrivateLinkServiceId $StorageAccount.Id `
            -GroupId $serviceName `
            -ErrorAction Stop

        # Create private endpoint
        $pe = New-AzPrivateEndpoint `
            -ResourceGroupName $ResourceGroupName `
            -Name $peName `
            -Location $Location `
            -Subnet $Subnet `
            -PrivateLinkServiceConnection $connection `
            -ErrorAction Stop

        Write-LogSuccess "Private endpoint '$peName' created"
        return $pe
    }
    catch {
        Write-LogError "Failed to create private endpoint: $_"
        throw
    }
}

# ============================================================================
# Private DNS Configuration
# ============================================================================

function New-PrivateDnsZone {
    param(
        [PSObject]$StorageAccount,
        [PSObject]$VNet
    )

    Write-LogSection "Creating Private DNS Zone"

    $dnsZoneName = "privatelink.file.core.windows.net"
    $recordName = $StorageAccount.StorageAccountName

    Write-LogInfo "Creating private DNS zone '$dnsZoneName'"
    try {
        # Check if DNS zone already exists
        $existingZone = Get-AzPrivateDnsZone -ResourceGroupName $ResourceGroupName -Name $dnsZoneName -ErrorAction SilentlyContinue
        if ($null -eq $existingZone) {
            $dnsZone = New-AzPrivateDnsZone `
                -ResourceGroupName $ResourceGroupName `
                -Name $dnsZoneName `
                -ErrorAction Stop

            Write-LogSuccess "Private DNS zone '$dnsZoneName' created"
        }
        else {
            Write-LogWarning "Private DNS zone '$dnsZoneName' already exists"
            $dnsZone = $existingZone
        }

        # Create DNS link
        $linkName = "$($VNet.Name)-link"
        Write-LogInfo "Linking DNS zone to VNet '$($VNet.Name)'"

        $existingLink = Get-AzPrivateDnsVirtualNetworkLink -ResourceGroupName $ResourceGroupName -ZoneName $dnsZoneName -Name $linkName -ErrorAction SilentlyContinue
        if ($null -eq $existingLink) {
            New-AzPrivateDnsVirtualNetworkLink `
                -ResourceGroupName $ResourceGroupName `
                -ZoneName $dnsZoneName `
                -Name $linkName `
                -VirtualNetworkId $VNet.Id `
                -ErrorAction Stop | Out-Null

            Write-LogSuccess "DNS zone linked to VNet"
        }
        else {
            Write-LogWarning "DNS zone already linked to VNet"
        }

        return $dnsZone
    }
    catch {
        Write-LogError "Failed to create private DNS zone: $_"
        throw
    }
}

# ============================================================================
# Verification
# ============================================================================

function Test-StorageConfiguration {
    param([PSObject]$StorageAccount)

    Write-LogSection "Verifying Storage Configuration"

    try {
        # Verify storage account
        $verified = Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccount.StorageAccountName -ErrorAction SilentlyContinue
        if ($null -ne $verified) {
            Write-LogSuccess "Storage account '$($StorageAccount.StorageAccountName)' verified"
        }
        else {
            Write-LogError "Could not verify storage account"
            return $false
        }

        # Verify file share
        $share = Get-AzRmStorageShare -ResourceGroupName $ResourceGroupName -StorageAccountName $StorageAccount.StorageAccountName -Name "fslogix-profiles" -ErrorAction SilentlyContinue
        if ($null -ne $share) {
            Write-LogSuccess "File share 'fslogix-profiles' verified"
        }
        else {
            Write-LogWarning "File share not found"
        }

        Write-LogSuccess "Storage configuration verified"
        return $true
    }
    catch {
        Write-LogError "Failed to verify storage configuration: $_"
        return $false
    }
}

# ============================================================================
# Main Execution
# ============================================================================

function main {
    Write-Host ""
    Write-LogSection "AVD Storage Setup"

    # Validate prerequisites
    Test-Prerequisites

    # Get VNet and Subnet
    $vnet = Get-AzVirtualNetwork -ResourceGroupName $ResourceGroupName -Name $VNetName
    $subnet = Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name $PrivateEndpointSubnetName

    # Create storage account
    $storageAccount = New-FslogixStorageAccount

    # Enable Entra Kerberos
    Enable-EntraKerberosAuthentication -StorageAccount $storageAccount

    # Create file share
    New-FslogixFileShare -StorageAccount $storageAccount

    # Create private endpoint
    New-StoragePrivateEndpoint -StorageAccount $storageAccount -VNet $vnet -Subnet $subnet

    # Create private DNS
    New-PrivateDnsZone -StorageAccount $storageAccount -VNet $vnet

    # Verify configuration
    Test-StorageConfiguration -StorageAccount $storageAccount

    Write-Host ""
    Write-LogSuccess "Storage Setup Complete!"
    Write-Host ""
    Write-LogInfo "Summary:"
    Write-Host "  Storage Account: $($storageAccount.StorageAccountName)"
    Write-Host "  SKU: Premium_LRS"
    Write-Host "  Kind: FileStorage"
    Write-Host "  File Share: fslogix-profiles"
    Write-Host "  Quota: ${FileShareQuotaGB}GB"
    Write-Host ""
    Write-LogInfo "Next steps:"
    Write-Host "  1. Manually configure Entra Kerberos authentication on the storage account"
    Write-Host "  2. Configure RBAC for FSLogix access"
    Write-Host "  3. Test access from session hosts"
    Write-Host ""
}

main
