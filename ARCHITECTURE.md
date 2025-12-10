---
title: "System Architecture"
description: "Technical reference for the YAML-based deployment engine: unified execution path, core components, and design patterns"
tags: ["architecture", "technical", "engine", "design", "unified-execution"]
last_updated: "2025-12-10"
---
# System Architecture

Technical reference for the YAML-based deployment engine. For operational guides, see [QUICKSTART.md](QUICKSTART.md) and [.claude/CLAUDE.md](.claude/CLAUDE.md).

---

## Architecture Overview

### Unified Execution Flow (Updated 2025-12-10)

The system now uses a **unified execution path** through `executor.sh`:

```
┌─────────────────────────────────────────────────────────────┐
│ CLI Entry Points                                            │
├─────────────────────────────────────────────────────────────┤
│ ./core/engine.sh run <op-id>    (single operations)        │
│ ./core/engine.sh workflow <id>  (multi-step workflows)     │
└────────────┬────────────────────────────────┬───────────────┘
             │                                │
             v                                v
    ┌────────────────┐              ┌──────────────────┐
    │  engine.sh     │              │ workflow-engine  │
    │  (thin wrapper)│              │  (orchestration) │
    └────────┬───────┘              └────────┬─────────┘
             │                                │
             └────────────┬───────────────────┘
                          v
                ┌──────────────────┐
                │   executor.sh    │ ← UNIFIED EXECUTION ENGINE
                │                  │
                │ • Prerequisites  │
                │ • Step execution │
                │ • Rollback       │
                │ • State tracking │
                └────────┬─────────┘
                         │
         ┌───────────────┼───────────────┐
         v               v               v
   config-manager   template-engine   state-manager
   query.sh         error-handler     logger.sh
```

### Core Components

| Component | Purpose | Status |
|-----------|---------|--------|
| `engine.sh` | CLI wrapper, operation discovery, backward compatibility | REFACTORED (thin wrapper) |
| `executor.sh` | **UNIFIED execution engine**: prerequisites, steps, rollback, state | PRIMARY PATH |
| `workflow-engine.sh` | Multi-step orchestration (delegates to executor.sh) | ACTIVE |
| `config-manager.sh` | Load config, export ENV vars, validate | ACTIVE |
| `template-engine.sh` | Parse YAML, substitute variables | ACTIVE |
| `state-manager.sh` | SQLite state tracking | ACTIVE |
| `query.sh` | Azure resource queries and caching | ACTIVE |
| `logger.sh` | Structured JSONL logging | ACTIVE |
| `error-handler.sh` | Self-healing pattern matching | ACTIVE |
| `progress-tracker.sh` | Real-time monitoring | LEGACY (used by engine.sh only) |

### Deprecated Components

- **Module-based execution** (`execute_module` in engine.sh) - Use capability operations instead
- **Parallel group execution** (`execute_parallel_group`) - Use workflow-engine.sh instead
- **Legacy operation format** - Migrate to capability format with prerequisites and rollback

---

## Directory Structure

```
azure-cli/
├── config.yaml              # Configuration (single source of truth)
├── state.db                 # SQLite state tracking
├── core/                    # 7 engine scripts
├── capabilities/            # 79 operations across 7 domains
│   ├── networking/          # 20 operations
│   ├── storage/             # 9 operations
│   ├── identity/            # 15 operations
│   ├── compute/             # 17 operations
│   ├── avd/                 # 15 operations
│   ├── management/          # 2 operations
│   └── test-capability/     # 1 operation
├── artifacts/               # Logs only (gitignored)
│   ├── logs/                # JSONL structured logs
│   └── temp/                # Temporary files
├── tools/
│   └── capability-cli.sh    # Operation generator
└── legacy/                  # Archived (DO NOT USE)
```

---

## Configuration System

### config.yaml Structure

```yaml
azure:
  subscription_id: "{{YOUR_SUBSCRIPTION_ID}}"
  tenant_id: "{{YOUR_TENANT_ID}}"
  location: "{{YOUR_REGION}}"           # e.g., centralus, eastus
  resource_group: "{{YOUR_RG_NAME}}"

networking:
  vnet_name: "{{YOUR_VNET_NAME}}"
  subnet_name: "{{YOUR_SUBNET_NAME}}"
  address_space: "{{YOUR_CIDR}}"        # e.g., 10.0.0.0/16

storage:
  account_name: "{{YOUR_STORAGE_NAME}}" # lowercase, 3-24 chars
  share_name: "{{YOUR_SHARE_NAME}}"

compute:
  vm_size: "{{YOUR_VM_SKU}}"            # e.g., Standard_D4s_v5
  vm_count: {{YOUR_COUNT}}              # e.g., 2
```

### Variable Mapping

```bash
# Load configuration
source core/config-manager.sh && load_config

# config.yaml → Environment Variables
azure.subscription_id    → AZURE_SUBSCRIPTION_ID
azure.resource_group     → AZURE_RESOURCE_GROUP
networking.vnet_name     → NETWORKING_VNET_NAME
storage.account_name     → STORAGE_ACCOUNT_NAME
```

