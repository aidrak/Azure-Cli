---
title: "Azure VDI Deployment Engine - Project Memory"
description: "Central hub for project context, architecture, and development standards for the YAML-based Azure Virtual Desktop deployment engine."
tags: ["azure", "avd", "deployment", "yaml", "capabilities"]
last_updated: "2025-12-06"
---

# Azure VDI Deployment Engine - Project Memory

This is the central project memory file for the Azure Virtual Desktop (AVD) deployment engine. It provides essential context, architecture overview, and development standards for working with this codebase.

## Project Overview

**What:** A production-ready YAML-based deployment engine for Azure Virtual Desktop (AVD) infrastructure.

**How:** Declarative, idempotent, self-healing operations defined in YAML templates, orchestrated by a core Bash engine.

**Why:** Enables reliable, repeatable AVD deployments with centralized configuration, automatic error recovery, and real-time progress tracking.

## Quick Start

```bash
# 1. Load configuration (exports 50+ environment variables)
source core/config-manager.sh && load_config

# 2. Run operations
./core/engine.sh run <operation-id>

# 3. Resume after failure (automatic retry with self-healing)
./core/engine.sh resume

# 4. Check status
./core/engine.sh status
```

For detailed getting started guide: [QUICKSTART.md](../QUICKSTART.md)

---

## Architecture Overview

### Core Principle

**Declarative, Template-Driven Deployment:**
- NO standalone scripts - all logic in YAML operation files
- NO hardcoded values - single source of truth in `config.yaml`
- NO manual PowerShell remoting - use `az vm run-command invoke`
- YES to idempotent operations with validation and self-healing

### System Components

```
config.yaml → config-manager.sh → Export ENV vars
                ↓
      template-engine.sh → Substitute {{VARIABLES}}
                ↓
           engine.sh → Execute operations
                ↓
    progress-tracker.sh → Monitor [START/PROGRESS/SUCCESS]
                ↓
       error-handler.sh → Self-heal on failure
                ↓
    state.json + artifacts/ → Track execution
```

**7 Core Scripts** (3,018 total lines):
- `core/config-manager.sh` (556 lines) - Configuration loading & validation
- `core/template-engine.sh` (556 lines) - YAML parsing & variable substitution
- `core/engine.sh` (515 lines) - Main orchestrator
- `core/progress-tracker.sh` (325 lines) - Real-time monitoring
- `core/error-handler.sh` (382 lines) - Error extraction & auto-fixes
- `core/logger.sh` (322 lines) - Structured JSONL logging
- `core/validator.sh` (362 lines) - Configuration & prerequisite validation

**79 Operations** across **7 Capability Domains**:
- `capabilities/networking/` (20 ops) - VNets, subnets, NSGs, VPN, DNS
- `capabilities/storage/` (9 ops) - Storage accounts, file shares, private endpoints
- `capabilities/identity/` (15 ops) - Entra ID groups, RBAC, service principals
- `capabilities/compute/` (17 ops) - VMs, images, golden image preparation
- `capabilities/avd/` (15 ops) - Host pools, workspaces, app groups, scaling
- `capabilities/management/` (2 ops) - Resource groups, validation
- `capabilities/test-capability/` (1 op) - Testing framework

### Directory Structure

```
azure-cli/
├── config.yaml              # Single source of truth (all configuration)
├── state.json               # Execution state tracking
├── secrets.yaml            # Secrets (gitignored, overrides config.yaml)
│
├── core/                   # Engine components (7 files, 3,018 lines)
│   ├── config-manager.sh
│   ├── template-engine.sh
│   ├── engine.sh
│   ├── progress-tracker.sh
│   ├── error-handler.sh
│   ├── logger.sh
│   └── validator.sh
│
├── capabilities/           # 79 operations across 7 domains
│   ├── networking/operations/
│   ├── storage/operations/
│   ├── identity/operations/
│   ├── compute/operations/
│   ├── avd/operations/
│   ├── management/operations/
│   └── test-capability/operations/
│
├── artifacts/              # Logs, state, outputs (gitignored)
│   ├── logs/
│   ├── outputs/
│   └── checkpoints/
│
├── docs/                   # 74 documentation files (all <300 lines)
│   ├── guides/            # How-to guides (13 files)
│   ├── reference/         # Technical references (18 files)
│   ├── capability-system/ # System documentation (39 files)
│   ├── features/          # Feature deep-dives (2 files)
│   └── migration/         # Migration history (2 files)
│
└── legacy/                 # Archived module system (reference only)
    └── modules/           # Old 01-12 numbered modules (DO NOT USE)
```

