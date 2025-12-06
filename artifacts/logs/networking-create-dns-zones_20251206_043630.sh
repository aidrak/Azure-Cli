cat > /tmp/networking-07-create-dns-zones-wrapper.ps1 << 'PSWRAPPER'
Write-Host "[START] Private DNS zone creation: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC')"

$resourceGroup = "RG-Azure-VDI-01"

# Check if private DNS is enabled
$dnsEnabled = (yq e '.networking.private_dns.enabled' config.yaml)

if ($dnsEnabled -ne "true") {
  Write-Host "[INFO] Private DNS disabled - skipping"
  exit 0
}

$zoneCount = [int](yq e '.networking.private_dns.zones | length' config.yaml)
Write-Host "[PROGRESS] Creating $zoneCount private DNS zone(s)..."

for ($i = 0; $i -lt $zoneCount; $i++) {
  $zoneName = (yq e ".networking.private_dns.zones[$i].name" config.yaml)

  Write-Host "[PROGRESS] Processing zone: $zoneName"

  az network private-dns zone show `
    --resource-group $resourceGroup `
    --name $zoneName `
    --output none 2>$null

  if ($LASTEXITCODE -eq 0) {
    Write-Host "[INFO] Zone already exists: $zoneName"
    continue
  }

  $safeZoneName = $zoneName -replace '\.', '-'
  $outputFile = "artifacts/outputs/networking-dns-zone-$safeZoneName.json"

  az network private-dns zone create `
    --resource-group $resourceGroup `
    --name $zoneName `
    --output json > $outputFile

  if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Failed to create zone: $zoneName"
    exit 1
  }

  Write-Host "[SUCCESS] Zone created: $zoneName"
}

Write-Host "[SUCCESS] All private DNS zones created"
exit 0
PSWRAPPER
pwsh -NoProfile -NonInteractive -File /tmp/networking-07-create-dns-zones-wrapper.ps1
rm -f /tmp/networking-07-create-dns-zones-wrapper.ps1
