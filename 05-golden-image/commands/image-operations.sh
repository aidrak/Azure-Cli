#!/bin/bash

# ============================================================================
# Image Operations Command Reference
# ============================================================================
#
# This file contains reusable Azure CLI commands for image gallery operations.
# These commands are documented and ready for direct execution or
# incorporation into scripts.
#
# Usage: Source this file and execute commands as needed
#   source ./commands/image-operations.sh
#   create_gallery
#

# ============================================================================
# Configuration (from config.env)
# ============================================================================
# Assumes config.env has been sourced with all required variables:
# RESOURCE_GROUP_NAME, LOCATION, IMAGE_GALLERY_NAME, IMAGE_DEFINITION_NAME,
# IMAGE_PUBLISHER, IMAGE_OFFER, IMAGE_SKU_NAME

# ============================================================================
# Gallery Management
# ============================================================================

# Create Azure Compute Gallery
# Purpose: Container for storing versioned images
# Expected output: Gallery resource created
# Expected duration: 1-2 minutes
# Idempotent: Yes (safe to run multiple times)
#
# Example usage:
#   ./commands/image-operations.sh create_gallery
#
: '
az sig create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --gallery-name "$IMAGE_GALLERY_NAME" \
    --location "$LOCATION" \
    --output json
'

# Show gallery details
: '
az sig show \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --gallery-name "$IMAGE_GALLERY_NAME" \
    --output json
'

# List all galleries in resource group
: '
az sig list \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --output table
'

# Delete gallery (WARNING: This deletes all images in the gallery)
: '
az sig delete \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --gallery-name "$IMAGE_GALLERY_NAME"
'

# ============================================================================
# Image Definition Management
# ============================================================================

# Create Image Definition
# Purpose: Schema for image versions (defines publisher, offer, SKU)
# Expected output: Image definition created
# Expected duration: < 1 minute
# Idempotent: Yes
#
# Parameters:
#   --os-type: Windows or Linux
#   --os-state: Generalized or Specialized
#
# Example usage:
#   ./commands/image-operations.sh create_image_definition
#
: '
az sig image-definition create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --gallery-name "$IMAGE_GALLERY_NAME" \
    --gallery-image-definition "$IMAGE_DEFINITION_NAME" \
    --publisher "$IMAGE_PUBLISHER" \
    --offer "$IMAGE_OFFER" \
    --sku "$IMAGE_SKU_NAME" \
    --os-type Windows \
    --os-state Generalized \
    --output json
'

# Show image definition details
: '
az sig image-definition show \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --gallery-name "$IMAGE_GALLERY_NAME" \
    --gallery-image-definition "$IMAGE_DEFINITION_NAME" \
    --output json
'

# List image definitions in gallery
: '
az sig image-definition list \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --gallery-name "$IMAGE_GALLERY_NAME" \
    --output table
'

# Delete image definition (deletes all versions)
: '
az sig image-definition delete \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --gallery-name "$IMAGE_GALLERY_NAME" \
    --gallery-image-definition "$IMAGE_DEFINITION_NAME"
'

# ============================================================================
# Image Version Management
# ============================================================================

# Create Image Version from VM
# Purpose: Capture a sysprepped VM as a reusable image version
# Prerequisites:
#   - VM must be deallocated and generalized
#   - Gallery and definition must exist
# Expected output: Image version created and replicated
# Expected duration: 15-30 minutes
# Idempotent: No (creates new version each time)
#
# Note: Image version format should be MAJOR.MINOR.PATCH (e.g., 2025.1204.0530)
#
# Example usage:
#   VM_ID="/subscriptions/.../resourceGroups/.../providers/Microsoft.Compute/virtualMachines/vm-name"
#   IMAGE_VERSION="2025.1204.0530"
#
: '
az sig image-version create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --gallery-name "$IMAGE_GALLERY_NAME" \
    --gallery-image-definition "$IMAGE_DEFINITION_NAME" \
    --gallery-image-version "$IMAGE_VERSION" \
    --managed-image "$VM_ID" \
    --location "$LOCATION" \
    --output json
'

# Create Image Version from VHD
# Purpose: Create image version from existing VHD blob
# Prerequisites:
#   - VHD must be uploaded to storage account
#   - Gallery and definition must exist
# Expected duration: 20-40 minutes
#
: '
az sig image-version create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --gallery-name "$IMAGE_GALLERY_NAME" \
    --gallery-image-definition "$IMAGE_DEFINITION_NAME" \
    --gallery-image-version "$IMAGE_VERSION" \
    --os-vhd-storage-account "$STORAGE_ACCOUNT_ID" \
    --os-vhd-uri "https://storageaccount.blob.core.windows.net/container/image.vhd" \
    --output json