---

## Development Standards

### 🚫 Critical Anti-Patterns (NEVER DO THIS)

1. **NO standalone scripts** - All logic goes in YAML operation files
   ```bash
   # ❌ WRONG
   ./scripts/install-app.sh

   # ✅ CORRECT
   ./core/engine.sh run golden-image-install-apps
   ```

2. **NO hardcoded values** - Use `config.yaml` variables
   ```yaml
   # ❌ WRONG
   --resource-group "RG-Azure-VDI-01"

   # ✅ CORRECT
   --resource-group "{{AZURE_RESOURCE_GROUP}}"
   ```

3. **NO PowerShell remoting** - Use Azure CLI `az vm run-command`
   ```bash
   # ❌ WRONG (RDP, Enter-PSSession, Invoke-Command)
   Enter-PSSession -ComputerName $VM_NAME

   # ✅ CORRECT
   az vm run-command invoke \
     --resource-group "{{AZURE_RESOURCE_GROUP}}" \
     --name "{{VM_NAME}}" \
     --command-id RunPowerShellScript \
     --scripts "@path/to/script.ps1"
   ```

4. **NO direct file manipulation** - Use template engine
   ```bash
   # ❌ WRONG
   sed -i "s/VALUE/$MY_VAR/g" file.yaml

   # ✅ CORRECT
   # Define in config.yaml, use {{MY_VAR}} in templates
   ```

### ✅ Required Patterns (ALWAYS DO THIS)

1. **Load configuration before any operation**
   ```bash
   source core/config-manager.sh && load_config
   ```

2. **Use YAML operation templates for all tasks**
   ```yaml
   operation:
     id: "capability-operation-name"
     name: "Human Readable Name"
     duration:
       expected: 180
       timeout: 300
     template:
       type: "az-vm-run-command"
       command: |
         az vm run-command invoke \
           --resource-group "{{AZURE_RESOURCE_GROUP}}" \
           --name "{{VM_NAME}}" \
           --scripts "@capabilities/compute/operations/script.ps1"
     powershell:
       content: |
         Write-Host "[START] Operation: $(Get-Date)"
         # Your code here
         Write-Host "[SUCCESS] Complete"
         exit 0
     validation:
       enabled: true
       checks:
         - type: "exit_code"
           expected: 0
   ```

3. **Use `@filename` syntax for PowerShell scripts** (NOT `$(cat)`)
   ```bash
   # ✅ CORRECT
   --scripts "@capabilities/compute/operations/install.ps1"
   ```

4. **All PowerShell output uses ASCII markers**
   ```powershell
   # Use these markers (ASCII only, NO emoji):
   Write-Host "[*] Starting..."    # Info
   Write-Host "[v] Success"        # Success
   Write-Host "[x] Error"          # Error
   Write-Host "[!] Warning"        # Warning
   Write-Host "[i] Info"           # Information
   ```

5. **Save artifacts to artifacts/ directory**
   ```bash
   --output json > artifacts/outputs/operation-name.json || true
   ```
### Naming Conventions

**Operation IDs:**
- Format: `{capability}-{action}-{resource}`
- Examples: `networking-create-vnet`, `storage-create-account`, `golden-image-install-apps`

