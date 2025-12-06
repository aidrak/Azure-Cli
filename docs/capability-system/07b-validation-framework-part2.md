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
