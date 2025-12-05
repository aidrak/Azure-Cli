#!/bin/bash
set -euo pipefail

RESOURCE_GROUP="RG-Azure-VDI-01"
HOST_POOL_NAME="Pool-Pooled-Prod"
APP_GROUP_NAME="Desktop-Prod"
WORKSPACE_NAME="AVD-Workspace-Prod"

echo "[START] Starting 'Validate Host Pool and Workspace' operation..."

ALL_VALID=true

echo "[VALIDATE] Validating host pool '$HOST_POOL_NAME'..."
if az desktopvirtualization hostpool show --name "$HOST_POOL_NAME" --resource-group "$RESOURCE_GROUP" &>/dev/null; then
  echo "[INFO] Host pool '$HOST_POOL_NAME' exists."
else
  echo "[ERROR] Host pool '$HOST_POOL_NAME' not found."
  ALL_VALID=false
fi

echo "[VALIDATE] Validating application group '$APP_GROUP_NAME'..."
if az desktopvirtualization applicationgroup show --name "$APP_GROUP_NAME" --resource-group "$RESOURCE_GROUP" &>/dev/null; then
  echo "[INFO] Application group '$APP_GROUP_NAME' exists."
else
  echo "[ERROR] Application group '$APP_GROUP_NAME' not found."
  ALL_VALID=false
fi

echo "[VALIDATE] Validating workspace '$WORKSPACE_NAME'..."
if az desktopvirtualization workspace show --name "$WORKSPACE_NAME" --resource-group "$RESOURCE_GROUP" &>/dev/null; then
  echo "[INFO] Workspace '$WORKSPACE_NAME' exists."
else
  echo "[ERROR] Workspace '$WORKSPACE_NAME' not found."
  ALL_VALID=false
fi

if [ "$ALL_VALID" = true ]; then
  echo "[SUCCESS] All Host Pool and Workspace resources are correctly provisioned."
else
  echo "[ERROR] One or more Host Pool and Workspace resources are missing. Please check the logs."
  exit 1
fi
