# Validation Framework

**Post-execution verification to ensure operations achieved intended results**

## Table of Contents

1. [Validation Check Types](#validation-check-types)
2. [Post-Execution Verification](#post-execution-verification)
3. [Check Structure](#check-structure)
4. [Validation Examples](#validation-examples)

---

## Validation Check Types

Validation checks run **after** successful operation execution to verify results.

### Type: resource_exists

Verifies Azure resource was created.

**Schema:**
```yaml
- type: "resource_exists"
  resource_type: "Microsoft.Network/virtualNetworks"
  resource_name: "{{NETWORKING_VNET_NAME}}"
  description: "VNet exists"
```

**Command Generated:**
```bash
az resource show \
  --resource-type "Microsoft.Network/virtualNetworks" \
  --name "{{NETWORKING_VNET_NAME}}" \
  --output none
```

**Success Condition:** Exit code 0 (resource found)

---

### Type: provisioning_state

Verifies resource provisioning completed.

**Schema:**
```yaml
- type: "provisioning_state"
  expected: "Succeeded"
  description: "VNet provisioned successfully"
```

**Execution:**
```bash
az resource show \
  --query "provisioningState" -o tsv
# Expected: "Succeeded"
```

**Success Condition:** Actual state matches expected state

**Common States:**
- `Succeeded` - Provisioning complete
- `Failed` - Provisioning failed
- `Creating` - In progress
- `Updating` - Update in progress

---

### Type: property_equals

Verifies specific property value.

**Schema:**
```yaml
- type: "property_equals"
  property: "sku.name"
  expected: "Premium_LRS"
  description: "Storage SKU is Premium_LRS"
```

**Execution:**
```bash
az storage account show \
  --query "sku.name" -o tsv
# Expected: "Premium_LRS"
```

**Success Condition:** Property value equals expected value

**Common Properties:**
- `sku.name` - Resource SKU
- `location` - Azure region
- `tags.Environment` - Tag values
- `properties.enableHttpsTrafficOnly` - Boolean settings

---

### Type: group_exists

Verifies Entra ID group.

**Schema:**
```yaml
- type: "group_exists"
  group_name: "{{ENTRA_GROUP_USERS_STANDARD}}"
  description: "Users group exists"
```

**Execution:**
```bash
az ad group show \
  --group "{{ENTRA_GROUP_USERS_STANDARD}}" \
  --output none
```

**Success Condition:** Exit code 0 (group found)

---

### Type: group_type

Verifies group type (Security vs Microsoft 365).

**Schema:**
```yaml
- type: "group_type"
  expected: "Security"
  description: "Group is a security group"
```

**Execution:**
```bash
az ad group show \
  --group "{{GROUP_NAME}}" \
  --query "securityEnabled" -o tsv
# Expected: "true" for Security groups
```

**Success Condition:** Group type matches expected type

**Valid Types:**
- `Security` - Security-enabled group
- `Microsoft365` - Microsoft 365 group

---

### Type: custom

Execute arbitrary command.

**Schema:**
```yaml
- type: "custom"
  command: |
    $count = az vm list --query "length([])" -o tsv
    if [ "$count" -gt 0 ]; then exit 0; else exit 1; fi
  description: "At least one VM exists"
```

**Execution:** Runs provided command directly

**Success Condition:** Command exits with 0

**Use Cases:**
- Complex multi-step validation
- Aggregated checks
- Custom business logic

---

## Post-Execution Verification

### Verification Sequence

```
1. Operation script completes
   ↓
2. Check if script exit code = 0
   ├─ Yes → Proceed to validation checks
   └─ No → Operation failed, rollback
   ↓
3. Run each validation check in order
   ├─ All pass → Operation succeeded
   ├─ Some fail → Check if critical
   │   ├─ Critical → Rollback
   │   └─ Warning → Continue with notification
   └─ Check if should apply fixes
   ↓
4. If fixes available, attempt self-healing
   └─ Retry validation checks
```

### Critical vs Non-Critical Checks

**Critical Checks (default):**
- Operation fails if check fails
- Triggers rollback
- Use for essential validation

**Non-Critical Checks:**
- Operation succeeds with warning
- Logged but doesn't fail operation
- Use for optional verification

**Example:**
```yaml
validation:
  enabled: true
  checks:
    - type: "resource_exists"
      critical: true  # Must pass
      description: "VNet exists"

    - type: "property_equals"
      property: "tags.Environment"
      expected: "Production"
      critical: false  # Warning only
      description: "Environment tag set"
```

---

## Check Structure

### Complete Check Definition

```yaml
validation:
  enabled: boolean
