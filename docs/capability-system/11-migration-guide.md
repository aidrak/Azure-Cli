# Migration Guide

**Step-by-step guide to converting legacy operations to capability format**

## Table of Contents

1. [Migration Process Overview](#migration-process-overview)
2. [Step-by-Step Guide](#step-by-step-guide)
3. [Schema Mapping Reference](#schema-mapping-reference)
4. [Migration Checklist](#migration-checklist)
5. [Common Pitfalls](#common-pitfalls)

---

## Migration Process Overview

### Overview

Converting legacy module-based operations to the capability-based format while preserving 100% of PowerShell/Bash logic.

### Goals

- **Preserve Scripts:** 100% of original PowerShell/Bash code preserved
- **Add Metadata:** Enrich with capability schema (idempotency, validation, rollback)
- **Improve Organization:** Move to capability-based structure
- **Enable Features:** Unlock self-healing, better state tracking

### Time Estimate

**Per Operation:**
- Simple operation: 15-20 minutes
- Complex operation: 30-45 minutes

---

## Step-by-Step Guide

### Step 1: Identify Legacy Operation

Find the old operation in `legacy/modules/` directory (archived):

```bash
find legacy/modules/ -name "*create*" -type f
# Example: legacy/modules/01-networking/operations/01-create-vnet.yaml
```

**Examine the legacy operation:**
```bash
cat legacy/modules/01-networking/operations/01-create-vnet.yaml
```

---

### Step 2: Analyze PowerShell Script

Extract the PowerShell/bash script from the legacy operation.

**Old format:**
```yaml
operation:
  id: "01-create-vnet"
  script: |
    # PowerShell script here
```

**What to identify:**
- All variable assignments
- Azure CLI commands
- Resource names
- Configuration values
- Error handling

---

### Step 3: Create New Capability Operation

Create new file in appropriate capability directory.

**Command:**
```bash
mkdir -p capabilities/CAPABILITY/operations/
touch capabilities/CAPABILITY/operations/OPERATION_NAME.yaml
```

**Capability mapping:**
```
01-networking        → capabilities/networking/
02-storage           → capabilities/storage/
03-entra-group       → capabilities/identity/
04-host-pool         → capabilities/avd/
05-golden-image      → capabilities/compute/
06-session-host      → capabilities/avd/
08-rbac              → capabilities/identity/
09-sso               → capabilities/identity/ + avd/
10-autoscaling       → capabilities/avd/
```

**Example:**
```bash
# Legacy: modules/01-networking/operations/01-create-vnet.yaml
# New: capabilities/networking/operations/vnet-create.yaml

mkdir -p capabilities/networking/operations/
touch capabilities/networking/operations/vnet-create.yaml
```

---

### Step 4: Map Schema Elements

Transform old operation format to new capability schema.

**Old Operation:**
```yaml
operation:
  id: "01-create-vnet"
  name: "Create VNet"
  description: "..."
  script: "..."
```

**New Schema:**
```yaml
operation:
  id: "vnet-create"  # Remove numeric prefix
  name: "Create Virtual Network"
  description: "Create Azure VNet with configured address space"
  capability: "networking"
  operation_mode: "create"
  resource_type: "Microsoft.Network/virtualNetworks"
  
  duration:
    expected: 60
    timeout: 300
    type: "FAST"
  
  # ... rest of new schema
```

---

### Step 5: Extract Parameters

Identify parameters from PowerShell script.

**Look for variable assignments:**
```powershell
# In PowerShell script
$vnetName = "avd-vnet"
$resourceGroup = "RG-AVD"
$location = "centralus"
$addressSpace = "10.0.0.0/16"
```

**Map to parameters section:**
```yaml
parameters:
  required:
    - name: "vnet_name"
      type: "string"
      description: "Name of the virtual network"
      default: "{{NETWORKING_VNET_NAME}}"
      
    - name: "resource_group"
      type: "string"
      description: "Azure resource group name"
      default: "{{AZURE_RESOURCE_GROUP}}"
      
  optional:
    - name: "address_space"
      type: "string"
      description: "Address space for the VNet"
      default: "{{NETWORKING_VNET_ADDRESS_SPACE}}"
```

---

### Step 6: Define Idempotency

Create check_command that detects existing resource.

**For most create operations:**
```yaml
idempotency:
  enabled: true
  check_command: |
    az network vnet show \
      --resource-group "{{AZURE_RESOURCE_GROUP}}" \
      --name "{{NETWORKING_VNET_NAME}}" \
      --output none 2>/dev/null
  skip_if_exists: true
```

**For Entra ID resources:**
```yaml
idempotency:
  enabled: true
  check_command: |
    az ad group list \
      --filter "displayName eq '{{GROUP_NAME}}'" \
      --query "[0].id" -o tsv 2>/dev/null | grep -q .
  skip_if_exists: true
```

---

### Step 7: Add Validation Checks

Define post-execution validation.

**Minimum validation (all operations):**
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
```

**Enhanced validation (critical resources):**
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
      description: "VNet provisioned"

    - type: "property_equals"
      property: "addressSpace.addressPrefixes[0]"
      expected: "{{NETWORKING_VNET_ADDRESS_SPACE}}"
      description: "Address space correct"
```

---

### Step 8: Define Rollback

Create cleanup steps for failure scenarios.

**Simple rollback (single resource):**
```yaml
rollback:
  enabled: true
  steps:
    - name: "Delete Virtual Network"
      description: "Remove the VNet and associated resources"
      command: |
        az network vnet delete \
          --resource-group "{{AZURE_RESOURCE_GROUP}}" \
          --name "{{NETWORKING_VNET_NAME}}" \
          --yes
      continue_on_error: false
```

**Complex rollback (multiple steps):**
```yaml
rollback:
  enabled: true
  steps:
    - name: "Delete Dependent Resources"
      description: "Remove resources that depend on main resource"
      command: |
        # Delete subnets, NSGs, etc.
      continue_on_error: true

    - name: "Delete Main Resource"
      description: "Remove the main resource"
      command: |
        az network vnet delete ...
      continue_on_error: false
```

---

### Step 9: Preserve PowerShell Script

Copy original script into template section (**100% preserved**).

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

- [Operation Schema](03-operation-schema.md) - Complete schema reference
- [Best Practices](12-best-practices.md) - Design guidelines
- [Operation Examples](10-operation-examples.md) - Example operations

---

**Last Updated:** 2025-12-06
