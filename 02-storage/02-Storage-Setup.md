# FSLogix Storage Account & Private Endpoint Setup

**Purpose:** Create Azure Files Premium storage for FSLogix profiles with Entra Kerberos authentication and private endpoint connectivity

**Prerequisites:**
- Azure subscription with Owner or Contributor role
- Resource group: `RG-Azure-VDI-01` exists
- AVD spoke VNet created with private endpoint subnet (10.1.4.0/24)
- Azure CLI or PowerShell installed
- Logged into Azure

**Storage Account Naming (IMPORTANT):**
- Pattern: `fslogix<random-5-digits>` (e.g., `fslogix37402`, `fslogix12345`)
- Storage account names must be **globally unique** across all Azure subscriptions
- 3-24 characters, lowercase letters and numbers only
- Generate a unique name for your deployment using: `Get-Random -Minimum 10000 -Maximum 99999`
- **Save your chosen storage account name** - you'll use it in all subsequent guides (04, 05, 06, 07, 08, etc.)
- Examples: `fslogix52847`, `fslogix18392`, `fslogix74561`

---

## Automated Deployment (Recommended)

### Using the Automation Script

**Script:** `02-Storage-Setup.ps1` (PowerShell)

**Quick Start:**

```powershell
# 1. Login to Azure
Connect-AzAccount

# 2. Run the script with default settings
.\02-Storage-Setup.ps1 -ResourceGroupName "RG-Azure-VDI-01" -Location "centralus" -VNetName "vnet-avd-prod"

# 3. Or with custom storage account name
.\02-Storage-Setup.ps1 `
  -ResourceGroupName "RG-Azure-VDI-01" `
  -Location "centralus" `
  -StorageAccountName "fslogix52847" `
  -VNetName "vnet-avd-prod" `
  -PrivateEndpointSubnetName "snet-avd-privateendpoints" `
  -FileShareQuotaGB 5120
```

**What the script does:**
1. Creates Premium FileStorage account with globally unique name
2. Enables Entra Kerberos authentication for passwordless access
3. Creates `fslogix-profiles` file share (5 TB default, adjustable)
4. Creates private DNS zone for Azure Files
5. Creates private endpoint in VNet for secure storage access
6. Links DNS zone to VNet for DNS resolution
7. Validates all configurations completed successfully

**Expected Runtime:** 5-8 minutes

**Verification:**
```powershell
# Verify storage account created
Get-AzStorageAccount -ResourceGroupName "RG-Azure-VDI-01" -Name "YOUR_STORAGE_ACCOUNT"

# Verify file share exists
Get-AzStorageShare -Name "fslogix-profiles" -Context (Get-AzStorageAccount -ResourceGroupName "RG-Azure-VDI-01" -Name "YOUR_STORAGE_ACCOUNT").Context

# Verify private endpoint
Get-AzPrivateEndpoint -ResourceGroupName "RG-Azure-VDI-01" -Name "pe-fslogix-files"
```

---

## Manual Deployment (Alternative)

### Part 1: Create FSLogix Storage Account

### Option A: Azure Portal (GUI)

#### Step 1: Create Storage Account

1. **Navigate to Storage Accounts**
   - Open Azure Portal → Search "Storage accounts"
   - Click **+ Create**

2. **Basics Tab**
   - Subscription: Select your subscription
   - Resource group: `RG-Azure-VDI-01`
   - Storage account name: `YOUR_STORAGE_ACCOUNT` (e.g., `fslogix52847`)
     - ⚠️ Must be globally unique
     - 3-24 characters, lowercase letters and numbers only
     - Use the storage account name you generated from the Prerequisites section above
   - Region: `Central US` (match your AVD location)
   - Performance: **Premium** ⚠️ CRITICAL for FSLogix
   - Premium account type: **File shares**
   - Redundancy: `Locally-redundant storage (LRS)`
   - Click **Next: Advanced**

3. **Advanced Tab**
   - Require secure transfer (HTTPS): **Enabled**
   - Allow Blob public access: **Disabled**
   - Enable storage account key access: **Enabled** (needed for initial setup)
   - Default to Microsoft Entra authorization: **Enabled**
   - Minimum TLS version: **Version 1.2**
   - **Enable large file shares: Enabled** ✓ IMPORTANT
   - Scroll down:
   - **Enable identity-based access for file shares: Enabled**
   - Click **Next: Networking**

