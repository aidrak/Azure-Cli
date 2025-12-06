# Azure VDI Deployment - Quick Start Guide

Get your Azure Virtual Desktop environment up and running in minutes.

## Prerequisites

### Required Software
- **Bash** 4.4+ (Linux/macOS/WSL)
- **Azure CLI** (`az`) - [Install Guide](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
- **jq** - JSON processor
- **yq** - YAML processor ([Download](https://github.com/mikefarah/yq))

### Azure Requirements
- Azure subscription with appropriate permissions
- Azure AD/Entra ID tenant access
- Contributor role on target resource group

## 5-Minute Setup

### 1. Configure Your Deployment

Edit `config.yaml` with your Azure settings:

```yaml
azure:
  subscription_id: "your-subscription-id"
  tenant_id: "your-tenant-id"
  location: "centralus"
  resource_group: "RG-Azure-VDI-01"

networking:
  vnet_name: "avd-vnet"
  vnet_address_space: "10.0.0.0/16"
  subnet_name: "avd-subnet"
  subnet_prefix: "10.0.1.0/24"

storage:
  account_name: "avdfslogix001"  # Must be globally unique
  share_name: "fslogix-profiles"

host_pool:
  name: "AVD-HostPool-01"
  type: "Pooled"
  max_sessions: 10

session_host:
  vm_count: 2
  vm_size: "Standard_D4s_v6"
  name_prefix: "avd-sh"
```

### 2. Configure Secrets (Optional but Recommended)

```bash
# Copy the secrets template
cp secrets.yaml.example secrets.yaml

# Edit secrets (never committed to git)
vi secrets.yaml
```

Secrets in `secrets.yaml` automatically override values in `config.yaml`, keeping sensitive data secure.

### 3. Load Configuration

```bash
# Load configuration into environment
source core/config-manager.sh && load_config
```

### 4. Run Operations

Execute capability operations to deploy your infrastructure:

```bash
# Create resource group
./core/engine.sh run resource-group-create

# Deploy networking
./core/engine.sh run vnet-create
./core/engine.sh run subnet-create
./core/engine.sh run nsg-create

# Deploy storage for FSLogix profiles
./core/engine.sh run storage-account-create
./core/engine.sh run file-share-create

# Create Entra ID groups
./core/engine.sh run users-group-create
./core/engine.sh run admins-group-create

# Deploy AVD infrastructure
./core/engine.sh run hostpool-create
./core/engine.sh run workspace-create
./core/engine.sh run appgroup-create
```

### 5. Monitor Progress

```bash
# Check current execution status
./core/engine.sh status

# View real-time logs
tail -f artifacts/logs/deployment_$(date +%Y%m%d).jsonl

# View specific operation output
cat artifacts/outputs/vnet-create.json | jq -r '.value[0].message'
```

## Common Workflows

### Complete Network Deployment

```bash
# Load config
source core/config-manager.sh && load_config

# Execute networking operations in sequence
./core/engine.sh run vnet-create
./core/engine.sh run subnet-create
./core/engine.sh run nsg-create
./core/engine.sh run nsg-rule-add
./core/engine.sh run nsg-attach
./core/engine.sh run networking-validate
```

### Golden Image Creation

```bash
# 1. Create temporary VM for image preparation
./core/engine.sh run golden-image-create-vm
./core/engine.sh run golden-image-validate-vm-ready

# 2. Prepare the system
./core/engine.sh run golden-image-system-prep

# 3. Install applications
./core/engine.sh run golden-image-install-apps
./core/engine.sh run golden-image-install-office

# 4. Optimize and configure
./core/engine.sh run golden-image-run-vdot
./core/engine.sh run golden-image-registry-avd
./core/engine.sh run golden-image-configure-defaults

# 5. Final validation
./core/engine.sh run golden-image-validate
```

### Session Host Deployment

```bash
# Deploy session hosts from golden image
./core/engine.sh run sessionhost-deploy

# Register to host pool
./core/engine.sh run sessionhost-register
```

## Resuming After Failure

If an operation fails, the engine automatically:
- Logs the error
- Saves current state
- Creates a checkpoint

To resume:

```bash
./core/engine.sh resume
```

The engine will automatically retry the failed operation with self-healing applied.

## Troubleshooting

### Configuration Not Loading

```bash
# Verify yq is installed
which yq

# Install if missing
sudo wget -qO /usr/local/bin/yq \
  https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
sudo chmod +x /usr/local/bin/yq
```

### Variables Not Substituting

```bash
# Ensure load_config was called
source core/config-manager.sh && load_config

# Verify variables are exported
echo $AZURE_RESOURCE_GROUP
echo $NETWORKING_VNET_NAME
```

### Operation Times Out

Check expected vs actual duration. If operation legitimately takes longer, you can adjust the timeout in the operation YAML file.

### View Recent Errors

```bash
# Search logs for errors
grep '\[ERROR\]' artifacts/logs/*.jsonl

# View last operation output
ls -t artifacts/outputs/*.json | head -1 | xargs cat | jq -r '.value[0].message'
```

## List Available Operations

```bash
# List all capability operations
./core/engine.sh list

# Count operations by capability
find capabilities/ -name "*.yaml" -path "*/operations/*" | \
  awk -F'/' '{print $2}' | sort | uniq -c
```

## Next Steps

### Learn the System
- **Architecture:** [ARCHITECTURE.md](ARCHITECTURE.md) - Complete system design
- **Capabilities:** [docs/capability-system/](docs/capability-system/) - All 7 capability domains
- **AI Operations:** [.claude/CLAUDE.md](.claude/CLAUDE.md) - AI assistant guide

### Deep Dives
- **Creating Operations:** [docs/guides/creating-operations.md](docs/capability-system/12-best-practices.md)
- **State Management:** [docs/reference/state-management.md](docs/state-manager-guide.md)
- **Remote Execution:** [docs/features/remote-execution-part1.md](docs/features/remote-execution-part1.md)

### Advanced Features
- **Self-Healing:** Automatic error recovery and retry
- **Idempotency:** Safe to run operations multiple times
- **Validation:** Post-execution verification
- **Rollback:** Cleanup procedures for failed operations

## Quick Reference Card

| Task | Command |
|------|---------|
| Load config | `source core/config-manager.sh && load_config` |
| Run operation | `./core/engine.sh run <operation-id>` |
| Resume failed | `./core/engine.sh resume` |
| Check status | `./core/engine.sh status` |
| List operations | `./core/engine.sh list` |
| View logs | `tail -f artifacts/logs/deployment_$(date +%Y%m%d).jsonl` |
| Check output | `cat artifacts/outputs/<operation-id>.json \| jq` |

## Support & Resources

- **Documentation:** [docs/](docs/)
- **Examples:** [docs/capability-system/10-operation-examples.md](docs/capability-system/10-operation-examples.md)
- **Troubleshooting:** [docs/guides/troubleshooting.md](docs/capability-system/)
- **Best Practices:** [docs/capability-system/12-best-practices.md](docs/capability-system/12-best-practices.md)

---

**System:** Capability-based (83 operations across 7 capabilities)
**Engine:** Phase 3 Complete (Self-Healing)
**Last Updated:** 2025-12-06
