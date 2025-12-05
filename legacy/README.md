# Legacy Bash-Based Modules

⚠️ **DEPRECATED**: These modules use the old bash script approach and have been superseded by the YAML-based engine in `/modules/`.

## Why This Directory Exists

These legacy modules contain **valuable implementation details** including:
- Azure CLI commands for resource creation
- PowerShell scripts for configuration
- Task breakdowns and execution patterns
- Comments explaining Azure AVD best practices

## Reference Only

**Do NOT execute these scripts directly**. They are retained as:
1. **Implementation reference** for converting to YAML modules
2. **Documentation** of Azure resource configuration
3. **Historical context** for project evolution

## Execution Status

All modules in this directory have **NEVER BEEN EXECUTED** (artifacts/ directories empty).

## Legacy Modules

| Module | Directory | Purpose |
|--------|-----------|---------|
| 01 | `modules/01-networking/` | VNet, subnet, NSG creation |
| 02 | `modules/02-storage/` | Storage account, file share, private endpoint |
| 03 | `modules/03-entra-group/` | Security groups, service principals |
| 04 | `modules/04-host-pool-workspace/` | Host pool, workspace, app group |
| 05 | `modules/05-golden-image/` | Golden image creation (bash version) |
| 06 | `modules/06-session-host-deployment/` | Session host VMs |
| 07 | `modules/07-intune/` | Intune device enrollment |
| 08 | `modules/08-rbac/` | Role-based access control |
| 09 | `modules/09-sso/` | Single sign-on configuration |
| 10 | `modules/10-autoscaling/` | Autoscaling plans |
| 11 | `modules/11-testing/` | Validation and testing |
| 12 | `modules/12-cleanup-migration/` | Cleanup and migration tools |

## Migration Guide

To convert a legacy module to the new YAML format:

### 1. Review Legacy Implementation
```bash
# Example: Converting Module 06 (Session Host Deployment)
cd legacy/modules/06-session-host-deployment/tasks/
cat 01-create-session-hosts.sh
```

### 2. Extract Key Components
- Azure CLI commands
- PowerShell scripts
- Configuration variables
- Validation checks

### 3. Create YAML Module Structure
```bash
mkdir -p /modules/06-session-host-deployment/operations/
```

### 4. Define Module
Create `modules/06-session-host-deployment/module.yaml`:
```yaml
module:
  id: "06-session-host-deployment"
  name: "Session Host Deployment"
  description: "Deploy session host VMs"

  operations:
    - id: "session-host-create-vms"
      name: "Create Session Host VMs"
      duration: 300
      type: "NORMAL"
```

### 5. Create Operation Templates
Create `modules/06-session-host-deployment/operations/01-create-vms.yaml`:
```yaml
operation:
  id: "session-host-create-vms"
  name: "Create Session Host VMs"

  duration:
    expected: 300
    timeout: 600
    type: "NORMAL"

  template:
    type: "az-vm-run-command"
    command: |
      az vm run-command invoke \
        --resource-group "{{AZURE_RESOURCE_GROUP}}" \
        --scripts "@modules/06-session-host-deployment/operations/01-create-vms.ps1"

  powershell:
    content: |
      # Extracted from legacy bash script
      Write-Host "[START] Session host creation: $(Get-Date -Format 'HH:mm:ss')"
      # ... PowerShell code ...
      Write-Host "[SUCCESS] Session hosts created"
```

### 6. Add Configuration
Update `config.yaml` with required variables:
```yaml
session_host:
  vm_count: 2
  vm_size: "Standard_D4s_v6"
  name_prefix: "avd-sh"
```

### 7. Execute with New Engine
```bash
source core/config-manager.sh && load_config
./core/engine.sh run 06-session-host-deployment
```

## Legacy Configuration

The legacy modules used **config.env** files for configuration:
```bash
# Example: legacy/modules/01-networking/config.env
export VNET_NAME="avd-vnet"
export VNET_CIDR="10.0.0.0/16"
```

**All legacy configuration has been migrated to `/config.yaml`**.

## Reference Implementation

### Module 05 Golden Image

The best reference for YAML conversion is **Module 05** - which has been fully implemented in the new YAML format:

```
/modules/05-golden-image/
├── module.yaml                    # Module definition
└── operations/                    # 11 YAML operations
    ├── 01-system-prep.yaml
    ├── 02-install-fslogix.yaml
    ├── 03-install-chrome.yaml
    ├── 04-install-adobe.yaml
    ├── 05-install-office.yaml
    ├── 06-configure-defaults.yaml
    ├── 07-run-vdot.yaml
    ├── 08-registry-avd.yaml
    ├── 09-configure-default-profile.yaml
    ├── 10-cleanup-temp.yaml
    └── 11-validate-all.yaml
```

**Compare**:
- Legacy: `legacy/modules/05-golden-image/tasks/`
- New YAML: `/modules/05-golden-image/operations/`

---

**For complete system documentation, see** [`/ARCHITECTURE.md`](/ARCHITECTURE.md)

**To use the new YAML-based system, see** [`.claude/CLAUDE.md`](/.claude/CLAUDE.md)
