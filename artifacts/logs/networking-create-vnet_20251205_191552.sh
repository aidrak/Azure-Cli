#!/bin/bash
# ==============================================================================
# Create Virtual Network
# ==============================================================================

set -euo pipefail

echo "[START] VNet creation: $(date '+%Y-%m-%d %H:%M:%S')"

# Configuration from config.yaml (loaded by config-manager.sh)
VNET_NAME="avd-vnet"
RESOURCE_GROUP="RG-Azure-VDI-01"
LOCATION="centralus"

# Parse address space from config.yaml
ADDRESS_SPACE=$(yq e '.networking.vnet.address_space | join(" ")' config.yaml)

# Parse custom DNS servers (if configured)
DNS_SERVERS_COUNT=$(yq e '.networking.vnet.dns_servers | length' config.yaml)
DNS_SERVERS=""

if [[ "$DNS_SERVERS_COUNT" -gt 0 ]]; then
  DNS_SERVERS=$(yq e '.networking.vnet.dns_servers | join(" ")' config.yaml)
fi

# Check if VNet already exists (idempotent)
echo "[PROGRESS] Checking if VNet exists..."
if az network vnet show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$VNET_NAME" &>/dev/null; then

  echo "[INFO] VNet already exists: $VNET_NAME"
  echo "[SUCCESS] VNet creation complete (already exists)"
  exit 0
fi

# Create VNet
echo "[PROGRESS] Creating VNet: $VNET_NAME"
echo "[PROGRESS]   Address space: $ADDRESS_SPACE"
echo "[PROGRESS]   Location: $LOCATION"

if [[ -n "$DNS_SERVERS" ]]; then
  echo "[PROGRESS]   Custom DNS servers: $DNS_SERVERS"

  if ! az network vnet create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$VNET_NAME" \
    --address-prefixes $ADDRESS_SPACE \
    --location "$LOCATION" \
    --dns-servers $DNS_SERVERS \
    --output json > artifacts/outputs/networking-create-vnet.json; then

    echo "[ERROR] Failed to create VNet"
    exit 1
  fi
else
  if ! az network vnet create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$VNET_NAME" \
    --address-prefixes $ADDRESS_SPACE \
    --location "$LOCATION" \
    --output json > artifacts/outputs/networking-create-vnet.json; then

    echo "[ERROR] Failed to create VNet"
    exit 1
  fi
fi

# Validate creation
echo "[VALIDATE] Checking VNet provisioning state..."
PROVISIONING_STATE=$(az network vnet show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$VNET_NAME" \
  --query "provisioningState" -o tsv)

if [[ "$PROVISIONING_STATE" != "Succeeded" ]]; then
  echo "[ERROR] VNet provisioning failed: $PROVISIONING_STATE"
  exit 1
fi

# Get VNet ID for reference
VNET_ID=$(az network vnet show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$VNET_NAME" \
  --query "id" -o tsv)

echo "[SUCCESS] VNet created successfully"
echo "[SUCCESS]   Name: $VNET_NAME"
echo "[SUCCESS]   ID: $VNET_ID"
echo "[SUCCESS]   State: $PROVISIONING_STATE"
exit 0
