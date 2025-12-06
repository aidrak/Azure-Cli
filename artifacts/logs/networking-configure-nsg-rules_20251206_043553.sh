cat > /tmp/networking-04-configure-nsg-rules-wrapper.ps1 << 'PSWRAPPER'
Write-Host "[START] NSG rule configuration: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC')"

# Configuration
$resourceGroup = "RG-Azure-VDI-01"

# Get subnet count
$subnetCount = [int](yq e '.networking.subnets | length' config.yaml)
$script:ruleCount = 0

Write-Host "[PROGRESS] Configuring NSG rules for $subnetCount subnet(s)..."

# Function to create NSG rule
function Create-NsgRule {
  param(
    [string]$NsgName,
    [string]$RuleName,
    [int]$Priority,
    [string]$Direction,
    [string]$Access,
    [string]$Protocol,
    [string]$SrcPrefix,
    [string]$SrcPort,
    [string]$DstPrefix,
    [string]$DstPort
  )

  # Check if rule already exists
  az network nsg rule show `
    --resource-group $resourceGroup `
    --nsg-name $NsgName `
    --name $RuleName `
    --output none 2>$null

  if ($LASTEXITCODE -eq 0) {
    Write-Host "[INFO] Rule already exists: $RuleName"
    return $true
  }

  # Create rule
  az network nsg rule create `
    --resource-group $resourceGroup `
    --nsg-name $NsgName `
    --name $RuleName `
    --priority $Priority `
    --direction $Direction `
    --access $Access `
    --protocol $Protocol `
    --source-address-prefixes $SrcPrefix `
    --source-port-ranges $SrcPort `
    --destination-address-prefixes $DstPrefix `
    --destination-port-ranges $DstPort `
    --output none

  if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Failed to create rule: $RuleName"
    return $false
  }

  Write-Host "[SUCCESS] Rule created: $RuleName (Priority: $Priority)"
  $script:ruleCount++
  return $true
}

