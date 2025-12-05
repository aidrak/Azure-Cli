# Azure VDI Deployment - System Architecture

Complete technical reference for the YAML-based deployment engine.

## Quick Reference

- **Active System**: YAML engine (`core/` + `modules/`)
- **Configuration**: `config.yaml` (single source of truth)
- **Execution**: `./core/engine.sh run [module] [operation]`
- **State**: `state.json` (centralized tracking)
- **Legacy**: `legacy/` directory (reference only, never execute)

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Directory Structure](#directory-structure)
3. [Configuration System](#configuration-system)
4. [Execution Model](#execution-model)
5. [Module Development](#module-development)
6. [Error Handling & Self-Healing](#error-handling--self-healing)
7. [Troubleshooting](#troubleshooting)

---

## Architecture Overview

### System Flow

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

### Core Components

| Component | Lines | Purpose |
|-----------|-------|---------|
| `core/config-manager.sh` | 556 | Load config.yaml, export 50+ ENV vars, validate |
| `core/template-engine.sh` | 556 | Parse YAML operations, substitute variables |
| `core/engine.sh` | 515 | Main orchestrator (run/resume/status/list) |
| `core/progress-tracker.sh` | 325 | Real-time monitoring, duration validation |
| `core/error-handler.sh` | 382 | Extract errors, apply fixes, retry (max 3) |
| `core/logger.sh` | 322 | Structured JSONL logging |
| `core/validator.sh` | 362 | Configuration & prerequisite validation |

**Total**: 3,018 lines

---

## Directory Structure

```
azure-cli/
├── config.yaml                  # Single source of truth
├── state.json                   # Execution state
│
├── core/                        # Engine components (7 files)
│   ├── config-manager.sh
│   ├── template-engine.sh
│   ├── engine.sh
│   ├── progress-tracker.sh
│   ├── error-handler.sh
│   ├── logger.sh
│   └── validator.sh
│
├── modules/                     # YAML-based modules
│   ├── 01-networking/
│   ├── 02-storage/
│   ├── 03-entra-group/
│   ├── 04-host-pool-workspace/
│   ├── 05-golden-image/        # ✅ Complete (11 operations)
│   │   ├── module.yaml
│   │   └── operations/
│   │       ├── 01-system-prep.yaml
│   │       ├── 02-install-fslogix.yaml
│   │       └── ... (9 more operations)
│   ├── 06-session-host-deployment/
│   ├── 08-rbac/
│   ├── 09-sso/
│   └── 10-autoscaling/
│
├── artifacts/                   # Centralized output
│   ├── logs/                    # JSONL structured logs
│   ├── outputs/                 # Azure CLI JSON outputs
│   ├── scripts/                 # Generated PowerShell scripts
│   ├── state/                   # Retry counters
│   └── checkpoint_*.json        # Resume files
│
├── tools/
│   └── create-module.sh         # Module generator
│
├── docs/
│   ├── config-migration.md
│   └── archive/                 # Historical documentation
│
├── .claude/
│   └── CLAUDE.md                # AI assistant instructions
│
└── legacy/                      # ARCHIVED: Bash-based modules
    ├── README.md
    └── modules/                 # 12 legacy modules (reference only)
```

---

## Configuration System

### config.yaml Structure

Single file containing all deployment configuration:

```yaml
# Global Azure
azure:
  subscription_id: "00000000-0000-0000-0000-000000000000"
  tenant_id: "00000000-0000-0000-0000-000000000000"
  location: "centralus"
  resource_group: "RG-Azure-VDI-01"

# Module-specific sections
networking:
  vnet_name: "avd-vnet"
  subnet_name: "avd-subnet"

storage:
  account_name: "avdfslogix001"
  share_name: "fslogix-profiles"

golden_image:
  temp_vm_name: "gm-temp-vm"
  vm_size: "Standard_D4s_v6"
  fslogix_version: "2.9.8653.48899"
  timezone: "Central Standard Time"

session_host:
  vm_count: 2
  vm_size: "Standard_D4s_v6"
  name_prefix: "avd-sh"
```

### Configuration Loading

```bash
# Load configuration (exports 50+ environment variables)
source core/config-manager.sh
load_config

# Variables available as:
echo $AZURE_RESOURCE_GROUP          # "RG-Azure-VDI-01"
echo $GOLDEN_IMAGE_TEMP_VM_NAME     # "gm-temp-vm"
echo $SESSION_HOST_VM_COUNT         # "2"
```

### Variable Usage in Templates

YAML templates use `{{VARIABLE}}` syntax:

```yaml
operation:
  template:
    command: |
      az vm run-command invoke \
        --resource-group "{{AZURE_RESOURCE_GROUP}}" \
        --name "{{GOLDEN_IMAGE_TEMP_VM_NAME}}" \
        --scripts "@modules/05-golden-image/operations/install-fslogix.ps1"
```

**Available Variable Categories**:
- `AZURE_*` - Global Azure settings (5 vars)
- `NETWORKING_*` - VNet, subnet, NSG (5 vars)
- `STORAGE_*` - Storage account, file shares (4 vars)
- `ENTRA_ID_*` - Security groups (6 vars)
- `HOST_POOL_*` - Host pool settings (4 vars)
- `WORKSPACE_*` - Workspace settings (3 vars)
- `APP_GROUP_*` - Application group settings (3 vars)
- `GOLDEN_IMAGE_*` - Golden image settings (12 vars)
- `SESSION_HOST_*` - Session host settings (4 vars)

**Total**: 50+ configuration variables

---

## Execution Model

### Commands

```bash
# Run entire module (all operations sequentially)
./core/engine.sh run 05-golden-image

# Run single operation
./core/engine.sh run 05-golden-image 01-system-prep

# Resume from last failure
./core/engine.sh resume

# List operations in module
./core/engine.sh list 05-golden-image

# Check execution status
./core/engine.sh status
```

### Execution Flow

```
1. User Command
   ./core/engine.sh run 05-golden-image

2. Initialize State
   ├─ Create state.json if missing
   ├─ Initialize module tracking
   └─ Create artifacts/ directories

3. Load Configuration
   ├─ Parse config.yaml with yq
   ├─ Export 50+ environment variables
   └─ Validate required fields

4. Get Module Operations
   ├─ Read modules/05-golden-image/module.yaml
   └─ Extract operation list

5. For Each Operation:
   ├─ Parse operation YAML
   ├─ Load previous fixes (if any)
   ├─ Substitute {{VARIABLES}}
   ├─ Execute command
   ├─ Monitor progress markers
   ├─ Update state.json
   └─ Create checkpoint

6. On Error → error-handler.sh
   ├─ Extract [ERROR] markers
   ├─ Generate fix description
   ├─ Apply fix to YAML (yq)
   ├─ Retry (max 3 times)
   └─ Next run uses fixed template

7. On Success → Next Operation
```

### Progress Markers

All PowerShell scripts **must** include:

```powershell
Write-Host "[START] Operation: $(Get-Date -Format 'HH:mm:ss')"
Write-Host "[PROGRESS] Step 1/4: Downloading..."
Write-Host "[PROGRESS] Step 2/4: Installing..."
Write-Host "[VALIDATE] Checking installation..."
Write-Host "[SUCCESS] Operation completed"
exit 0  # Required
```

**Supported Markers**:
- `[START]` - Operation begins
- `[PROGRESS]` - Step update
- `[VALIDATE]` - Validation check
- `[SUCCESS]` - Completed successfully
- `[ERROR]` - Error occurred
- `[WARNING]` - Non-fatal issue

---

## Module Development

### Creating a New Module

Use the generator:

```bash
./tools/create-module.sh 06 "Session Host Deployment"
```

Or manually:

#### 1. Create Directory

```bash
mkdir -p modules/06-session-host-deployment/operations/
```

#### 2. Define Module (`module.yaml`)

```yaml
module:
  id: "06-session-host-deployment"
  name: "Session Host Deployment"
  description: "Deploy session host VMs from golden image"

  operations:
    - id: "session-host-create-vms"
      name: "Create Session Host VMs"
      duration: 300
      type: "NORMAL"
```

#### 3. Create Operation Template (`operations/01-create-vms.yaml`)

```yaml
operation:
  id: "session-host-create-vms"
  name: "Create Session Host VMs"

  duration:
    expected: 300      # Seconds
    timeout: 600
    type: "NORMAL"

  template:
    type: "az-cli"
    command: |
      az vm create \
        --resource-group "{{AZURE_RESOURCE_GROUP}}" \
        --name "{{SESSION_HOST_NAME_PREFIX}}-01" \
        --image "{{GOLDEN_IMAGE_DEFINITION_NAME}}" \
        --size "{{SESSION_HOST_VM_SIZE}}"

  validation:
    enabled: true
    checks:
      - type: "vm_running"
        timeout: 120

  fixes:
    # Auto-populated by error handler
```

#### 4. Add Configuration to `config.yaml`

```yaml
session_host:
  vm_count: 2
  vm_size: "Standard_D4s_v6"
  name_prefix: "avd-sh"
```

#### 5. Execute Module

```bash
source core/config-manager.sh && load_config
./core/engine.sh run 06-session-host-deployment
```

### Operation YAML Template Format

**Required Fields**:
- `operation.id` - Unique identifier
- `operation.name` - Human-readable name
- `operation.duration.expected` - Expected duration (seconds)
- `operation.duration.timeout` - Fail if exceeds this
- `operation.duration.type` - `FAST` | `NORMAL` | `SLOW`
- `operation.template.command` - Bash command to execute

**Optional Fields**:
- `operation.powershell.content` - Inline PowerShell script
- `operation.validation.enabled` - Enable validation
- `operation.validation.checks` - List of validation checks
- `operation.fixes` - Previous fixes (auto-populated)

---

## Error Handling & Self-Healing

### Automatic Error Recovery

When an operation fails:

#### 1. Error Detection

```powershell
Write-Host "[ERROR] Failed to download FSLogix: Connection timeout"
exit 1
```

#### 2. Error Extraction

`error-handler.sh` parses `[ERROR]` markers from operation output:

```bash
cat artifacts/outputs/golden-image-install-fslogix.json | jq -r '.value[0].message' | grep '\[ERROR\]'
```

#### 3. Fix Generation

Analyze error and generate fix description:

```bash
# Example error: "Connection timeout"
# Generated fix: "Increase timeout in Invoke-WebRequest -TimeoutSec 120"
```

#### 4. Apply Fix to YAML

Use `yq` to add fix to operation template:

```bash
yq eval '.operation.fixes += [{"issue": "Download timeout", "detected": "2025-12-05", "fix": "Added -TimeoutSec 120", "applied_to_template": true}]' -i operation.yaml
```

#### 5. Retry Operation

```bash
# Automatically retry (max 3 attempts)
if [ "$retry_count" -lt 3 ]; then
    increment_retry_count "$operation_id"
    execute_operation "$module_id" "$operation_id"
else
    fail_operation "$operation_id" "Max retries exceeded"
fi
```

### Anti-Destructive Safeguards

Error handler **blocks** these patterns:

- `az vm delete`
- `recreate.*vm`
- `start over`
- `create.*new.*vm`
- `destroy`
- `remove.*vm`
- `az vm deallocate.*delete`

**Philosophy**: Fix incrementally, never destroy and recreate.

### State Files

**state.json**:
```json
{
  "current_module": "05-golden-image",
  "current_operation": "golden-image-install-fslogix",
  "operations": {
    "golden-image-system-prep": {
      "status": "completed",
      "duration": 33,
      "timestamp": "2025-12-04T20:47:06Z"
    }
  }
}
```

**Checkpoint Files** (`artifacts/checkpoint_[operation].json`):
```json
{
  "operation_id": "golden-image-system-prep",
  "status": "completed",
  "duration_seconds": 33,
  "timestamp": "2025-12-04T20:47:06Z"
}
```

**Structured Logs** (`artifacts/logs/deployment_YYYYMMDD.jsonl`):
```jsonl
{"timestamp":"2025-12-04T20:47:06Z","level":"INFO","operation":"golden-image-system-prep","message":"[START] System preparation"}
{"timestamp":"2025-12-04T20:47:39Z","level":"INFO","operation":"golden-image-system-prep","message":"[SUCCESS] Complete"}
```

---

## Troubleshooting

### Config Loading Fails

```bash
# Error: yq command not found
# Solution:
sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
sudo chmod +x /usr/local/bin/yq
```

### Variable Substitution Fails

```bash
# Error: {{VARIABLE}} not replaced
# Solution: Ensure load_config() was called
source core/config-manager.sh
load_config
echo $AZURE_RESOURCE_GROUP  # Should not be empty
```

### Operation Timeout

```bash
# Check expected vs actual duration
# Adjust timeout if operation legitimately takes longer
yq eval '.operation.duration.timeout = 900' -i modules/05-golden-image/operations/01-system-prep.yaml
```

### Resume After Failure

```bash
# Check current state
cat state.json | jq '.current_operation'

# Resume from last checkpoint
./core/engine.sh resume
```

### View Logs

```bash
# Real-time monitoring
tail -f artifacts/logs/deployment_$(date +%Y%m%d).jsonl

# View operation output
cat artifacts/outputs/[operation-id].json | jq -r '.value[0].message'

# Check for errors
grep '\[ERROR\]' artifacts/logs/*.jsonl
```

---

## Module Status

| Module | Status | Operations | Notes |
|--------|--------|------------|-------|
| 01 - Networking | 🔨 In Progress | TBD | YAML conversion |
| 02 - Storage | 🔨 In Progress | TBD | YAML conversion |
| 03 - Entra ID Groups | 🔨 In Progress | TBD | YAML conversion |
| 04 - Host Pool & Workspace | 🔨 In Progress | 5 ops | YAML templates created |
| **05 - Golden Image** | ✅ **Complete** | 11 ops | **Production-ready** |
| 06 - Session Host Deployment | 🔨 In Progress | 2 ops | YAML templates created |
| 08 - RBAC | 🔨 In Progress | 4 ops | YAML templates created |
| 09 - SSO | 🔨 In Progress | 3 ops | YAML templates created |
| 10 - Autoscaling | 🔨 In Progress | 3 ops | YAML templates created |
| 07, 11, 12 - Intune, Testing, Cleanup | 📋 Pending | - | Awaiting conversion |

---

## Additional Resources

- **Quick Start**: [README.md](README.md)
- **AI Instructions**: [.claude/CLAUDE.md](.claude/CLAUDE.md)
- **Remote Execution**: [AZURE-VM-REMOTE-EXECUTION.md](AZURE-VM-REMOTE-EXECUTION.md)
- **Configuration**: [config.yaml](config.yaml)
- **Legacy Reference**: [legacy/README.md](legacy/README.md)
- **Config Migration**: [docs/config-migration.md](docs/config-migration.md)

---

**Last Updated**: 2025-12-05
**Engine Version**: Phase 3 Complete (Self-Healing)
**Active Modules**: 1/12 (Module 05: Golden Image ✅)
