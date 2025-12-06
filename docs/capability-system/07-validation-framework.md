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

  checks:
    - type: "check_type"
      description: "What this check verifies"
      critical: boolean  # Optional, defaults to true
      # Type-specific fields
```

### Field Reference

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `type` | string | Yes | Check type (see types above) |
| `description` | string | Yes | Human-readable description |
| `critical` | boolean | No | Whether check is critical (default: true) |

### Type-Specific Fields

**resource_exists:**
- `resource_type` - Azure ARM resource type
- `resource_name` - Resource name

**provisioning_state:**
- `expected` - Expected state (usually "Succeeded")

**property_equals:**
- `property` - JMESPath query for property
- `expected` - Expected value

**group_exists:**
- `group_name` - Entra ID group name

**group_type:**
- `expected` - Expected type ("Security" or "Microsoft365")

**custom:**
- `command` - Command to execute

---

## Validation Examples

### Network Resource Validation

```yaml
validation:
  enabled: true
  checks:
    - type: "resource_exists"
      resource_type: "Microsoft.Network/virtualNetworks"
      resource_name: "{{NETWORKING_VNET_NAME}}"
      description: "VNet exists"

    - type: "provisioning_state"
      expected: "Succeeded"
      description: "VNet provisioned successfully"

    - type: "property_equals"
      property: "addressSpace.addressPrefixes[0]"
      expected: "10.0.0.0/16"
      description: "Address space configured correctly"
```

**Validates:**
1. VNet resource exists in Azure
2. Provisioning completed successfully
3. Address space is correct

---

### Storage Account Validation

```yaml
validation:
  enabled: true
  checks:
    - type: "resource_exists"
      resource_type: "Microsoft.Storage/storageAccounts"
      resource_name: "{{STORAGE_ACCOUNT_NAME}}"
      description: "Storage account exists"

    - type: "provisioning_state"
      expected: "Succeeded"
      description: "Storage account provisioned"

    - type: "property_equals"
      property: "sku.name"
      expected: "Premium_LRS"
      description: "SKU is Premium_LRS"

    - type: "property_equals"
      property: "properties.minimumTlsVersion"
      expected: "TLS1_2"
      description: "TLS 1.2 enforced"

    - type: "property_equals"
      property: "properties.allowBlobPublicAccess"
      expected: false
      description: "Public access disabled"
```

**Validates:**
1. Storage account exists
2. Provisioning successful
3. Premium SKU configured
4. TLS 1.2 enforced
5. Public access disabled

---

### Identity Resource Validation

```yaml
validation:
  enabled: true
  checks:
    - type: "group_exists"
      group_name: "{{ENTRA_GROUP_USERS_STANDARD}}"
      description: "Users group exists"

    - type: "group_type"
      expected: "Security"
      description: "Group is security-enabled"

    - type: "custom"
      command: |
        member_count=$(az ad group member list \
          --group "{{ENTRA_GROUP_USERS_STANDARD}}" \
          --query "length([])" -o tsv)
        [ "$member_count" -ge 0 ]
      description: "Group membership queryable"
```

**Validates:**
1. Group exists in Entra ID
2. Group is security-enabled
3. Group membership can be queried

---

### Compute Resource Validation

```yaml
validation:
  enabled: true
  checks:
    - type: "resource_exists"
      resource_type: "Microsoft.Compute/virtualMachines"
      resource_name: "{{VM_NAME}}"
      description: "VM exists"

    - type: "provisioning_state"
      expected: "Succeeded"
      description: "VM provisioned successfully"

    - type: "property_equals"
      property: "properties.hardwareProfile.vmSize"
      expected: "Standard_D4s_v3"
      description: "VM size is correct"

    - type: "custom"
      command: |
        power_state=$(az vm get-instance-view \
          --resource-group "{{AZURE_RESOURCE_GROUP}}" \
          --name "{{VM_NAME}}" \
          --query "instanceView.statuses[?starts_with(code, 'PowerState/')].displayStatus" -o tsv)
        echo "$power_state" | grep -q "running"
      description: "VM is running"
```

**Validates:**
1. VM exists
2. Provisioning successful
3. Correct VM size
4. VM is powered on

---

### AVD Resource Validation

```yaml
validation:
  enabled: true
  checks:
    - type: "resource_exists"
      resource_type: "Microsoft.DesktopVirtualization/hostPools"
      resource_name: "{{HOST_POOL_NAME}}"
      description: "Host pool exists"

    - type: "provisioning_state"
      expected: "Succeeded"
      description: "Host pool provisioned"

    - type: "property_equals"
      property: "properties.hostPoolType"
      expected: "Pooled"
      description: "Host pool type is Pooled"

    - type: "property_equals"
      property: "properties.maxSessionLimit"
      expected: 10
      description: "Session limit configured"

    - type: "property_equals"
      property: "properties.loadBalancerType"
      expected: "BreadthFirst"
      description: "Load balancer type correct"
```

**Validates:**
1. Host pool exists
2. Provisioning successful
3. Pooled configuration
4. Session limits set
5. Load balancing configured

---

## Related Documentation

- [Operation Lifecycle](04-04a1-operation-lifecycle-phases1-2.md) - Where validation fits in execution
- [Operation Schema](03-03a1-operation-schema-core-part1.md) - Validation schema details
- [Best Practices](12-best-practices.md) - Validation design guidelines
- [Self-Healing](09-self-healing.md) - What happens when validation fails

---

**Last Updated:** 2025-12-06