4. **Networking Tab**
   - Network connectivity: **Disable public access and use private access**
     - ⚠️ We'll create the private endpoint in next section
   - Network routing: **Microsoft network routing** (default)
   - Click **Next: Data protection**

5. **Data protection Tab**
   - Enable soft delete for blobs: Optional (not used for file shares)
   - Enable soft delete for file shares: **Enabled** (7 days recommended)
   - Click **Next: Encryption**

6. **Encryption Tab**
   - Encryption type: **Microsoft-managed keys** (default)
   - Enable infrastructure encryption: Optional
   - Click **Next: Tags**

7. **Tags Tab** (optional but recommended)
   - Add tags:
     - `Environment`: `Production`
     - `Purpose`: `AVD-FSLogix`
     - `CostCenter`: (your cost center)
   - Click **Next: Review + create**

8. **Review + Create**
   - Verify all settings
   - Click **Create**
   - Wait 1-2 minutes for deployment

#### Step 2: Enable Entra Kerberos Authentication

⚠️ **CRITICAL STEP** - Without this, Entra-only authentication won't work

1. **Navigate to your storage account**
   - Go to your storage account (e.g., `fslogix52847` - the name you created in Step 1)

2. **Enable Kerberos**
   - Left menu → **File shares**
   - Click **Active Directory: Not Configured**
   - Select **Microsoft Entra Kerberos**
   - Click **Set up**
   - **Domain name:** Leave blank (Entra-only)
   - **Domain GUID:** Leave blank
   - Click **Save**
   - Wait 30 seconds for configuration

3. **Verify Configuration**
   - Refresh the page
   - Should show: **Microsoft Entra Kerberos: Enabled**

#### Step 3: Create File Share

1. **Create Share**
   - In storage account → **File shares**
   - Click **+ File share**
   
2. **Basics**
   - Name: `fslogix-profiles`
   - Access tier: **Premium** (only option for Premium storage)
   - Provisioned capacity: `5120` GiB (5 TB)
     - Calculate: (Number of users × 50 GB) + 20% buffer
     - For 400 users: (400 × 50) + 4000 = 24 TB recommended
     - Start with 5 TB, expand as needed
   - Protocol: **SMB**
   - Click **Review + create** → **Create**

---

### Option B: PowerShell

```powershell
# Login to Azure
Connect-AzAccount

# Set variables
$resourceGroup = "RG-Azure-VDI-01"
$location = "centralus"
# IMPORTANT: Replace with your unique storage account name (pattern: fslogix<random-5-digits>)
$storageAccountName = "fslogix" + (Get-Random -Minimum 10000 -Maximum 99999)
# Example: fslogix52847 (your number will be different)
Write-Host "Using storage account: $storageAccountName" -ForegroundColor Yellow
$fileShareName = "fslogix-profiles"
$shareQuotaGiB = 5120  # 5 TB

# Create storage account
Write-Host "Creating Premium FileStorage account..." -ForegroundColor Cyan
$storageAccount = New-AzStorageAccount `
    -ResourceGroupName $resourceGroup `
    -Name $storageAccountName `
    -Location $location `
    -SkuName Premium_LRS `
    -Kind FileStorage `
    -EnableLargeFileShare `
    -MinimumTlsVersion TLS1_2 `
    -AllowBlobPublicAccess $false `
    -EnableHttpsTrafficOnly $true

Write-Host "✓ Storage account created: $storageAccountName" -ForegroundColor Green

