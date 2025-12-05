# Azure Virtual Desktop Deployment - YAML-Based Engine

> **🤖 AI ASSISTANTS**: Read [`.claude/CLAUDE.md`](.claude/CLAUDE.md) for instructions, then [`ARCHITECTURE.md`](ARCHITECTURE.md) for complete system documentation.

## Overview

This repository provides a **template-based YAML engine** for deploying production-ready Azure Virtual Desktop (AVD) environments with:

- **YAML-based operations** - Template-driven deployment with variable substitution
- **Centralized configuration** - Single `config.yaml` source of truth
- **Self-healing** - Automatic error recovery with retry mechanism
- **Real-time tracking** - Progress monitoring, state management, checkpoint-based resume
- **AI-optimized** - Designed for AI assistants with comprehensive documentation

## Quick Start

### 1. Configure

Edit `config.yaml` with your Azure subscription and resource settings:

```yaml
azure:
  subscription_id: "00000000-0000-0000-0000-000000000000"
  tenant_id: "00000000-0000-0000-0000-000000000000"
  location: "centralus"
  resource_group: "RG-Azure-VDI-01"
```

### 2. Execute

```bash
# Load configuration (exports 50+ environment variables)
source core/config-manager.sh && load_config

# Run entire module
./core/engine.sh run 05-golden-image

# Or run single operation
./core/engine.sh run 05-golden-image 01-system-prep
```

### 3. Monitor

```bash
# Check execution state
cat state.json

# Real-time log monitoring
tail -f artifacts/logs/deployment_$(date +%Y%m%d).jsonl

# View operation output
cat artifacts/outputs/golden-image-install-fslogix.json | jq -r '.value[0].message'
```

### 4. Resume After Failure

```bash
# Automatically resume from last checkpoint
./core/engine.sh resume
```

## Architecture

This project uses a **YAML-based template engine** with:

- **Core Engine** - 7 components (3,018 lines):
  - `core/config-manager.sh` - Configuration loading & validation
  - `core/template-engine.sh` - YAML template processing
  - `core/engine.sh` - Main orchestrator
  - `core/progress-tracker.sh` - Real-time progress monitoring
  - `core/error-handler.sh` - Self-healing & automatic retry
  - `core/logger.sh` - Structured logging (JSONL)
  - `core/validator.sh` - Configuration validation

- **Module System** - Template-based operations:
  ```
  modules/[ID]-[name]/
  ├── module.yaml              # Module definition
  └── operations/
      └── XX-[operation].yaml  # Self-contained YAML templates
  ```

- **Configuration Flow**:
  ```
  config.yaml → load_config() → {{VARIABLES}} → YAML templates → Azure CLI
  ```

**See [ARCHITECTURE.md](ARCHITECTURE.md) for complete system documentation.**

## Module Status

| Module | Status | Operations | Duration |
|--------|--------|------------|----------|
| 05 - Golden Image | ✅ **Complete** | 11 operations | ~16 minutes |
| 01-04, 06-12 | 🚧 Pending | Awaiting YAML conversion | - |

### Module 05: Golden Image (Complete)

Successfully executed 11 operations:
1. System Preparation
2. Install FSLogix
3. Install Google Chrome
4. Install Adobe Reader (optional)
5. Install Microsoft Office 365
6. Configure Default Applications
7. Run VDOT Optimization
8. Configure AVD Registry Settings
9. Configure Default User Profile
10. Cleanup Temporary Files
11. Validate All Components

**Status**: Golden image ready for capture and deployment.

## Creating New Modules

Use the template generator:

```bash
./tools/create-module.sh 06 "Session Host Deployment"
```

This creates:
```
modules/06-session-host-deployment/
├── module.yaml
└── operations/
    └── 01-example-operation.yaml
```

Then:
1. Define operations in `module.yaml`
2. Create operation templates in `operations/`
3. Add configuration section to `config.yaml`
4. Execute: `./core/engine.sh run 06-session-host-deployment`

**See [ARCHITECTURE.md](ARCHITECTURE.md) → Module Development** for details.

## Legacy Reference

The `legacy/` directory contains the **original bash-based modules** (never executed):

- **Do NOT execute** these scripts (deprecated)
- **Do reference** them for:
  - Azure CLI commands
  - PowerShell implementation details
  - Task breakdowns
  - AVD best practices