'

# Show image version details
: '
az sig image-version show \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --gallery-name "$IMAGE_GALLERY_NAME" \
    --gallery-image-definition "$IMAGE_DEFINITION_NAME" \
    --gallery-image-version "$IMAGE_VERSION" \
    --output json
'

# List all image versions for a definition
: '
az sig image-version list \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --gallery-name "$IMAGE_GALLERY_NAME" \
    --gallery-image-definition "$IMAGE_DEFINITION_NAME" \
    --output table
'

# List all image versions with details
: '
az sig image-version list \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --gallery-name "$IMAGE_GALLERY_NAME" \
    --gallery-image-definition "$IMAGE_DEFINITION_NAME" \
    --query "[].{Version:name, PublishingProfile:publishingProfile, ReplicatedRegions:replicaCount}" \
    --output table
'

# Delete specific image version
: '
az sig image-version delete \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --gallery-name "$IMAGE_GALLERY_NAME" \
    --gallery-image-definition "$IMAGE_DEFINITION_NAME" \
    --gallery-image-version "$IMAGE_VERSION"
'

# ============================================================================
# Image Deployment Reference
# ============================================================================

# Get Image Resource ID (for use in session host deployment)
# This ID is used when creating session host VMs from the golden image
#
: '
az sig image-version show \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --gallery-name "$IMAGE_GALLERY_NAME" \
    --gallery-image-definition "$IMAGE_DEFINITION_NAME" \
    --gallery-image-version "$IMAGE_VERSION" \
    --query "id" \
    -o tsv
'

# Use image ID to create a VM from the image (example for session host deployment)
#
: '
az vm create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "session-host-01" \
    --image "/subscriptions/{subscription-id}/resourceGroups/{rg-name}/providers/Microsoft.Compute/galleries/{gallery-name}/images/{definition-name}/versions/{version}" \
    --size "Standard_D4s_v6" \
    --admin-username "localadmin" \
    --admin-password "SecurePassword123!" \
    --vnet-name "vnet-name" \
    --subnet "subnet-name" \
    --output json
'

# ============================================================================
# Replication Management
# ============================================================================

# Update image version replication (for multi-region deployments)
# Replicates image to additional regions for faster deployment
#
: '
az sig image-version update \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --gallery-name "$IMAGE_GALLERY_NAME" \
    --gallery-image-definition "$IMAGE_DEFINITION_NAME" \
    --gallery-image-version "$IMAGE_VERSION" \
    --add "publishingProfile.targetRegions[].name=$REGION1" \
    --output json
'

# ============================================================================
# Troubleshooting Commands
# ============================================================================

# Check image version provisioning state
: '
az sig image-version show \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --gallery-name "$IMAGE_GALLERY_NAME" \
    --gallery-image-definition "$IMAGE_DEFINITION_NAME" \
    --gallery-image-version "$IMAGE_VERSION" \
    --query "provisioningState" \
    -o tsv
'

# Get image version replication status
: '
az sig image-version show \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --gallery-name "$IMAGE_GALLERY_NAME" \
    --gallery-image-definition "$IMAGE_DEFINITION_NAME" \
    --gallery-image-version "$IMAGE_VERSION" \
    --query "publishingProfile.replicatedRegions" \
    -o json
'

# Check gallery statistics
: '
az sig show \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --gallery-name "$IMAGE_GALLERY_NAME" \
    --query "{Name:name, ResourceGroup:resourceGroup, Location:location, Definitions:\"definitions[].length(@)\"}" \
    -o json
'

# ============================================================================
# Cleanup Commands
# ============================================================================

# Delete old image versions (to manage costs/storage)
# Keep only the latest 3 versions (example)
#
# Get list of versions sorted by date:
: '
az sig image-version list \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --gallery-name "$IMAGE_GALLERY_NAME" \
    --gallery-image-definition "$IMAGE_DEFINITION_NAME" \
    --query "sort_by([].{Name:name, Created:timeCreated}, &Created)" \
    --output table
'

# Delete specific old version:
: '
az sig image-version delete \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --gallery-name "$IMAGE_GALLERY_NAME" \
    --gallery-image-definition "$IMAGE_DEFINITION_NAME" \
    --gallery-image-version "2025.1101.0000"
'
