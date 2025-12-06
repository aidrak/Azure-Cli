cat > /tmp/networking-12-create-gateway-subnet-wrapper.ps1 << 'PSWRAPPER'
Write-Host "[START] Gateway subnet creation: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC')"

$vnetName = "avd-vnet"
$resourceGroup = "RG-Azure-VDI-01"

# Check if VPN gateway is enabled
$vpnEnabled = (yq e '.networking.vpn_gateway.enabled' config.yaml)

if ($vpnEnabled -ne "true") {
  Write-Host "[INFO] VPN Gateway disabled - skipping gateway subnet creation"
  exit 0
}

$gatewaySubnetName = "GatewaySubnet"
$gatewaySubnetPrefix = "10.0.255.0/27" # Standard /27 subnet for gateways

Write-Host "[PROGRESS] Checking if GatewaySubnet already exists..."

az network vnet subnet show `
  --resource-group $resourceGroup `
  --vnet-name $vnetName `
  --name $gatewaySubnetName `
  --output none 2>$null

if ($LASTEXITCODE -eq 0) {
  Write-Host "[INFO] GatewaySubnet already exists"
  exit 0
}

Write-Host "[PROGRESS] Creating GatewaySubnet with prefix: $gatewaySubnetPrefix"

az network vnet subnet create `
  --resource-group $resourceGroup `
  --vnet-name $vnetName `
  --name $gatewaySubnetName `
  --address-prefix $gatewaySubnetPrefix `
  --output none

if ($LASTEXITCODE -ne 0) {
  Write-Host "[ERROR] Failed to create GatewaySubnet"
  exit 1
}

Write-Host "[SUCCESS] GatewaySubnet created successfully"
exit 0
PSWRAPPER
pwsh -NoProfile -NonInteractive -File /tmp/networking-12-create-gateway-subnet-wrapper.ps1
rm -f /tmp/networking-12-create-gateway-subnet-wrapper.ps1
