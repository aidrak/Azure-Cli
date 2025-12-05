#!/bin/bash
# ==============================================================================
# Attach NSGs to Subnets
# ==============================================================================

set -euo pipefail

echo "[START] NSG attachment: $(date '+%Y-%m-%d %H:%M:%S')"

# Configuration
VNET_NAME="avd-vnet"
RESOURCE_GROUP="RG-Azure-VDI-01"

# Get subnet count
SUBNET_COUNT=$(yq e '.networking.subnets | length' config.yaml)
ATTACHED_COUNT=0

echo "[PROGRESS] Attaching NSGs to $SUBNET_COUNT subnet(s)..."

# Iterate through subnets
for i in $(seq 0 $((SUBNET_COUNT - 1))); do
  # Check if NSG enabled
  NSG_ENABLED=$(yq e ".networking.subnets[$i].nsg.enabled" config.yaml)

  if [[ "$NSG_ENABLED" != "true" ]]; then
    continue
  fi

  # Get subnet and NSG names
  SUBNET_NAME=$(yq e ".networking.subnets[$i].name" config.yaml)
  NSG_NAME=$(yq e ".networking.subnets[$i].nsg.name" config.yaml)

  # Auto-generate NSG name if empty
  if [[ -z "$NSG_NAME" || "$NSG_NAME" == "null" || "$NSG_NAME" == "" ]]; then
    NSG_NAME="nsg-${SUBNET_NAME}"
  fi

  echo "[PROGRESS] Attaching NSG to subnet: $SUBNET_NAME"
  echo "[PROGRESS]   NSG: $NSG_NAME"

  # Check if NSG is already attached
  CURRENT_NSG=$(az network vnet subnet show \
    --resource-group "$RESOURCE_GROUP" \
    --vnet-name "$VNET_NAME" \
    --name "$SUBNET_NAME" \
    --query "networkSecurityGroup.id" -o tsv 2>/dev/null || echo "")

  if [[ -n "$CURRENT_NSG" ]]; then
    echo "[INFO] NSG already attached to subnet: $SUBNET_NAME"
    ((ATTACHED_COUNT++)) || true
    continue
  fi

  # Attach NSG to subnet
  if ! az network vnet subnet update \
    --resource-group "$RESOURCE_GROUP" \
    --vnet-name "$VNET_NAME" \
    --name "$SUBNET_NAME" \
    --network-security-group "$NSG_NAME" \
    --output none; then

    echo "[ERROR] Failed to attach NSG to subnet: $SUBNET_NAME"
    exit 1
  fi

  echo "[SUCCESS] NSG attached: $NSG_NAME -> $SUBNET_NAME"
  ((ATTACHED_COUNT++)) || true
done

echo "[SUCCESS] All NSGs attached successfully"
echo "[SUCCESS]   Total attachments: $ATTACHED_COUNT"

exit 0
