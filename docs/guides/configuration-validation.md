# Configuration Validation and Pre-Flight Checks

Enhanced configuration validation system with pre-flight checks and dry-run mode for safe operation execution.

---

## Overview

The validation system provides three complementary functions for ensuring operations execute safely and successfully:

1. **`preflight_check`** - Comprehensive pre-execution system validation
2. **`validate_operation_config`** - Operation-specific variable validation
3. **`dry_run_operation`** - Preview execution without making changes

---

## preflight_check - System Readiness Verification

Validates the entire system before executing any operations.

### Usage

```bash
source core/config-manager.sh && load_config

# Check system readiness (no specific operation)
preflight_check

# Check readiness for a specific operation
preflight_check "vnet-create"
```

### What It Checks

#### Check 1: Bootstrap Configuration
- Validates essential Azure variables:
  - `AZURE_SUBSCRIPTION_ID`
  - `AZURE_TENANT_ID`
  - `AZURE_LOCATION`
  - `AZURE_RESOURCE_GROUP`

**Remediation:**
```bash
# Load configuration
source core/config-manager.sh && load_config

# Or verify values are set
echo $AZURE_SUBSCRIPTION_ID
```

#### Check 2: Required Tools
- **az** - Azure CLI
- **yq** - YAML parser
- **jq** - JSON parser

**Remediation:**
```bash
# Install Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | bash

# Install yq
sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
chmod +x /usr/local/bin/yq

# Install jq
sudo apt-get install -y jq
```

#### Check 3: Azure CLI Authentication
Verifies you are authenticated to Azure.

**Remediation:**
```bash
# Method 1: Service Principal (recommended for automation)
./core/engine.sh run identity/az-login-service-principal

# Method 2: Interactive Login
az login
```

#### Check 4: Resource Group Accessibility
Confirms the target resource group exists and is accessible.

**Remediation:**
```bash
# Create resource group manually
az group create --name "RG-Azure-VDI-01" --location "centralus"

# Or use the operation
./core/engine.sh run management/resource-group-create
```

#### Check 5: Operation-Specific Validation
When an operation ID is provided:
- Locates the operation YAML file
- Validates YAML syntax
- Confirms operation.id is defined
- Checks for PowerShell or template content

**Remediation:**
```bash
# List all available operations
./core/engine.sh list

# Verify operation file syntax
yq e '.' capabilities/networking/operations/vnet-create.yaml
```

### Example Output

```
====================================================================
  PRE-FLIGHT CHECKS
====================================================================

[*] Check 1/5: Bootstrap Configuration
    Validating essential configuration...
[v]   Bootstrap configuration OK
      Subscription: 6c7eb5e0-8e77-40dd-a...
      Tenant: e61ea1b3-fb30-4c33-9...
      Location: centralus
      Resource Group: RG-Azure-VDI-01

[*] Check 2/5: Required Tools
[v]   az: azure-cli                         2.80.0 *
[v]   yq: yq (https://github.com/mikefarah/yq/) version v4.49.2
[v]   jq: jq-1.7
[v]   All required tools available

[*] Check 3/5: Azure CLI Authentication
[v]   Authenticated to Azure
      Current account: Azure subscription 1

[*] Check 4/5: Azure Resource Accessibility
[v]   Resource group exists: RG-Azure-VDI-01

[*] Check 5/5: Operation-Specific Validation
    Validating operation: vnet-create
[v]   Operation file found: .../vnet-create.yaml
[v]   YAML syntax valid
[v]   Operation has executable content

====================================================================
  PRE-FLIGHT CHECK SUMMARY
====================================================================
[v] All checks passed

Ready to execute: ./core/engine.sh run vnet-create
```

---

## validate_operation_config - Operation Variable Validation

Validates all variables required for a specific operation BEFORE execution.

### Usage

```bash
source core/config-manager.sh && load_config

# Validate operation configuration
validate_operation_config "vnet-create"
```

### What It Checks

1. **Operation YAML** - Locates and validates the operation file exists
2. **Required Parameters** - Extracts all required parameters from operation YAML
3. **Variable Substitution** - Checks for template variables like `{{NETWORKING_VNET_NAME}}`
4. **Variable Presence** - Confirms all required variables are set in environment
5. **Bootstrap Variables** - Validates Azure authentication variables
6. **Azure CLI** - Confirms Azure CLI is available

