#!/bin/bash
# ==============================================================================
# Create Network Security Groups
# ==============================================================================

set -euo pipefail

echo "[START] NSG creation: $(date '+%Y-%m-%d %H:%M:%S')"

# Configuration
RESOURCE_GROUP="RG-Azure-VDI-01"
LOCATION="centralus"

# Get subnet count
SUBNET_COUNT=$(yq e '.networking.subnets | length' config.yaml)
NSG_COUNT=0

echo "[PROGRESS] Processing $SUBNET_COUNT subnet(s) for NSG creation..."

# Iterate through subnets
for i in $(seq 0 $((SUBNET_COUNT - 1))); do
  # Check if NSG enabled for this subnet
  NSG_ENABLED=$(yq e ".networking.subnets[$i].nsg.enabled" config.yaml)

  if [[ "$NSG_ENABLED" != "true" ]]; then
    continue
  fi

  # Get subnet name
  SUBNET_NAME=$(yq e ".networking.subnets[$i].name" config.yaml)

  # Get or auto-generate NSG name
  NSG_NAME=$(yq e ".networking.subnets[$i].nsg.name" config.yaml)

  # Auto-generate if empty
  if [[ -z "$NSG_NAME" || "$NSG_NAME" == "null" || "$NSG_NAME" == "" ]]; then
    NSG_NAME="nsg-${SUBNET_NAME}"
  fi

  echo "[PROGRESS] Processing NSG for subnet: $SUBNET_NAME"
  echo "[PROGRESS]   NSG name: $NSG_NAME"

  # Check if NSG already exists (idempotent)
  if az network nsg show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$NSG_NAME" &>/dev/null; then

    echo "[INFO] NSG already exists: $NSG_NAME"
    ((NSG_COUNT++)) || true
    continue
  fi

  # Create NSG
  echo "[PROGRESS] Creating NSG: $NSG_NAME"

  if ! az network nsg create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$NSG_NAME" \
    --location "$LOCATION" \
    --output json > "artifacts/outputs/networking-create-nsg-${NSG_NAME}.json"; then

    echo "[ERROR] Failed to create NSG: $NSG_NAME"
    exit 1
  fi

  echo "[SUCCESS] NSG created: $NSG_NAME"
  ((NSG_COUNT++)) || true
done

echo "[SUCCESS] All NSGs created successfully"
echo "[SUCCESS]   Total NSGs: $NSG_COUNT"

exit 0
