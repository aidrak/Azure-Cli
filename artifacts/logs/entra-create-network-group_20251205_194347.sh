#!/bin/bash
set -euo pipefail

echo "[START] Creating Network device security group: $(date '+%Y-%m-%d %H:%M:%S')"

GROUP_NAME="AVD-Devices-Pooled-Network"
GROUP_DESCRIPTION="Device group for network configuration policies"
MAIL_NICKNAME=$(echo "$GROUP_NAME" | tr ' ' '-' | tr '[:upper:]' '[:lower:]')

echo "[PROGRESS] Checking if group exists: $GROUP_NAME"

GROUP_ID=$(az ad group list \
  --filter "displayName eq '$GROUP_NAME'" \
  --query "[0].id" -o tsv 2>/dev/null || echo "")

if [[ -n "$GROUP_ID" && "$GROUP_ID" != "None" ]]; then
  echo "[INFO] Group already exists: $GROUP_NAME"
  echo "[SUCCESS] Network device group creation complete (already exists)"
  az ad group show --group "$GROUP_ID" \
    --output json > artifacts/outputs/entra-create-network-group.json
  exit 0
fi

echo "[PROGRESS] Creating security group for network devices..."

if ! GROUP_ID=$(az ad group create \
  --display-name "$GROUP_NAME" \
  --mail-nickname "$MAIL_NICKNAME" \
  --description "$GROUP_DESCRIPTION" \
  --query id -o tsv 2>&1); then
  echo "[ERROR] Failed to create security group: $GROUP_ID"
  exit 1
fi

echo "[VALIDATE] Verifying group creation..."
GROUP_DETAILS=$(az ad group show --group "$GROUP_ID" --output json)
echo "$GROUP_DETAILS" > artifacts/outputs/entra-create-network-group.json

echo "[SUCCESS] Network device group created: $GROUP_NAME (ID: $GROUP_ID)"
echo "[INFO] Use this group for network configuration policies"

exit 0