### Variable Resolution Priority

Variables are checked in this order:
1. Environment variable (e.g., `export NETWORKING_VNET_NAME='my-vnet'`)
2. config.yaml defaults
3. standards.yaml patterns

### Example Output - Success

```
[*] Validating configuration for operation: vnet-create
[*] Found operation file: .../vnet-create.yaml
[*] Checking 3 required parameters...
[v] NETWORKING_VNET_NAME = test-vnet
[v] AZURE_RESOURCE_GROUP = RG-Azure-VDI-01
[v] AZURE_LOCATION = centralus
[*] Validating bootstrap variables...
[v] AZURE_SUBSCRIPTION_ID is set
[v] AZURE_TENANT_ID is set
[v] AZURE_LOCATION is set
[v] AZURE_RESOURCE_GROUP is set
[*] Checking Azure CLI availability...
[v] Azure CLI is available

[v] Configuration validation passed
```

### Example Output - Failure

```
[*] Validating configuration for operation: vnet-create
[*] Found operation file: .../vnet-create.yaml
[*] Checking 3 required parameters...
[x] ERROR: Required variable not set: NETWORKING_VNET_NAME (for parameter: vnet_name)
    [i] Remediation:
        1. Check config.yaml for the value
        2. Or set: export NETWORKING_VNET_NAME='<value>'
        3. Or run: ./core/engine.sh run config/prompt-config

[x] Configuration validation FAILED: 1 error(s)
```

### Remediation Steps

**Option 1: Set variable in environment**
```bash
export NETWORKING_VNET_NAME="my-vnet"
validate_operation_config "vnet-create"
```

**Option 2: Check config.yaml**
```yaml
# config.yaml
networking:
  vnet:
    name: "my-vnet"
    address_space:
      - "10.0.0.0/16"
```

**Option 3: Use interactive configuration**
```bash
./core/engine.sh run config/prompt-config
```

---

## dry_run_operation - Safe Preview Execution

Simulates operation execution without making any changes to Azure resources.

### Usage

```bash
source core/config-manager.sh && load_config

# Preview operation execution
dry_run_operation "vnet-create"
```

### What It Shows

1. **Configuration Validation** - First validates all required variables
2. **Operation Metadata**
   - Operation ID, name, and description
   - Resource type (e.g., Microsoft.Network/virtualNetworks)
   - Operation mode (create, update, delete)

3. **Execution Expectations**
   - Expected duration
   - Timeout value

4. **Idempotency** - Whether operation can be safely re-run
5. **Post-Execution Validation** - Tests run after operation completes
6. **Rollback Strategy** - Steps to reverse operation if needed
7. **Script Preview** - First 20 lines of PowerShell/template script

### Example Output

```
====================================================================
  DRY-RUN MODE - No changes will be made
====================================================================

[*] Validating configuration for operation: vnet-create
...
[v] Configuration validation passed
[*] Analyzing operation: vnet-create
[*] Operation file: .../vnet-create.yaml

Operation Details:
  ID: vnet-create
  Name: Create Virtual Network
  Description: Create Azure VNet with configured address space
  Type: create
  Resource Type: Microsoft.Network/virtualNetworks

Execution Expectations:
  Expected duration: 60s
  Timeout: 120s

Idempotency:
  Enabled: true
  Skip if exists: true

Post-Execution Validation:
  Enabled: true
  Checks: 2
    - VNet exists
    - VNet provisioned successfully

Rollback Configuration:
  Enabled: true
  Rollback steps: 1
    - Delete Virtual Network

Preview of Operation Script (first 20 lines):
----
Write-Host "[START] VNet creation: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC')"

# Configuration from config.yaml
$vnetName = "{{NETWORKING_VNET_NAME}}"
$resourceGroup = "{{AZURE_RESOURCE_GROUP}}"
$location = "{{AZURE_LOCATION}}"
...
[... script continues ...]
----

====================================================================
  DRY-RUN COMPLETE - Operation validated but NOT executed
====================================================================

To execute this operation, run:
  ./core/engine.sh run vnet-create
```

### Use Cases

