# Operation Lifecycle

**Complete execution flow from discovery to completion**

## Table of Contents

1. [Complete Execution Flow](#complete-execution-flow)
2. [Phase 1: Discovery](#phase-1-discovery)
3. [Phase 2: Validation](#phase-2-validation)
4. [Phase 3: Idempotency Check](#phase-3-idempotency-check)
5. [Phase 4: Execution](#phase-4-execution)
6. [Phase 5: Validation Checks](#phase-5-validation-checks)
7. [Phase 6: State Tracking](#phase-6-state-tracking)
8. [Phase 7: Rollback](#phase-7-rollback)
9. [Phase 8: Self-Healing](#phase-8-self-healing)
10. [ASCII Flow Diagram](#ascii-flow-diagram)

---

## Complete Execution Flow

The operation lifecycle consists of 8 distinct phases:

```
1. DISCOVERY
   ├─ Engine scans capabilities/{capability}/operations/
   ├─ Loads operation YAML
   └─ Validates schema
        │
        ↓
2. VALIDATION
   ├─ Check all parameters provided
   ├─ Validate parameter types
   ├─ Verify {{PLACEHOLDER}} substitution
   └─ Check prerequisites satisfied
        │
        ↓
3. IDEMPOTENCY CHECK
   ├─ Run check_command
   ├─ If exits with 0: resource exists
   └─ If skip_if_exists=true: skip execution
        │
        ↓
4. EXECUTION
   ├─ Substitute all {{PLACEHOLDERS}}
   ├─ Write script to temp file
   ├─ Execute template command
   ├─ Monitor duration (fail if timeout)
   └─ Capture output and errors
        │
        ↓
5. VALIDATION CHECKS
   ├─ Run each validation check
   ├─ Verify expected states
   ├─ Store results in artifacts
   └─ Fail if critical checks fail
        │
        ↓
6. STATE TRACKING
   ├─ Log execution results
   ├─ Record timestamps
   ├─ Store artifact outputs
   └─ Update state.json
        │
        ↓
7. ROLLBACK (on failure)
   ├─ Execute rollback steps in order
   ├─ Respect continue_on_error flags
   └─ Log rollback results
        │
        ↓
8. SELF-HEALING (if applicable)
   ├─ Apply recorded fixes
   ├─ Retry up to 3 times
   ├─ Track fix history
   └─ Log healing outcomes
```

---

## Phase 1: Discovery

### Overview

The engine discovers operations by scanning the capability directory structure.

### Discovery Process

```bash
# Scan capability directories
for capability in capabilities/*/; do
  # Scan operations directory
  for operation in $capability/operations/*.yaml; do
    # Load YAML
    # Validate schema
    # Register operation
  done
done
```

### What Gets Validated

1. **YAML Syntax** - Valid YAML format
2. **Required Fields** - All mandatory fields present
3. **Field Types** - Correct data types
4. **Enum Values** - Valid capability, operation_mode, etc.

### Example

```bash
# Engine discovers:
capabilities/networking/operations/vnet-create.yaml
capabilities/storage/operations/account-create.yaml
capabilities/identity/operations/group-create.yaml
...

# Loads and validates each YAML file
```

### Failure Handling

If schema validation fails:
- Operation is not registered
- Error logged with details
- Engine continues discovering other operations
- Invalid operation cannot be executed

---

## Phase 2: Validation

### Overview

Before execution, the engine validates that all requirements are met.

### Validation Checks

**Parameter Validation:**
```
1. Check all required parameters provided
2. Validate parameter types (string, integer, boolean, array)
3. Apply validation_regex if specified
4. Apply validation_enum if specified
5. Verify sensitive parameters handled correctly
```

**Placeholder Validation:**
```
1. Find all {{PLACEHOLDER}} instances
2. Verify corresponding config.yaml values exist
3. Validate placeholder names are valid
4. Prepare substitution mapping
```

**Prerequisite Validation:**
```
1. Check required operations completed
2. Verify required resources exist in Azure
3. Validate dependency chain is satisfied
```

### Example

```yaml
# Operation requires these parameters
parameters:
  required:
    - name: "vnet_name"
      type: "string"
      default: "{{NETWORKING_VNET_NAME}}"

# Engine validates:
✓ Parameter "vnet_name" present
✓ Type is string
✓ Placeholder {{NETWORKING_VNET_NAME}} exists in config.yaml
✓ Value is non-empty
```

### Failure Handling

If validation fails:
- Operation does not execute
- Clear error message shown
- Indicates which validation failed
- User can correct and retry
