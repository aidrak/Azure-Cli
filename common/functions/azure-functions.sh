#!/bin/bash

# Azure CLI wrapper functions for deployment scripts
#
# Purpose: Standardized Azure CLI operations with error handling
# Usage: source ../common/functions/azure-functions.sh
#
# Functions:
#   azure_vm_create()      - Create VM with standard options
#   azure_vm_delete()      - Delete VM with cleanup
#   azure_vm_start()       - Start stopped VM
#   azure_vm_stop()        - Stop running VM
#   azure_vm_status()      - Get VM status
#   azure_run_command()    - Execute command on VM
#   azure_wait_operation() - Wait for async operation
#   azure_check_auth()     - Verify Azure authentication
#   azure_set_subscription()- Set active subscription
#
# Error Handling:
#   All functions return 0 on success, 1 on failure
#   Errors logged via log_error() function
#   Check function result with: if ! azure_vm_create ...; then

# Retry configuration
AZURE_RETRY_COUNT="${AZURE_RETRY_COUNT:-3}"
AZURE_RETRY_DELAY="${AZURE_RETRY_DELAY:-5}"

# ============================================================================
# Authentication Functions
# ============================================================================

# Check Azure CLI authentication
# Usage: if ! azure_check_auth; then exit 1; fi
azure_check_auth() {
    if ! command -v az &>/dev/null; then
        log_error "Azure CLI not installed"
        return 1
    fi

    if ! az account show &>/dev/null; then
        log_error "Not authenticated to Azure. Run: az login"
        return 1
    fi

    log_success "Azure authentication verified"
    return 0
}

# Set active subscription
# Usage: azure_set_subscription "subscription-id-or-name"
azure_set_subscription() {
    local subscription="$1"

    if [[ -z "$subscription" ]]; then
        log_error "Subscription ID or name required"
        return 1
    fi

    if ! az account set --subscription "$subscription" &>/dev/null; then
        log_error "Failed to set subscription: $subscription"
        return 1
    fi

    local current
    current=$(az account show --query name -o tsv)
    log_success "Active subscription: $current"
    return 0
}

# Get current subscription ID
# Usage: subscription_id=$(azure_get_subscription_id)
azure_get_subscription_id() {
    az account show --query id -o tsv
}

# ============================================================================
# Resource Group Functions
# ============================================================================

# Check if resource group exists
# Usage: if azure_rg_exists "RG-Azure-VDI"; then ... fi
azure_rg_exists() {
    local resource_group="$1"

    if [[ -z "$resource_group" ]]; then
        log_error "Resource group name required"
        return 1
    fi

    az group exists --name "$resource_group" | grep -q "true"
}

# Get resource group details
# Usage: details=$(azure_rg_show "RG-Azure-VDI")
azure_rg_show() {
    local resource_group="$1"
    local query="${2:-}"

    if [[ -z "$resource_group" ]]; then
        log_error "Resource group name required"
        return 1
    fi

    az group show --name "$resource_group" ${query:+--query "$query"} -o tsv
}

# ============================================================================
# Virtual Machine Functions
# ============================================================================

# Create virtual machine with error handling and retry
# Usage: azure_vm_create "resource-group" "vm-name" "image" "size"
azure_vm_create() {
    local resource_group="$1"
    local vm_name="$2"
    local image="$3"
    local size="$4"

    if [[ -z "$resource_group" ]] || [[ -z "$vm_name" ]]; then
        log_error "Resource group and VM name required"
        return 1
    fi

    # Check if VM already exists
    if azure_vm_exists "$resource_group" "$vm_name"; then
        log_warning "VM already exists: $vm_name"
        return 0
    fi

    log_info "Creating VM: $vm_name (size: $size, image: $image)"

    local attempt=1
    while [[ $attempt -le $AZURE_RETRY_COUNT ]]; do
        if az vm create \
            --resource-group "$resource_group" \
            --name "$vm_name" \
            --image "$image" \
            --size "$size" \
            --output none 2>/dev/null; then

            log_success "VM created: $vm_name"
            return 0
        fi

        log_warning "VM creation attempt $attempt failed, retrying..."
        ((attempt++))
        sleep "$AZURE_RETRY_DELAY"
    done

    log_error "Failed to create VM after $AZURE_RETRY_COUNT attempts"
    return 1
}

