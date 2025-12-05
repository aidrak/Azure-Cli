DNS_ZONE_NAME="privatelink.file.core.windows.net"
VNET_NAME="avd-vnet"

echo "[START] Configuring private DNS zone at $(date +%H:%M:%S)"
echo "  DNS zone: $DNS_ZONE_NAME"
echo "  VNet: $VNET_NAME"

# Check if private DNS zone exists
echo "[PROGRESS] Checking if private DNS zone exists..."

if az network private-dns zone show \
  --resource-group "RG-Azure-VDI-01" \
  --name "$DNS_ZONE_NAME" &>/dev/null; then

  echo "[SUCCESS] Private DNS zone already exists: $DNS_ZONE_NAME"
else
  echo "[PROGRESS] Creating private DNS zone..."

  if az network private-dns zone create \
    --resource-group "RG-Azure-VDI-01" \
    --name "$DNS_ZONE_NAME" \
    --output json > /tmp/dns-zone.json; then

    echo "[SUCCESS] Private DNS zone created: $DNS_ZONE_NAME"
  else
    echo "[ERROR] Failed to create private DNS zone"
    cat /tmp/dns-zone.json
    exit 1
  fi
fi

# Check if VNet link exists
echo "[PROGRESS] Checking VNet link..."

LINK_NAME="${VNET_NAME}-link"

if az network private-dns link vnet show \
  --resource-group "RG-Azure-VDI-01" \
  --zone-name "$DNS_ZONE_NAME" \
  --name "$LINK_NAME" &>/dev/null; then

  echo "[SUCCESS] VNet link already exists: $LINK_NAME"
else
  echo "[PROGRESS] Creating VNet link..."

  # Get VNet ID
  VNET_ID=$(az network vnet show \
    --resource-group "RG-Azure-VDI-01" \
    --name "$VNET_NAME" \
    --query id -o tsv)

  if [ -z "$VNET_ID" ]; then
    echo "[ERROR] VNet not found: $VNET_NAME"
    exit 1
  fi

  # Create VNet link
  if az network private-dns link vnet create \
    --resource-group "RG-Azure-VDI-01" \
    --zone-name "$DNS_ZONE_NAME" \
    --name "$LINK_NAME" \
    --virtual-network "$VNET_ID" \
    --registration-enabled false \
    --output json > /tmp/vnet-link.json; then

    echo "[SUCCESS] VNet link created: $LINK_NAME"
  else
    echo "[ERROR] Failed to create VNet link"
    cat /tmp/vnet-link.json
    exit 1
  fi
fi

echo "[VALIDATE] Verifying DNS zone configuration..."

# Verify DNS zone exists
DNS_ZONE_ID=$(az network private-dns zone show \
  --resource-group "RG-Azure-VDI-01" \
  --name "$DNS_ZONE_NAME" \
  --query id -o tsv)

# Verify VNet link exists
LINK_STATE=$(az network private-dns link vnet show \
  --resource-group "RG-Azure-VDI-01" \
  --zone-name "$DNS_ZONE_NAME" \
  --name "$LINK_NAME" \
  --query virtualNetworkLinkState -o tsv)

if [[ "$LINK_STATE" == "Completed" ]]; then
  echo "[SUCCESS] Private DNS zone configured successfully"
  echo "  DNS zone ID: $DNS_ZONE_ID"
  echo "  VNet link: $LINK_NAME"
  echo "  Link state: $LINK_STATE"
  echo "  Auto-registration: Disabled"
  echo ""
  echo "[INFO] DNS Resolution:"
  echo "  Storage accounts will resolve to private IPs within VNet"
  echo "  Pattern: <storage-account>.file.core.windows.net -> <private-ip>"
  exit 0
else
  echo "[ERROR] VNet link state is not 'Completed': $LINK_STATE"
  exit 1
fi
