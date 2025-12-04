# Step 06 - Session Host Deployment Commands Reference

Quick reference for deploying and registering session host VMs for AVD.

## Prerequisites

```bash
# Ensure authenticated
az account show

# Verify image gallery exists
az sig list --resource-group "RG-Azure-VDI-01"

# Verify host pool exists
az desktopvirtualization hostpool list --resource-group "RG-Azure-VDI-01"
```

## VM Operations

### Get Image ID from Gallery

```bash
# List images in gallery
az sig image-definition list \
  --resource-group "RG-Azure-VDI-01" \
  --gallery-name "avdimagegallery"

# Get specific image version ID
IMAGE_ID=$(az sig image-version list \
  --resource-group "RG-Azure-VDI-01" \
  --gallery-name "avdimagegallery" \
  --gallery-image-definition "golden-image" \
  --query "[0].id" -o tsv)

echo "Image ID: $IMAGE_ID"
```

### Create Session Host VM

```bash
# Create single VM from golden image
az vm create \
  --resource-group "RG-Azure-VDI-01" \
  --name "avd-session-host-1" \
  --image "<image-id>" \
  --nics "vnic-1" \
  --size "Standard_D2s_v3" \
  --os-disk-name "osdisk-1" \
  --os-disk-delete-option "Delete" \
  --data-disk-name "data-1" \
  --data-disk-delete-option "Delete" \
  --location "centralus"
```

**Parameters:**
- `--image`: Full image ID or image name
- `--size`: VM size (Standard_D2s_v3, Standard_D4s_v3, etc.)
- `--os-disk-delete-option`: "Delete" to remove when VM is deleted

### Create Multiple Session Hosts (Batch)

```bash
#!/bin/bash

# Variables
RG="RG-Azure-VDI-01"
IMAGE_ID="<image-id>"
VM_PREFIX="avd-host"
VM_COUNT=3
VM_SIZE="Standard_D2s_v3"
LOCATION="centralus"

# Get subnet ID
SUBNET_ID=$(az network vnet subnet show \
  --resource-group "$RG" \
  --vnet-name "avd-vnet" \
  --name "session-hosts" \
  --query id -o tsv)

# Create VMs in parallel
for i in $(seq 1 $VM_COUNT); do
  VM_NAME="${VM_PREFIX}-${i}"

  echo "Creating VM: $VM_NAME"

  az vm create \
    --resource-group "$RG" \
    --name "$VM_NAME" \
    --image "$IMAGE_ID" \
    --subnet "$SUBNET_ID" \
    --size "$VM_SIZE" \
    --os-disk-delete-option "Delete" \
    --location "$LOCATION" \
    &  # Background process for parallelism
done

# Wait for all background jobs
wait
echo "All VMs created"
```

### List Session Host VMs

```bash
# List all VMs in resource group
az vm list \
  --resource-group "RG-Azure-VDI-01" \
  --output table

# List specific pattern
az vm list \
  --resource-group "RG-Azure-VDI-01" \
  --query "[?contains(name, 'avd-host')]" \
  --output table
```

### Get VM Details

```bash
# Show VM properties
az vm show \
  --resource-group "RG-Azure-VDI-01" \
  --name "avd-session-host-1" \
  --output json

# Get VM ID
az vm show \
  --resource-group "RG-Azure-VDI-01" \
  --name "avd-session-host-1" \
  --query id -o tsv
```

### Check VM Status

```bash
# Get power state
az vm get-instance-view \
  --resource-group "RG-Azure-VDI-01" \
  --name "avd-session-host-1" \
  --query "instanceView.statuses" \
  --output json

# Simple status check
az vm get-instance-view \
  --resource-group "RG-Azure-VDI-01" \
  --name "avd-session-host-1" \
  --query "instanceView.statuses[?starts_with(code, 'PowerState')].displayStatus" \
  --output tsv
```

### Start/Stop VMs

```bash
# Start VM
az vm start \
  --resource-group "RG-Azure-VDI-01" \
  --name "avd-session-host-1"

# Stop VM
az vm stop \
  --resource-group "RG-Azure-VDI-01" \
  --name "avd-session-host-1"

# Deallocate VM (stop and release compute)
az vm deallocate \
  --resource-group "RG-Azure-VDI-01" \
  --name "avd-session-host-1"

# Restart VM
az vm restart \
  --resource-group "RG-Azure-VDI-01" \
  --name "avd-session-host-1"
```

### Delete VM

```bash
az vm delete \
  --resource-group "RG-Azure-VDI-01" \
  --name "avd-session-host-1" \
  --yes
```

## Network Interface Operations

### Create Network Interface

```bash
az network nic create \
  --resource-group "RG-Azure-VDI-01" \
  --name "nic-session-host-1" \
  --vnet-name "avd-vnet" \
  --subnet "session-hosts" \
  --private-ip-address "10.0.1.10"
```

### Get Network Interface Details

```bash
az network nic show \
  --resource-group "RG-Azure-VDI-01" \
  --name "nic-session-host-1" \
  --output json
```

### List Network Interfaces

```bash
az network nic list \
  --resource-group "RG-Azure-VDI-01" \
  --output table
```

## Disk Operations

### List Disks

```bash
# List all disks
az disk list \
  --resource-group "RG-Azure-VDI-01" \
  --output table

# Find unattached disks
az disk list \
  --resource-group "RG-Azure-VDI-01" \
  --query "[?diskState=='Unattached']" \
  --output table
```

### Get Disk Details

```bash
az disk show \
  --resource-group "RG-Azure-VDI-01" \
  --name "osdisk-1" \
  --output json
```

### Delete Disk

```bash
az disk delete \
  --resource-group "RG-Azure-VDI-01" \
  --name "old-disk" \
  --yes
```

