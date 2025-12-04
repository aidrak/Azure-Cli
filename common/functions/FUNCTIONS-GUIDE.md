# Function Libraries Guide

Complete reference for reusable function libraries across all deployment steps.

## Overview

Function libraries provide reusable, well-tested functions that can be used across multiple deployment steps. This reduces code duplication and ensures consistent behavior.

## Available Function Libraries

### Bash Functions

#### 1. logging-functions.sh (450+ lines)

**Purpose**: Unified logging across all Bash scripts

**Core Functions**:
- `log_info()` - Informational messages (cyan)
- `log_success()` - Success messages (green checkmark)
- `log_error()` - Error messages (red X, stderr)
- `log_warning()` - Warning messages (yellow triangle)
- `log_section()` - Section headers (cyan box)
- `log_debug()` - Debug messages (gray, if DEBUG=1)

**File Management**:
- `save_log()` - Create timestamped log file
- `append_to_log()` - Append to existing log
- `get_log_file()` - Get current log file path

**Structured Output**:
- `log_key_value()` - Key-value pair formatting
- `log_data_block()` / `log_data_end()` - Data block headers

**Operation Tracking**:
- `track_operation()` - Track operation attempt
- `track_success()` / `track_failure()` - Track results
- `log_summary()` - Print operation summary

**Error Handling**:
- `die()` - Log error and exit
- `warn_continue()` - Log warning but continue

**Usage Example**:
```bash
#!/bin/bash
source ../common/functions/logging-functions.sh

# Initialize logging
ENABLE_LOGGING=1
LOG_FILE=$(save_log "my-task" "artifacts")

log_section "Starting Task"
log_info "Doing something"

if some_command; then
    log_success "Command succeeded"
    track_success
else
    log_error "Command failed"
    track_failure
fi

log_summary "Task"
```

#### 2. config-functions.sh (450+ lines)

**Purpose**: Configuration loading, validation, and management

**Core Functions**:
- `load_config()` - Load config from file (sources centralized first)
- `get_config()` - Get config value with fallback
- `set_config()` - Set config value in memory
- `config_is_set()` - Check if variable is set

**Validation**:
- `validate_config_value()` - Validate against pattern
- `validate_required_config()` - Validate multiple required variables
- `validate_azure_name()` - Validate Azure naming conventions
- `validate_cidr()` - Validate CIDR block format

**Azure Validators**:
- `is_valid_subscription_id()` - Check GUID format
- `is_valid_rg_name()` - Check resource group name
- `is_valid_location()` - Check against known regions

**Export & Output**:
- `export_config()` - Export to environment variables
- `list_config()` - Display all config variables
- `save_config()` - Save config to file

**Templates**:
- `get_config_template()` - Get template for resource type

**Usage Example**:
```bash
#!/bin/bash
source ../common/functions/logging-functions.sh
source ../common/functions/config-functions.sh

# Load configuration (centralized → local → environment)
load_config "config.env"

# Validate required variables
validate_required_config "RESOURCE_GROUP_NAME" "LOCATION" "VNET_NAME"

# Get config value with default
VM_SIZE=$(get_config "VM_SIZE" "Standard_D4s_v5")

# Validate specific values
validate_config_value "LOCATION" "^(eastus|centralus|westus)$" "Invalid location"

# Set new config value
set_config "DEPLOYMENT_ID" "deployment-$(date +%s)"
```

#### 3. azure-functions.sh (400+ lines)

**Purpose**: Standardized Azure CLI operations with error handling

**Authentication**:
- `azure_check_auth()` - Verify Azure CLI installation and auth
- `azure_set_subscription()` - Set active subscription
- `azure_get_subscription_id()` - Get current subscription ID

**Resource Group**:
- `azure_rg_exists()` - Check if RG exists
- `azure_rg_show()` - Get RG details

**Virtual Machines**:
- `azure_vm_create()` - Create VM (with retry logic)
- `azure_vm_delete()` - Delete VM
- `azure_vm_exists()` - Check if VM exists
- `azure_vm_status()` - Get VM power state
- `azure_vm_start()` - Start VM
- `azure_vm_stop()` - Stop VM
- `azure_vm_deallocate()` - Deallocate VM

