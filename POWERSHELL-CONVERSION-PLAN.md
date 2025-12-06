# PowerShell Conversion Plan: Modules 00-05

**Date**: December 6, 2025
**Scope**: Convert 5 modules (00-05) from bash-based orchestration to PowerShell (following Module 05 pattern)
**Note**: Modules 06-09 handled by separate team
**Reference Implementation**: Module 05 (Golden Image) - already complete

---

## Executive Summary

This plan converts modules 00-05 from bash-centric deployment scripts to a unified PowerShell orchestration model, mirroring the successful implementation in Module 05 (Golden Image). The conversion maintains **idempotency**, **state tracking**, and **error handling** while simplifying script injection, improving readability, and providing native JSON/object handling.

**Key Metrics**:
- **Total Operations**: 32 across 5 modules
- **Estimated Effort**: 5-7 hours (distributed across modules)
- **Complexity**: LOW → MODERATE (Module 01 is the bottleneck)
- **Risk Level**: LOW (modular changes, comprehensive testing per module)

---

## Module Conversion Summary

### Priority Order

| # | Module | Ops | Priority | Est. Time | Complexity | Status |
|---|--------|-----|----------|-----------|-----------|--------|
| 1 | **00-resource-group** | 2 | 🟢 Low | 15 min | Low | Ready |
| 2 | **02-storage** | 6 | 🟢 Low | 20 min | Low | Ready |
| 3 | **03-entra-group** | 7 | 🟢 Low | 20 min | Low | Ready |
| 4 | **04-host-pool-workspace** | 5 | 🟡 Medium | 25 min | Low | Requires script inlining |
| 5 | **01-networking** | 11 | 🔴 High | 60 min | HIGH | Most complex (NSG rules) |

**Recommended Execution Order** (by effort/complexity ratio):
1. **Module 02** (storage) - simplest, highest confidence
2. **Module 03** (entra-group) - simplest, very repetitive
3. **Module 00** (resource-group) - trivial, good warm-up
4. **Module 04** (host-pool-workspace) - medium, requires script discovery
5. **Module 01** (networking) - complex, needs careful handling of NSG rules

---

## Module 00: Resource Group Creation

**Current State**: ✓ Working bash-script
**Files**: 2 operations (create, validate)
**Complexity**: ⚪ TRIVIAL
**Conversion Time**: 15 minutes

### Current Template Type
```yaml
template:
  type: "bash-script"
```

### Conversion Strategy

**Minimal Changes** - Can operate as-is or convert to PowerShell for consistency.

#### Option A: Convert to PowerShell (Recommended for Consistency)

```yaml
template:
  type: "powershell-local"
  command: |
    cat > /tmp/resource-group-01-wrapper.ps1 << 'PSWRAPPER'
    # Check if resource group already exists (idempotent)
    $resourceGroup = @(az group show `
      --resource-group "{{AZURE_RESOURCE_GROUP}}" `
      --query "[0]" 2>$null | ConvertFrom-Json)

    if ($resourceGroup.Count -gt 0) {
      Write-Host "[INFO] Resource group '{{AZURE_RESOURCE_GROUP}}' already exists"
      exit 0
    }

    # Create resource group
    Write-Host "[START] Creating resource group: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    az group create `
      --resource-group "{{AZURE_RESOURCE_GROUP}}" `
      --location "{{AZURE_LOCATION}}" `
      --output json > artifacts/outputs/resource-group-create.json

    if ($LASTEXITCODE -eq 0) {
      Write-Host "[SUCCESS] Resource group created"
    } else {
      Write-Host "[ERROR] Failed to create resource group"
      exit 1
    }
    PSWRAPPER
    pwsh -NoProfile -NonInteractive -File /tmp/resource-group-01-wrapper.ps1
    rm -f /tmp/resource-group-01-wrapper.ps1
