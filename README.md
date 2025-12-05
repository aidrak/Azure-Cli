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

**Secrets Management** (for passwords and sensitive values):

```bash
# Copy the secrets template
cp secrets.yaml.example secrets.yaml

# Edit secrets.yaml (this file is in .gitignore - never committed)
vi secrets.yaml
```

Secrets in `secrets.yaml` automatically override values in `config.yaml`. This keeps sensitive data out of git while allowing you to configure once and not constantly provide passwords.

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

This project uses a declarative, YAML-based template engine with centralized configuration and self-healing capabilities. It is composed of 7 core scripts in the `/core` directory that manage configuration, templating, execution, and state.

Modules and their operations are defined entirely in YAML. For a complete technical breakdown, see the **[System Architecture Guide](ARCHITECTURE.md)**.

## Module Status

Currently, Module 05 (Golden Image) is production-ready. Other modules are in the process of being converted to the new YAML format. See the [full status table in ARCHITECTURE.md](ARCHITECTURE.md#module-status) for details.

## Prerequisites
| Document | Purpose |
|----------|---------|
| [**`ARCHITECTURE.md`**](ARCHITECTURE.md) | Complete system architecture and technical reference. |
| [**`.claude/CLAUDE.md`**](.claude/CLAUDE.md) | **Main Hub & User Guide** for operations and development. |
| [`AZURE-VM-REMOTE-EXECUTION.md`](AZURE-VM-REMOTE-EXECUTION.md) | Deep dive into the `az vm run-command` pattern. |
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