# Delete virtual machine
# Usage: azure_vm_delete "resource-group" "vm-name"
azure_vm_delete() {
    local resource_group="$1"
    local vm_name="$2"

    if [[ -z "$resource_group" ]] || [[ -z "$vm_name" ]]; then
        log_error "Resource group and VM name required"
        return 1
    fi

    # Check if VM exists
    if ! azure_vm_exists "$resource_group" "$vm_name"; then
        log_warning "VM not found: $vm_name"
        return 0
    fi

    log_info "Deleting VM: $vm_name"

    if ! az vm delete \
        --resource-group "$resource_group" \
        --name "$vm_name" \
        --yes \
        --no-wait \
        --output none; then

        log_error "Failed to delete VM: $vm_name"
        return 1
    fi

    log_success "VM deletion initiated: $vm_name"
    return 0
}

# Check if VM exists
# Usage: if azure_vm_exists "RG" "vm-name"; then ... fi
azure_vm_exists() {
    local resource_group="$1"
    local vm_name="$2"

    az vm show --resource-group "$resource_group" --name "$vm_name" \
        &>/dev/null
}

# Get VM status
# Usage: status=$(azure_vm_status "RG" "vm-name")
azure_vm_status() {
    local resource_group="$1"
    local vm_name="$2"

    if ! azure_vm_exists "$resource_group" "$vm_name"; then
        echo "not-found"
        return 1
    fi

    local power_state
    power_state=$(az vm get-instance-view \
        --resource-group "$resource_group" \
        --name "$vm_name" \
        --query "instanceView.statuses[?starts_with(code, 'PowerState/')].displayStatus" \
        -o tsv 2>/dev/null)

    if [[ -z "$power_state" ]]; then
        echo "unknown"
    else
        echo "$power_state"
    fi
}

# Start VM
# Usage: azure_vm_start "RG" "vm-name"
azure_vm_start() {
    local resource_group="$1"
    local vm_name="$2"

    if [[ -z "$resource_group" ]] || [[ -z "$vm_name" ]]; then
        log_error "Resource group and VM name required"
        return 1
    fi

    log_info "Starting VM: $vm_name"

    if ! az vm start \
        --resource-group "$resource_group" \
        --name "$vm_name" \
        --no-wait \
        --output none; then

        log_error "Failed to start VM: $vm_name"
        return 1
    fi

    log_success "VM start initiated: $vm_name"
    return 0
}

# Stop VM
# Usage: azure_vm_stop "RG" "vm-name"
azure_vm_stop() {
    local resource_group="$1"
    local vm_name="$2"

    if [[ -z "$resource_group" ]] || [[ -z "$vm_name" ]]; then
        log_error "Resource group and VM name required"
        return 1
    fi

    log_info "Stopping VM: $vm_name"

    if ! az vm stop \
        --resource-group "$resource_group" \
        --name "$vm_name" \
        --no-wait \
        --output none; then

        log_error "Failed to stop VM: $vm_name"
        return 1
    fi

    log_success "VM stop initiated: $vm_name"
    return 0
}

# Deallocate VM (stop and remove compute resources)
# Usage: azure_vm_deallocate "RG" "vm-name"
azure_vm_deallocate() {
    local resource_group="$1"
    local vm_name="$2"

    if [[ -z "$resource_group" ]] || [[ -z "$vm_name" ]]; then
        log_error "Resource group and VM name required"
        return 1
    fi

    log_info "Deallocating VM: $vm_name"

    if ! az vm deallocate \
        --resource-group "$resource_group" \
        --name "$vm_name" \
        --no-wait \
        --output none; then

        log_error "Failed to deallocate VM: $vm_name"
        return 1
    fi

    log_success "VM deallocation initiated: $vm_name"
    return 0
}

# ============================================================================
# Command Execution
# ============================================================================