**Command Execution**:
- `azure_run_command()` - Execute command on VM
- `azure_run_command_file()` - Execute script file on VM

**Waiting**:
- `azure_wait_vm_state()` - Wait for VM to reach state
- `azure_wait_operation()` - Wait for async operation

**Error Handling**:
- `azure_execute()` - Execute with error handling
- `azure_get_last_error()` - Get last error message

**Usage Example**:
```bash
#!/bin/bash
source ../common/functions/azure-functions.sh

# Verify authentication
if ! azure_check_auth; then
    log_error "Not authenticated"
    exit 1
fi

# Set subscription
azure_set_subscription "my-subscription-id"

# Create VM with retry
if azure_vm_create "RG" "my-vm" "UbuntuLTS" "Standard_D4s_v5"; then
    log_success "VM created"

    # Wait for running state
    if azure_wait_vm_state "RG" "my-vm" "VM running" 600; then
        log_success "VM is running"

        # Run command on VM
        azure_run_command "RG" "my-vm" "RunShellScript" "sudo apt update"
    fi
fi
```

#### 4. string-functions.sh (400+ lines)

**Purpose**: String manipulation and formatting utilities

**Sanitization**:
- `sanitize_name()` - Clean resource names (remove invalid chars, case conversion)
- `generate_unique_name()` - Generate name with timestamp
- `ensure_name_length()` - Enforce max length

**Azure IDs**:
- `parse_azure_id()` - Extract parts from resource ID
- `get_subscription_from_id()` - Extract subscription
- `get_rg_from_id()` - Extract resource group

**JSON**:
- `validate_json()` - Check JSON format validity
- `json_extract()` - Extract value from JSON
- `escape_json()` - Escape special characters

**Security**:
- `mask_secrets()` - Hide sensitive values
- `contains_secrets()` - Detect secrets in text
- `safe_log()` - Log with automatic secret masking

**Text Formatting**:
- `trim()` - Remove whitespace
- `to_upper()` / `to_lower()` - Case conversion
- `kebab_to_snake()` / `snake_to_kebab()` - Name conversion

**String Testing**:
- `is_empty()` - Check if empty/whitespace
- `matches()` - Test against regex
- `contains()` - Check for substring
- `starts_with()` / `ends_with()` - Check prefix/suffix

**Text Replacement**:
- `replace_first()` - Replace first occurrence
- `replace_all()` - Replace all occurrences

**Coloring**:
- `colorize()` - Add color to text
- `print_header()` - Formatted header
- `print_line()` - Formatted key-value line

**Usage Example**:
```bash
#!/bin/bash
source ../common/functions/string-functions.sh

# Clean resource names
name=$(sanitize_name "My-Resource Name!" "lowercase")
# Result: "my-resource-name"

# Extract from Azure ID
sub=$(get_subscription_from_id "/subscriptions/xxx/...")
rg=$(get_rg_from_id "/subscriptions/xxx/resourceGroups/yyy/...")

# Mask secrets in logs
msg="Connection string: DefaultEndpointsProtocol=https;AccountName=..."
safe_log "$msg"  # Output will have secrets masked

# String testing
if starts_with "production-vm" "production"; then
    echo "Production resource"
fi
```

### PowerShell Functions

#### logging-functions.ps1 (300+ lines)

**Purpose**: PowerShell equivalent of Bash logging functions

**Core Functions**:
- `Write-LogInfo()` - Informational messages
- `Write-LogSuccess()` - Success messages (green)
- `Write-LogError()` - Error messages (red)
- `Write-LogWarning()` - Warning messages (yellow)
- `Write-LogSection()` - Section headers
- `Write-LogDebug()` - Debug messages

**File Management**:
- `Start-LogFile()` - Initialize logging to file
- `Get-LogFile()` - Get current log file path

**Structured Output**:
- `Write-LogKeyValue()` - Key-value pairs
- `Start-LogDataBlock()` / `End-LogDataBlock()` - Data blocks

**Operation Tracking**:
- `Track-Operation()` / `Track-Success()` / `Track-Failure()` - Track operations
- `Write-LogSummary()` - Print summary