## AVD Host Pool Registration

### Get Host Pool Registration Token

```bash
az desktopvirtualization hostpool update \
  --name "avd-hostpool" \
  --resource-group "RG-Azure-VDI-01" \
  --registration-info expiration-time="2025-12-11T23:59:59Z" registration-token-operation="Update" \
  --query "registrationInfo.token" -o tsv > token.txt
```

### Register Session Host (PowerShell on VM)

```powershell
# Run on session host VM
# Get token from token.txt created above

$hostPoolToken = Get-Content -Path "C:\token.txt"

# Download and install AVD agent
$agentInstallerURL = "https://query.prod.cms.rt.microsoft.com/cms/api/am/binary/RWrmXv"
Invoke-WebRequest -Uri $agentInstallerURL -OutFile "$env:TEMP\AVDAgent.msi"
msiexec.exe /i "$env:TEMP\AVDAgent.msi" /quiet /qn /norestart REGISTRATIONTOKEN="$hostPoolToken"

# Restart
Restart-Computer -Force
```

## Common Patterns

### Wait for VM to be Running

```bash
#!/bin/bash

VM_NAME="avd-session-host-1"
RG="RG-Azure-VDI-01"
MAX_ATTEMPTS=30
ATTEMPT=0

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
  STATUS=$(az vm get-instance-view \
    --resource-group "$RG" \
    --name "$VM_NAME" \
    --query "instanceView.statuses[?starts_with(code, 'PowerState')].displayStatus" \
    --output tsv)

  if [ "$STATUS" == "VM running" ]; then
    echo "VM is running"
    exit 0
  fi

  echo "VM status: $STATUS (attempt $((ATTEMPT+1))/$MAX_ATTEMPTS)"
  sleep 10
  ((ATTEMPT++))
done

echo "VM did not start within timeout"
exit 1
```

### Get All Session Host IPs

```bash
az vm list-ip-addresses \
  --resource-group "RG-Azure-VDI-01" \
  --output table
```

### Bulk Delete VMs

```bash
#!/bin/bash

RG="RG-Azure-VDI-01"
PATTERN="temp"  # Delete VMs with "temp" in name

az vm list \
  --resource-group "$RG" \
  --query "[?contains(name, '$PATTERN')].name" \
  --output tsv | while read VM_NAME; do

  echo "Deleting VM: $VM_NAME"
  az vm delete --resource-group "$RG" --name "$VM_NAME" --yes &
done

wait
echo "All VMs deleted"
```

## Complete Deployment Example

```bash
#!/bin/bash

# Variables
RG="RG-Azure-VDI-01"
HOSTPOOL="avd-hostpool"
IMAGE_GALLERY="avdimagegallery"
IMAGE_DEF="golden-image"
VM_PREFIX="avd-host"
VM_COUNT=2
VM_SIZE="Standard_D2s_v3"
LOCATION="centralus"
VNET="avd-vnet"
SUBNET="session-hosts"

echo "=== Session Host Deployment ==="

# Get image ID
echo "Getting image ID..."
IMAGE_ID=$(az sig image-version list \
  --resource-group "$RG" \
  --gallery-name "$IMAGE_GALLERY" \
  --gallery-image-definition "$IMAGE_DEF" \
  --query "[0].id" -o tsv)

echo "Image ID: $IMAGE_ID"

# Get subnet ID
SUBNET_ID=$(az network vnet subnet show \
  --resource-group "$RG" \
  --vnet-name "$VNET" \
  --name "$SUBNET" \
  --query id -o tsv)

echo "Subnet ID: $SUBNET_ID"

# Create VMs
echo "Creating $VM_COUNT VMs..."
for i in $(seq 1 $VM_COUNT); do
  VM_NAME="${VM_PREFIX}-${i}"

  echo "Creating: $VM_NAME"

  az vm create \
    --resource-group "$RG" \
    --name "$VM_NAME" \
    --image "$IMAGE_ID" \
    --subnet "$SUBNET_ID" \
    --size "$VM_SIZE" \
    --os-disk-delete-option "Delete" \
    --location "$LOCATION" \
    --output json > "${VM_NAME}-output.json" &
done

# Wait for all creations
wait
echo "All VMs created"

# Get host pool token
echo "Getting host pool registration token..."
TOKEN=$(az desktopvirtualization hostpool update \
  --name "$HOSTPOOL" \
  --resource-group "$RG" \
  --registration-info expiration-time="2025-12-11T23:59:59Z" registration-token-operation="Update" \
  --query "registrationInfo.token" -o tsv)

echo "Token: ${TOKEN:0:20}..."
echo "$TOKEN" > hostpool-token.txt

echo "Deployment complete. Register VMs with token in hostpool-token.txt"
```

## Troubleshooting

### Image Not Found
- Verify gallery exists: `az sig list`
- Check image definition: `az sig image-definition list`
- List image versions: `az sig image-version list`

### VM Creation Fails
- Verify subnet exists and has available IPs
- Check VM size availability in region
- Ensure sufficient quota in subscription

### Cannot Register Host
- Verify token is current (tokens expire)
- Ensure VM has internet connectivity
- Check AVD agent installer can download

### Disk Cleanup Issues
- Use `--os-disk-delete-option "Delete"` on creation
- Manually delete orphaned disks with `az disk delete`

## References

- [Azure VM Documentation](https://learn.microsoft.com/en-us/azure/virtual-machines/)
- [VM Size Reference](https://learn.microsoft.com/en-us/azure/virtual-machines/sizes)
- [AVD Registration Documentation](https://learn.microsoft.com/en-us/azure/virtual-desktop/create-host-pools-azure-marketplace)