```

### Files to Modify
- `modules/00-resource-group/operations/01-create.yaml` - Update template.type
- `modules/00-resource-group/operations/02-validate.yaml` - Update template.type

### Bash → PowerShell Syntax Mapping

| Bash | PowerShell |
|------|-----------|
| `set -euo pipefail` | `$ErrorActionPreference = 'Stop'` |
| `echo "text"` | `Write-Host "text"` |
| `$?` (exit status) | `$LASTEXITCODE` |
| `$(command)` (command substitution) | `$(command)` (same syntax) |
| `if [ -z "$var" ]` (empty check) | `if ([string]::IsNullOrEmpty($var))` |
| `local var=value` | `$var = value` |
| `jq '.field'` | `ConvertFrom-Json | Select-Object -ExpandProperty field` |

---

## Module 02: Storage (FSLogix) Account

**Current State**: ✓ Working az-cli bash
**Files**: 6 operations (create account through private endpoint)
**Complexity**: ⚪ LOW
**Conversion Time**: 20 minutes
**Reason**: Clean bash, straightforward linear flow

### Current Template Type
```yaml
template:
  type: "az-cli"
```

### Conversion Strategy

Convert all 6 operations to `powershell-local` using the wrapper pattern. Focus on:
1. Idempotency checks (does resource exist?)
2. Output to artifacts for traceability
3. Error handling consistency

### Example: Operation 01 (Create Storage Account)

**Before** (bash):
```yaml
template:
  type: "az-cli"
  command: |
    if [ -z "{{STORAGE_ACCOUNT_NAME}}" ]; then
      STORAGE_NAME="fslogix$(printf '%05d' $((RANDOM % 99999)))"
    else
      STORAGE_NAME="{{STORAGE_ACCOUNT_NAME}}"
    fi