**Error Handling**:
- `Invoke-Exit()` - Exit with error logging
- `Invoke-WarnContinue()` - Continue with warning

**Usage Example**:
```powershell
. .\logging-functions.ps1

Start-LogFile -OutputDirectory "./artifacts" -ScriptName "deploy"

Write-LogSection "Starting Deployment"
Write-LogInfo "Step 1: Creating resources"

Write-LogSuccess "Resources created"
Track-Success

Write-LogSummary "Deployment"
```

## Loading Function Libraries

### In Bash Scripts

```bash
#!/bin/bash

# Load functions
source ../common/functions/logging-functions.sh
source ../common/functions/config-functions.sh
source ../common/functions/azure-functions.sh
source ../common/functions/string-functions.sh

# Now use functions
log_info "Starting"
load_config "config.env"
azure_check_auth
```

### In PowerShell Scripts

```powershell
# Load functions
. ./logging-functions.ps1

# Now use functions
Write-LogInfo "Starting"
Start-LogFile
```

### In Task Templates

The `task-template.sh` shows the recommended way to load functions in a deployment task.

## Best Practices

1. **Always load logging first**:
   ```bash
   source ../common/functions/logging-functions.sh
   # Then other functions can use log_info, etc.
   ```

2. **Check function availability**:
   ```bash
   if ! declare -f log_info &>/dev/null; then
       echo "ERROR: Logging functions not loaded"
       exit 1
   fi
   ```

3. **Use function return codes**:
   ```bash
   if ! azure_vm_create "RG" "vm" "image" "size"; then
       log_error "VM creation failed"
       exit 1
   fi
   ```

4. **Export functions for subshells**:
   - All functions automatically exported
   - Can be used in background jobs (`&`)
   - Can be used in command substitution (`$()`)

5. **Combine functions for workflows**:
   ```bash
   log_section "Creating VM"
   track_operation
   if azure_vm_create "RG" "vm" "image" "size"; then
       track_success
       log_success "VM created"
   else
       track_failure
       log_error "VM creation failed"
   fi
   ```

## Performance

- Logging functions: Minimal overhead (~1ms per call)
- Config functions: One-time load cost (~50ms), retrieval (<1ms)
- Azure functions: Depends on Azure CLI (seconds to minutes)
- String functions: Minimal overhead (<1ms per call)

All functions are optimized for shell script usage.

## Testing Functions

To test a function library:

```bash
#!/bin/bash

# Load the library
source ./logging-functions.sh

# Test basic functionality
log_info "Test info message"
log_success "Test success message"
log_error "Test error message"
log_warning "Test warning message"

log_section "Test section"

# Test log file
LOG_FILE=$(save_log "test")
log_info "This goes to log file"

# Check log file was created
if [[ -f "$LOG_FILE" ]]; then
    echo "✓ Log file created"
    cat "$LOG_FILE"
else
    echo "✗ Log file not created"
fi
```

## Contributing New Functions

To add new functions to a library:

1. **Maintain consistency**: Match style of existing functions
2. **Document well**: Add comments explaining purpose and usage
3. **Handle errors**: Return 0 on success, 1 on failure
4. **Use logging**: Call log_* functions for messages
5. **Export**: Add to export statement at end of file
6. **Test**: Verify in task script before committing

## Troubleshooting

### "Function not found" error

**Cause**: Function library not loaded or not sourced correctly

**Solution**:
```bash
# Check file exists
ls -l ../common/functions/logging-functions.sh

# Check it's sourced before use
source ../common/functions/logging-functions.sh
log_info "Now this works"
```

### Functions not working in subshells

**Cause**: Functions not exported

**Solution**: All functions are exported automatically. If issue persists:
```bash
# Re-export after sourcing
source ../common/functions/logging-functions.sh
export -f log_info log_success log_error
```

### Variable scope issues

**Cause**: Variables not exported

**Solution**: Use `export` when setting variables for use in functions
```bash
export LOG_FILE="/path/to/log"
log_info "Using log file: $LOG_FILE"
```

---

**Status**: Phase 2B - Function libraries complete
**Next**: Phase 3 - Enhance deployment steps with templates
