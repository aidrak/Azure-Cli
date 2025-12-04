#!/bin/bash

# ============================================================================
# VM Operations Command Reference
# ============================================================================
#
# This file contains reusable Azure CLI commands for VM operations.
# These commands are documented and ready for direct execution or
# incorporation into scripts.
#
# Usage: Source this file and execute commands as needed
#   source ./commands/vm-operations.sh
#   create_vm
#
# Note: These are example commands. Always review and customize
# for your specific environment before running.
#

# ============================================================================
# Configuration (from config.env)
# ============================================================================
# Assumes config.env has been sourced with all required variables:
# RESOURCE_GROUP_NAME, LOCATION, TEMP_VM_NAME, VM_SIZE, WINDOWS_IMAGE_SKU,
# VNET_NAME, SUBNET_NAME, ADMIN_USERNAME, ADMIN_PASSWORD, TAGS

# ============================================================================
# Create VM
# ============================================================================

# Creates a new Windows VM with TrustedLaunch security enabled
# Prerequisites:
#   - Resource group must exist
#   - VNet and subnet must exist
#   - ADMIN_PASSWORD should be a secure password
# Expected output:
#   - VM resource created in Azure
#   - Public IP assigned
# Expected duration: 5-10 minutes
#
# Example usage:
#   ADMIN_PASSWORD="MySecurePassword123!" ./commands/vm-operations.sh
#
: '
az vm create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$TEMP_VM_NAME" \
    --image "$WINDOWS_IMAGE_SKU" \
    --size "$VM_SIZE" \
    --admin-username "$ADMIN_USERNAME" \
    --admin-password "$ADMIN_PASSWORD" \
    --vnet-name "$VNET_NAME" \
    --subnet "$SUBNET_NAME" \
    --public-ip-sku Standard \
    --security-type TrustedLaunch \
    --enable-secure-boot true \
    --enable-vtpm true \
    --location "$LOCATION" \
    --tags $TAGS \
    --output json
'

# ============================================================================
# Get VM Details
# ============================================================================

# Retrieves VM information including IPs, status, and configuration
# Usage examples:

# Get VM power state
: '
az vm get-instance-view \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$TEMP_VM_NAME" \
    --query "instanceView.statuses[?starts_with(code, '"'"'PowerState'"'"')].displayStatus" \
    -o tsv
'

# Get public IP address
: '
az vm show \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$TEMP_VM_NAME" \
    -d \
    --query "publicIps" \
    -o tsv
'

# Get private IP address
: '
az vm show \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$TEMP_VM_NAME" \
    -d \
    --query "privateIps" \
    -o tsv
'

# Get VM ID (useful for image capture)
: '
az vm show \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$TEMP_VM_NAME" \
    --query "id" \
    -o tsv
'

# Get full VM details
: '
az vm show \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$TEMP_VM_NAME" \
    -d \
    --output json
'

# ============================================================================
# Run Commands on VM (Remote Execution)
# ============================================================================

# Execute PowerShell script on running VM via Azure CLI
# Note: VM must be running and have network access
# Expected output: Command execution result (stdout/stderr)
# Expected duration: Varies based on script complexity
#
# Example: Run Windows Update check
: '
az vm run-command invoke \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$TEMP_VM_NAME" \
    --command-id RunPowerShellScript \
    --scripts "Get-WmiObject Win32_QuickFixEngineering | Measure-Object" \
    --output json
'

# Example: Run Sysprep
: '
az vm run-command invoke \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$TEMP_VM_NAME" \
    --command-id RunPowerShellScript \
    --scripts "C:\\Windows\\System32\\Sysprep\\sysprep.exe /oobe /generalize /shutdown /quiet" \
    --output json
'

# ============================================================================
# VM State Management
# ============================================================================

# Deallocate VM (stops and deallocates compute)
# Usage: When VM needs to be deallocated for image capture or to save costs
: '
az vm deallocate \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$TEMP_VM_NAME" \
    --no-wait \
    --output json
'

# Start VM
# Usage: When VM is deallocated and needs to be started
: '
az vm start \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$TEMP_VM_NAME" \
    --no-wait \
    --output json
'

# Restart VM
# Usage: To restart a running VM
: '
az vm restart \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$TEMP_VM_NAME" \
    --no-wait \
    --output json
'

# Generalize VM
# Usage: Mark VM as generalized for image capture
# Note: Should be done after sysprep
: '
az vm generalize \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$TEMP_VM_NAME" \
    --output json
'

# ============================================================================
# VM Deletion
# ============================================================================

# Delete VM (also removes associated disks and NICs if no other resources reference them)
# Warning: This action is destructive and cannot be undone
# Usage: After golden image is captured and no longer needed
: '
az vm delete \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$TEMP_VM_NAME" \
    --yes \
    --no-wait \
    --output json
'

# ============================================================================
# Disk Management
# ============================================================================

# List disks associated with resource group
: '
az disk list \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --query "[?contains(name, '"'"'$TEMP_VM_NAME'"'"')].{Name:name, State:diskState, Size:diskSizeGb}" \
    --output table
'

# Delete a specific disk
: '
az disk delete \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "disk-name" \
    --yes \
    --no-wait
'

# ============================================================================
# Network Interface Management
# ============================================================================

# List network interfaces for resource group
: '
az network nic list \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --query "[?contains(name, '"'"'$TEMP_VM_NAME'"'"')].{Name:name, VirtualMachine:virtualMachine}" \
    --output table
'

# Delete a specific network interface
: '
az network nic delete \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "nic-name" \
    --no-wait
'

# ============================================================================
# Public IP Management
# ============================================================================

# List public IPs for resource group
: '
az network public-ip list \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --query "[?contains(name, '"'"'$TEMP_VM_NAME'"'"')].{Name:name, IpAddress:ipAddress, State:provisioningState}" \
    --output table
'

# Delete a specific public IP
: '
az network public-ip delete \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "public-ip-name" \
    --no-wait
'

# ============================================================================
# Troubleshooting Commands
# ============================================================================

# Check VM provisioning state
: '
az vm get-instance-view \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$TEMP_VM_NAME" \
    --query "provisioningState" \
    -o tsv
'

# Check VM agent status
: '
az vm get-instance-view \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$TEMP_VM_NAME" \
    --query "instanceView.vmAgent.statuses" \
    -o json
'

# Check extension statuses
: '
az vm get-instance-view \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$TEMP_VM_NAME" \
    --query "instanceView.extensions" \
    -o json
'
