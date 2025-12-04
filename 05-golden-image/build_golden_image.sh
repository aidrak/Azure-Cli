#!/bin/bash

# This script orchestrates the entire golden image creation process.
# It sources variables from config.env and executes the required scripts in order.

set -e # Exit immediately if a command exits with a non-zero status.

# --- Setup ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.env"

# Load environment variables
if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: Configuration file not found at $CONFIG_FILE"
    echo "Please create it based on the template."
    exit 1
fi
source "$CONFIG_FILE"

echo "=== Starting Golden Image Creation Process ==="

# --- 1. Create the temporary VM ---
echo "--> Step 1: Creating temporary VM..."
# Assuming create_vm.sh is in the same directory and is executable.
# It should use the environment variables sourced from config.env.
. "$SCRIPT_DIR/create_vm.sh"
echo "VM '$VM_NAME' created successfully."

# --- 2. Run PowerShell Configuration Script on the VM ---
echo "--> Step 2: Running 'config_vm.ps1' to configure the VM..."
az vm run-command invoke \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$VM_NAME" \
    --command-id RunPowerShellScript \
    --scripts "@$SCRIPT_DIR/config_vm.ps1"

echo "Configuration script executed."

# --- 3. Sysprep the VM ---
echo "--> Step 3: Sysprepping the VM..."
az vm run-command invoke \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$VM_NAME" \
    --command-id RunPowerShellScript \
    --scripts "@$SCRIPT_DIR/sysprep_vm.ps1"

# It's important to wait for the VM to be generalized and stopped.
echo "Waiting for VM to be generalized..."
az vm wait --resource-group "$RESOURCE_GROUP_NAME" --name "$VM_NAME" --custom "powerState=='VM deallocated'" --timeout 600

echo "VM has been generalized and deallocated."

# --- 4. Capture the Image ---
echo "--> Step 4: Capturing the image..."
# Assuming capture_image.sh is in the same directory and is executable.
# It should use the environment variables sourced from config.env.
. "$SCRIPT_DIR/capture_image.sh"
echo "Image captured successfully."

echo "=== Golden Image Creation Process Finished ==="