**File Names:**
- Operations: `{action}-{resource}.yaml` (e.g., `create-vnet.yaml`)
- PowerShell: Same as operation (e.g., `create-vnet.ps1`)
- All lowercase, hyphens for spaces

**Variable Names in config.yaml:**
- Format: `{category}.{subcategory}.{name}`
- Exported as: `{CATEGORY}_{SUBCATEGORY}_{NAME}`
- Example: `azure.resource_group` → `AZURE_RESOURCE_GROUP`

---

## Configuration Management

### Single Source of Truth: config.yaml

All configuration in one file with hierarchical structure:

```yaml
azure:
  subscription_id: "your-sub-id"
  tenant_id: "your-tenant-id"
  location: "centralus"
  resource_group: "RG-Azure-VDI-01"

networking:
  vnet:
    name: "vnet-avd-prod"
    address_space: "10.0.0.0/16"
  subnet:
    name: "snet-avd-session-hosts"
    address_prefix: "10.0.1.0/24"

golden_image:
  temp_vm_name: "vm-golden-image-temp"
  vm_size: "Standard_D4s_v3"
  admin_username: "azureadmin"
```

### Secrets Management

**NEVER commit secrets to git.** Use `secrets.yaml`:

```bash
# Copy template
cp secrets.yaml.example secrets.yaml

# Edit secrets (this file is gitignored)
vi secrets.yaml
```

Secrets in `secrets.yaml` automatically override `config.yaml` values.

### Loading Configuration

```bash
# Load configuration (required before any operation)
source core/config-manager.sh
load_config

# Verify configuration
validate_config

# Check specific variable
echo $AZURE_RESOURCE_GROUP
```

---

## Common Workflows

### Running Operations

```bash
# List all operations
./core/engine.sh list

# Run specific operation
./core/engine.sh run <operation-id>

# Example: Create VNet
./core/engine.sh run networking-create-vnet

# Check status
./core/engine.sh status
```

### Handling Failures

```bash
# If operation fails, engine creates checkpoint
# Fix the issue in YAML, then resume:
./core/engine.sh resume

# Check logs
tail -f artifacts/logs/deployment_$(date +%Y%m%d).jsonl

# View operation output
cat artifacts/outputs/operation-name.json | jq -r '.value[0].message'
```

### Creating New Operations

1. Create YAML file: `capabilities/{capability}/operations/{name}.yaml`
2. Define operation structure (id, duration, template, validation)
3. Add PowerShell script if using `az-vm-run-command`
4. Test: `./core/engine.sh run {operation-id}`

See: `docs/guides/executor-overview.md` for detailed guide.

---

## Documentation Navigation

**All documentation files are under 300 lines for efficient AI navigation.**

### Quick Access

- **[QUICKSTART.md](../QUICKSTART.md)** - 5-minute getting started guide
- **[ARCHITECTURE.md](../ARCHITECTURE.md)** - Complete system architecture
- **[docs/README.md](../docs/README.md)** - Documentation hub (index of all 74 docs)

### By Task

