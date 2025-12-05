#!/bin/bash
set -euo pipefail

RESOURCE_GROUP="RG-Azure-VDI-01"
LOCATION="centralus"
HOST_POOL_NAME="Pool-Pooled-Prod"
APP_GROUP_NAME="Desktop-Prod"
APP_GROUP_FRIENDLY_NAME="{{APP_GROUP_FRIENDLY_NAME}}"
TAGS="environment={{AZURE_ENVIRONMENT}} project=avd-deployment managed_by=azure-cli-automation"

echo "[START] Starting 'Create Desktop Application Group' operation..."

echo "[PROGRESS] Checking if application group '$APP_GROUP_NAME' already exists..."
if az desktopvirtualization applicationgroup show --name "$APP_GROUP_NAME" --resource-group "$RESOURCE_GROUP" &>/dev/null; then
  echo "[SUCCESS] Application group '$APP_GROUP_NAME' already exists."
  exit 0
fi

echo "[PROGRESS] Application group '$APP_GROUP_NAME' not found. Creating..."
HOST_POOL_ID=$(az desktopvirtualization hostpool show --name "$HOST_POOL_NAME" --resource-group "$RESOURCE_GROUP" --query "id" -o tsv)

az desktopvirtualization applicationgroup create \
  --name "$APP_GROUP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --application-group-type "Desktop" \
  --host-pool-arm-path "$HOST_POOL_ID" \
  --friendly-name "$APP_GROUP_FRIENDLY_NAME" \
  --tags $TAGS \
  --output none

echo "[SUCCESS] Successfully created application group '$APP_GROUP_NAME'."
