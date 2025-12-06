cat > /tmp/networking-01-create-vnet-wrapper.ps1 << 'PSWRAPPER'
Write-Host "[START] VNet creation: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC')"

# Configuration from config.yaml
$vnetName = "avd-vnet"
$resourceGroup = "RG-Azure-VDI-01"
$location = "centralus"

# Parse address space from config.yaml
$addressSpace = (yq e '.networking.vnet.address_space | join(" ")' config.yaml)

# Parse custom DNS servers (if configured)
$dnsServersCount = [int](yq e '.networking.vnet.dns_servers | length' config.yaml)
$dnsServers = ""

if ($dnsServersCount -gt 0) {
  $dnsServers = (yq e '.networking.vnet.dns_servers | join(" ")' config.yaml)
}

# Check if VNet already exists (idempotent)
Write-Host "[PROGRESS] Checking if VNet exists..."
az network vnet show `
  --resource-group $resourceGroup `
  --name $vnetName `
  --output none 2>$null

if ($LASTEXITCODE -eq 0) {
  Write-Host "[INFO] VNet already exists: $vnetName"
  Write-Host "[SUCCESS] VNet creation complete (already exists)"
  exit 0
}

# Create VNet
Write-Host "[PROGRESS] Creating VNet: $vnetName"
Write-Host "[PROGRESS]   Address space: $addressSpace"
Write-Host "[PROGRESS]   Location: $location"

if (-not [string]::IsNullOrEmpty($dnsServers)) {
  Write-Host "[PROGRESS]   Custom DNS servers: $dnsServers"

  $addressPrefixArray = $addressSpace -split ' '
  $dnsServerArray = $dnsServers -split ' '

  az network vnet create `
    --resource-group $resourceGroup `
    --name $vnetName `
    --address-prefixes @addressPrefixArray `
    --location $location `
    --dns-servers @dnsServerArray `
    --output json > artifacts/outputs/networking-create-vnet.json
} else {
  $addressPrefixArray = $addressSpace -split ' '

  az network vnet create `
    --resource-group $resourceGroup `
    --name $vnetName `
    --address-prefixes @addressPrefixArray `
    --location $location `
    --output json > artifacts/outputs/networking-create-vnet.json
}

if ($LASTEXITCODE -ne 0) {
  Write-Host "[ERROR] Failed to create VNet"
  exit 1
}

# Validate creation
Write-Host "[VALIDATE] Checking VNet provisioning state..."
$provisioningState = az network vnet show `
  --resource-group $resourceGroup `
  --name $vnetName `
  --query "provisioningState" -o tsv

if ($provisioningState -ne "Succeeded") {
  Write-Host "[ERROR] VNet provisioning failed: $provisioningState"
  exit 1
}

# Get VNet ID for reference
$vnetId = az network vnet show `
  --resource-group $resourceGroup `
  --name $vnetName `
  --query "id" -o tsv

Write-Host "[SUCCESS] VNet created successfully"
Write-Host "[SUCCESS]   Name: $vnetName"
Write-Host "[SUCCESS]   ID: $vnetId"
Write-Host "[SUCCESS]   State: $provisioningState"
exit 0
PSWRAPPER
pwsh -NoProfile -NonInteractive -File /tmp/networking-01-create-vnet-wrapper.ps1
rm -f /tmp/networking-01-create-vnet-wrapper.ps1