```

**After** (PowerShell):
```yaml
template:
  type: "powershell-local"
  command: |
    cat > /tmp/storage-01-wrapper.ps1 << 'PSWRAPPER'
    # Determine storage account name
    if ([string]::IsNullOrEmpty("{{STORAGE_ACCOUNT_NAME}}")) {
      $storageName = "fslogix$(Get-Random -Minimum 0 -Maximum 99999)"
    } else {
      $storageName = "{{STORAGE_ACCOUNT_NAME}}"
    }

    # Check if storage account already exists
    $existingStorage = @(az storage account show `
      --resource-group "{{AZURE_RESOURCE_GROUP}}" `
      --name $storageName `
      --query "[0]" 2>$null | ConvertFrom-Json)

    if ($existingStorage.Count -gt 0) {
      Write-Host "[INFO] Storage account '$storageName' already exists"
      exit 0
    }

    # Create storage account
    Write-Host "[START] Creating storage account: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    az storage account create `
      --resource-group "{{AZURE_RESOURCE_GROUP}}" `
      --name $storageName `
      --location "{{AZURE_LOCATION}}" `
      --sku {{STORAGE_ACCOUNT_SKU}} `
      --kind StorageV2 `
      --https-only true `
      --output json > artifacts/outputs/storage-01-create.json

    if ($LASTEXITCODE -eq 0) {
      Write-Host "[SUCCESS] Storage account created: $storageName"
    } else {
      Write-Host "[ERROR] Failed to create storage account"
      exit 1
    }
    PSWRAPPER
    pwsh -NoProfile -NonInteractive -File /tmp/storage-01-wrapper.ps1
    rm -f /tmp/storage-01-wrapper.ps1
```

### Files to Modify (6 operations)
1. `modules/02-storage/operations/01-create-storage-account.yaml`
2. `modules/02-storage/operations/02-enable-entra-kerberos.yaml`
3. `modules/02-storage/operations/03-create-file-share.yaml`
4. `modules/02-storage/operations/04-disable-public-access.yaml`
5. `modules/02-storage/operations/05-create-private-dns-zone.yaml`
6. `modules/02-storage/operations/06-create-private-endpoint.yaml`

### Conversion Checklist
- [ ] Change template.type from `az-cli` to `powershell-local`
- [ ] Wrap command in heredoc with `cat > /tmp/storage-NN-wrapper.ps1 << 'PSWRAPPER'`
- [ ] Convert bash syntax to PowerShell (see table above)
- [ ] Convert `yq` queries to PowerShell equivalents (unlikely in this module)
- [ ] Add `$ErrorActionPreference = 'Stop'` at top of script
- [ ] Replace `echo` with `Write-Host`
- [ ] Update inline comments to reference PowerShell syntax
- [ ] Test each operation individually

---

## Module 03: Entra ID Groups

**Current State**: ✓ Working az-cli bash
**Files**: 7 operations (create users, admins, SSO, FSLogix, network, security groups + validate)
**Complexity**: ⚪ LOW
**Conversion Time**: 20 minutes
**Note**: Highly repetitive (6 group creations with nearly identical structure)

### Current Template Type
```yaml
template:
  type: "az-cli"
```

### Conversion Strategy

Same wrapper pattern as Module 02. These are straightforward `az ad group` operations with minimal logic. After conversion, consider **operation templating** to eliminate duplication.

### Example: Operation 01 (Create Users Group)

**Before** (bash):
```bash
GROUP_NAME="{{AVD_ENTRA_USERS_GROUP_NAME}}"
GROUP_ID=$(az ad group list \
  --filter "displayName eq '$GROUP_NAME'" \
  --query "[0].id" -o tsv 2>/dev/null || echo "")

if [[ -n "$GROUP_ID" && "$GROUP_ID" != "None" ]]; then
  echo "[INFO] Group already exists"
  exit 0
fi

az ad group create \
  --display-name "$GROUP_NAME" \
  --mail-nickname "$(echo $GROUP_NAME | tr ' ' '-' | tr '[:upper:]' '[:lower:]')"
```

**After** (PowerShell):
```powershell
$groupName = "{{AVD_ENTRA_USERS_GROUP_NAME}}"
$existingGroup = @(az ad group list `
  --filter "displayName eq '$groupName'" `
  --query "[0]" 2>$null | ConvertFrom-Json)

if ($existingGroup.Count -gt 0) {
  Write-Host "[INFO] Group '$groupName' already exists"
  exit 0
}

$mailNickname = $groupName -replace ' ', '-' | % { $_.ToLower() }

az ad group create `
  --display-name $groupName `
  --mail-nickname $mailNickname `
  --output json > artifacts/outputs/entra-group-01-create.json
```

### Files to Modify (7 operations)
1. `modules/03-entra-group/operations/01-create-users-group.yaml`
2. `modules/03-entra-group/operations/02-create-admins-group.yaml`
3. `modules/03-entra-group/operations/03-create-sso-group.yaml`
4. `modules/03-entra-group/operations/04-create-fslogix-group.yaml`
5. `modules/03-entra-group/operations/05-create-network-group.yaml`
6. `modules/03-entra-group/operations/06-create-security-group.yaml`
7. `modules/03-entra-group/operations/07-validate-groups.yaml`

### Future Optimization (Post-Conversion)
After conversion, consolidate the 6 nearly-identical group creation operations into a single operation with parameters:
```yaml
- id: "entra-group-users"
  name: "Create Users Group"
  parameters:
    groupName: "{{AVD_ENTRA_USERS_GROUP_NAME}}"
```

---

## Module 04: Host Pool & Workspace

**Current State**: ⚠️ Uses script references (legacy pattern)
**Files**: 5 operations (create host pool, RDP config, app group, workspace, validate)
**Complexity**: 🟡 LOW-MEDIUM
**Conversion Time**: 25 minutes
**Issue**: References external scripts (e.g., `script: "create-host-pool.sh"`) that may or may not exist

### Current Template Type
```yaml
template:
  type: "azure-cli-bash"
```

### Current Structure
```yaml
- id: "hostpool-create-pool"
  script: "create-host-pool.sh"
  duration: 120
```

### Conversion Strategy

1. **Investigate**: Check if external scripts exist in the module directory
2. **Inline**: Move script content into YAML templates
3. **Convert**: Apply PowerShell wrapper pattern

### Bash Script Discovery

Run this command to check for script files:
```bash
ls -la /mnt/cache_pool/development/azure-cli/modules/04-host-pool-workspace/*.sh 2>/dev/null || echo "No .sh files found"
```

**If scripts exist**: Extract content and inline
**If scripts don't exist**: Convert existing YAML template.command to PowerShell

### Expected Script-to-Operation Mapping
```
create-host-pool.sh       → 01-create-host-pool.yaml
configure-rdp.sh          → 02-configure-rdp.yaml
create-app-group.sh       → 03-create-app-group.yaml
create-workspace.sh       → 04-create-workspace.yaml
validate-all.sh           → 05-validate-all.yaml
```

### PowerShell Conversion Template

```yaml
template:
  type: "powershell-local"
  command: |
    cat > /tmp/hostpool-01-wrapper.ps1 << 'PSWRAPPER'
    $ErrorActionPreference = 'Stop'

    Write-Host "[START] Creating host pool: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

    # Check if host pool already exists
    $existingPool = @(az desktopvirtualization hostpool show `
      --resource-group "{{AZURE_RESOURCE_GROUP}}" `
      --name "{{AVD_HOST_POOL_NAME}}" `
      --query "[0]" 2>$null | ConvertFrom-Json)

    if ($existingPool.Count -gt 0) {
      Write-Host "[INFO] Host pool already exists"
      exit 0
    }

    # Create host pool
    az desktopvirtualization hostpool create `
      --resource-group "{{AZURE_RESOURCE_GROUP}}" `
      --name "{{AVD_HOST_POOL_NAME}}" `
      --location "{{AZURE_LOCATION}}" `
      --host-pool-type "Pooled" `
      --load-balancer-type "DepthFirst" `
      --output json > artifacts/outputs/hostpool-01-create.json

    Write-Host "[SUCCESS] Host pool created"
    PSWRAPPER
    pwsh -NoProfile -NonInteractive -File /tmp/hostpool-01-wrapper.ps1
    rm -f /tmp/hostpool-01-wrapper.ps1
