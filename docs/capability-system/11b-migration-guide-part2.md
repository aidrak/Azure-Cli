**CRITICAL:** Do not modify the PowerShell logic. Copy exactly as-is.

```yaml
template:
  type: "powershell-local"
  command: |
    cat > /tmp/networking-vnet-create-wrapper.ps1 << 'PSWRAPPER'
    # Original PowerShell script (100% unchanged)
    Write-Host "[START] VNet creation..."
    
    $vnetName = "{{NETWORKING_VNET_NAME}}"
    $resourceGroup = "{{AZURE_RESOURCE_GROUP}}"
    
    # ... rest of original script ...
    
    PSWRAPPER
    pwsh -NoProfile -NonInteractive -File /tmp/networking-vnet-create-wrapper.ps1
    rm -f /tmp/networking-vnet-create-wrapper.ps1
```

**For Bash scripts:**
```yaml
template:
  type: "bash-local"
  command: |
    # Original bash script (100% preserved)
    az network vnet create \
      --resource-group "{{AZURE_RESOURCE_GROUP}}" \
      --name "{{NETWORKING_VNET_NAME}}"
```

---

### Step 10: Test Migration

Validate the new operation before committing.

**YAML Syntax Check:**
```bash
yamllint capabilities/networking/operations/vnet-create.yaml
```

**Schema Validation:**
The engine validates schema when operation is loaded. Test by running:
```bash
./core/engine.sh validate vnet-create
```

**Compare with Legacy:**
```bash
diff legacy/modules/01-networking/operations/01-create-vnet.yaml \
     capabilities/networking/operations/vnet-create.yaml
```

Look for:
- PowerShell script exactly preserved
- All parameters captured
- Idempotency defined
- Validation added
- Rollback defined

---

### Step 11: Commit Changes

Create git commit following conventions.

```bash
git add capabilities/networking/operations/vnet-create.yaml
git commit -m "feat: Migrate vnet-create operation to capability format

- Convert from module-based to capability-based structure
- Add idempotency check for existing VNets
- Add validation for provisioning state
- Add rollback procedure
- Preserve 100% of original PowerShell logic"
```

---

## Schema Mapping Reference

### Old Format → New Format

| Old Field | New Field | Notes |
|-----------|-----------|-------|
| `id: "01-create-vnet"` | `id: "vnet-create"` | Remove numeric prefix |
| `name: "..."` | `name: "..."` | Expand to full name |
| `description: "..."` | `description: "..."` | Make more descriptive |
| `script: "..."` | `template.command: "..."` | Move to template section |
| N/A | `capability: "networking"` | Add capability classification |
| N/A | `operation_mode: "create"` | Add operation mode |
| N/A | `resource_type: "..."` | Add Azure resource type |
| N/A | `duration: {...}` | Add duration metadata |
| N/A | `parameters: {...}` | Extract from script |
| N/A | `idempotency: {...}` | Add idempotency check |
| N/A | `validation: {...}` | Add validation checks |
| N/A | `rollback: {...}` | Add rollback steps |

---

## Migration Checklist

### Pre-Migration

- [ ] Identify legacy operation file
- [ ] Review PowerShell/Bash script
- [ ] Identify all parameters
- [ ] Determine capability domain
- [ ] Choose operation mode

### During Migration

- [ ] Operation file created in correct capability directory
- [ ] ID uses kebab-case (no numeric prefixes)
- [ ] All required schema fields populated
- [ ] Parameters extracted and typed correctly
- [ ] Idempotency check defined
- [ ] Validation checks specified
- [ ] Rollback procedures documented
- [ ] PowerShell script 100% preserved (no modifications)
- [ ] YAML syntax valid
- [ ] Placeholders use {{UPPERCASE}} format
- [ ] Duration/timeout values realistic
- [ ] Description clear and concise

### Post-Migration

- [ ] YAML syntax validated
- [ ] Schema validated by engine
- [ ] Compared with legacy operation
- [ ] Git commit message follows convention
- [ ] Operation tested in dev environment
- [ ] Documentation updated if needed

---

## Common Pitfalls

### Pitfall 1: Changing PowerShell Logic

**WRONG:**
```yaml
# Modified the script
template:
  command: |
    # "Improved" version with changes
    az network vnet create ... --tags "Owner=Me"  # Added tag
```

**RIGHT:**
```yaml
# Exact copy of original
template:
  command: |
    # Original PowerShell script (unchanged)
    # ... exact copy ...
```

**Why:** Changes may introduce bugs. Preserve 100% of original logic.

---

### Pitfall 2: Hardcoding Values

**WRONG:**
```yaml
template:
  command: |
    az network vnet create --name "avd-vnet"  # Hardcoded
```

**RIGHT:**
```yaml
template:
  command: |
    az network vnet create --name "{{NETWORKING_VNET_NAME}}"  # Placeholder
```

**Why:** Hardcoded values prevent reuse and configuration.

---

### Pitfall 3: Wrong Capability Assignment

**WRONG:**
```yaml
# NSG operation in compute capability
capability: "compute"  # Wrong!
```

**RIGHT:**
```yaml
# NSG operation in networking capability
capability: "networking"  # Correct
```

**How to determine:**
- Check Azure resource type
- Microsoft.Network/* → networking
- Microsoft.Compute/* → compute
- Microsoft.Storage/* → storage
- Microsoft.Graph/* → identity
- Microsoft.DesktopVirtualization/* → avd

---

### Pitfall 4: Missing Idempotency

**WRONG:**
```yaml
# No idempotency check
idempotency:
  enabled: false
```

**RIGHT:**
```yaml
idempotency:
  enabled: true
  check_command: |
    az network vnet show ... --output none 2>/dev/null
  skip_if_exists: true
```

**Why:** Every create/update operation should be idempotent for safe retry.

---

### Pitfall 5: Incomplete Validation

**WRONG:**
```yaml
validation:
  enabled: true
  checks:
    - type: "resource_exists"
      # Missing provisioning_state check
```

**RIGHT:**
```yaml
validation:
  enabled: true
  checks:
    - type: "resource_exists"
      resource_type: "Microsoft.Network/virtualNetworks"
      resource_name: "{{VNET_NAME}}"
      
    - type: "provisioning_state"
      expected: "Succeeded"
```

**Minimum:** Always include resource_exists + provisioning_state.

---

### Pitfall 6: Inadequate Rollback

**WRONG:**
```yaml
rollback:
  enabled: false  # No rollback defined
```

**RIGHT:**
```yaml
rollback:
  enabled: true
  steps:
    - name: "Delete Resource"
      command: |
        az network vnet delete ... --yes
      continue_on_error: false
```

**Why:** Rollback prevents orphaned resources and enables clean retry.

---

## Related Documentation

- [Operation Schema](03-03a1-operation-schema-core-part1.md) - Complete schema reference
- [Best Practices](12-best-practices.md) - Design guidelines
- [Operation Examples](10-operation-examples.md) - Example operations

---

**Last Updated:** 2025-12-06
