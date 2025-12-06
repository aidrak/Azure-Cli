# Azure Virtual Desktop - YAML Deployment Engine

> **AI ASSISTANTS**: Read [`.claude/CLAUDE.md`](.claude/CLAUDE.md) first, then [`ARCHITECTURE.md`](ARCHITECTURE.md) for system details.

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

# Run operations by capability (current system)
./core/engine.sh run golden-image-install-apps
./core/engine.sh run vnet-create
./core/engine.sh run storage-account-create

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

This project uses a **capability-based operation system** for Azure Virtual Desktop deployment. The system is declarative, YAML-based, with centralized configuration and self-healing capabilities. It is composed of 7 core scripts in the `/core` directory that manage configuration, templating, execution, and state.

### Core Components
- **config.yaml** - Single source of configuration
- **core/** - 7 engine scripts (config, template, execution, progress, error handling, logging, validation)
- **capabilities/** - 79 operations across 7 capability domains
- **artifacts/** - Logs, state, and outputs

### Capability Domains
- **networking** (20 ops) - VNets, subnets, NSGs, VPN, DNS, load balancers
- **storage** (9 ops) - Storage accounts, file shares, private endpoints
- **identity** (15 ops) - Entra ID groups, RBAC, service principals
- **compute** (17 ops) - VMs, images, golden image preparation
- **avd** (15 ops) - Host pools, workspaces, app groups, scaling
- **management** (2 ops) - Resource groups, validation
- **test-capability** (1 op) - Testing framework

**Total:** 79 automated operations

For complete architecture details, see [ARCHITECTURE.md](ARCHITECTURE.md).
For capability system documentation, see [ARCHITECTURE.md#capability-system](ARCHITECTURE.md#capability-system).

## Migration Status

✅ **COMPLETE** - All legacy modules migrated to capability-based format (2025-12-06)

- **79 operations** migrated across **7 capabilities**
- **100% PowerShell** logic preserved
- **Legacy system** archived in `legacy/modules/` (reference only)

See [MIGRATION-INDEX.md](MIGRATION-INDEX.md) for complete catalog.

## Documentation

| Document | Purpose |
|----------|---------|
| [ARCHITECTURE.md](ARCHITECTURE.md) | Complete system architecture |
| [.claude/CLAUDE.md](.claude/CLAUDE.md) | Main operational guide and development hub |
| [AZURE-VM-REMOTE-EXECUTION.md](AZURE-VM-REMOTE-EXECUTION.md) | Details on `az vm run-command` pattern |
| [MIGRATION-INDEX.md](MIGRATION-INDEX.md) | Complete operation catalog |
| [config.yaml](config.yaml) | Configuration reference |

### Legacy Reference
- [legacy/](legacy/) - Archived module system (reference only, do not execute)

---

**Last Updated**: 2025-12-06
**Engine Status**: Phase 3 Complete (Self-Healing)
**System**: Capability-based (79 operations across 7 capabilities)
**Migration Status**: ✅ Complete
