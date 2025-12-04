# Step 12 - Cleanup & Migration Commands Reference

Quick reference for cleanup operations and resource migration.

## Prerequisites

```bash
# Ensure authenticated
az account show

# Set variables
RG="RG-Azure-VDI-01"

# IMPORTANT: Always run in dry-run mode first!
DRY_RUN="true"
```

## Resource Listing & Discovery

### Find Resources by Pattern

```bash
# Find temporary VMs (containing "temp" in name)
az vm list \
  --resource-group "$RG" \
  --query "[?contains(name, 'temp')].{name: name, id: id, state: powerState}" \
  --output table

# Find temporary disks
az disk list \
  --resource-group "$RG" \
  --query "[?contains(name, 'temp')].{name: name, id: id}" \
  --output table

# Find unattached disks (orphaned)
az disk list \
  --resource-group "$RG" \
  --query "[?diskState=='Unattached'].{name: name, id: id, created: timeCreated}" \
  --output table

# Find unused images
az image list \
  --resource-group "$RG" \
  --query "[?contains(name, 'temp')].{name: name, id: id}" \
  --output table
```

### Find Resources by Age

```bash
# Find disks older than 7 days (unattached)
az disk list \
  --resource-group "$RG" \
  --query "[?diskState=='Unattached' && timeCreated < now_add('-7', 'days')]" \
  --output json
```

## VM Cleanup Operations

### Deallocate VM (Stop Compute Charges)

```bash
# Deallocate single VM
az vm deallocate \
  --resource-group "$RG" \
  --name "temp-vm-1"

# Deallocate all VMs with pattern
az vm list \
  --resource-group "$RG" \
  --query "[?contains(name, 'temp')].name" -o tsv | \
  while read VM; do
    echo "Deallocating: $VM"
    az vm deallocate --resource-group "$RG" --name "$VM" --no-wait
  done

# Wait for all deallocations
wait
echo "All VMs deallocated"
```

### Delete VM

```bash
# Delete single VM
az vm delete \
  --resource-group "$RG" \
  --name "temp-vm-1" \
  --yes

# Delete all temporary VMs
az vm list \
  --resource-group "$RG" \
  --query "[?contains(name, 'temp')].name" -o tsv | \
  while read VM; do
    echo "Deleting VM: $VM"
    az vm delete --resource-group "$RG" --name "$VM" --yes --no-wait
  done

# Wait for deletions
wait
echo "All VMs deleted"
```

### Delete VM (Dry-Run Preview)

```bash
#!/bin/bash

RG="RG-Azure-VDI-01"
PATTERN="temp"

echo "=== Dry-Run: VMs to be deleted ==="

az vm list \
  --resource-group "$RG" \
  --query "[?contains(name, '$PATTERN')]" \
  --output table

echo ""
echo "To proceed with deletion, run the commands above without --no-wait"
echo "Or use: az vm delete --resource-group \"$RG\" --name \"<vm-name>\" --yes"
```

## Disk Cleanup Operations

### Delete Unattached Disks

```bash
# Delete single unattached disk
az disk delete \
  --resource-group "$RG" \
  --name "orphan-disk-1" \
  --yes

# Delete all unattached disks
az disk list \
  --resource-group "$RG" \
  --query "[?diskState=='Unattached'].name" -o tsv | \
  while read DISK; do
    echo "Deleting disk: $DISK"
    az disk delete --resource-group "$RG" --name "$DISK" --yes --no-wait
  done

# Wait for deletions
wait
echo "All unattached disks deleted"
```

### Delete Specific Disk Pattern

```bash
# Delete all disks matching pattern
PATTERN="temp|backup|old"

az disk list \
  --resource-group "$RG" \
  --query "[?matches(name, '$PATTERN')].name" -o tsv | \
  while read DISK; do
    echo "Deleting disk: $DISK"
    az disk delete --resource-group "$RG" --name "$DISK" --yes
  done
```

### Disk Cleanup Dry-Run

