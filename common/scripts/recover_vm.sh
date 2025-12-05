#!/bin/bash

RESOURCE_GROUP="RG-Azure-VDI-01"
OLD_VM_NAME="avd-gold-pool"
NEW_VM_NAME="avd-gold-pool-v2"
LOCATION="centralus"

echo "Getting OS Disk ID..."
OS_DISK_ID=$(az vm show -g $RESOURCE_GROUP -n $OLD_VM_NAME --query storageProfile.osDisk.managedDisk.id -o tsv)

if [ -z "$OS_DISK_ID" ]; then
    echo "Error: Could not find OS Disk ID. Is the VM already deleted?"
    exit 1
fi

echo "OS Disk ID: $OS_DISK_ID"

echo "Deleting old generalized VM..."
az vm delete -g $RESOURCE_GROUP -n $OLD_VM_NAME --yes

echo "Creating new VM from OS Disk..."
az vm create \
  --resource-group $RESOURCE_GROUP \
  --name $NEW_VM_NAME \
  --attach-os-disk "$OS_DISK_ID" \
  --os-type Windows \
  --size "Standard_D4s_v6" \
  --location $LOCATION \
  --public-ip-sku Standard \
  --security-type TrustedLaunch \
  --enable-secure-boot true \
  --enable-vtpm true

echo "Recovery VM created: $NEW_VM_NAME"
echo "You can now RDP into $NEW_VM_NAME to install applications."
