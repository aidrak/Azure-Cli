#!/bin/bash
set -euo pipefail

echo "[START] Session Host Deployment: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"

# Configuration from config.yaml
RESOURCE_GROUP="RG-Azure-VDI-01"
LOCATION="centralus"
VM_PREFIX="avd-sh"
VM_COUNT=1
VM_SIZE="Standard_D4s_v6"
GALLERY_NAME="avd_gallery"
IMAGE_DEFINITION="windows11-golden-image"
VNET_NAME="avd-vnet"
SUBNET_NAME="subnet-session-hosts"

# Step 1: Validate Azure authentication
echo "[PROGRESS] Step 1/6: Validating Azure authentication..."
if ! az account show &>/dev/null; then
  echo "[ERROR] Not authenticated to Azure"
  exit 1
fi

# Step 2: Validate resource group exists
echo "[PROGRESS] Step 2/6: Validating resource group..."
if ! az group exists --name "$RESOURCE_GROUP" | grep -q "true"; then
  echo "[ERROR] Resource group not found: $RESOURCE_GROUP"
  exit 1
fi

# Step 3: Get golden image ID from gallery
echo "[PROGRESS] Step 3/6: Getting golden image from gallery..."
IMAGE_ID=$(az sig image-definition show \
  --resource-group "$RESOURCE_GROUP" \
  --gallery-name "$GALLERY_NAME" \
  --gallery-image-definition "$IMAGE_DEFINITION" \
  --query id -o tsv 2>/dev/null)

if [[ -z "$IMAGE_ID" ]]; then
  echo "[ERROR] Image definition not found: $IMAGE_DEFINITION in gallery $GALLERY_NAME"
  echo "[ERROR] Please ensure golden image was captured successfully (Module 05)"
  exit 1
fi

echo "[VALIDATE] Found image: $IMAGE_ID"

# Step 4: Get subnet ID
echo "[PROGRESS] Step 4/6: Getting subnet ID..."
SUBNET_ID=$(az network vnet subnet show \
  --resource-group "$RESOURCE_GROUP" \
  --vnet-name "$VNET_NAME" \
  --name "$SUBNET_NAME" \
  --query id -o tsv)

if [[ -z "$SUBNET_ID" ]]; then
  echo "[ERROR] Subnet not found: $SUBNET_NAME in VNet $VNET_NAME"
  exit 1
fi

echo "[VALIDATE] Found subnet: $SUBNET_ID"

# Step 5: Deploy session host VMs
echo "[PROGRESS] Step 5/6: Deploying $VM_COUNT session host VMs..."
echo "[PROGRESS] VM prefix: $VM_PREFIX"
echo "[PROGRESS] VM size: $VM_SIZE"
echo "[PROGRESS] Location: $LOCATION"

deployed_vms=()
failed_vms=()

for ((i=1; i<=VM_COUNT; i++)); do
  vm_name="${VM_PREFIX}-$(printf '%02d' $i)"

  # Check if VM already exists
  if az vm show --resource-group "$RESOURCE_GROUP" --name "$vm_name" &>/dev/null; then
    echo "[PROGRESS] VM already exists: $vm_name ($i/$VM_COUNT)"
    deployed_vms+=("$vm_name")
    continue
  fi

  echo "[PROGRESS] Creating VM: $vm_name ($i/$VM_COUNT)..."

  # Deploy VM from golden image
  if az vm create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$vm_name" \
    --location "$LOCATION" \
    --image "$IMAGE_ID" \
    --size "$VM_SIZE" \
    --subnet "$SUBNET_ID" \
    --admin-username "entra-admin" \
    --generate-ssh-keys \
    --nsg "" \
    --public-ip-address "" \
    --os-disk-delete-option Delete \
    --data-disk-delete-option Delete \
    --nic-delete-option Delete \
    --output json > "artifacts/outputs/session-host-deploy-${vm_name}.json" 2>&1; then

    echo "[SUCCESS] VM created: $vm_name"
    deployed_vms+=("$vm_name")
  else
    echo "[ERROR] Failed to create VM: $vm_name"
    failed_vms+=("$vm_name")
  fi
done

# Step 6: Summary
echo "[PROGRESS] Step 6/6: Deployment summary..."
echo "[VALIDATE] Successfully deployed: ${#deployed_vms[@]}/$VM_COUNT"
echo "[VALIDATE] Failed: ${#failed_vms[@]}/$VM_COUNT"

if [[ ${#failed_vms[@]} -gt 0 ]]; then
  echo "[ERROR] Failed VMs: ${failed_vms[*]}"
  echo "[ERROR] Check artifacts/outputs/ for detailed error logs"
  exit 1
fi

# Save deployment details
{
  echo "Session Host Deployment Summary"
  echo "================================"
  echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
  echo ""
  echo "Configuration:"
  echo "  Resource Group: $RESOURCE_GROUP"
  echo "  Location: $LOCATION"
  echo "  VM Count: $VM_COUNT"
  echo "  VM Size: $VM_SIZE"
  echo "  VM Prefix: $VM_PREFIX"
  echo ""
  echo "Image Source:"
  echo "  Gallery: $GALLERY_NAME"
  echo "  Definition: $IMAGE_DEFINITION"
  echo "  Image ID: $IMAGE_ID"
  echo ""
  echo "Network:"
  echo "  VNet: $VNET_NAME"
  echo "  Subnet: $SUBNET_NAME"
  echo ""
  echo "Deployed VMs:"
  for vm in "${deployed_vms[@]}"; do
    echo "  - $vm"
  done
  echo ""
  echo "Next Steps:"
  echo "  1. Wait for VMs to fully initialize"
  echo "  2. Register VMs with host pool (next operation)"
  echo "  3. Verify connectivity and join status"
  echo ""
} > "artifacts/outputs/session-host-deploy-summary.txt"

echo "[SUCCESS] Session host deployment completed successfully"
exit 0
