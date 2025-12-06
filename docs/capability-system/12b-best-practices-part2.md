**4. Timeout Consideration - Should complete quickly**
```bash
✓ Check single specific resource (~1-2 seconds)
✗ Enumerate all resources (may be slow)
```

### Good Examples

**Azure Resource:**
```yaml
check_command: |
  az network vnet show \
    --resource-group "{{AZURE_RESOURCE_GROUP}}" \
    --name "{{NETWORKING_VNET_NAME}}" \
    --output none 2>/dev/null
```

**Entra ID Group:**
```yaml
check_command: |
  az ad group list \
    --filter "displayName eq '{{GROUP_NAME}}'" \
    --query "[0].id" -o tsv 2>/dev/null | grep -q .
```

**File Existence:**
```yaml
check_command: |
  az storage file exists \
    --account-name "{{STORAGE_ACCOUNT_NAME}}" \
    --share-name "{{SHARE_NAME}}" \
    --path "{{FILE_PATH}}" \
    --query "exists" -o tsv 2>/dev/null | grep -q "true"
```

---

## Validation Check Design

### Design Principles

**1. Critical vs Optional - Fail only on critical**
```yaml
critical: true   # Must succeed (operation fails if this fails)
critical: false  # Log warning but continue
```

**2. Clear Expectations - Specific expected values**
```yaml
✓ expected: "Succeeded"
✓ expected: "Premium_LRS"
✗ expected: "OK" (ambiguous)
```

**3. Meaningful Descriptions - What does check verify?**
```yaml
✓ description: "VNet provisioned successfully"
✗ description: "Check 1" (meaningless)
```

**4. Logical Order - Existence before properties**
```yaml
1. resource_exists     # Does resource exist?
2. provisioning_state  # Is it ready?
3. property_equals     # Are settings correct?
```

### Minimum Validation

**Every create operation should have:**
```yaml
validation:
  enabled: true
  checks:
    - type: "resource_exists"
      resource_type: "Microsoft.Network/virtualNetworks"
      resource_name: "{{VNET_NAME}}"
      description: "VNet exists"

    - type: "provisioning_state"
      expected: "Succeeded"
      description: "VNet provisioned successfully"
```

### Enhanced Validation

**For critical resources, add property checks:**
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
```

---

## Rollback Procedure Design

### Design Principles

**1. Reverse Order - Undo in opposite sequence**
```yaml
Create:
1. Create VNet
2. Create Subnet
3. Create NSG

Rollback:
1. Delete NSG       # Reverse of step 3
2. Delete Subnet    # Reverse of step 2
3. Delete VNet      # Reverse of step 1
```

**2. Dependency Awareness - Delete dependents first**
```yaml
✓ Delete subnets before VNet
✓ Delete NSG before VNet
✗ Delete VNet first (subnets still attached - will fail)
```

**3. Error Tolerance - Allow some failures**
```yaml
# Critical deletion
continue_on_error: false  # Must succeed

# Optional cleanup
continue_on_error: true   # OK if fails
```

**4. Idempotent Rollback - Safe to run multiple times**
```yaml
✓ az network vnet delete ... --yes  # OK if already deleted
✗ rm -rf /important-data (destructive, non-idempotent)
```

### Good Rollback Examples

**Simple (single resource):**
```yaml
rollback:
  enabled: true
  steps:
    - name: "Delete Virtual Network"
      description: "Remove the VNet"
      command: |
        az network vnet delete \
          --resource-group "{{AZURE_RESOURCE_GROUP}}" \
          --name "{{NETWORKING_VNET_NAME}}" \
          --yes
      continue_on_error: false
```

**Complex (multiple resources):**
```yaml
rollback:
  enabled: true
  steps:
    - name: "Detach NSG"
      description: "Remove NSG association"
      command: |
        az network vnet subnet update ... --network-security-group ""
      continue_on_error: true  # May not be attached

    - name: "Delete NSG"
      description: "Remove network security group"
      command: |
        az network nsg delete ... --yes
      continue_on_error: false  # Critical

    - name: "Delete VNet"
      description: "Remove virtual network"
      command: |
        az network vnet delete ... --yes
      continue_on_error: false  # Critical
```

---

## General Guidelines

### Use Placeholders, Not Hardcoded Values

**Bad:**
```yaml
command: |
  az network vnet create --name "avd-vnet" --location "eastus"
```

**Good:**
```yaml
command: |
  az network vnet create \
    --name "{{NETWORKING_VNET_NAME}}" \
    --location "{{AZURE_LOCATION}}"
```

### Document Constraints in Descriptions

**Bad:**
```yaml
description: "Maximum sessions"
```

**Good:**
```yaml
description: "Maximum concurrent sessions per session host (1-999)"
```

### Use Validation for Critical Settings

**Bad:**
```yaml
# No validation that TLS 1.2 is enforced
```

**Good:**
```yaml
validation:
  checks:
    - type: "property_equals"
      property: "properties.minimumTlsVersion"
      expected: "TLS1_2"
      description: "TLS 1.2 enforced"
```

---

## Related Documentation

- [Operation Schema](03-03a1-operation-schema-core-part1.md) - Schema details
- [Migration Guide](11-migration-guide.md) - Converting operations
- [Operation Examples](10-operation-examples.md) - Real examples

---

**Last Updated:** 2025-12-06