```

### Files to Modify (5 operations)
1. `modules/04-host-pool-workspace/operations/01-create-host-pool.yaml`
2. `modules/04-host-pool-workspace/operations/02-configure-rdp.yaml`
3. `modules/04-host-pool-workspace/operations/03-create-app-group.yaml`
4. `modules/04-host-pool-workspace/operations/04-create-workspace.yaml`
5. `modules/04-host-pool-workspace/operations/05-validate-all.yaml`

### Action Items
1. **Check for external scripts**
2. **If found**: Extract and inline into YAML
3. **If not found**: Ensure YAML templates already have bash content
4. **Convert all to PowerShell wrapper pattern**

---

## Module 01: Advanced Networking (COMPLEX)

**Current State**: ✓ Working but complex azure-cli-bash
**Files**: 11 operations (create VNet through validate)
**Complexity**: 🔴 HIGH
**Conversion Time**: 60-75 minutes
**Bottleneck**: Operation 04 (NSG Rules) - 8.2KB of complex bash logic

### Current Template Type
```yaml
template:
  type: "azure-cli-bash"
```

### Operations Breakdown

| # | Operation | Size | Complexity | Notes |
|---|-----------|------|-----------|-------|
| 01 | Create VNet | 4.6KB | Low | Simple az CLI command |
| 02 | Create Subnets | 4.3KB | Medium | Array iteration with yq |
| 03 | Create NSGs | 3.3KB | Low | Simple loop |
| **04** | **Configure NSG Rules** | **8.2KB** | **HIGH** | Complex conditional logic, nested loops |
| 05 | Attach NSGs | 3.4KB | Low | Simple attachment |
| 06 | Service Endpoints | 3.2KB | Medium | Array iteration |
| 07 | Create DNS Zones | 2.0KB | Low | Simple creation |
| 08 | Link DNS Zones | 2.3KB | Low | Simple linking |
| 09 | VNet Peering | 2.7KB | Low | Conditional peering logic |
| 10 | Route Tables | 4.1KB | Medium | Array iteration |
| 11 | Validate All | 5.2KB | Medium | Multiple validation checks |

### Critical Conversion Focus: Operation 04 (NSG Rules)

This is the most complex operation with:
- **Nested loops**: Iterates through subnets, then rules within each subnet
- **Conditional logic**: Different rules per subnet type (mgmt, workload, etc.)
- **Array handling**: Reads rule definitions from `config.yaml`
- **Function definitions**: Local `create_nsg_rule()` function

#### Bash Logic Structure
```bash
for i in $(seq 0 $((SUBNET_COUNT - 1))); do
  NSG_ENABLED=$(yq e ".networking.subnets[$i].nsg.enabled" config.yaml)
  if [[ "$NSG_ENABLED" != "true" ]]; then continue; fi

  NSG_NAME=$(yq e ".networking.subnets[$i].nsg.name" config.yaml)
  RULE_COUNT=$(yq e ".networking.subnets[$i].nsg.rules | length" config.yaml)

  for j in $(seq 0 $((RULE_COUNT - 1))); do
    # Extract rule properties
    RULE_NAME=$(yq e ".networking.subnets[$i].nsg.rules[$j].name" config.yaml)
    # ... 10 more properties ...

    # Create rule
    create_nsg_rule "$NSG_NAME" "$RULE_NAME" ... 10 parameters ...
  done
