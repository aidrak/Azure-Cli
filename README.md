# Azure Virtual Desktop - YAML Deployment Engine

> **🤖 AI ASSISTANTS**: Read [`.claude/CLAUDE.md`](.claude/CLAUDE.md) first, then [`ARCHITECTURE.md`](ARCHITECTURE.md) for system details.

Production-ready Azure Virtual Desktop (AVD) deployment using a YAML-based template engine with centralized configuration, self-healing, and real-time progress tracking.

## Quick Start

### 1. Configure

Edit `config.yaml` with your Azure settings:

```yaml
azure:
  subscription_id: "your-subscription-id"
  tenant_id: "your-tenant-id"
  location: "centralus"
  resource_group: "RG-Azure-VDI-01"
```

### 2. Execute

```bash
# Load configuration
source core/config-manager.sh && load_config

# Run entire module (all operations)
./core/engine.sh run 05-golden-image

# Run single operation
./core/engine.sh run 05-golden-image 01-system-prep

# Resume after failure
./core/engine.sh resume
```

### 3. Monitor

```bash
# Check state
cat state.json | jq

# Real-time logs
tail -f artifacts/logs/deployment_$(date +%Y%m%d).jsonl

# View operation output
cat artifacts/outputs/[operation-id].json | jq -r '.value[0].message'
```

## System Architecture

**YAML-based template engine** with 7 core components:

- **config.yaml** - Single source of truth (50+ variables)
- **core/config-manager.sh** - Configuration loading & validation
- **core/template-engine.sh** - YAML template processing with variable substitution
- **core/engine.sh** - Main orchestrator (run/resume/status/list)
- **core/progress-tracker.sh** - Real-time monitoring with `[START/PROGRESS/SUCCESS]` markers
- **core/error-handler.sh** - Self-healing with automatic retry (max 3)
- **core/logger.sh** - Structured JSONL logging

**Module Structure**:
```
modules/[ID]-[name]/
├── module.yaml              # Module definition
└── operations/
    └── XX-[name].yaml       # Self-contained YAML templates
```

**See [ARCHITECTURE.md](ARCHITECTURE.md) for complete documentation.**

## Module Status

| ID | Module | Status | Operations | Notes |
|----|--------|--------|------------|-------|
| 01 | Networking | 🔨 In Progress | TBD | YAML conversion |
| 02 | Storage | 🔨 In Progress | TBD | YAML conversion |
| 03 | Entra ID Groups | 🔨 In Progress | TBD | YAML conversion |
| 04 | Host Pool & Workspace | 🔨 In Progress | 5 operations | YAML templates created |
| 05 | **Golden Image** | ✅ **Complete** | 11 operations | Production-ready |
| 06 | Session Host Deployment | 🔨 In Progress | 2 operations | YAML templates created |
| 08 | RBAC | 🔨 In Progress | 4 operations | YAML templates created |
| 09 | SSO | 🔨 In Progress | 3 operations | YAML templates created |
| 10 | Autoscaling | 🔨 In Progress | 3 operations | YAML templates created |
| 07, 11, 12 | Intune, Testing, Cleanup | 📋 Pending | - | Awaiting YAML conversion |

### Module 05: Golden Image (Production Ready)

**11 operations executed successfully** (~16 minutes total):

1. System Preparation (0.5 min)
2. Install FSLogix (2.5 min)
3. Install Google Chrome (1 min)
4. Install Adobe Reader (1.5 min)
5. Install Microsoft Office 365 (6 min)
6. Configure Default Applications (0.5 min)
7. Run VDOT Optimization (1.5 min)
8. Configure AVD Registry Settings (0.5 min)
9. Configure Default User Profile (1 min)
10. Cleanup Temporary Files (0.5 min)
11. Validate All Components (0.5 min)

## Key Features

### Self-Healing Error Recovery

Automatic error detection and fix application:

1. Operation fails → Extract `[ERROR]` from PowerShell logs
2. Generate fix description
3. Apply fix to YAML template (`fixes:` section via `yq`)
4. Retry operation (max 3 attempts)
5. Next run uses fixed template automatically

**Anti-destructive safeguards** block: `az vm delete`, `recreate.*vm`, `start over`, etc.

### Real-Time Progress Tracking

All PowerShell scripts include progress markers:

```powershell
Write-Host "[START] Operation: $(Get-Date -Format 'HH:mm:ss')"
Write-Host "[PROGRESS] Step 1/4: Downloading..."
Write-Host "[VALIDATE] Checking installation..."
Write-Host "[SUCCESS] Complete"
exit 0
```