# Enable Entra Kerberos authentication
Write-Host "`nEnabling Microsoft Entra Kerberos authentication..." -ForegroundColor Cyan
Set-AzStorageAccount `
    -ResourceGroupName $resourceGroup `
    -Name $storageAccountName `
    -EnableAzureActiveDirectoryKerberosForFile $true `
    -ActiveDirectoryDomainName "" `
    -ActiveDirectoryDomainGuid ""

Write-Host "✓ Entra Kerberos enabled" -ForegroundColor Green

# Disable public network access (will use private endpoint)
Write-Host "`nDisabling public network access..." -ForegroundColor Cyan
Set-AzStorageAccount `
    -ResourceGroupName $resourceGroup `
    -Name $storageAccountName `
    -PublicNetworkAccess Disabled

Write-Host "✓ Public access disabled" -ForegroundColor Green

# Create file share
Write-Host "`nCreating file share: $fileShareName..." -ForegroundColor Cyan
$ctx = $storageAccount.Context
New-AzStorageShare `
    -Name $fileShareName `
    -Context $ctx `
    -QuotaGiB $shareQuotaGiB

Write-Host "✓ File share created: $fileShareName ($shareQuotaGiB GiB)" -ForegroundColor Green

# Output connection string for later use
Write-Host "`n=== CONFIGURATION SUMMARY ===" -ForegroundColor Cyan
Write-Host "Storage Account: $storageAccountName" -ForegroundColor White
Write-Host "File Share: $fileShareName" -ForegroundColor White
Write-Host "UNC Path: \\$storageAccountName.file.core.windows.net\$fileShareName" -ForegroundColor Yellow
Write-Host "Entra Kerberos: Enabled" -ForegroundColor Green
Write-Host "Public Access: Disabled" -ForegroundColor Green
Write-Host "`nNext Step: Create Private Endpoint" -ForegroundColor Cyan
```

---

## Part 2: Create Private Endpoint for Azure Files

### Option A: Azure Portal (GUI)

#### Step 1: Create Private DNS Zone (if not exists)

1. **Navigate to Private DNS zones**
   - Search "Private DNS zones" in Azure Portal
   - Click **+ Create**

2. **Create DNS Zone**
   - Resource group: `RG-Azure-VDI-01`
   - Name: `privatelink.file.core.windows.net`
   - Click **Review + create** → **Create**

3. **Link to Virtual Networks**
   - Open the DNS zone → **Virtual network links**
   - Click **+ Add**
   
   **Link 1 - Hub VNet:**
   - Link name: `hub-vnet-link`
   - Virtual network: Select your hub VNet (e.g., `vnet-hub-centralus`)
   - Enable auto registration: **Unchecked**
   - Click **OK**
   
   **Link 2 - AVD Spoke VNet:**
   - Click **+ Add** again
   - Link name: `avd-spoke-vnet-link`
   - Virtual network: `vnet-avd-prod` (10.1.0.0/16)
   - Enable auto registration: **Unchecked**
   - Click **OK**

#### Step 2: Create Private Endpoint

1. **Navigate to Private endpoints**
   - Search "Private endpoints"
   - Click **+ Create**

2. **Basics Tab**
   - Subscription: Your subscription
   - Resource group: `RG-Azure-VDI-01`
   - Name: `pe-fslogix-files`
   - Network Interface Name: `pe-fslogix-files-nic` (auto-filled)
   - Region: `Central US`
   - Click **Next: Resource**

3. **Resource Tab**
   - Connection method: **Connect to an Azure resource in my directory**
   - Subscription: Your subscription
   - Resource type: `Microsoft.Storage/storageAccounts`
   - Resource: `fslogix112125`
   - Target sub-resource: **file**
   - Click **Next: Virtual Network**

4. **Virtual Network Tab**
   - Virtual network: `vnet-avd-prod` (10.1.0.0/16)
   - Subnet: `snet-avd-privateendpoints` (10.1.4.0/24)
   - Private IP configuration: **Dynamically allocate IP address**
   - Application security group: None (leave empty)
   - Click **Next: DNS**

5. **DNS Tab**
   - Integrate with private DNS zone: **Yes**
   - Private DNS Zone: Select `privatelink.file.core.windows.net`
   - Click **Next: Tags**

6. **Tags Tab** (optional)
   - Add tags as needed
   - Click **Next: Review + create**

7. **Review + Create**
   - Verify settings
   - Click **Create**
   - Wait 2-3 minutes for deployment

#### Step 3: Verify Private Endpoint

1. **Get Private IP**
   - Go to private endpoint → **Overview**
   - Note the **Private IP address** (e.g., 10.1.4.5)

2. **Verify DNS Record**
   - Go to Private DNS zone `privatelink.file.core.windows.net`
   - Click **Recordsets**
   - You should see:
     - Name: Your storage account name (e.g., `fslogix52847`)
     - Type: `A`
     - IP: `10.1.4.x`

---

### Option B: PowerShell

```powershell
# Continue from Part 1 or re-login
Connect-AzAccount