**See [legacy/README.md](legacy/README.md)** for migration guide.

## Key Features

### Self-Healing Error Recovery

When operations fail:
1. Extract error from PowerShell logs
2. Generate fix description
3. Apply fix to YAML template (`fixes:` section)
4. Automatically retry (max 3 times)
5. Next run uses fixed template

**Anti-Destructive Safeguards**: Blocks destructive operations like `az vm delete`, `recreate.*vm`, etc.

### Real-Time Progress Tracking

All operations include progress markers:
```powershell
Write-Host "[START] Operation: $(Get-Date -Format 'HH:mm:ss')"
Write-Host "[PROGRESS] Step 1/4: Downloading..."
Write-Host "[VALIDATE] Checking installation..."
Write-Host "[SUCCESS] Complete"
```

### State Management

- **state.json** - Centralized execution state
- **Checkpoint files** - Resume capability after failures
- **Structured logs** - JSONL format for analysis
- **Operation outputs** - Full Azure CLI results

### Template System

Operations use YAML templates with variable substitution:

```yaml
operation:
  template:
    command: |
      az vm run-command invoke \
        --resource-group "{{AZURE_RESOURCE_GROUP}}" \
        --name "{{GOLDEN_IMAGE_TEMP_VM_NAME}}" \
        --scripts "@modules/05-golden-image/operations/01-system-prep.ps1"
```

Variables come from `config.yaml` - no hardcoded values.

## Documentation

| Document | Purpose |
|----------|---------|
| [ARCHITECTURE.md](ARCHITECTURE.md) | Complete system architecture (AI-focused) |
| [.claude/CLAUDE.md](.claude/CLAUDE.md) | AI assistant instructions |
| [config.yaml](config.yaml) | Configuration reference |
| [legacy/README.md](legacy/README.md) | Legacy module migration guide |
| [docs/config-migration.md](docs/config-migration.md) | Legacy config.env → config.yaml mapping |

## Prerequisites

- Azure CLI (`az`) installed and authenticated
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

## Commands Reference

```bash
# Configuration
source core/config-manager.sh && load_config  # Load config.yaml
validate_config                                # Validate configuration

# Execution
./core/engine.sh run [module]                  # Run entire module
./core/engine.sh run [module] [operation]      # Run single operation
./core/engine.sh resume                        # Resume from failure
./core/engine.sh list [module]                 # List operations
./core/engine.sh status                        # Check execution status

# Module Development
./tools/create-module.sh [ID] "[Name]"         # Generate module template

# Monitoring
cat state.json                                 # View execution state
tail -f artifacts/logs/deployment_*.jsonl      # Real-time logs
cat artifacts/outputs/[operation].json         # Operation output
```

## Troubleshooting

**Config loading fails**:
```bash
# Install yq
sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
sudo chmod +x /usr/local/bin/yq
```

**Variable substitution fails**:
```bash
# Verify config loaded
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
cat state.json | jq '.current_operation'  # Check current state
./core/engine.sh resume                    # Resume from checkpoint
```

**View detailed logs**:
```bash
# View operation output
cat artifacts/outputs/[operation-id].json | jq -r '.value[0].message'

# Check for errors
grep '\[ERROR\]' artifacts/logs/deployment_*.jsonl
```

## Project Status

**Engine Development**:
- ✅ Phase 1: Foundation (config-manager.sh, template-engine.sh)
- ✅ Phase 2: Progress & Validation (progress-tracker.sh, logger.sh)
- ✅ Phase 3: Self-Healing (error-handler.sh)
- ✅ Module 05: Golden Image (11 operations executed successfully)

**Next Steps**:
- Convert modules 01-04 to YAML format (reference legacy implementations)
- Implement modules 06-12 using YAML engine

## Contributing

When creating new modules:
1. Use `./tools/create-module.sh` for scaffolding
2. Follow Module 05 as reference implementation
3. Reference legacy modules for Azure CLI commands
4. Add configuration to `config.yaml`
5. Include `[START/PROGRESS/SUCCESS]` markers in PowerShell
6. Test with `./core/engine.sh run [module]`

## License

This template is provided as-is for Azure Virtual Desktop deployments.

---

**Last Updated**: 2025-12-04
**Engine Version**: Phase 3 Complete
**Active Modules**: 1/12 (Module 05: Golden Image ✅)