done
```

#### PowerShell Equivalent Strategy

**Option 1: Direct Translation** (Conservative)
```powershell
$subnets = $config.networking.subnets
foreach ($subnet in $subnets) {
  if (-not $subnet.nsg.enabled) { continue }

  foreach ($rule in $subnet.nsg.rules) {
    # Create rule using az CLI
    az network nsg rule create `
      --resource-group $resourceGroup `
      --nsg-name $subnet.nsg.name `
      --name $rule.name `
      ... parameters from $rule object ...
  }
}
```

**Option 2: Native PowerShell** (Recommended)
```powershell
$subnets = Get-Content config.yaml | ConvertFrom-Yaml | Select-Object -ExpandProperty networking | Select-Object -ExpandProperty subnets

$subnets | Where-Object { $_.nsg.enabled } | ForEach-Object {
  $nsgName = $_.nsg.name
  $_.nsg.rules | ForEach-Object {
    # Use splatting for cleaner parameter passing
    $params = @{
      ResourceGroupName = $resourceGroup
      NSGName          = $nsgName
      Name             = $_.name
      Priority         = $_.priority
      Direction        = $_.direction
      Access           = $_.access
      Protocol         = $_.protocol
      SourceAddressPrefix     = $_.source_address_prefix
      SourcePortRange         = $_.source_port_range
      DestinationAddressPrefix = $_.destination_address_prefix
      DestinationPortRange     = $_.destination_port_range
    }

    # Check existence and create if needed
    $existingRule = az network nsg rule show @params 2>$null
    if ($LASTEXITCODE -ne 0) {
      az network nsg rule create @params
    }
  }
}
```

### Conversion Strategy for Module 01

1. **Phase 1**: Convert operations 01-03, 05-11 (simpler operations)
   - Apply standard wrapper pattern
   - Replace `set -euo pipefail` with `$ErrorActionPreference = 'Stop'`
   - Replace `yq` queries with PowerShell YAML/JSON parsing

2. **Phase 2**: Convert operation 04 (NSG Rules) separately
   - Focus on nested iteration
   - Test thoroughly with multiple subnets/rules
   - Consider using PowerShell splatting for cleaner parameter passing

3. **Phase 3**: Integrate and test module end-to-end

### PowerShell YAML/Config Parsing

Module 01 uses `yq` to read from `config.yaml`. PowerShell equivalent:

**Bash**:
```bash
yq e '.networking.vnet.address_space | join(" ")' config.yaml
yq e '.networking.subnets[$i].name' config.yaml
```

**PowerShell**:
```powershell
# Load YAML (requires PSYaml or manual JSON conversion)
$config = Get-Content config.yaml | ConvertFrom-Yaml

# Query nested properties
$addressSpace = $config.networking.vnet.address_space -join " "
$subnetName = $config.networking.subnets[0].name
```

**Note**: PowerShell doesn't have native YAML parsing. Options:
- Use `powershell-yaml` module (install: `Install-Module powershell-yaml -Force`)
- Convert config.yaml to JSON
- Use shell `yq` within PowerShell: `yq e '...' config.yaml | ConvertFrom-Json`

**Recommended**: Call `yq` from PowerShell for minimal disruption:
```powershell
$addressSpace = yq e '.networking.vnet.address_space | join(" ")' config.yaml
```

### Files to Modify (11 operations)
1. `modules/01-networking/operations/01-create-vnet.yaml`
2. `modules/01-networking/operations/02-create-subnets.yaml`
3. `modules/01-networking/operations/03-create-nsgs.yaml`
4. `modules/01-networking/operations/04-configure-nsg-rules.yaml` **[PRIORITY]**
5. `modules/01-networking/operations/05-attach-nsgs.yaml`
6. `modules/01-networking/operations/06-configure-service-endpoints.yaml`
7. `modules/01-networking/operations/07-create-dns-zones.yaml`
8. `modules/01-networking/operations/08-link-dns-zones.yaml`
9. `modules/01-networking/operations/09-create-peering.yaml`
10. `modules/01-networking/operations/10-configure-route-tables.yaml`
11. `modules/01-networking/operations/11-validate-all.yaml`

### Key Conversion Patterns for Module 01

#### Pattern 1: Simple Azure CLI Call
```bash
az network vnet create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$VNET_NAME" \
  --address-prefix "$ADDRESS_SPACE"
