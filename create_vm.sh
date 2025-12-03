#!/bin/bash

RESOURCE_GROUP="RG-Azure-VDI-01"
VM_NAME="avd-gold-pool"
VNET_NAME="vnet-vdi-centralus"
SUBNET_NAME="subnet-vdi-hosts"
LOCATION="centralus"

echo "Creating Temporary VM for Golden Image..."

# Create VM with D4s_v6 and Gen2 settings
az vm create \
  --resource-group $RESOURCE_GROUP \
  --name $VM_NAME \
  --image "MicrosoftWindowsDesktop:windows-11:win11-25h2-avd:latest" \
  --size "Standard_D4s_v6" \
  --admin-username "entra-admin" \
  --admin-password "ComplexP@ss123!" \
  --vnet-name $VNET_NAME \
  --subnet $SUBNET_NAME \
  --public-ip-sku Standard \
  --security-type TrustedLaunch \
  --enable-secure-boot true \
  --enable-vtpm true \
  --location $LOCATION

echo "VM Creation initiated."