# Set variables
$resourceGroup = "RG-Azure-VDI-01"
$location = "centralus"
# IMPORTANT: Use the same storage account name you created in Part 1
$storageAccountName = "YOUR_STORAGE_ACCOUNT"  # Replace with your storage account name (e.g., fslogix52847)
$vnetName = "vnet-avd-prod"
$subnetName = "snet-avd-privateendpoints"
$privateEndpointName = "pe-fslogix-files"
$privateDnsZoneName = "privatelink.file.core.windows.net"

# Get storage account resource ID
Write-Host "Getting storage account resource ID..." -ForegroundColor Cyan
$storageAccount = Get-AzStorageAccount `
    -ResourceGroupName $resourceGroup `
    -Name $storageAccountName

# Get subnet ID
Write-Host "Getting subnet information..." -ForegroundColor Cyan
$vnet = Get-AzVirtualNetwork `
    -ResourceGroupName $resourceGroup `
    -Name $vnetName

$subnet = $vnet | Get-AzVirtualNetworkSubnetConfig -Name $subnetName

# Create private DNS zone if it doesn't exist
Write-Host "`nCreating/verifying private DNS zone..." -ForegroundColor Cyan
$privateDnsZone = Get-AzPrivateDnsZone `
    -ResourceGroupName $resourceGroup `
    -Name $privateDnsZoneName `
    -ErrorAction SilentlyContinue

if (-not $privateDnsZone) {
    $privateDnsZone = New-AzPrivateDnsZone `
        -ResourceGroupName $resourceGroup `
        -Name $privateDnsZoneName
    Write-Host "✓ Private DNS zone created" -ForegroundColor Green
} else {
    Write-Host "✓ Private DNS zone already exists" -ForegroundColor Green
}

# Link DNS zone to VNets
Write-Host "`nLinking DNS zone to virtual networks..." -ForegroundColor Cyan

# Link to AVD spoke VNet
$vnetLink = Get-AzPrivateDnsVirtualNetworkLink `
    -ResourceGroupName $resourceGroup `
    -ZoneName $privateDnsZoneName `
    -Name "avd-spoke-vnet-link" `
    -ErrorAction SilentlyContinue