```

**Converts to**:
```powershell
az network vnet create `
  --resource-group $resourceGroup `
  --name $vnetName `
  --address-prefix $addressSpace
```

#### Pattern 2: Array Iteration with yq
```bash
for i in $(seq 0 $((COUNT - 1))); do
  NAME=$(yq e ".path[$i].name" config.yaml)
  # ... use $NAME
done
```

**Converts to**:
```powershell
$items = yq e '.path' config.yaml | ConvertFrom-Json
foreach ($item in $items) {
  $name = $item.name
  # ... use $name
}
```

#### Pattern 3: Conditional with yq
```bash
if [[ "$(yq e '.path.enabled' config.yaml)" == "true" ]]; then
  # ... do something
fi
```

**Converts to**:
```powershell
if ((yq e '.path.enabled' config.yaml) -eq "true") {
  # ... do something
}
```

---

## Implementation Steps

### Phase 1: Preparation

**Step 1.1**: Clone current branch and create working branch
```bash
git checkout -b powershell-conversion/modules-00-05
```

**Step 1.2**: Verify all module files exist
```bash
for module in 00-resource-group 01-networking 02-storage 03-entra-group 04-host-pool-workspace; do
  echo "=== Module: $module ==="
  ls -lh /mnt/cache_pool/development/azure-cli/modules/$module/operations/*.yaml | wc -l
done
```

**Step 1.3**: Check for external scripts (Module 04)
```bash
find /mnt/cache_pool/development/azure-cli/modules/04-host-pool-workspace -name "*.sh" -o -name "*.ps1"
```

### Phase 2: Sequential Module Conversion

#### Module 02 (Storage) - START HERE
```
1. Read each operation file
2. Convert template.type: az-cli → powershell-local
3. Wrap command in heredoc
4. Convert bash to PowerShell
5. Test each operation
6. Commit: "feat: convert module 02-storage to powershell-local"
```

#### Module 03 (Entra Groups) - NEXT
```
1. Read each operation file
2. Convert template.type: az-cli → powershell-local
3. Apply heredoc wrapper
4. Convert bash to PowerShell
5. Test operations
6. Document opportunity for operation templating
7. Commit: "feat: convert module 03-entra-group to powershell-local"
```

#### Module 00 (Resource Group) - WARM-UP
```
1. Convert operations 01-02
2. Test creation and validation
3. Commit: "feat: convert module 00-resource-group to powershell-local"
```

#### Module 04 (Host Pool) - SCRIPT DISCOVERY
```
1. Check for external scripts
2. If found: Extract and inline
3. Convert to PowerShell
4. Test operations
5. Commit: "feat: convert module 04-host-pool-workspace to powershell-local"
```

#### Module 01 (Networking) - FINAL & COMPLEX
```
1. Convert operations 01-03, 05-11 (simpler)
2. Thoroughly test each
3. Commit: "feat(01-networking): convert non-NSG operations to powershell-local"
4. Convert operation 04 (NSG Rules) - FOCUS
5. Test NSG rule creation with multiple subnets
6. Commit: "feat(01-networking): convert NSG rules to powershell-local"
7. End-to-end module test
```

### Phase 3: Validation & Testing

For each module:
1. **Syntax Check**: Run YAML linter
2. **Variable Substitution**: Verify all {{VARIABLES}} are preserved
3. **Dry Run**: Test with `--dry-run` if available
4. **Artifact Output**: Confirm JSON outputs are written to `artifacts/outputs/`
5. **Error Handling**: Test with invalid inputs to verify error paths
6. **Idempotency**: Run operation twice, verify second run is a no-op

---

## PowerShell-to-Bash Template Cheat Sheet

### Error Handling
```
Bash:           set -euo pipefail
PowerShell:     $ErrorActionPreference = 'Stop'
```

### Output
```
Bash:           echo "message"
PowerShell:     Write-Host "message"
```

### Exit Codes
```
Bash:           $?                        (0=success, non-zero=fail)
PowerShell:     $LASTEXITCODE             (0=success, non-zero=fail)
```

### Command Substitution
```
Bash:           result=$(command)
PowerShell:     $result = $(command)      or   $result = command
```

### Array Iteration
```
Bash:           for i in $(seq 0 $((N-1))); do ... done
PowerShell:     for ($i = 0; $i -lt $N; $i++) { ... }
                or
                foreach ($item in $array) { ... }
```

