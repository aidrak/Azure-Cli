# Get storage account name (from previous operation or config)
if [ -f /tmp/storage-account-name.txt ]; then
  STORAGE_NAME=$(cat /tmp/storage-account-name.txt)
else
  STORAGE_NAME=""
fi

echo "[START] Disabling public network access at $(date +%H:%M:%S)"
echo "  Storage account: $STORAGE_NAME"

# Check current public network access setting
echo "[PROGRESS] Checking current network access configuration..."

CURRENT_ACCESS=$(az storage account show \
  --resource-group "RG-Azure-VDI-01" \
  --name "$STORAGE_NAME" \
  --query publicNetworkAccess \
  -o tsv 2>/dev/null || echo "Enabled")

if [[ "$CURRENT_ACCESS" == "Disabled" ]]; then
  echo "[SUCCESS] Public network access already disabled"
  exit 0
fi

echo "[PROGRESS] Disabling public network access..."
echo "[WARNING] After this operation, storage will only be accessible via private endpoint"

# Disable public network access
if az storage account update \
  --resource-group "RG-Azure-VDI-01" \
  --name "$STORAGE_NAME" \
  --public-network-access Disabled \
  --output json > /tmp/public-access.json; then

  echo "[VALIDATE] Verifying network access configuration..."

  # Wait 3 seconds for configuration to propagate
  sleep 3

  # Verify public access is disabled
  NEW_ACCESS=$(az storage account show \
    --resource-group "RG-Azure-VDI-01" \
    --name "$STORAGE_NAME" \
    --query publicNetworkAccess \
    -o tsv)

  if [[ "$NEW_ACCESS" == "Disabled" ]]; then
    echo "[SUCCESS] Public network access disabled"
    echo "  Network access: Private endpoint only"
    echo "  Public internet: Blocked"
    echo "  Security: Enhanced (zero-trust networking)"
    exit 0
  else
    echo "[ERROR] Network access configuration verification failed"
    echo "  Expected: Disabled"
    echo "  Got: $NEW_ACCESS"
    exit 1
  fi
else
  echo "[ERROR] Failed to disable public network access"
  cat /tmp/public-access.json
  exit 1
fi
