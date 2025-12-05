#!/bin/bash
set -euo pipefail

RESOURCE_GROUP="RG-Azure-VDI-01"
LOCATION="centralus"
HOST_POOL_NAME="Pool-Pooled-Prod"
HOST_POOL_TYPE="Pooled"
MAX_SESSIONS="10"
LOAD_BALANCER="BreadthFirst"
TAGS="environment={{AZURE_ENVIRONMENT}} project=avd-deployment managed_by=azure-cli-automation"

echo "[START] Starting 'Create AVD Host Pool' operation..."

echo "[PROGRESS] Checking if host pool '$HOST_POOL_NAME' already exists..."
if az desktopvirtualization hostpool show --name "$HOST_POOL_NAME" --resource-group "$RESOURCE_GROUP" &>/dev/null; then
  echo "[SUCCESS] Host pool '$HOST_POOL_NAME' already exists."
  exit 0
fi

echo "[PROGRESS] Host pool '$HOST_POOL_NAME' not found. Creating..."
az desktopvirtualization hostpool create \
  --name "$HOST_POOL_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --host-pool-type "$HOST_POOL_TYPE" \
  --load-balancer-type "$LOAD_BALANCER" \
  --max-sessions-limit "$MAX_SESSIONS" \
  --friendly-name "$HOST_POOL_NAME" \
  --tags $TAGS \
  --output none

echo "[SUCCESS] Successfully created host pool '$HOST_POOL_NAME'."
