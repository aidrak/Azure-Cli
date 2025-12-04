# Reusable Function Libraries

This directory will contain function libraries shared across all deployment steps (01-12).

## Status

✅ **Complete** - All function libraries implemented in Phase 2B

## Planned Function Libraries

### logging-functions.sh / logging-functions.ps1
**Purpose**: Unified logging functions for all scripts

**Planned Functions**:
- `log_info()` / `Write-LogInfo()` - Log informational messages
- `log_success()` / `Write-LogSuccess()` - Log successful operations
- `log_error()` / `Write-LogError()` - Log error messages
- `log_warning()` / `Write-LogWarning()` - Log warnings
- `log_section()` / `Write-LogSection()` - Log section headers
- `save_log()` / `Save-LogFile()` - Save logs to file with timestamp

**Benefits**:
- Consistent output formatting
- Color coding (success=green, error=red, warning=yellow)
- Automatic timestamping
- Centralized log file management

### config-functions.sh / config-functions.ps1
**Purpose**: Configuration loading and validation

**Planned Functions**:
- `load_config()` - Load configuration from file
- `validate_config_value()` - Validate single config value
- `get_config()` - Get config value with fallback
- `set_config()` - Set config value in memory
- `export_config()` - Export configuration to environment

**Benefits**:
- Consistent config loading across all steps
- Automatic validation
- Environment variable override support
- Centralized precedence logic

### azure-functions.sh / azure-functions.ps1
**Purpose**: Wrappers around Azure CLI/PowerShell with error handling

**Planned Functions**:
- `azure_vm_create()` - Create VM with error handling
- `azure_vm_delete()` - Delete VM with error handling
- `azure_vm_status()` - Get VM status
- `azure_network_get()` - Get network information
- `azure_wait_operation()` - Wait for Azure operation to complete
- `azure_handle_error()` - Standardized error handling

**Benefits**:
- Standardized error handling
- Automatic retry logic
- Consistent success/failure output
- Simplified error recovery

### string-functions.sh / string-functions.ps1
**Purpose**: String manipulation utilities

**Planned Functions**:
- `sanitize_name()` - Clean resource names
- `parse_id()` - Extract parts from Azure IDs
- `validate_json()` - Validate JSON strings
- `mask_secrets()` - Hide sensitive values in logs
- `colorize()` - Add color to terminal output

**Benefits**:
- Consistent string handling
- Security (secret masking)
- Easier output formatting

## Usage Pattern

Once implemented, functions will be used like:

```bash
#!/bin/bash

# Load functions
source ../common/functions/logging-functions.sh
source ../common/functions/config-functions.sh
source ../common/functions/azure-functions.sh

# Use functions
load_config "config.env"
log_info "Starting deployment"

azure_vm_create "$VM_NAME" "$VM_SIZE" || {
    log_error "Failed to create VM"
    exit 1
}

log_success "VM created successfully"
```

## Benefits of Function Libraries

1. **Consistency**: All scripts use same functions
2. **DRY**: Don't Repeat Yourself - code reuse
3. **Maintainability**: Fix bugs in one place
4. **Testing**: Functions can be unit tested
5. **AI-Friendly**: AI assistants understand patterns better

## Implementation Timeline

- **Phase 2B** (Coming Soon):
  - Implement logging-functions
  - Implement config-functions
  - Document usage patterns

- **Phase 3-4**:
  - Implement azure-functions
  - Implement string-functions
  - Integrate into deployment steps

- **Phase 5+**:
  - Add error recovery functions
  - Add monitoring/alerting functions
  - Add performance/optimization functions

## Current State

**Utilities in Scripts**:
Current utility scripts have logging patterns built-in:
```powershell
# From verify_prerequisites.ps1
function Write-LogSuccess {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor $Colors.Success
}
```

**Next**: Extract common patterns into reusable libraries

## File Structure (When Implemented)

```
functions/
├── logging-functions.sh
├── logging-functions.ps1
├── config-functions.sh
├── config-functions.ps1
├── azure-functions.sh
├── azure-functions.ps1
├── string-functions.sh
├── string-functions.ps1
└── README.md (this file)
```

---

**Status**: Planning Phase
**Next Step**: Phase 2B Implementation