1. **First-time operations** - Preview what will happen before execution
2. **Complex deployments** - Understand operation flow before committing
3. **Debugging** - Verify configuration and expected behavior
4. **Documentation** - Show stakeholders what will be deployed

---

## Error Messages and Remediation

### Error: Required variable not set

```
[x] ERROR: Required variable not set: NETWORKING_VNET_NAME
```

**Remediation:**
```bash
# 1. Check config.yaml
cat config.yaml | grep -A 5 networking

# 2. Set the variable
export NETWORKING_VNET_NAME="my-vnet"

# 3. Use interactive prompts
./core/engine.sh run config/prompt-config
```

### Error: Azure CLI not found

```
[x] ERROR: Azure CLI (az) not found in PATH
```

**Remediation:**
```bash
# Install Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | bash
```

### Error: Not authenticated to Azure

```
[!] Not authenticated to Azure
```

**Remediation:**
```bash
# Option 1: Service Principal (automation)
./core/engine.sh run identity/az-login-service-principal

# Option 2: Interactive login
az login
```

### Error: Resource group not found

```
[x] Resource group not found: RG-Azure-VDI-01
```

**Remediation:**
```bash
# Create resource group
az group create --name "RG-Azure-VDI-01" --location "centralus"

# Or use the operation
./core/engine.sh run management/resource-group-create
```

### Error: YAML syntax error

```
[x] YAML syntax error in: .../operation.yaml
```

**Remediation:**
```bash
# Validate YAML syntax
yq e '.' capabilities/networking/operations/vnet-create.yaml

# Fix syntax errors
vim capabilities/networking/operations/vnet-create.yaml
```

---

## Workflow Examples

### Complete Pre-Execution Workflow

```bash
#!/bin/bash

# 1. Load configuration
source core/config-manager.sh && load_config

# 2. Run system pre-flight checks
preflight_check

# 3. Validate specific operation
validate_operation_config "vnet-create"

# 4. Preview operation
dry_run_operation "vnet-create"

# 5. Execute operation (when satisfied)
./core/engine.sh run vnet-create
```

### Troubleshooting Operation Failures

```bash
#!/bin/bash

source core/config-manager.sh && load_config

operation_id="vnet-create"

# 1. Validate configuration
if ! validate_operation_config "$operation_id"; then
    echo "Configuration validation failed"
    exit 1
fi

# 2. Preview operation
if ! dry_run_operation "$operation_id"; then
    echo "Dry-run validation failed"
    exit 1
fi

# 3. Run full pre-flight checks
if ! preflight_check "$operation_id"; then
    echo "System not ready"
    exit 1
fi

# 4. Execute operation
./core/engine.sh run "$operation_id"
```

### CI/CD Integration

```bash
#!/bin/bash
set -euo pipefail

source core/config-manager.sh && load_config

# Fail fast on validation errors
preflight_check "vnet-create" || exit 1
validate_operation_config "vnet-create" || exit 1

# Execute operation
./core/engine.sh run "vnet-create"
```

---

## Integration with Engine

The validation functions integrate seamlessly with the main engine:

```bash
# Run pre-flight before any operation
./core/engine.sh preflight vnet-create

# Dry-run before committing
./core/engine.sh dry-run vnet-create

# Validate configuration
./core/engine.sh validate vnet-create

# Execute after validation
./core/engine.sh run vnet-create
```

---

## Best Practices

1. **Always run preflight_check** before executing operations
2. **Use dry_run_operation** for unfamiliar or complex operations
3. **Validate configuration** in CI/CD pipelines before execution
4. **Fix configuration errors** before retrying operations
5. **Review error messages** and follow suggested remediation steps
6. **Keep config.yaml synchronized** with current variable values
7. **Use environment variables** for sensitive or temporary overrides

---

## Architecture

The validation system is built on existing components:

- **config-manager.sh** - Loads and validates configuration
- **template-engine.sh** - Parses operation YAML files
- **executor.sh** - Executes operations with validation
- **error-handler.sh** - Handles validation failures

---

## Related Documentation

- [QUICKSTART.md](../QUICKSTART.md) - Getting started guide
- [ARCHITECTURE.md](../ARCHITECTURE.md) - System architecture
- [Dynamic Configuration](./dynamic-config.md) - Variable resolution pipeline
- [Error Handling](./error-handling.md) - Error recovery and self-healing
