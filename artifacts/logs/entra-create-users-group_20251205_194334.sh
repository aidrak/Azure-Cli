#!/bin/bash
# ==============================================================================
# Create AVD Users Security Group
# ==============================================================================

set -euo pipefail

echo "[START] Creating AVD Users security group: $(date '+%Y-%m-%d %H:%M:%S')"

# Configuration from config.yaml
GROUP_NAME="AVD-Users-Standard"
GROUP_DESCRIPTION="Standard users with access to AVD resources"

# Generate mail nickname (lowercase, no spaces)
MAIL_NICKNAME=$(echo "$GROUP_NAME" | tr ' ' '-' | tr '[:upper:]' '[:lower:]')

# Check if group already exists (idempotent)
echo "[PROGRESS] Checking if group exists: $GROUP_NAME"

GROUP_ID=$(az ad group list \
  --filter "displayName eq '$GROUP_NAME'" \
  --query "[0].id" -o tsv 2>/dev/null || echo "")

if [[ -n "$GROUP_ID" && "$GROUP_ID" != "None" ]]; then
  echo "[INFO] Group already exists: $GROUP_NAME"
  echo "[INFO]   Group ID: $GROUP_ID"
  echo "[SUCCESS] Users group creation complete (already exists)"

  # Save group details to artifacts
  az ad group show --group "$GROUP_ID" \
    --output json > artifacts/outputs/entra-create-users-group.json

  exit 0
fi

# Create security group
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

# Validate creation
echo "[VALIDATE] Verifying group creation..."

if ! az ad group show --group "$GROUP_ID" &>/dev/null; then
  echo "[ERROR] Group verification failed"
  exit 1
fi

# Get full group details
GROUP_DETAILS=$(az ad group show --group "$GROUP_ID" --output json)

# Save to artifacts
echo "$GROUP_DETAILS" > artifacts/outputs/entra-create-users-group.json

# Extract security enabled flag
SECURITY_ENABLED=$(echo "$GROUP_DETAILS" | jq -r '.securityEnabled')

echo "[SUCCESS] AVD Users group created successfully"
echo "[SUCCESS]   Name: $GROUP_NAME"
echo "[SUCCESS]   ID: $GROUP_ID"
echo "[SUCCESS]   Mail nickname: $MAIL_NICKNAME"
echo "[SUCCESS]   Security enabled: $SECURITY_ENABLED"
echo ""
echo "[INFO] Next steps:"
echo "[INFO]   - Add user members: az ad group member add --group '$GROUP_ID' --member-id <user-object-id>"
echo "[INFO]   - Use for RBAC assignments in Module 08"
echo "[INFO]   - Use for application group assignments in Module 04"

exit 0
