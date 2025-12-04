#!/bin/bash

# This script captures the temporary VM as a new version in the Azure Compute Gallery.
# It assumes the VM has already been deallocated and generalized.

set -e # Exit immediately if a command exits with a non-zero status.

echo "--- Preparing to Capture Image ---"

# --- Variable Validation ---
if [ -z "$RESOURCE_GROUP_NAME" ] || [ -z "$LOCATION" ] || [ -z "$VM_NAME" ] || [ -z "$IMAGE_GALLERY_NAME" ] || [ -z "$GOLDEN_IMAGE_NAME" ]; then
    echo "ERROR: One or more required environment variables are not set."
    echo "Please ensure config.env is sourced and all variables are defined."
    exit 1
fi

# Generate a version number based on the current date and time
IMAGE_VERSION=$(date -u +"%Y.%m%d.%H%M")

echo "Configuration:"
echo "  Resource Group: $RESOURCE_GROUP_NAME"
echo "  Location: $LOCATION"
echo "  VM Name: $VM_NAME"
echo "  Gallery Name: $IMAGE_GALLERY_NAME"
echo "  Image Definition: $GOLDEN_IMAGE_NAME"
echo "  New Image Version: $IMAGE_VERSION"
echo "----------------------------------------"

# --- Create Image Definition if it doesn't exist ---
echo "Checking for existing Image Definition '$GOLDEN_IMAGE_NAME'..."
if ! az sig image-definition show --resource-group "$RESOURCE_GROUP_NAME" --gallery-name "$IMAGE_GALLERY_NAME" --gallery-image-definition "$GOLDEN_IMAGE_NAME" &> /dev/null; then
  echo "Image Definition not found. Creating it..."
  az sig image-definition create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --gallery-name "$IMAGE_GALLERY_NAME" \
    --gallery-image-definition "$GOLDEN_IMAGE_NAME" \
    --publisher "Custom" \
    --offer "AVD" \
    --sku "Win11-FSLogix" \
    --os-type "Windows" \
    --os-state "Generalized" \
    --hyper-v-generation "V2" \
    --features SecurityType=TrustedLaunch \
    --location "$LOCATION"
  echo "Image Definition created."
else
  echo "Image Definition already exists."
fi

# --- Get VM ID ---
echo "Fetching VM ID for '$VM_NAME'..."
VM_ID=$(az vm get-instance-view -g "$RESOURCE_GROUP_NAME" -n "$VM_NAME" --query id -o tsv)
if [ -z "$VM_ID" ]; then
    echo "ERROR: Failed to get VM ID for '$VM_NAME'."
    exit 1
fi
echo "VM ID: $VM_ID"

# --- Create Image Version ---
echo "Creating new image version '$IMAGE_VERSION'..."
az sig image-version create \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --gallery-name "$IMAGE_GALLERY_NAME" \
  --gallery-image-definition "$GOLDEN_IMAGE_NAME" \
  --gallery-image-version "$IMAGE_VERSION" \
  --virtual-machine "$VM_ID" \
  --location "$LOCATION"

echo "Successfully started image version creation."
echo "The process will continue in the background. You can monitor progress in the Azure portal."

# --- Cleanup ---
echo "Removing the temporary VM resource '$VM_NAME'..."
az vm delete --resource-group "$RESOURCE_GROUP_NAME" --name "$VM_NAME" --yes
echo "Temporary VM deleted."

echo "--- Image Capture Process Complete ---"