| Task | Documentation |
|------|---------------|
| Configure deployment | [docs/guides/state-manager-overview.md](../docs/guides/state-manager-overview.md) |
| Run operations | [docs/guides/executor-overview.md](../docs/guides/executor-overview.md) |
| Create operations | [docs/capability-system/12a-best-practices-part1.md](../docs/capability-system/12a-best-practices-part1.md) |
| Troubleshoot | [QUICKSTART.md#troubleshooting](../QUICKSTART.md#troubleshooting) |
| Azure CLI commands | [docs/reference/azure-cli-core.md](../docs/reference/azure-cli-core.md) |
| Remote execution | [docs/features/remote-execution-part1.md](../docs/features/remote-execution-part1.md) |

### By Category

- **Guides** (How-to): `docs/guides/` (13 files)
- **Reference** (Technical): `docs/reference/` (18 files)
- **Capability System**: `docs/capability-system/` (39 files)
- **Features**: `docs/features/` (2 files)
- **Migration**: `docs/migration/` (2 files)

---

## Code Style & Conventions

### Bash Scripts (core/ directory)

```bash
#!/bin/bash
set -euo pipefail

# Use UPPER_SNAKE_CASE for environment variables
RESOURCE_GROUP="${AZURE_RESOURCE_GROUP}"

# Use lower_snake_case for local variables
local_variable="value"

# Functions: verb_noun format
function load_configuration() {
    # Implementation
}

# Always validate prerequisites
function validate_prerequisites() {
    [[ -n "$REQUIRED_VAR" ]] || { echo "ERROR: REQUIRED_VAR not set"; return 1; }
}
```

### YAML Operations

```yaml
# Consistent indentation (2 spaces)
operation:
  id: "capability-action-resource"
  name: "Title Case Name"

  duration:
    expected: 180      # Be realistic
    timeout: 300       # 50% buffer
    type: "NORMAL"     # FAST/NORMAL/SLOW

  template:
    type: "az-vm-run-command"
    command: |
      # Multi-line for readability
      az vm run-command invoke \
        --resource-group "{{AZURE_RESOURCE_GROUP}}" \
        --name "{{VM_NAME}}" \
        --scripts "@capabilities/compute/operations/script.ps1"
```

### PowerShell Scripts

```powershell
# ASCII markers only (NO emoji)
Write-Host "[START] Operation: $(Get-Date -Format 'HH:mm:ss')"

try {
    # Your code here
    Write-Host "[v] Success: Task completed"
    exit 0
} catch {
    Write-Host "[x] Error: $_"
    exit 1
}
```

---

## Git Workflow

```bash
# Check status
git status

# Commit frequently (every 15-30 minutes or logical checkpoint)
git add .
git commit -m "type(scope): Description

Detailed explanation of changes.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"

# Work on dev branch (default)
git branch  # Should show 'dev'

# View history
git log --oneline -10
```

**Commit types:** `feat`, `fix`, `docs`, `refactor`, `test`, `chore`

---

## Troubleshooting

### Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| "Configuration not loaded" | Didn't run `load_config` | `source core/config-manager.sh && load_config` |
| "Variable not found" | Missing in config.yaml | Add to config.yaml, reload with `load_config` |
| "Operation not found" | Wrong operation ID | Run `./core/engine.sh list` to see all IDs |
| "VM not ready" | Operation ran before VM created | Check operation dependencies |
| "Permission denied" | Not logged into Azure | Run `az login` |

### Debug Commands

```bash
# Verify configuration loaded
echo $AZURE_RESOURCE_GROUP

# Check Azure login
az account show

# View recent logs
tail -f artifacts/logs/deployment_$(date +%Y%m%d).jsonl

# Check operation output
cat artifacts/outputs/{operation-id}.json | jq -r '.value[0].message'

# View state
cat state.json | jq
```

---

## Migration Status

✅ **COMPLETE** - All legacy modules migrated to capability-based format (2025-12-06)

- **79 operations** migrated across **7 capabilities**
- **100% PowerShell** logic preserved
- **Legacy system** archived in `legacy/modules/` (reference only, DO NOT USE)

See: `docs/migration/` for migration history.

---

## Important Notes for AI Assistants

1. **ALWAYS read this file first** before making changes
2. **NEVER create standalone scripts** - use YAML operations
3. **NEVER use hardcoded values** - use `config.yaml` variables
4. **ALWAYS check existing operations** before creating new ones
5. **ALWAYS use `az vm run-command invoke`** for remote PowerShell execution
6. **NEVER use RDP, WinRM, or PowerShell remoting**
7. **ALL documentation files are under 300 lines** - navigate via docs/README.md
8. **Legacy modules (01-12) are archived** - DO NOT reference or use them

---

**Last Updated:** 2025-12-06
**System Version:** Phase 3 Complete (Self-Healing)
**Operations:** 79 across 7 capability domains
**Documentation:** 74 files (all <300 lines)
