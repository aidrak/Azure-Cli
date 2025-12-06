---
title: "Azure VDI Deployment Engine - Project Memory"
description: "Central hub for project context, architecture, and development standards"
tags: ["azure", "avd", "deployment", "yaml", "capabilities"]
last_updated: "2025-12-06"
---

# Azure VDI Deployment Engine

Production-ready YAML-based deployment engine for Azure Virtual Desktop (AVD). Declarative, idempotent, self-healing operations orchestrated by a core Bash engine.

## Quick Start

```bash
# Load configuration (exports 50+ environment variables)
source core/config-manager.sh && load_config

# Run operations
./core/engine.sh run <operation-id>

# Resume after failure
./core/engine.sh resume
```

**Full guide:** [QUICKSTART.md](../QUICKSTART.md) | **Architecture:** [ARCHITECTURE.md](../ARCHITECTURE.md) | **Docs:** [docs/README.md](../docs/README.md)

---

## System Architecture

### Core Components

**7 Core Scripts (3,018 lines):**
- `config-manager.sh` - Load config.yaml, export ENV vars
- `template-engine.sh` - Parse YAML, substitute {{VARIABLES}}
- `engine.sh` - Main orchestrator (run/resume/status/list)
- `progress-tracker.sh` - Real-time monitoring
- `error-handler.sh` - Auto-fix errors, retry
- `logger.sh` - Structured JSONL logging
- `validator.sh` - Configuration validation

**79 Operations across 7 Capabilities:**
- `networking/` (20) - VNets, NSGs, VPN, DNS
- `storage/` (9) - Storage accounts, file shares
- `identity/` (15) - Entra ID, RBAC
- `compute/` (17) - VMs, images
- `avd/` (15) - Host pools, workspaces
- `management/` (2) - Resource groups
- `test-capability/` (1) - Testing

### Directory Structure

```
azure-cli/
├── config.yaml              # Single source of truth
├── state.json               # Execution state
├── core/                    # 7 engine scripts
├── capabilities/            # 79 operations
├── artifacts/               # Logs, outputs (gitignored)
├── docs/                    # 74 docs (all <300 lines)
└── legacy/                  # Archived modules (DO NOT USE)
```

---

## Development Standards

### 🚫 Critical Anti-Patterns (NEVER)

1. **NO standalone scripts** - Use YAML operations
2. **NO hardcoded values** - Use `{{VARIABLES}}` from config.yaml
3. **NO PowerShell remoting** - Use `az vm run-command invoke`
4. **NO direct file edits** - Use template engine

### ✅ Required Patterns (ALWAYS)

