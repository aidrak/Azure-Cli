# Validation Functions - Quick Reference

Fast lookup guide for the three new validation functions.

---

## Function Overview

| Function | Purpose | Returns |
|----------|---------|---------|
| `preflight_check` | System readiness validation | 0=pass, 1=fail |
| `validate_operation_config` | Operation variable validation | 0=pass, 1=fail |
| `dry_run_operation` | Safe execution preview | 0=pass, 1=fail |

---

## preflight_check

**Full System Pre-Flight Validation**

```bash
# System only
preflight_check

# System + specific operation
preflight_check "vnet-create"
```

**Checks:**
1. Bootstrap configuration (subscription, tenant, location, resource group)
2. Required tools (az, yq, jq)
3. Azure CLI authentication
4. Resource group accessibility
5. Operation YAML syntax (if operation provided)

**Success Output:**
```
[v] All checks passed
System ready for operations
```

**Failure Output:**
```
[x] FAILED: N error(s) detected
Please resolve errors above
```

---

## validate_operation_config

**Operation-Specific Variable Validation**

```bash
validate_operation_config "operation_id"
```

**Checks:**
- Operation YAML file exists
- Required parameters defined in YAML
- All required variables are set in environment
- Bootstrap variables are set
- Azure CLI is available

**Success Output:**
```
[v] Configuration validation passed
```

**Failure Output:**
```
[x] Configuration validation FAILED: N error(s)
[x] ERROR: Required variable not set: VARIABLE_NAME
    [i] Remediation:
        1. Check config.yaml
        2. Or set: export VARIABLE_NAME='value'
        3. Or run: ./core/engine.sh run config/prompt-config
```

---

## dry_run_operation

**Safe Operation Execution Preview**

```bash
dry_run_operation "operation_id"
```

**Shows:**
- Configuration validation results
- Operation metadata (name, description, resource type)
- Execution expectations (duration, timeout)
- Idempotency settings
- Post-execution validation checks
- Rollback configuration
- Script preview (first 20 lines)

**Important:** Does NOT execute the operation

---

## Quick Usage Patterns

### Pattern 1: Check System Ready
```bash
source core/config-manager.sh && load_config
preflight_check
```

### Pattern 2: Validate Before Execution
```bash
source core/config-manager.sh && load_config
validate_operation_config "vnet-create" || exit 1
./core/engine.sh run "vnet-create"
```

### Pattern 3: Safe Exploration
```bash
source core/config-manager.sh && load_config
export NETWORKING_VNET_NAME="prod-vnet"
dry_run_operation "vnet-create"
# Review output, then:
./core/engine.sh run "vnet-create"
```

### Pattern 4: Complete Pre-Execution Workflow
```bash
#!/bin/bash
source core/config-manager.sh && load_config
preflight_check "vnet-create" || exit 1
validate_operation_config "vnet-create" || exit 1
dry_run_operation "vnet-create" || exit 1
./core/engine.sh run "vnet-create"
```

### Pattern 5: CI/CD Integration
```bash
#!/bin/bash
set -euo pipefail
source core/config-manager.sh && load_config
preflight_check "$OPERATION" || exit 1
validate_operation_config "$OPERATION" || exit 1
./core/engine.sh run "$OPERATION"
```

---

## Return Codes

All three functions return standard exit codes:

- `0` - Success (all validations passed)
- `1` - Failure (one or more validations failed)

Use in shell scripts:
```bash
if validate_operation_config "vnet-create"; then
    ./core/engine.sh run "vnet-create"
else
    echo "Configuration invalid"
    exit 1
fi
```

---

## Common Error Scenarios

### Error: Required variable not set

```
[x] ERROR: Required variable not set: NETWORKING_VNET_NAME
```

**Fix:**
```bash
export NETWORKING_VNET_NAME="my-vnet"
validate_operation_config "vnet-create"
```

---

### Error: Not authenticated to Azure

```
[!] Not authenticated to Azure
```

**Fix:**
```bash
./core/engine.sh run identity/az-login-service-principal
# or
az login
```

---

### Error: Resource group not found

```
[x] Resource group not found: RG-Azure-VDI-01
```

**Fix:**
```bash
az group create --name "RG-Azure-VDI-01" --location "centralus"
# or
./core/engine.sh run management/resource-group-create
```

---

### Error: YAML syntax error

```
[x] YAML syntax error in: .../vnet-create.yaml
```

**Fix:**
```bash
yq e '.' capabilities/networking/operations/vnet-create.yaml
# Fix any syntax errors reported
```

---

## Status Markers

All output uses consistent ASCII markers:

| Marker | Meaning |
|--------|---------|
| `[*]` | Information / In progress |
| `[v]` | Success / Validation passed |
| `[x]` | Error / Critical failure |
| `[!]` | Warning / Non-critical issue |
| `[i]` | Information / Helpful notes |

---

## Full Documentation

See [Configuration Validation Guide](../guides/configuration-validation.md) for:
- Detailed function documentation
- Complete workflow examples
- Error handling strategies
- Integration patterns
- Best practices

---

## Examples

Interactive examples available:
```bash
bash .claude/examples/validation-workflow.sh
```

Provides 7 runnable examples:
1. Basic system pre-flight check
2. Pre-flight with operation
3. Configuration validation
4. Dry-run operation
5. Complete workflow
6. Missing variable handling
7. Error detection and recovery

---

## Integration

These functions work with:
- `core/config-manager.sh` - Configuration loading
- `core/template-engine.sh` - YAML parsing
- `core/executor.sh` - Operation execution
- `core/value-resolver.sh` - Variable resolution
- `./core/engine.sh` - Main execution engine
