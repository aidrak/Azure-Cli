#!/bin/bash
set -euo pipefail

RESOURCE_GROUP="RG-Azure-VDI-01"
HOST_POOL_NAME="Pool-Pooled-Prod"

echo "[START] Starting 'Configure Host Pool RDP Properties' operation..."

RDP_PROPERTIES="audiocapturemode:i:0;audiomode:i:0;camerastoredirect:s:*;clipboardredirect:i:1;drivestoredirect:s:;usbdevicestoredirect:s:*;use multimon:i:1;promptcredentialonce:i:0;promptfordestinationcert:i:1;devicestoredirect:s:*"

echo "[PROGRESS] Applying RDP properties to host pool '$HOST_POOL_NAME'..."

az desktopvirtualization host-pool update \
  --name "$HOST_POOL_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --custom-rdp-property "$RDP_PROPERTIES" \
  --output none

echo "[SUCCESS] Successfully configured RDP properties on host pool '$HOST_POOL_NAME'."