1. **Load config first:** `source core/config-manager.sh && load_config`
2. **YAML operations only** - All logic in `capabilities/*/operations/*.yaml`
3. **Use @filename syntax** - `--scripts "@path/to/script.ps1"`
4. **ASCII markers in PowerShell** - `[*] [v] [x] [!] [i]` (NO emoji)
5. **Save to artifacts/** - `> artifacts/outputs/name.json || true`

### Naming Conventions

- **Operations:** `{capability}-{action}-{resource}` (e.g., `networking-create-vnet`)
- **Files:** `{action}-{resource}.yaml` (lowercase, hyphens)
- **Variables:** `{category}.{subcategory}.{name}` → `CATEGORY_SUBCATEGORY_NAME`

---

## Common Workflows

### Running Operations

```bash
./core/engine.sh list              # List all operations
./core/engine.sh run <op-id>       # Run operation
./core/engine.sh resume            # Resume from failure
./core/engine.sh status            # Check state
```

### Handling Failures

```bash
# Engine creates checkpoint on failure
./core/engine.sh resume

# Check logs
tail -f artifacts/logs/deployment_$(date +%Y%m%d).jsonl

# View output
cat artifacts/outputs/<op-id>.json | jq -r '.value[0].message'
```

### Creating Operations

1. Create: `capabilities/{capability}/operations/{name}.yaml`
2. Define: id, duration, template, validation
3. Test: `./core/engine.sh run {operation-id}`

**Guide:** [docs/guides/executor-overview.md](../docs/guides/executor-overview.md)

---

## Configuration

### config.yaml - Single Source of Truth

```yaml
azure:
  subscription_id: "your-sub-id"
  location: "centralus"
  resource_group: "RG-Azure-VDI-01"

networking:
  vnet:
    name: "vnet-avd-prod"
    address_space: "10.0.0.0/16"
```

### Secrets Management

```bash
cp secrets.yaml.example secrets.yaml
vi secrets.yaml  # This file is gitignored
```

Secrets in `secrets.yaml` override `config.yaml` values.

---

## YAML Operation Template

```yaml
operation:
  id: "capability-action-resource"
  name: "Human Readable Name"

  duration:
    expected: 180
    timeout: 300
    type: "NORMAL"

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

---

## Documentation Navigation

**All docs are <300 lines. Navigate via [docs/README.md](../docs/README.md)**

**By Task:**
- Configure: [docs/guides/state-manager-overview.md](../docs/guides/state-manager-overview.md)
- Run ops: [docs/guides/executor-overview.md](../docs/guides/executor-overview.md)
- Create ops: [docs/capability-system/12a-best-practices-part1.md](../docs/capability-system/12a-best-practices-part1.md)
- Troubleshoot: [QUICKSTART.md#troubleshooting](../QUICKSTART.md#troubleshooting)
- Azure CLI: [docs/reference/azure-cli-core.md](../docs/reference/azure-cli-core.md)
- Remote exec: [docs/features/remote-execution-part1.md](../docs/features/remote-execution-part1.md)

**By Category:**
- Guides (how-to): `docs/guides/` (13 files)
- Reference (technical): `docs/reference/` (18 files)
- Capability system: `docs/capability-system/` (39 files)
- Features: `docs/features/` (2 files)
- Migration: `docs/migration/` (2 files)

---

## Code Style

### Bash Scripts

```bash
#!/bin/bash
set -euo pipefail

# UPPER_SNAKE_CASE for environment variables
RESOURCE_GROUP="${AZURE_RESOURCE_GROUP}"

# lower_snake_case for local variables
local_var="value"

# Functions: verb_noun format
function validate_prerequisites() {
    [[ -n "$REQUIRED_VAR" ]] || { echo "ERROR: Not set"; return 1; }
}
```

### PowerShell Scripts

```powershell
# ASCII markers only (NO emoji)
Write-Host "[START] Operation: $(Get-Date -Format 'HH:mm:ss')"

try {
    # Your code
    Write-Host "[v] Success"
    exit 0
} catch {
    Write-Host "[x] Error: $_"
    exit 1
}
```

---

## Git Workflow

```bash
git status
git add .
git commit -m "type(scope): Description

Details here.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

**Types:** `feat`, `fix`, `docs`, `refactor`, `test`, `chore`
**Branch:** Work on `dev` (default)
**Commit frequency:** Every 15-30 minutes

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "Config not loaded" | `source core/config-manager.sh && load_config` |
| "Variable not found" | Add to config.yaml, reload |
| "Operation not found" | `./core/engine.sh list` |
| "VM not ready" | Check operation dependencies |
| "Permission denied" | `az login` |

**Debug:**
```bash
echo $AZURE_RESOURCE_GROUP        # Check variable
az account show                   # Check login
tail -f artifacts/logs/*.jsonl    # View logs
cat state.json | jq               # Check state
```

---

## Important Notes for AI Assistants

1. **Read this file first** before making changes
2. **NEVER create standalone scripts** - use YAML operations
3. **NEVER hardcode values** - use config.yaml variables
4. **ALWAYS use `az vm run-command invoke`** for remote PowerShell
5. **NEVER use RDP, WinRM, or PowerShell remoting**
6. **All docs are <300 lines** - navigate via docs/README.md
7. **Legacy modules (01-12) are archived** - DO NOT use

---

**Status:** ✅ Complete - 79 ops, 7 capabilities | Updated: 2025-12-06 | Phase 3 (Self-Healing)
