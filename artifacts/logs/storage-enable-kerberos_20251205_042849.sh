# Get storage account name (from previous operation or config)
if [ -f /tmp/storage-account-name.txt ]; then
  STORAGE_NAME=$(cat /tmp/storage-account-name.txt)
else
  STORAGE_NAME=""
fi

echo "[START] Enabling Entra Kerberos authentication at $(date +%H:%M:%S)"
echo "  Storage account: $STORAGE_NAME"

# Check current Kerberos configuration
echo "[PROGRESS] Checking current authentication configuration..."

CURRENT_CONFIG=$(az storage account show \
  --resource-group "RG-Azure-VDI-01" \
  --name "$STORAGE_NAME" \
  --query "azureFilesIdentityBasedAuthentication.directoryServiceOptions" \
  -o tsv 2>/dev/null || echo "None")

if [[ "$CURRENT_CONFIG" == "AADKERB" ]] || [[ "$CURRENT_CONFIG" == "AADDS" ]]; then
  echo "[SUCCESS] Kerberos authentication already enabled: $CURRENT_CONFIG"
  exit 0
fi

echo "[PROGRESS] Enabling Microsoft Entra Kerberos (AADKERB)..."

# Enable Entra Kerberos authentication
if az storage account update \
  --resource-group "RG-Azure-VDI-01" \
  --name "$STORAGE_NAME" \
  --enable-files-aadkerb true \
  --output json > /tmp/kerberos-config.json; then

  echo "[VALIDATE] Verifying Kerberos configuration..."

  # Wait 5 seconds for configuration to propagate
  sleep 5

  # Verify Kerberos is enabled
  NEW_CONFIG=$(az storage account show \
    --resource-group "RG-Azure-VDI-01" \
    --name "$STORAGE_NAME" \
    --query "azureFilesIdentityBasedAuthentication.directoryServiceOptions" \
    -o tsv)

  if [[ "$NEW_CONFIG" == "AADKERB" ]]; then
    echo "[SUCCESS] Entra Kerberos authentication enabled"
    echo "  Authentication method: $NEW_CONFIG"
    echo "  Domain name: Entra-only (no domain GUID required)"
    echo "  Users can now mount shares with domain credentials"
    exit 0
  else
    echo "[ERROR] Kerberos configuration verification failed"
    echo "  Expected: AADKERB"
    echo "  Got: $NEW_CONFIG"
    exit 1
  fi
else
  echo "[ERROR] Failed to enable Kerberos authentication"
  cat /tmp/kerberos-config.json
  exit 1
fi
