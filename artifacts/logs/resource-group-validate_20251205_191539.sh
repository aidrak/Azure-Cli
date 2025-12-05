echo "[START] Resource group validation: $(date '+%Y-%m-%d %H:%M:%S')"

RESOURCE_GROUP="RG-Azure-VDI-01"
EXPECTED_LOCATION="centralus"

echo "[PROGRESS] Validating resource group: $RESOURCE_GROUP"

# Check if resource group exists
if ! az group show --name "$RESOURCE_GROUP" --output json > /tmp/rg-info.json 2>/dev/null; then
    echo "[ERROR] Resource group not found: $RESOURCE_GROUP"
    exit 1
fi

# Extract details
ACTUAL_LOCATION=$(jq -r '.location' /tmp/rg-info.json)
PROVISIONING_STATE=$(jq -r '.properties.provisioningState' /tmp/rg-info.json)
RG_ID=$(jq -r '.id' /tmp/rg-info.json)

echo "[VALIDATE] Resource Group ID: $RG_ID"
echo "[VALIDATE] Location: $ACTUAL_LOCATION (expected: $EXPECTED_LOCATION)"
echo "[VALIDATE] Provisioning State: $PROVISIONING_STATE"

# Validate provisioning state
if [[ "$PROVISIONING_STATE" != "Succeeded" ]]; then
    echo "[ERROR] Resource group is not in 'Succeeded' state"
    echo "[ERROR] Current state: $PROVISIONING_STATE"
    rm -f /tmp/rg-info.json
    exit 1
fi

# Validate location (warning only if different)
if [[ "$ACTUAL_LOCATION" != "$EXPECTED_LOCATION" ]]; then
    echo "[WARNING] Location mismatch (using existing location)"
    echo "[WARNING]   Expected: $EXPECTED_LOCATION"
    echo "[WARNING]   Actual: $ACTUAL_LOCATION"
fi

# Check permissions (try to list resources)
echo "[VALIDATE] Checking permissions..."
if az resource list --resource-group "$RESOURCE_GROUP" --output none; then
    echo "[SUCCESS] Resource group is accessible and ready"
else
    echo "[ERROR] Cannot list resources in resource group (permission issue?)"
    rm -f /tmp/rg-info.json
    exit 1
fi

rm -f /tmp/rg-info.json
echo "[SUCCESS] Resource group validation complete"
exit 0