**Variable Categories** (50+ total):
- `AZURE_*` - Global settings (5 vars)
- `NETWORKING_*` - VNet, NSG (5 vars)
- `STORAGE_*` - Accounts, shares (4 vars)
- `ENTRA_ID_*` - Groups, RBAC (6 vars)
- `HOST_POOL_*` - AVD settings (4 vars)
- `GOLDEN_IMAGE_*` - Image prep (12 vars)
- `SESSION_HOST_*` - VMs (4 vars)

### Template Substitution

```yaml
operation:
  template:
    command: |
      az vm run-command invoke \
        --resource-group "{{AZURE_RESOURCE_GROUP}}" \
        --name "{{COMPUTE_VM_NAME}}" \
        --scripts "@capabilities/compute/operations/script.ps1"
```

---

## Execution Model

```
./core/engine.sh run <operation-id>
  → Initialize state.db
  → Load config.yaml → Export ENV vars
  → Parse YAML → Substitute {{VARIABLES}}
  → Execute command
  → Monitor markers ([START/PROGRESS/SUCCESS])
  → On error: retry max 3x
  → Update state.db + checkpoint
```

**Progress markers** (required in PowerShell):
```powershell
Write-Host "[START] {{Operation}}: $(Get-Date -Format 'HH:mm:ss')"
Write-Host "[PROGRESS] Step 1/N: {{Description}}"
Write-Host "[SUCCESS] {{Completion message}}"
exit 0
```

Supported: `[START]`, `[PROGRESS]`, `[VALIDATE]`, `[SUCCESS]`, `[ERROR]`, `[WARNING]`

---

## Capability System

### Design Principles

- **Domain Organization**: Group by Azure service (networking, compute, etc.)
- **Reusability**: Use operations across workflows
- **Composability**: Chain operations
- **Idempotency**: Check before execute
- **Self-Documenting**: YAML defines behavior

### Operation Structure

```yaml
operation:
  id: "{{capability}}-{{action}}-{{resource}}"
  name: "{{Human Readable Name}}"

  duration:
    expected: {{seconds}}
    timeout: {{seconds}}
    type: "FAST|NORMAL|SLOW"

  template:
    type: "az-cli|az-vm-run-command"
    command: |
      {{Azure CLI command with {{VARIABLES}}}}

  powershell:
    content: |
      {{Inline PowerShell if needed}}

  validation:
    enabled: true|false
    checks:
      - type: "{{validation_type}}"
        expected: {{value}}

  fixes:
    # Auto-populated by error-handler.sh
```

### Available Capabilities

| Capability | Operations | Purpose |
|------------|-----------|---------|
| networking | 20 | VNets, subnets, NSGs, DNS, VPN |
| storage | 9 | Accounts, shares, private endpoints |
| identity | 15 | Entra ID, RBAC, managed identities |
| compute | 17 | VMs, images, disks, extensions |
| avd | 15 | Host pools, workspaces, app groups |
| management | 2 | Resource groups, validation |
| test-capability | 1 | Testing framework |

**Total**: 79 operations

---

## Error Handling & Self-Healing

**Automatic recovery**:
```
Error → Extract [ERROR] text → Generate fix → Apply to YAML (yq)
  → Retry (max 3x) → Success or checkpoint
```

**Anti-destructive safeguards** (blocked patterns):
`az vm delete`, `recreate.*vm`, `start over`, `destroy`, `remove.*vm`

**Philosophy**: Fix incrementally, never destroy and recreate.

**State tracking**:
- `state.db` - SQLite (current operation, history, retry counts)
- `artifacts/checkpoint_*.json` - Operation checkpoints
- `artifacts/logs/*.jsonl` - Structured logs

---

## Operation Development

See [docs/guides/executor-overview.md](docs/guides/executor-overview.md) for detailed guides.

**Quick create**:
```bash
./tools/capability-cli.sh create-operation {{capability}} {{operation-name}}
```

**Naming conventions**:
- Operations: `{{capability}}-{{action}}-{{resource}}`
- Files: `{{action}}-{{resource}}.yaml`
- Variables: `{{CATEGORY}}_{{SUBCATEGORY}}_{{NAME}}`

**Required fields**: id, name, duration.expected, duration.timeout, template.command
**Optional fields**: powershell.content, validation, fixes (auto-populated)

---

## Integration Points

- **Azure CLI**: All operations use `az` commands (no RDP/WinRM/PowerShell remoting)
- **State**: SQLite database (`state.db`) tracks execution
- **Logs**: JSONL format (`artifacts/logs/deployment_YYYYMMDD.jsonl`)

---

## Additional Resources

- **Quick Start**: [QUICKSTART.md](QUICKSTART.md)
- **User Guide**: [.claude/CLAUDE.md](.claude/CLAUDE.md)
- **Documentation**: [docs/README.md](docs/README.md)
- **Migration Status**: [docs/migration/](docs/migration/)

---

**Last Updated**: 2025-12-07
**Engine Version**: Phase 3 (Self-Healing)
**Operations**: 79 across 7 capabilities
**Status**: ✅ Production Ready
