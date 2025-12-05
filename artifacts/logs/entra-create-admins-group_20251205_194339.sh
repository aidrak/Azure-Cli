#!/bin/bash
set -euo pipefail

echo "[START] Creating AVD Admins security group: $(date '+%Y-%m-%d %H:%M:%S')"

GROUP_NAME="AVD-Users-Admins"
GROUP_DESCRIPTION="Administrative users with elevated AVD access"
MAIL_NICKNAME=$(echo "$GROUP_NAME" | tr ' ' '-' | tr '[:upper:]' '[:lower:]')

echo "[PROGRESS] Checking if group exists: $GROUP_NAME"

GROUP_ID=$(az ad group list \
  --filter "displayName eq '$GROUP_NAME'" \
  --query "[0].id" -o tsv 2>/dev/null || echo "")

if [[ -n "$GROUP_ID" && "$GROUP_ID" != "None" ]]; then
  echo "[INFO] Group already exists: $GROUP_NAME"
  echo "[INFO]   Group ID: $GROUP_ID"
  echo "[SUCCESS] Admins group creation complete (already exists)"

  az ad group show --group "$GROUP_ID" \
    --output json > artifacts/outputs/entra-create-admins-group.json

  exit 0
fi

echo "[PROGRESS] Creating security group..."
echo "[PROGRESS]   Name: $GROUP_NAME"
echo "[PROGRESS]   Description: $GROUP_DESCRIPTION"
echo "[PROGRESS]   Mail nickname: $MAIL_NICKNAME"

if ! GROUP_ID=$(az ad group create \
  --display-name "$GROUP_NAME" \
  --mail-nickname "$MAIL_NICKNAME" \
  --description "$GROUP_DESCRIPTION" \
  --query id -o tsv 2>&1); then

  echo "[ERROR] Failed to create security group"
  echo "[ERROR] $GROUP_ID"
  exit 1
fi

echo "[VALIDATE] Verifying group creation..."

if ! az ad group show --group "$GROUP_ID" &>/dev/null; then
  echo "[ERROR] Group verification failed"
  exit 1
fi

GROUP_DETAILS=$(az ad group show --group "$GROUP_ID" --output json)
echo "$GROUP_DETAILS" > artifacts/outputs/entra-create-admins-group.json

SECURITY_ENABLED=$(echo "$GROUP_DETAILS" | jq -r '.securityEnabled')

echo "[SUCCESS] AVD Admins group created successfully"
echo "[SUCCESS]   Name: $GROUP_NAME"
echo "[SUCCESS]   ID: $GROUP_ID"
echo "[SUCCESS]   Mail nickname: $MAIL_NICKNAME"
echo "[SUCCESS]   Security enabled: $SECURITY_ENABLED"
echo ""
echo "[INFO] Next steps:"
echo "[INFO]   - Add admin members: az ad group member add --group '$GROUP_ID' --member-id <user-object-id>"
echo "[INFO]   - Use for privileged RBAC assignments (e.g., Virtual Machine Administrator Login)"

exit 0