if (-not $vnetLink) {
    New-AzPrivateDnsVirtualNetworkLink `
        -ResourceGroupName $resourceGroup `
        -ZoneName $privateDnsZoneName `
        -Name "avd-spoke-vnet-link" `
        -VirtualNetworkId $vnet.Id `
        -EnableRegistration $false | Out-Null
    Write-Host "✓ Linked DNS zone to AVD spoke VNet" -ForegroundColor Green
} else {
    Write-Host "✓ DNS zone already linked to AVD spoke VNet" -ForegroundColor Green
}

# Link to hub VNet (if you have one)
# Uncomment and update if needed:
# $hubVnet = Get-AzVirtualNetwork -ResourceGroupName "RG-HUB" -Name "vnet-hub-centralus"
# New-AzPrivateDnsVirtualNetworkLink `
#     -ResourceGroupName $resourceGroup `
#     -ZoneName $privateDnsZoneName `
#     -Name "hub-vnet-link" `
#     -VirtualNetworkId $hubVnet.Id `
#     -EnableRegistration $false | Out-Null

# Create private endpoint connection
Write-Host "`nCreating private endpoint..." -ForegroundColor Cyan
$privateEndpointConnection = New-AzPrivateLinkServiceConnection `
    -Name "$privateEndpointName-connection" `
    -PrivateLinkServiceId $storageAccount.Id `
    -GroupId "file"

# Create private endpoint
$privateEndpoint = New-AzPrivateEndpoint `
    -ResourceGroupName $resourceGroup `
    -Name $privateEndpointName `
    -Location $location `
    -Subnet $subnet `
    -PrivateLinkServiceConnection $privateEndpointConnection

Write-Host "✓ Private endpoint created: $privateEndpointName" -ForegroundColor Green

# Create DNS zone group (integrates private endpoint with DNS zone)
Write-Host "`nIntegrating private endpoint with DNS zone..." -ForegroundColor Cyan
$dnsConfig = New-AzPrivateDnsZoneConfig `
    -Name $privateDnsZoneName `
    -PrivateDnsZoneId $privateDnsZone.ResourceId

$dnsZoneGroup = New-AzPrivateDnsZoneGroup `
    -ResourceGroupName $resourceGroup `
    -PrivateEndpointName $privateEndpointName `
    -Name "default" `
    -PrivateDnsZoneConfig $dnsConfig

Write-Host "✓ DNS integration complete" -ForegroundColor Green

# Get private endpoint details
$privateEndpoint = Get-AzPrivateEndpoint `
    -ResourceGroupName $resourceGroup `
    -Name $privateEndpointName

$privateIpAddress = $privateEndpoint.NetworkInterfaces[0].IpConfigurations[0].PrivateIpAddress

# Output summary
Write-Host "`n=== PRIVATE ENDPOINT CONFIGURATION SUMMARY ===" -ForegroundColor Cyan
Write-Host "Private Endpoint Name: $privateEndpointName" -ForegroundColor White
Write-Host "Private IP Address: $privateIpAddress" -ForegroundColor Yellow
Write-Host "Subnet: $subnetName" -ForegroundColor White
Write-Host "DNS Zone: $privateDnsZoneName" -ForegroundColor White
Write-Host "Storage Account: $storageAccountName.file.core.windows.net" -ForegroundColor White
Write-Host "`nFSLogix UNC Path: \\$storageAccountName.file.core.windows.net\fslogix-profiles" -ForegroundColor Yellow
Write-Host "Will resolve to: $privateIpAddress (private)" -ForegroundColor Green
```

---

## Part 3: Test and Verify Configuration

### Verification Steps

#### Option A: From Azure Portal

1. **Verify Private Endpoint**
   - Go to Storage account → **Networking** → **Private endpoint connections**
   - Should show `pe-fslogix-files` with status **Approved**

2. **Verify DNS Resolution**
   - Go to Private DNS zone → **Recordsets**
   - Should show A record for `fslogix112125` pointing to private IP

3. **Test from Session Host (later)**
   - After deploying session hosts, RDP in and run (replace YOUR_STORAGE_ACCOUNT with your storage account name):
   ```powershell
   # Test DNS resolution
   nslookup YOUR_STORAGE_ACCOUNT.file.core.windows.net
   # Should return private IP (10.1.4.x), not public IP

   # Test connectivity
   Test-NetConnection -ComputerName YOUR_STORAGE_ACCOUNT.file.core.windows.net -Port 445

   # Test Kerberos ticket
   klist get cifs/YOUR_STORAGE_ACCOUNT.file.core.windows.net
   ```

#### Option B: PowerShell Verification Script

```powershell
# Run from a VM in the same VNet to test
# Replace with your storage account name (e.g., fslogix52847)
$storageAccountName = "YOUR_STORAGE_ACCOUNT"
$fqdn = "$storageAccountName.file.core.windows.net"

Write-Host "=== TESTING STORAGE CONNECTIVITY ===" -ForegroundColor Cyan

# Test 1: DNS Resolution
Write-Host "`n[Test 1] DNS Resolution..." -ForegroundColor Yellow
$dnsResult = Resolve-DnsName -Name $fqdn -Type A -ErrorAction SilentlyContinue

if ($dnsResult) {
    $resolvedIp = $dnsResult | Where-Object { $_.Type -eq 'A' } | Select-Object -First 1 -ExpandProperty IPAddress
    Write-Host "✓ DNS resolves to: $resolvedIp" -ForegroundColor Green
    
    # Check if it's a private IP
    if ($resolvedIp -match '^10\.|^172\.(1[6-9]|2[0-9]|3[0-1])\.|^192\.168\.') {
        Write-Host "✓ Private IP detected (using private endpoint)" -ForegroundColor Green
    } else {
        Write-Host "⚠ Public IP detected (private endpoint may not be configured)" -ForegroundColor Yellow
    }
} else {
    Write-Host "✗ DNS resolution failed" -ForegroundColor Red
}

# Test 2: TCP Connectivity
Write-Host "`n[Test 2] Port 445 Connectivity..." -ForegroundColor Yellow
$tcpTest = Test-NetConnection -ComputerName $fqdn -Port 445 -WarningAction SilentlyContinue

if ($tcpTest.TcpTestSucceeded) {
    Write-Host "✓ Port 445 is accessible" -ForegroundColor Green
    Write-Host "  Remote Address: $($tcpTest.RemoteAddress)" -ForegroundColor Gray
} else {
    Write-Host "✗ Port 445 is blocked or unreachable" -ForegroundColor Red
    Write-Host "  Check NSG rules and private endpoint configuration" -ForegroundColor Yellow
}

# Test 3: Kerberos Ticket (requires Entra-joined device)
Write-Host "`n[Test 3] Kerberos Authentication..." -ForegroundColor Yellow
try {
    $klistOutput = klist get "cifs/$fqdn" 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Kerberos ticket obtained successfully" -ForegroundColor Green
        Write-Host "  Entra Kerberos authentication is working" -ForegroundColor Gray
    } else {
        Write-Host "⚠ Could not obtain Kerberos ticket" -ForegroundColor Yellow
        Write-Host "  This is normal if not on Entra-joined device" -ForegroundColor Gray
    }
} catch {
    Write-Host "⚠ Kerberos test skipped (device may not be Entra-joined)" -ForegroundColor Yellow
}