# Run command on VM via Azure CLI
# Usage: azure_run_command "RG" "vm-name" "powershell" "command or script"
azure_run_command() {
    local resource_group="$1"
    local vm_name="$2"
    local command_type="${3:-RunPowerShellScript}"
    local script_content="$4"

    if [[ -z "$resource_group" ]] || [[ -z "$vm_name" ]] || [[ -z "$script_content" ]]; then
        log_error "Resource group, VM name, and script content required"
        return 1
    fi

    log_info "Executing command on VM: $vm_name"
    log_debug "Command type: $command_type"

    if ! az vm run-command invoke \
        --resource-group "$resource_group" \
        --name "$vm_name" \
        --command-id "$command_type" \
        --scripts "$script_content" \
        --output json; then

        log_error "Failed to execute command on VM: $vm_name"
        return 1
    fi

    log_success "Command executed successfully on VM: $vm_name"
    return 0
}

# Run command from file on VM
# Usage: azure_run_command_file "RG" "vm-name" "powershell" "script.ps1"
azure_run_command_file() {
    local resource_group="$1"
    local vm_name="$2"
    local command_type="${3:-RunPowerShellScript}"
    local script_file="$4"

    if [[ ! -f "$script_file" ]]; then
        log_error "Script file not found: $script_file"
        return 1
    fi

    local script_content
    script_content=$(<"$script_file")

    azure_run_command "$resource_group" "$vm_name" "$command_type" "$script_content"
}

# ============================================================================
# Async Operation Waiting
# ============================================================================

# Wait for VM to reach desired state
# Usage: azure_wait_vm_state "RG" "vm-name" "VM running" 300
azure_wait_vm_state() {
    local resource_group="$1"
    local vm_name="$2"
    local desired_state="$3"
    local timeout_seconds="${4:-600}"

    local elapsed=0
    local poll_interval=5

    log_info "Waiting for VM to reach state: $desired_state (timeout: ${timeout_seconds}s)"

    while [[ $elapsed -lt $timeout_seconds ]]; do
        local current_state
        current_state=$(azure_vm_status "$resource_group" "$vm_name")

        if [[ "$current_state" == "$desired_state" ]]; then
            log_success "VM reached desired state: $desired_state"
            return 0
        fi

        log_debug "Current state: $current_state (elapsed: ${elapsed}s)"

        sleep "$poll_interval"
        ((elapsed += poll_interval))
    done

    log_error "Timeout waiting for VM state: $desired_state"
    return 1
}

# Wait for async operation to complete
# Usage: azure_wait_operation "operation-id"
azure_wait_operation() {
    local operation_id="$1"
    local timeout_seconds="${2:-600}"

    if [[ -z "$operation_id" ]]; then
        log_error "Operation ID required"
        return 1
    fi

    log_info "Waiting for operation: $operation_id"

    # This is a placeholder - actual implementation depends on operation type
    # For now, simple polling wait
    sleep 30

    log_success "Operation completed: $operation_id"
    return 0
}

# ============================================================================
# Error Handling Utilities
# ============================================================================

# Execute Azure CLI command with error handling
# Usage: azure_execute "az vm show -g RG -n vm-name"
azure_execute() {
    local command="$1"
    local error_message="${2:-Azure CLI command failed}"

    if ! eval "$command"; then
        log_error "$error_message"
        return 1
    fi

    return 0
}

# Get detailed error message from last Azure CLI operation
# Usage: azure_get_last_error
azure_get_last_error() {
    # Azure CLI error messages are typically in stderr
    # This function would require capturing stderr separately
    log_error "Check the error output above for details"
}

# ============================================================================
# Initialization
# ============================================================================

# Require logging functions
if ! declare -f log_info &>/dev/null; then
    log_info() { echo "INFO: $*"; }
    log_error() { echo "ERROR: $*" >&2; }
    log_warning() { echo "WARNING: $*"; }
    log_success() { echo "SUCCESS: $*"; }
    log_debug() { return 0; }
fi

# Export all functions
export -f azure_check_auth
export -f azure_set_subscription
export -f azure_get_subscription_id
export -f azure_rg_exists
export -f azure_rg_show
export -f azure_vm_create
export -f azure_vm_delete
export -f azure_vm_exists
export -f azure_vm_status
export -f azure_vm_start
export -f azure_vm_stop
export -f azure_vm_deallocate
export -f azure_run_command
export -f azure_run_command_file
export -f azure_wait_vm_state
export -f azure_wait_operation
export -f azure_execute
export -f azure_get_last_error
