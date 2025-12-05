echo "[START] Resource group creation: $(date '+%Y-%m-%d %H:%M:%S')"

RESOURCE_GROUP="RG-Azure-VDI-01"
LOCATION="centralus"

echo "[PROGRESS] Checking if resource group exists..."
if az group show --name "$RESOURCE_GROUP" &>/dev/null; then
    echo "[INFO] Resource group already exists: $RESOURCE_GROUP"
    RG_LOCATION=$(az group show --name "$RESOURCE_GROUP" --query location -o tsv)
    echo "[VALIDATE] Current location: $RG_LOCATION"

    if [[ "$RG_LOCATION" != "$LOCATION" ]]; then
        echo "[WARNING] Resource group exists in different location"
        echo "[WARNING]   Expected: $LOCATION"
        echo "[WARNING]   Actual: $RG_LOCATION"
        echo "[WARNING] Using existing resource group location"
    fi

    echo "[SUCCESS] Resource group verified: $RESOURCE_GROUP"
    exit 0
fi

echo "[PROGRESS] Creating resource group..."
echo "[PROGRESS]   Name: $RESOURCE_GROUP"
echo "[PROGRESS]   Location: $LOCATION"

if az group create \
    --name "$RESOURCE_GROUP" \
    --location "$LOCATION" \
    --output json > /tmp/rg-create-output.json; then

    echo "[VALIDATE] Verifying creation..."
    CREATED_LOCATION=$(jq -r '.location' /tmp/rg-create-output.json)
    PROVISIONING_STATE=$(jq -r '.properties.provisioningState' /tmp/rg-create-output.json)

    echo "[INFO] Location: $CREATED_LOCATION"
    echo "[INFO] Provisioning State: $PROVISIONING_STATE"

    if [[ "$PROVISIONING_STATE" == "Succeeded" ]]; then
        echo "[SUCCESS] Resource group created successfully"
        rm -f /tmp/rg-create-output.json
        exit 0
    else
        echo "[ERROR] Unexpected provisioning state: $PROVISIONING_STATE"
        rm -f /tmp/rg-create-output.json
        exit 1
    fi
else
    echo "[ERROR] Failed to create resource group"
    exit 1
fi