Engine monitors markers for:
- Duration tracking vs expected time
- Timeout detection (2x expected = fail-fast)
- Structured logging to JSONL

### State Management

- **state.json** - Centralized execution state
- **Checkpoint files** - `artifacts/checkpoint_[operation].json` for resume
- **Structured logs** - `artifacts/logs/deployment_YYYYMMDD.jsonl`
- **Operation outputs** - `artifacts/outputs/[operation].json`

### Configuration System

Single `config.yaml` exports 50+ environment variables:

```yaml
golden_image:
  temp_vm_name: "gm-temp-vm"
  vm_size: "Standard_D4s_v6"
  fslogix_version: "2.9.8653.48899"
  timezone: "Central Standard Time"
```

Variables used in YAML templates:

```yaml
template:
  command: |
    az vm run-command invoke \
      --resource-group "{{AZURE_RESOURCE_GROUP}}" \
      --name "{{GOLDEN_IMAGE_TEMP_VM_NAME}}" \
      --scripts "@modules/05-golden-image/operations/01-system-prep.ps1"
```

## Creating New Modules

```bash
# Generate module scaffold
./tools/create-module.sh 06 "Session Host Deployment"

# This creates:
modules/06-session-host-deployment/
├── module.yaml
└── operations/
    └── 01-example-operation.yaml

# Then:
# 1. Define operations in module.yaml
# 2. Create operation templates in operations/
# 3. Add config section to config.yaml
# 4. Execute: ./core/engine.sh run 06-session-host-deployment
```

## Commands Reference

```bash
# Configuration
source core/config-manager.sh && load_config  # Load config.yaml
validate_config                                # Validate required fields

# Execution
./core/engine.sh run [module]                  # Run all operations
./core/engine.sh run [module] [operation]      # Run single operation
./core/engine.sh resume                        # Resume from failure
./core/engine.sh list [module]                 # List operations
./core/engine.sh status                        # Execution status

# State & Logs
cat state.json | jq                            # View state
tail -f artifacts/logs/deployment_*.jsonl      # Real-time logs
cat artifacts/outputs/[operation].json         # Operation output
```

## Prerequisites

- Azure CLI (`az`) - [Install](https://learn.microsoft.com/cli/azure/install-azure-cli)
- `yq` (YAML processor) - [Install](https://github.com/mikefarah/yq)
- `jq` (JSON processor) - [Install](https://stedolan.github.io/jq/)
- Bash shell (Linux/macOS/WSL)
- Azure subscription with appropriate permissions

```bash
# Install yq
sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
sudo chmod +x /usr/local/bin/yq

# Verify prerequisites
az account show
yq --version
jq --version
```

## Troubleshooting

**Config loading fails**:
```bash
# Install yq if missing
sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
sudo chmod +x /usr/local/bin/yq
```

**Variable substitution fails**:
```bash
# Ensure config loaded
source core/config-manager.sh && load_config
echo $AZURE_RESOURCE_GROUP  # Should not be empty
```

**Operation timeout**:
```bash
# Adjust timeout in operation YAML
yq eval '.operation.duration.timeout = 600' -i modules/[module]/operations/[operation].yaml
```

**Resume after failure**:
```bash
cat state.json | jq '.current_operation'  # Check state
./core/engine.sh resume                    # Resume from checkpoint
```

## Documentation

| Document | Purpose |
|----------|---------|
| [ARCHITECTURE.md](ARCHITECTURE.md) | Complete system architecture |
| [.claude/CLAUDE.md](.claude/CLAUDE.md) | AI assistant instructions |
| [AZURE-VM-REMOTE-EXECUTION.md](AZURE-VM-REMOTE-EXECUTION.md) | `az vm run-command` pattern reference |
| [config.yaml](config.yaml) | Configuration reference |
| [legacy/README.md](legacy/README.md) | Legacy bash modules (reference only) |

## Legacy Reference

The `legacy/` directory contains original bash-based modules:

- **Do NOT execute** (deprecated)
- **Do reference** for Azure CLI commands, PowerShell implementations, and AVD best practices
- See [legacy/README.md](legacy/README.md) for details

---

**Last Updated**: 2025-12-05
**Engine Status**: Phase 3 Complete (Self-Healing)
**Production Modules**: 1/12 (Module 05: Golden Image ✅)