### String Substitution
```
Bash:           name="John"; echo "Hello $name"
PowerShell:     $name = "John"; Write-Host "Hello $name"
```

### Conditional
```
Bash:           if [ -z "$var" ]; then
PowerShell:     if ([string]::IsNullOrEmpty($var)) {
```

### Function Definition
```
Bash:           function_name() { ... }
PowerShell:     function function_name { ... }
```

### JSON Processing
```
Bash:           jq '.field' file.json
PowerShell:     Get-Content file.json | ConvertFrom-Json | Select-Object -ExpandProperty field
```

### YAML/Config Parsing
```
Bash:           yq e '.networking.vnet.name' config.yaml
PowerShell:     yq e '.networking.vnet.name' config.yaml   (call yq directly)
                or
                (Get-Content config.yaml | ConvertFrom-Yaml).networking.vnet.name
```

### Piping
```
Bash:           cmd1 | cmd2 | cmd3
PowerShell:     cmd1 | cmd2 | cmd3       (same syntax!)
```

### Background Jobs
```
Bash:           cmd &
PowerShell:     Start-Job -ScriptBlock { cmd }
                or
                cmd &   (ampersand works in PowerShell too)
```

---

## Reference: Module 05 Golden Image Pattern

Module 05 (Golden Image) is the **reference implementation**. Key patterns to follow:

### Heredoc Wrapper Pattern
```yaml
template:
  type: "powershell-local"
  command: |
    cat > /tmp/golden-image-NN-wrapper.ps1 << 'PSWRAPPER'
    # PowerShell content here
    # Supports multi-line scripts, here-strings, etc.
    PSWRAPPER
    pwsh -NoProfile -NonInteractive -File /tmp/golden-image-NN-wrapper.ps1
    rm -f /tmp/golden-image-NN-wrapper.ps1
```

**Why this pattern?**
- **Safety**: Bash heredoc prevents YAML parsing issues with PowerShell curly braces `{}`
- **Simplicity**: PowerShell script content is plain text, no quoting escapes needed
- **Separation**: Clear boundary between bash wrapper and PowerShell content
- **Cleanup**: Temporary file is deleted after execution

### Error Handling
```powershell
if ($LASTEXITCODE -ne 0) {
  Write-Host "[ERROR] Command failed"
  exit 1
}
```

### Idempotency Check
```powershell
# Check if resource exists before creating
$existingResource = @(az resource show ... 2>$null | ConvertFrom-Json)

if ($existingResource.Count -gt 0) {
  Write-Host "[INFO] Resource already exists"
  exit 0
}
```

### Output to Artifacts
```powershell
# Always output JSON to artifacts for traceability
az resource create ... --output json > artifacts/outputs/operation-name.json
```

### Logging Markers
```powershell
Write-Host "[START] Operation description"
Write-Host "[INFO] Status message"
Write-Host "[SUCCESS] Operation completed"
Write-Host "[ERROR] Something went wrong"
```

---

## Rollback Plan

Each conversion is **modular and reversible**:

### If a module conversion fails:
1. Git reset to previous commit: `git reset --hard HEAD~1`
2. Revert just the failed module using `git checkout HEAD -- modules/NN-module-name/`
3. Fix the conversion issues
4. Re-commit: `git commit -m "fix: re-convert module NN with corrections"`

### Keep bash versions as backup:
```bash
# Before conversion, create backups
cp modules/NN-module-name/operations/01-*.yaml \
   modules/NN-module-name/operations/01-*.yaml.bak
```

---

## Success Criteria

### Per-Module Success
- ✓ All operations syntax is valid YAML
- ✓ All {{VARIABLE}} substitutions are preserved
- ✓ Heredoc wrapper syntax is correct (`cat > ... << 'PSWRAPPER'`)
- ✓ No shell special characters leaked into PowerShell content
- ✓ Error handling with `$LASTEXITCODE` checks
- ✓ Logging with proper markers ([START], [INFO], [SUCCESS], [ERROR])
- ✓ Output JSON to `artifacts/outputs/`
- ✓ Idempotency checks where applicable

### End-to-End Success
- ✓ All 32 operations converted across 5 modules
- ✓ Each module runs without errors in sequence
- ✓ State tracking via `state.json` works correctly
- ✓ Artifacts are generated for each operation
- ✓ No bash residuals left in templates
- ✓ Documentation updated with PowerShell patterns

