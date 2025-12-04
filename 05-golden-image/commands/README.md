# Command Reference Guide

This directory contains reusable Azure CLI commands for golden image operations. These commands are documented and ready for direct execution or incorporation into custom scripts.

## Files

### `vm-operations.sh`
Commands for virtual machine lifecycle management:
- **Create VM** - Create a new Windows VM with TrustedLaunch security
- **Get VM Details** - Retrieve IP addresses, status, and configuration
- **Run Commands** - Execute PowerShell scripts on running VM
- **State Management** - Start, stop, restart, deallocate VM
- **Deletion** - Delete VM and associated resources
- **Disk Management** - List and delete VM disks
- **Network Management** - List and delete network interfaces
- **Public IP Management** - List and delete public IPs
- **Troubleshooting** - Check provisioning state, agent status

### `image-operations.sh`
Commands for Azure Compute Gallery management:
- **Gallery Management** - Create, list, delete galleries
- **Image Definition** - Create, list, delete image definitions
- **Image Version** - Create from VM or VHD, list, delete versions
- **Deployment Reference** - Get image IDs for session host deployment
- **Replication** - Configure multi-region replication
- **Troubleshooting** - Check provisioning state, replication status
- **Cleanup** - Delete old image versions

## Usage

### Option 1: Execute Commands Directly

Each command is provided in comment blocks. Copy the command you need and run it:

```bash
# Source the configuration first
source ../config.env

# Run a command from the reference
az vm create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$TEMP_VM_NAME" \
    ...
```

### Option 2: Source and Use Helper Functions

Source the file to access commands:

```bash
source ./commands/vm-operations.sh
source ../config.env

# Then execute commands
create_vm
```

### Option 3: Use in Task Scripts

Task scripts already use these commands internally. Reference them for custom workflows:

```bash
source ../config.env
source ./commands/image-operations.sh

# Custom logic here
```

## Command Structure

Each command follows this format:

```bash
# Description of what the command does
# Prerequisites: What must be set up first
# Expected output: What you'll see when it succeeds
# Expected duration: How long it takes
# Usage example: How to run it

: '
az command \
    --parameter "$VARIABLE" \
    --another-param "value" \
    --output json
'
```

The `: '...'` syntax is a shell comment that preserves the command for easy copy/paste.

## Important Notes

### Before Running Commands

1. **Always source config.env first**:
   ```bash
   source ../config.env
   ```

2. **Verify all variables are set**:
   ```bash
   echo $RESOURCE_GROUP_NAME
   echo $TEMP_VM_NAME
   ```

3. **Review each command** before execution to ensure it matches your environment

4. **Test in non-production first** before running against production resources

### Security Considerations

- **ADMIN_PASSWORD**: Never hardcode passwords. Set as environment variable:
  ```bash
  export ADMIN_PASSWORD="SecurePassword123!"
  ```

- **Output**: Commands output JSON by default. Consider using `--output json` for automation and `--output table` for human-readable output

- **Error Handling**: Add error handling when using commands in scripts:
  ```bash
  set -e  # Exit on error
  ```

## Common Workflows

### Create Golden Image

1. **Create VM**:
   ```bash
   source ../config.env
   source ./commands/vm-operations.sh

   # Copy and run the "Create VM" command
   ```

2. **Wait for readiness** (see task 02)

3. **Configure VM** (see task 03)

4. **Sysprep** (see task 04)

5. **Capture image**:
   ```bash
   source ../config.env
   source ./commands/image-operations.sh

   # Get VM ID and run "Create Image Version from VM"
   ```

### Deploy from Golden Image

1. **Get image ID**:
   ```bash
   source ../config.env
   source ./commands/image-operations.sh

   # Run "Get Image Resource ID"
   ```

2. **Create session hosts** (use image ID from above):
   ```bash
   # Use the image ID in a vm create command
   ```

### List Available Images

```bash
source ../config.env
source ./commands/image-operations.sh

# List image versions
az sig image-version list \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --gallery-name "$IMAGE_GALLERY_NAME" \
    --gallery-image-definition "$IMAGE_DEFINITION_NAME" \
    --output table
```

### Cleanup Old Versions

```bash
source ../config.env
source ./commands/image-operations.sh

# List versions to see which ones to delete
az sig image-version list \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --gallery-name "$IMAGE_GALLERY_NAME" \
    --gallery-image-definition "$IMAGE_DEFINITION_NAME" \
    --query "sort_by([].{Name:name, Created:timeCreated}, &Created)" \
    --output table

# Delete old version
az sig image-version delete \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --gallery-name "$IMAGE_GALLERY_NAME" \
    --gallery-image-definition "$IMAGE_DEFINITION_NAME" \
    --gallery-image-version "2025.1101.0000"
```

## Troubleshooting

### VM not transitioning to "running"

Check provisioning state:
```bash
source ../config.env
source ./commands/vm-operations.sh

# Run "Check VM provisioning state" command
```

### Image version stuck in "Creating" state

Check replication status:
```bash
source ../config.env
source ./commands/image-operations.sh

# Run "Get image version replication status" command
```

### Cannot delete disk/NIC

Check if it's attached:
```bash
source ../config.env
source ./commands/vm-operations.sh

# Run appropriate "Check if attached" commands
```

## Reference Documentation

- [Azure CLI VM Commands](https://learn.microsoft.com/en-us/cli/azure/vm)
- [Azure CLI Compute Gallery](https://learn.microsoft.com/en-us/cli/azure/sig)
- [Azure Compute Gallery Documentation](https://learn.microsoft.com/en-us/azure/virtual-machines/shared-image-galleries)
- [Azure CLI Configuration Management](https://learn.microsoft.com/en-us/cli/azure/authorize-access-with-manage-identity)
