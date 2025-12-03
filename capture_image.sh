#!/bin/bash

RESOURCE_GROUP="RG-Azure-VDI-01"
VM_NAME="avd-gold-pool"
GALLERY_NAME="AVD_Image_Gallery"
IMAGE_DEF_NAME="Win11-AVD-Pooled"
VERSION="1.0.0"
LOCATION="centralus"

echo "Deallocating VM..."
az vm deallocate -g $RESOURCE_GROUP -n $VM_NAME

echo "Generalizing VM..."
az vm generalize -g $RESOURCE_GROUP -n $VM_NAME

echo "Creating Compute Gallery (if not exists)..."
az sig create -g $RESOURCE_GROUP --gallery-name $GALLERY_NAME --location $LOCATION

echo "Creating Image Definition..."
az sig image-definition create \
  -g $RESOURCE_GROUP \
  --gallery-name $GALLERY_NAME \
  --gallery-image-definition $IMAGE_DEF_NAME \
  --publisher "YourCompany" \
  --offer "AVD" \
  --sku "Win11-Pooled-FSLogix" \
  --os-type Windows \
  --os-state Generalized \
  --hyper-v-generation V2 \
  --features "SecurityType=TrustedLaunch" \
  --location $LOCATION

# Get VM ID
VM_ID=$(az vm show -g $RESOURCE_GROUP -n $VM_NAME --query id -o tsv)

echo "Creating Image Version $VERSION..."
az sig image-version create \
  -g $RESOURCE_GROUP \
  --gallery-name $GALLERY_NAME \
  --gallery-image-definition $IMAGE_DEF_NAME \
  --gallery-image-version $VERSION \
  --virtual-machine $VM_ID \
  --location $LOCATION

echo "Image Capture Complete."