---

## Documentation Updates

### Files to Update
1. **POWERSHELL-CONVERSION-PLAN.md** (this file)
   - Mark completed modules with ✓
   - Document any deviations from the plan

2. **Module-level README.md** files
   - Add note: "This module uses PowerShell-local orchestration (converted Dec 2025)"
   - Link to Module 05 as reference implementation

3. **Main Architecture Documentation** (if exists)
   - Update execution model description
   - Note: "Modules 00-05 now use unified PowerShell orchestration pattern"

---

## Timeline & Dependencies

### Recommended Execution Order (lowest to highest risk)

| Order | Module | Time | Blocker | Next |
|-------|--------|------|---------|------|
| 1 | Module 02 (Storage) | 20 min | None | Module 03 |
| 2 | Module 03 (Entra) | 20 min | Module 02 | Module 00 |
| 3 | Module 00 (RG) | 15 min | Module 03 | Module 04 |
| 4 | Module 04 (HostPool) | 25 min | Module 00 | Module 01 |
| 5 | Module 01 (Network) | 75 min | Module 04 | Validation |

**Total Estimated Time**: 155 minutes ≈ 2.5-3 hours

**Actual time may vary based on**:
- Script discovery complexity in Module 04
- Testing thoroughness for Module 01 NSG rules
- Number of variables needing substitution

---

## Notes for Implementation Team

1. **Commit Frequently**: After each module, create a commit. Don't batch multiple modules.
2. **Test After Each Module**: Run the module with test variables before moving to the next.
3. **Preserve Comments**: Keep all operation documentation in YAML headers.
4. **Variable Names**: Don't rename variables; keep {{EXACTLY_AS_IS}}.
5. **Artifacts Directory**: Ensure `artifacts/outputs/` exists in execution environment.
6. **Review Module 05**: Reference the golden image module (05) for any questions about pattern usage.
7. **Document Deviations**: If you find a module needs different treatment, document why.

---

## Questions to Address Before Starting

1. **Module 04 Scripts**: Do external `.sh` files exist? Where are they referenced?
2. **Artifacts Directory**: Where should `artifacts/outputs/` be created? Relative to working directory?
3. **Testing Environment**: How will modules be tested (integration with actual Azure, mocking, dry-run)?
4. **yq Availability**: Is `yq` available in the execution environment for PowerShell to call?
5. **PowerShell Version**: What's the minimum PowerShell version supported? (Code assumes 7.0+)

---

## Appendix: File Structure Reference

```
/mnt/cache_pool/development/azure-cli/
├── modules/
│   ├── 00-resource-group/
│   │   ├── module.yaml
│   │   └── operations/
│   │       ├── 01-create.yaml
│   │       └── 02-validate.yaml
│   ├── 01-networking/
│   │   ├── module.yaml
│   │   └── operations/
│   │       ├── 01-create-vnet.yaml
│   │       ├── 02-create-subnets.yaml
│   │       ├── ...
│   │       └── 11-validate-all.yaml
│   ├── 02-storage/
│   │   ├── module.yaml
│   │   └── operations/
│   │       ├── 01-create-storage-account.yaml
│   │       ├── ...
│   │       └── 06-create-private-endpoint.yaml
│   ├── 03-entra-group/
│   │   ├── module.yaml
│   │   └── operations/
│   │       ├── 01-create-users-group.yaml
│   │       ├── ...
│   │       └── 07-validate-groups.yaml
│   ├── 04-host-pool-workspace/
│   │   ├── module.yaml
│   │   └── operations/
│   │       ├── 01-create-host-pool.yaml
│   │       ├── ...
│   │       └── 05-validate-all.yaml
│   └── 05-golden-image/                    [REFERENCE IMPLEMENTATION]
│       ├── module.yaml
│       ├── operations/
│       │   ├── 00-create-vm.yaml
│       │   ├── ...
│       │   └── 10-validate-all.yaml
│       ├── scripts/
│       │   └── heartbeat.ps1
│       └── app_manifest.yaml
└── core/
    └── engine.sh
```

---

**Plan Status**: ✅ READY FOR IMPLEMENTATION
**Last Updated**: December 6, 2025
**Next Step**: Begin with Module 02 (Storage) conversion