Write-Host "`n=== TEST COMPLETE ===" -ForegroundColor Cyan
```

---

## Troubleshooting

### Issue: DNS resolves to public IP instead of private IP

**Cause:** Private DNS zone not linked to VNet or DNS not configured

**Solution:**
1. Verify private DNS zone exists: `privatelink.file.core.windows.net`
2. Verify VNet links are created for both hub and spoke VNets
3. Check VNet DNS settings:
   - Should be **Default (Azure-provided)** OR
   - Custom DNS servers that forward to Azure DNS (168.63.129.16)

### Issue: Port 445 blocked

**Cause:** NSG rules blocking traffic or no route to private endpoint

**Solution:**
1. Check NSG on session host subnet allows outbound to 10.1.4.0/24 (private endpoint subnet)
2. Check NSG on private endpoint subnet allows inbound from session host subnet
3. Verify no UDR forcing traffic through firewall

### Issue: Cannot obtain Kerberos ticket

**Cause:** Entra Kerberos not enabled on storage account

**Solution:**
```powershell
Set-AzStorageAccount `
    -ResourceGroupName "RG-Azure-VDI-01" `
    -Name "YOUR_STORAGE_ACCOUNT" `
    -EnableAzureActiveDirectoryKerberosForFile $true
```

### Issue: "Access Denied" when accessing file share

**Cause:** RBAC permissions not assigned

**Solution:** See next guide `07-RBAC-Assignments.md` for proper RBAC configuration

---

## Next Steps

1. ✓ Storage account created with Entra Kerberos
2. ✓ Private endpoint configured
3. ✓ DNS resolution tested
4. ⏭ Next: Create Entra ID groups (Guide 03)
5. ⏭ Next: Create host pool and workspace (Guide 04)
6. ⏭ Next: Configure Intune FSLogix policies (Guide 07)

---

## Configuration Reference

**Storage Account Name:** `YOUR_STORAGE_ACCOUNT` (e.g., `fslogix52847`)
**File Share Name:** `fslogix-profiles`
**UNC Path:** `\\YOUR_STORAGE_ACCOUNT.file.core.windows.net\fslogix-profiles`
**Private Endpoint Name:** `pe-fslogix-files`
**Private IP Range:** `10.1.4.x`
**DNS Zone:** `privatelink.file.core.windows.net`

**FSLogix Configuration Value (for Intune - use in later guides):**
```
VHDLocations: \\YOUR_STORAGE_ACCOUNT.file.core.windows.net\fslogix-profiles
```

---

**Document Version:** 1.0  
**Last Updated:** December 2, 2025
