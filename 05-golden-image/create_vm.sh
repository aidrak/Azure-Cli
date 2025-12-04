#!/bin/bash

# This script creates the temporary Azure VM that will be used to build the golden image.
# It uses environment variables sourced by the main orchestrator script.

set -e # Exit immediately if a command exits with a non-zero status.

echo "--- Preparing to Create Temporary VM ---"

# --- Variable Validation ---
# Check if all required variables are set.
if [ -z "$RESOURCE_GROUP_NAME" ] || [ -z "$LOCATION" ] || [ -z "$VM_NAME" ] || [ -z "$VM_SIZE" ] || [ -z "$WINDOWS_IMAGE_SKU" ] || [ -z "$ADMIN_USERNAME" ] || [ -z "$ADMIN_PASSWORD" ] || [ -z "$VNET_NAME" ] || [ -z "$SUBNET_NAME" ]; then
    echo "ERROR: One or more required environment variables are not set."
    echo "Please ensure config.env is sourced and all variables are defined."
    exit 1
fi

echo "Configuration:"
echo "  Resource Group: $RESOURCE_GROUP_NAME"
echo "  Location: $LOCATION"
echo "  VM Name: $VM_NAME"
echo "  VM Size: $VM_SIZE"
echo "  VNet/Subnet: $VNET_NAME/$SUBNET_NAME"
echo "  Windows SKU: $WINDOWS_IMAGE_SKU"
echo "----------------------------------------"

echo "Creating Temporary VM '$VM_NAME'..."

# Create a Gen 2 VM with Trusted Launch security type
az vm create \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --name "$VM_NAME" \
  --image "MicrosoftWindowsDesktop:windows-11:$WINDOWS_IMAGE_SKU:latest" \
  --size "$VM_SIZE" \
  --admin-username "$ADMIN_USERNAME" \
  --admin-password "$ADMIN_PASSWORD" \
  --vnet-name "$VNET_NAME" \
  --subnet "$SUBNET_NAME" \
  --public-ip-sku Standard \
  --security-type TrustedLaunch \
  --enable-secure-boot true \
  --enable-vtpm true \
  --location "$LOCATION"

echo "VM '$VM_NAME' creation command executed successfully."