```bash
#!/bin/bash

RG="RG-Azure-VDI-01"

echo "=== Unattached Disks (Safe to delete) ==="
az disk list \
  --resource-group "$RG" \
  --query "[?diskState=='Unattached'].{name: name, size: diskSizeGb, created: timeCreated}" \
  --output table

echo ""
echo "To delete, run: az disk delete --resource-group \"$RG\" --name \"<disk-name>\" --yes"
```

## Image Cleanup Operations

### Delete Images

```bash
# Delete single image
az image delete \
  --resource-group "$RG" \
  --name "temp-image-1" \
  --yes

# Delete all images with pattern
az image list \
  --resource-group "$RG" \
  --query "[?contains(name, 'temp')].name" -o tsv | \
  while read IMAGE; do
    echo "Deleting image: $IMAGE"
    az image delete --resource-group "$RG" --name "$IMAGE" --yes
  done
```

### Delete Gallery Images

```bash
# List gallery images
az sig image-version list \
  --resource-group "$RG" \
  --gallery-name "avdimagegallery" \
  --gallery-image-definition "golden-image" \
  --output table

# Delete specific image version
az sig image-version delete \
  --resource-group "$RG" \
  --gallery-name "avdimagegallery" \
  --gallery-image-definition "golden-image" \
  --gallery-image-version "1.0.0"

# Delete entire image definition
az sig image-definition delete \
  --resource-group "$RG" \
  --gallery-name "avdimagegallery" \
  --gallery-image-definition "golden-image"
```

## Network Cleanup Operations

### Delete Network Interfaces

```bash
# List network interfaces
az network nic list \
  --resource-group "$RG" \
  --query "[?contains(name, 'temp')].{name: name, id: id}" \
  --output table

# Delete network interface
az network nic delete \
  --resource-group "$RG" \
  --name "nic-temp-1" \
  --yes

# Delete all temporary NICs
az network nic list \
  --resource-group "$RG" \
  --query "[?contains(name, 'temp')].name" -o tsv | \
  while read NIC; do
    echo "Deleting NIC: $NIC"
    az network nic delete --resource-group "$RG" --name "$NIC" --yes
  done
```

### Delete NSGs and Rules

```bash
# Delete network security group
az network nsg delete \
  --resource-group "$RG" \
  --name "nsg-temp" \
  --yes

# Delete NSG rule
az network nsg rule delete \
  --resource-group "$RG" \
  --nsg-name "nsg-session-hosts" \
  --name "allow-temp-rdp"
```

## Storage Cleanup Operations

### Delete File Shares

```bash
# Delete file share
az storage share delete \
  --account-name "avdfslogix001" \
  --name "temp-share"

# Delete all shares matching pattern
az storage share list \
  --account-name "avdfslogix001" \
  --query "[?contains(name, 'temp')].name" -o tsv | \
  while read SHARE; do
    echo "Deleting share: $SHARE"
    az storage share delete --account-name "avdfslogix001" --name "$SHARE"
  done
```

### Clear Storage Account Blobs

```bash
# List blobs
az storage blob list \
  --account-name "avdfslogix001" \
  --container-name "temp-container"

# Delete blobs
az storage blob delete \
  --account-name "avdfslogix001" \
  --container-name "temp-container" \
  --name "temp-file.vhd"

# Delete entire container
az storage container delete \
  --account-name "avdfslogix001" \
  --name "temp-container"
```

## Complete Cleanup Script with Safety