# Iterate through subnets
for ($i = 0; $i -lt $subnetCount; $i++) {
  # Check if NSG enabled
  $nsgEnabled = (yq e ".networking.subnets[$i].nsg.enabled" config.yaml)

  if ($nsgEnabled -ne "true") {
    continue
  }

  # Get subnet and NSG names
  $subnetName = (yq e ".networking.subnets[$i].name" config.yaml)
  $nsgName = (yq e ".networking.subnets[$i].nsg.name" config.yaml)

  # Auto-generate NSG name if empty
  if ([string]::IsNullOrEmpty($nsgName) -or $nsgName -eq "null") {
    $nsgName = "nsg-$subnetName"
  }

  # Check if using defaults
  $useDefaults = (yq e ".networking.subnets[$i].nsg.use_defaults" config.yaml)

  Write-Host "[PROGRESS] Configuring NSG: $nsgName (for subnet: $subnetName)"

  # Apply smart defaults based on subnet name pattern
  if ($useDefaults -eq "true") {
    Write-Host "[PROGRESS]   Applying smart default rules..."

    if ($subnetName -like "*session-host*") {
      Write-Host "[PROGRESS]   Detected: Session Hosts subnet"

      # Allow RDP from VNet
      Create-NsgRule -NsgName $nsgName -RuleName "Allow-RDP-From-VNet" -Priority 100 -Direction "Inbound" -Access "Allow" -Protocol "Tcp" -SrcPrefix "VirtualNetwork" -SrcPort "*" -DstPrefix "VirtualNetwork" -DstPort "3389"

      # Allow AVD control plane (outbound)
      Create-NsgRule -NsgName $nsgName -RuleName "Allow-AVD-Control-Plane" -Priority 110 -Direction "Outbound" -Access "Allow" -Protocol "Tcp" -SrcPrefix "*" -SrcPort "*" -DstPrefix "WindowsVirtualDesktop" -DstPort "443"

      # Allow Azure Monitor (outbound)
      Create-NsgRule -NsgName $nsgName -RuleName "Allow-Azure-Monitor" -Priority 120 -Direction "Outbound" -Access "Allow" -Protocol "Tcp" -SrcPrefix "*" -SrcPort "*" -DstPrefix "AzureMonitor" -DstPort "443"
    }
    elseif ($subnetName -like "*private-endpoint*") {
      Write-Host "[PROGRESS]   Detected: Private Endpoints subnet"

      # Allow VNet inbound
      Create-NsgRule -NsgName $nsgName -RuleName "Allow-VNet-Inbound" -Priority 100 -Direction "Inbound" -Access "Allow" -Protocol "*" -SrcPrefix "VirtualNetwork" -SrcPort "*" -DstPrefix "VirtualNetwork" -DstPort "*"

      # Allow VNet outbound
      Create-NsgRule -NsgName $nsgName -RuleName "Allow-VNet-Outbound" -Priority 100 -Direction "Outbound" -Access "Allow" -Protocol "*" -SrcPrefix "VirtualNetwork" -SrcPort "*" -DstPrefix "VirtualNetwork" -DstPort "*"
    }
    elseif ($subnetName -like "*management*") {
      Write-Host "[PROGRESS]   Detected: Management subnet"

      # Allow HTTPS outbound (for management operations, updates, monitoring)
      Create-NsgRule -NsgName $nsgName -RuleName "Allow-HTTPS-Outbound" -Priority 100 -Direction "Outbound" -Access "Allow" -Protocol "Tcp" -SrcPrefix "*" -SrcPort "*" -DstPrefix "*" -DstPort "443"

      # Allow VNet inbound (for internal management traffic)
      Create-NsgRule -NsgName $nsgName -RuleName "Allow-VNet-Inbound" -Priority 110 -Direction "Inbound" -Access "Allow" -Protocol "*" -SrcPrefix "VirtualNetwork" -SrcPort "*" -DstPrefix "*" -DstPort "*"
    }
    else {
      Write-Host "[INFO]   No pattern match - skipping default rules (subnet: $subnetName)"
    }
  } else {
    Write-Host "[INFO]   Smart defaults disabled for this subnet"
  }

  # Apply custom rules (if defined)
  $customRuleCount = [int](yq e ".networking.subnets[$i].nsg.custom_rules | length" config.yaml)

  if ($customRuleCount -gt 0) {
    Write-Host "[PROGRESS]   Applying $customRuleCount custom rule(s)..."

    for ($j = 0; $j -lt $customRuleCount; $j++) {
      $ruleName = (yq e ".networking.subnets[$i].nsg.custom_rules[$j].name" config.yaml)
      $priority = [int](yq e ".networking.subnets[$i].nsg.custom_rules[$j].priority" config.yaml)
      $direction = (yq e ".networking.subnets[$i].nsg.custom_rules[$j].direction" config.yaml)
      $access = (yq e ".networking.subnets[$i].nsg.custom_rules[$j].access" config.yaml)
      $protocol = (yq e ".networking.subnets[$i].nsg.custom_rules[$j].protocol" config.yaml)
      $srcPrefix = (yq e ".networking.subnets[$i].nsg.custom_rules[$j].source_address_prefix" config.yaml)
      $srcPort = (yq e ".networking.subnets[$i].nsg.custom_rules[$j].source_port_range" config.yaml)
      $dstPrefix = (yq e ".networking.subnets[$i].nsg.custom_rules[$j].destination_address_prefix" config.yaml)
      $dstPort = (yq e ".networking.subnets[$i].nsg.custom_rules[$j].destination_port_range" config.yaml)

      Write-Host "[PROGRESS]   Creating custom rule: $ruleName"
      Create-NsgRule -NsgName $nsgName -RuleName $ruleName -Priority $priority -Direction $direction -Access $access -Protocol $protocol -SrcPrefix $srcPrefix -SrcPort $srcPort -DstPrefix $dstPrefix -DstPort $dstPort
    }
  }

  Write-Host "[SUCCESS] NSG rules configured: $nsgName"
}

Write-Host "[SUCCESS] All NSG rules configured successfully"
Write-Host "[SUCCESS]   Total rules created: $script:ruleCount"

exit 0
PSWRAPPER
pwsh -NoProfile -NonInteractive -File /tmp/networking-04-configure-nsg-rules-wrapper.ps1
rm -f /tmp/networking-04-configure-nsg-rules-wrapper.ps1