```bash
#!/bin/bash

set -euo pipefail

# Variables
RG="RG-Azure-VDI-01"
DRY_RUN="${DRY_RUN:-true}"
PATTERNS=("temp" "tmp" "backup")
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
CLEANUP_LOG="cleanup-${TIMESTAMP}.log"

# Functions
log() { echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "$CLEANUP_LOG"; }
error() { echo "ERROR: $*" >&2; exit 1; }

# Safety check
if [[ "$DRY_RUN" == "true" ]]; then
  log "Running in DRY-RUN mode (no deletions)"
  log "Set DRY_RUN=false to execute actual cleanup"
else
  log "WARNING: Running in DESTRUCTIVE mode (resources will be deleted)"
  log "Press Ctrl+C to cancel or wait 10 seconds..."
  sleep 10
fi

# Cleanup function
cleanup_resources() {
  local resource_type="$1"
  local pattern="$2"

  log "=== Checking for $resource_type matching: $pattern ==="

  case "$resource_type" in
    "vms")
      az vm list \
        --resource-group "$RG" \
        --query "[?contains(name, '$pattern')].name" -o tsv | \
        while read -r resource; do
          if [[ "$DRY_RUN" == "true" ]]; then
            log "DRY-RUN: Would delete VM: $resource"
          else
            log "Deleting VM: $resource"
            az vm delete --resource-group "$RG" --name "$resource" --yes --no-wait
          fi
        done
      ;;
    "disks")
      az disk list \
        --resource-group "$RG" \
        --query "[?diskState=='Unattached' && contains(name, '$pattern')].name" -o tsv | \
        while read -r resource; do
          if [[ "$DRY_RUN" == "true" ]]; then
            log "DRY-RUN: Would delete disk: $resource"
          else
            log "Deleting disk: $resource"
            az disk delete --resource-group "$RG" --name "$resource" --yes
          fi
        done
      ;;
    "images")
      az image list \
        --resource-group "$RG" \
        --query "[?contains(name, '$pattern')].name" -o tsv | \
        while read -r resource; do
          if [[ "$DRY_RUN" == "true" ]]; then
            log "DRY-RUN: Would delete image: $resource"
          else
            log "Deleting image: $resource"
            az image delete --resource-group "$RG" --name "$resource" --yes
          fi
        done
      ;;
  esac
}

# Main execution
log "Starting cleanup of resource group: $RG"

for pattern in "${PATTERNS[@]}"; do
  cleanup_resources "vms" "$pattern"
  cleanup_resources "disks" "$pattern"
  cleanup_resources "images" "$pattern"
done

# Cleanup orphaned disks
log "=== Checking for orphaned unattached disks ==="
az disk list \
  --resource-group "$RG" \
  --query "[?diskState=='Unattached'].{name: name, created: timeCreated}" \
  --output table | tee -a "$CLEANUP_LOG"

log "Cleanup complete. Log saved to: $CLEANUP_LOG"
```

## Migration Operations

### Export VM Configuration

```bash
# Export VM as template
az vm run-command invoke \
  --resource-group "$RG" \
  --name "avd-session-host-1" \
  --command-id RunShellScript \
  --scripts "echo 'VM configuration exported'"

# Or export as JSON
az vm show \
  --resource-group "$RG" \
  --name "avd-session-host-1" \
  --output json > vm-config.json
```

### Migrate Resources to Different Resource Group

```bash
# Move VM to different resource group
az resource move \
  --ids "/subscriptions/<sub-id>/resourceGroups/$RG/providers/Microsoft.Compute/virtualMachines/avd-session-host-1" \
  --destination-group "RG-New-Location"

# Move multiple resources
RESOURCE_IDS=$(az resource list \
  --resource-group "$RG" \
  --query "[?contains(name, 'avd')].id" -o tsv)

az resource move --ids $RESOURCE_IDS --destination-group "RG-New-Location"
```

## Troubleshooting

### Resource in Use Cannot Delete
- Check if resource has dependencies
- List dependent resources: `az resource list --depends-on <resource-id>`
- Delete dependents first

### Disk Still Attached
- Verify disk is deallocated with VM
- Check disk details: `az disk show --name <disk-name>`
- May need to wait for asynchronous operations

### Cannot Delete Unattached Disk
- Verify disk is truly unattached
- Try again after 5 minutes

## References

- [Delete Resources](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/delete-resource-group)
- [Move Resources](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/move-resource-group-and-subscription)
- [Cleanup Best Practices](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/delete-resource-group)
