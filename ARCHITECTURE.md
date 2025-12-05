# Azure VDI Deployment - System Architecture

## Quick Reference

- **Active System**: YAML-based engine (`core/` + `modules/`)
- **Configuration**: `config.yaml` (single source of truth)
- **Execution**: `./core/engine.sh run [module] [operation]`
- **State**: `state.json` (centralized tracking)
- **Legacy**: `legacy/modules/` (reference only, never executed)

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Directory Structure](#directory-structure)
3. [Configuration System](#configuration-system)
4. [Execution Model](#execution-model)
5. [Module Development](#module-development)
6. [State Tracking](#state-tracking)
7. [Error Handling & Self-Healing](#error-handling--self-healing)
8. [Legacy vs New Comparison](#legacy-vs-new-comparison)

---

## Architecture Overview

### New YAML-Based System (Active)

The project uses a **template-based YAML engine** with the following components:

```
┌─────────────────────────────────────────────────────────────────────┐
│                         config.yaml                                 │
│                  (Single Source of Truth)                           │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│                   core/config-manager.sh                            │
│                  - Parse YAML with yq                               │
│                  - Export 50+ environment variables                 │
│                  - Validate required fields                         │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│                     core/engine.sh                                  │
│                  Main Orchestrator                                  │
│   - run [module] [operation]                                        │
│   - resume (from failure)                                           │
│   - list [module]                                                   │
│   - status                                                          │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│              core/template-engine.sh                                │
│   - Parse YAML operation templates                                 │
│   - Substitute {{VARIABLES}} with values                           │
│   - Generate executable Azure CLI commands                         │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│              core/progress-tracker.sh                               │
│   - Monitor [START/PROGRESS/SUCCESS] markers                       │
│   - Real-time duration tracking                                    │
│   - Timeout detection (fail-fast)                                  │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│              Execute Azure CLI Command                              │
│   az vm run-command invoke --scripts @operation.ps1                │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│              core/error-handler.sh                                  │
│   If error occurs:                                                  │
│   1. Extract error from PowerShell logs                            │
│   2. Generate fix description                                      │
│   3. Apply fix to YAML template (via yq)                           │
│   4. Retry operation (max 3 times)                                 │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│              Update state.json + artifacts/                         │
│   - Operation status: completed/failed                             │
│   - Duration tracking                                              │
│   - Checkpoint files for resume                                    │
│   - Structured logs (JSONL)                                        │
└─────────────────────────────────────────────────────────────────────┘
```

### Core Engine Components

| Component | Lines | Purpose |
|-----------|-------|---------|
| `core/config-manager.sh` | 556 | Load YAML config, export env vars, validate required fields |
| `core/template-engine.sh` | 556 | Parse YAML operations, substitute variables, execute templates |
| `core/engine.sh` | 515 | Main orchestrator: run/resume/status/list operations |
| `core/progress-tracker.sh` | 325 | Real-time monitoring, progress markers, duration validation |
| `core/error-handler.sh` | 382 | Extract errors, generate fixes, apply to YAML, retry (max 3) |
| `core/logger.sh` | 322 | Structured logging to JSONL format |
| `core/validator.sh` | 362 | Configuration validation, prerequisite checks |

**Total**: 3,018 lines of production code

---

## Directory Structure

### Post-Reorganization Structure

```
/mnt/cache_pool/development/azure-cli/
├── README.md                    # Project documentation (YAML-focused)
├── ARCHITECTURE.md              # THIS FILE - Complete system architecture
├── config.yaml                  # Single source of truth for configuration
├── state.json                   # Execution state tracker
│
├── core/                        # Core YAML engine components
│   ├── config-manager.sh        # Configuration loading & validation
│   ├── template-engine.sh       # YAML template processing
│   ├── engine.sh                # Main orchestrator
│   ├── progress-tracker.sh      # Real-time progress monitoring
│   ├── error-handler.sh         # Self-healing & error management
│   ├── logger.sh                # Structured logging
│   └── validator.sh             # Configuration validation
│
├── modules/                     # Active YAML-based modules
│   └── 05-golden-image/
│       ├── module.yaml          # Module definition
│       └── operations/          # 11 YAML operation templates
│           ├── 01-system-prep.yaml
│           ├── 02-install-fslogix.yaml
│           ├── 03-install-chrome.yaml
│           ├── 04-install-adobe.yaml
│           ├── 05-install-office.yaml
│           ├── 06-configure-defaults.yaml
│           ├── 07-run-vdot.yaml
│           ├── 08-registry-avd.yaml
│           ├── 09-configure-default-profile.yaml
│           ├── 10-cleanup-temp.yaml
│           └── 11-validate-all.yaml
│
├── artifacts/                   # Centralized output storage
│   ├── logs/                    # Operation logs (JSONL format)
│   │   └── deployment_20251204.jsonl
│   ├── outputs/                 # Azure CLI operation outputs (JSON)
│   │   ├── golden-image-system-prep.json
│   │   └── ... (11 operation outputs)
│   ├── scripts/                 # Generated PowerShell scripts
│   ├── state/                   # Operation state files
│   └── checkpoint_*.json        # Checkpoint files for resume capability
│
├── tools/                       # Development tools
│   └── create-module.sh         # Module template generator
│
├── docs/                        # Documentation
│   └── config-migration.md      # Legacy config.env → config.yaml mapping
│
├── .claude/                     # Claude Code configuration
│   ├── CLAUDE.md                # AI assistant instructions
│   └── settings.local.json
│
├── common/                      # Shared utilities (legacy compatibility)
│   ├── functions/               # Bash functions
│   └── scripts/                 # Utility scripts
│
└── legacy/                      # ARCHIVED: Legacy bash-based modules
    ├── README.md                # Why legacy exists, migration guide
    ├── modules/                 # All 12 legacy bash modules
    │   ├── 01-networking/
    │   ├── 02-storage/
    │   ├── 03-entra-group/
    │   ├── 04-host-pool-workspace/
    │   ├── 05-golden-image/     # Bash version (superseded by modules/)
    │   ├── 06-session-host-deployment/
    │   ├── 07-intune/
    │   ├── 08-rbac/
    │   ├── 09-sso/
    │   ├── 10-autoscaling/
    │   ├── 11-testing/
    │   └── 12-cleanup-migration/
    ├── config/                  # Old config directory
    └── orchestrate.sh           # Old bash orchestrator
```

---

## Configuration System

### config.yaml Structure

The **single source of truth** for all configuration values:

```yaml
# Global Azure Settings
azure:
  subscription_id: "00000000-0000-0000-0000-000000000000"
  tenant_id: "00000000-0000-0000-0000-000000000000"
  location: "centralus"
  resource_group: "RG-Azure-VDI-01"
  environment: "prod"

# Module-specific configurations
networking:          # Module 01
  vnet_name: "avd-vnet"
  vnet_cidr: "10.0.0.0/16"
  subnet_name: "avd-subnet"
  subnet_cidr: "10.0.1.0/24"
  nsg_name: "avd-nsg"

storage:            # Module 02
  account_name: ""  # Auto-generated
  share_name: "fslogix-profiles"
  quota_gb: 1024
  tier: "Premium"

entra_id:           # Module 03
  group_users_standard: "AVD-Users-Standard"
  group_users_admins: "AVD-Users-Admins"
  # ... device groups

host_pool:          # Module 04
  name: "Pool-Pooled-Prod"
  type: "Pooled"
  max_sessions: 10
  load_balancer: "BreadthFirst"

workspace:          # Module 04
  name: "AVD-Workspace-Prod"
  friendly_name: "Azure Virtual Desktop"

app_group:          # Module 04
  name: "Desktop-Prod"
  type: "Desktop"

golden_image:       # Module 05
  temp_vm_name: "gm-temp-vm"
  vm_size: "Standard_D4s_v6"
  image_publisher: "MicrosoftWindowsDesktop"
  image_offer: "windows-11"
  image_sku: "win11-25h2-avd"
  admin_username: "entra-admin"
  fslogix_version: "2.9.8653.48899"
  timezone: "Central Standard Time"

session_host:       # Module 06
  vm_count: 1
  vm_size: "Standard_D4s_v6"
  name_prefix: "avd-sh"
  use_golden_image: true

# ... Modules 07-12
```

### Configuration Loading

```bash
# Load configuration
source core/config-manager.sh
load_config

# This exports 50+ environment variables:
echo $AZURE_RESOURCE_GROUP        # "RG-Azure-VDI-01"
echo $GOLDEN_IMAGE_TEMP_VM_NAME   # "gm-temp-vm"
echo $NETWORKING_VNET_NAME        # "avd-vnet"
```

### Available Variables

Variables exported from `config.yaml` (used as `{{VARIABLE}}` in YAML templates):

**Azure Global**:
- `{{AZURE_SUBSCRIPTION_ID}}`
- `{{AZURE_TENANT_ID}}`
- `{{AZURE_LOCATION}}`
- `{{AZURE_RESOURCE_GROUP}}`
- `{{AZURE_ENVIRONMENT}}`

**Networking (Module 01)**:
- `{{NETWORKING_VNET_NAME}}`
- `{{NETWORKING_VNET_CIDR}}`
- `{{NETWORKING_SUBNET_NAME}}`
- `{{NETWORKING_SUBNET_CIDR}}`
- `{{NETWORKING_NSG_NAME}}`

**Storage (Module 02)**:
- `{{STORAGE_ACCOUNT_NAME}}`
- `{{STORAGE_SHARE_NAME}}`
- `{{STORAGE_QUOTA_GB}}`
- `{{STORAGE_TIER}}`

**Entra ID (Module 03)**:
- `{{ENTRA_ID_GROUP_USERS_STANDARD}}`
- `{{ENTRA_ID_GROUP_USERS_ADMINS}}`
- `{{ENTRA_ID_GROUP_DEVICES_SSO}}`
- ... (6 total group variables)

**Host Pool (Module 04)**:
- `{{HOST_POOL_NAME}}`
- `{{HOST_POOL_TYPE}}`
- `{{HOST_POOL_MAX_SESSIONS}}`
- `{{HOST_POOL_LOAD_BALANCER}}`

**Workspace (Module 04)**:
- `{{WORKSPACE_NAME}}`
- `{{WORKSPACE_FRIENDLY_NAME}}`
- `{{WORKSPACE_DESCRIPTION}}`

**Application Group (Module 04)**:
- `{{APP_GROUP_NAME}}`
- `{{APP_GROUP_TYPE}}`
- `{{APP_GROUP_FRIENDLY_NAME}}`

**Golden Image (Module 05)**:
- `{{GOLDEN_IMAGE_TEMP_VM_NAME}}`
- `{{GOLDEN_IMAGE_VM_SIZE}}`
- `{{GOLDEN_IMAGE_IMAGE_PUBLISHER}}`
- `{{GOLDEN_IMAGE_IMAGE_OFFER}}`
- `{{GOLDEN_IMAGE_IMAGE_SKU}}`
- `{{GOLDEN_IMAGE_IMAGE_VERSION}}`
- `{{GOLDEN_IMAGE_ADMIN_USERNAME}}`
- `{{GOLDEN_IMAGE_GALLERY_NAME}}`
- `{{GOLDEN_IMAGE_DEFINITION_NAME}}`
- `{{GOLDEN_IMAGE_TIMEZONE}}`
- `{{GOLDEN_IMAGE_FSLOGIX_VERSION}}`
- `{{GOLDEN_IMAGE_VDOT_VERSION}}`

**Session Host (Module 06)**:
- `{{SESSION_HOST_VM_COUNT}}`
- `{{SESSION_HOST_VM_SIZE}}`
- `{{SESSION_HOST_NAME_PREFIX}}`
- `{{SESSION_HOST_USE_GOLDEN_IMAGE}}`

---

## Execution Model

### Command Structure

```bash
# Run entire module (all operations in sequence)
./core/engine.sh run [module-id]

# Run single operation
./core/engine.sh run [module-id] [operation-id]

# Resume from last failure
./core/engine.sh resume

# List available operations
./core/engine.sh list [module-id]

# Check execution status
./core/engine.sh status
```

### Execution Flow

```
1. User Command:
   ./core/engine.sh run 05-golden-image 01-system-prep

2. init_state()
   ├─ Create state.json if missing
   ├─ Initialize module tracking
   └─ Create artifacts/ directories

3. load_config()
   ├─ Parse config.yaml with yq
   ├─ Export 50+ environment variables
   └─ Validate required fields

4. get_module_operations()
   ├─ Read modules/05-golden-image/module.yaml
   └─ Extract operation list

5. parse_operation_yaml()
   ├─ Read modules/05-golden-image/operations/01-system-prep.yaml
   ├─ Extract: id, name, duration, template, powershell, validation
   └─ Load previous fixes (if any)

6. substitute_variables()
   ├─ Replace {{AZURE_RESOURCE_GROUP}} → "RG-Azure-VDI-01"
   ├─ Replace {{GOLDEN_IMAGE_TEMP_VM_NAME}} → "gm-temp-vm"
   └─ Generate executable command

7. execute_operation()
   ├─ Write PowerShell script to artifacts/scripts/
   ├─ Execute: az vm run-command invoke
   ├─ Save output to artifacts/outputs/golden-image-system-prep.json
   └─ Parse [START/PROGRESS/SUCCESS] markers

8. Monitor Progress (progress-tracker.sh)
   ├─ Track duration
   ├─ Detect timeout (if duration > 2x expected)
   └─ Fail-fast if stuck

9. Update State
   ├─ Record operation status in state.json
   ├─ Create checkpoint_golden-image-system-prep.json
   ├─ Log to artifacts/logs/deployment_20251204.jsonl
   └─ Update module status

10. On Error → error-handler.sh
    ├─ Extract [ERROR] markers
    ├─ Generate fix description
    ├─ Apply fix to YAML template (via yq)
    ├─ Retry operation (max 3 times)
    └─ Next run uses fixed template automatically

11. On Success → Next Operation
    └─ Proceed to 02-install-fslogix.yaml
```

### Progress Markers

All PowerShell scripts **must** include these markers for tracking:

```powershell
Write-Host "[START] Operation: $(Get-Date -Format 'HH:mm:ss')"
Write-Host "[PROGRESS] Step 1/4: Downloading software..."
Write-Host "[PROGRESS] Step 2/4: Installing..."
Write-Host "[VALIDATE] Checking installation..."
Write-Host "[SUCCESS] Operation completed successfully"
exit 0  # Required for success detection
```

**Markers Used**:
- `[START]` - Operation begins
- `[PROGRESS]` - Step update
- `[VALIDATE]` - Validation check
- `[SUCCESS]` - Operation completed
- `[ERROR]` - Error occurred
- `[WARNING]` - Non-fatal issue

---

## Module Development

### Creating a New Module

Use the template generator:

```bash
./tools/create-module.sh 06 "Session Host Deployment"
```

Or manually:

#### 1. Create Directory Structure

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

    - id: "session-host-join-domain"
      name: "Join VMs to Host Pool"
      duration: 180
      type: "NORMAL"

  validation:
    enabled: true
    checks:
      - type: "resource_exists"
        resource: "vm"
        name: "{{SESSION_HOST_NAME_PREFIX}}-01"
```

#### 3. Create Operation Template (`operations/01-create-vms.yaml`)

```yaml
operation:
  id: "session-host-create-vms"
  name: "Create Session Host VMs"

  duration:
    expected: 300      # Expected duration (seconds)
    timeout: 600       # Timeout threshold
    type: "NORMAL"     # FAST, NORMAL, SLOW

  template:
    type: "az-vm-run-command"
    command: |
      az vm create \
        --resource-group "{{AZURE_RESOURCE_GROUP}}" \
        --name "{{SESSION_HOST_NAME_PREFIX}}-01" \
        --image "{{GOLDEN_IMAGE_DEFINITION_NAME}}" \
        --size "{{SESSION_HOST_VM_SIZE}}" \
        --vnet-name "{{NETWORKING_VNET_NAME}}" \
        --subnet "{{NETWORKING_SUBNET_NAME}}"

  validation:
    enabled: true
    checks:
      - type: "vm_running"
        timeout: 120

  fixes:
    # Auto-populated by error handler on failures
```

#### 4. Add Configuration to `config.yaml`

```yaml
session_host:
  vm_count: 2
  vm_size: "Standard_D4s_v6"
  name_prefix: "avd-sh"
  use_golden_image: true
```

#### 5. Execute Module

```bash
source core/config-manager.sh && load_config
./core/engine.sh run 06-session-host-deployment
```

---

## State Tracking

### state.json Format

```json
{
  "version": "1.0",
  "started_at": "2025-12-04T20:17:14Z",
  "current_module": "05-golden-image",
  "current_operation": "golden-image-validate-all",
  "status": "running",

  "modules": {
    "05-golden-image": {
      "status": "completed",
      "timestamp": "2025-12-04T22:32:06Z"
    }
  },

  "operations": {
    "golden-image-system-prep": {
      "status": "completed",
      "duration": 33,
      "timestamp": "2025-12-04T20:47:06Z"
    },
    "golden-image-install-fslogix": {
      "status": "completed",
      "duration": 155,
      "timestamp": "2025-12-04T20:52:24Z"
    }
    // ... 9 more operations
  },

  "updated_at": "2025-12-04T22:32:06Z"
}
```

### Checkpoint Files

Created after each operation for resume capability:

```json
// artifacts/checkpoint_golden-image-system-prep.json
{
  "operation_id": "golden-image-system-prep",
  "status": "completed",
  "duration_seconds": 33,
  "timestamp": "2025-12-04T20:47:06Z",
  "log_file": "/mnt/cache_pool/development/azure-cli/artifacts/logs/golden-image-system-prep_20251204_204633.log"
}
```

### Logs

**Structured JSONL** (JSON Lines) format:

```jsonl
{"timestamp":"2025-12-04T20:47:06Z","level":"INFO","module":"05-golden-image","operation":"golden-image-system-prep","message":"[START] System preparation"}
{"timestamp":"2025-12-04T20:47:12Z","level":"INFO","module":"05-golden-image","operation":"golden-image-system-prep","message":"[PROGRESS] Step 1/3: Creating directory"}
{"timestamp":"2025-12-04T20:47:39Z","level":"INFO","module":"05-golden-image","operation":"golden-image-system-prep","message":"[SUCCESS] Complete"}
```

---

## Error Handling & Self-Healing

### Phase 3 Implementation

The engine includes **automatic error recovery**:

#### 1. Error Detection

```powershell
# In PowerShell script:
Write-Host "[ERROR] Failed to download FSLogix: Connection timeout"
exit 1
```

#### 2. Error Extraction (`error-handler.sh`)

```bash
extract_error_from_logs() {
    # Parse [ERROR] markers from artifacts/outputs/
    local error_msg=$(jq -r '.value[0].message' "$output_file" | grep '\[ERROR\]')
    echo "$error_msg"
}
```

#### 3. Fix Generation

```bash
generate_fix() {
    local error="$1"
    local fix=""

    case "$error" in
        *"timeout"*)
            fix="Increase timeout value in Invoke-WebRequest -TimeoutSec 120"
            ;;
        *"access denied"*)
            fix="Add elevated permissions to script execution"
            ;;
    esac

    echo "$fix"
}
```

#### 4. Apply Fix to YAML Template

```bash
apply_fix_to_yaml() {
    local operation_yaml="$1"
    local fix_description="$2"

    # Add fix to fixes: section using yq
    yq eval ".operation.fixes += [{\"issue\": \"$error\", \"detected\": \"$(date -u +%Y-%m-%d)\", \"fix\": \"$fix_description\", \"applied_to_template\": true}]" -i "$operation_yaml"
}
```

#### 5. Retry Operation

```bash
# Automatically retry (max 3 times)
retry_count=$(get_retry_count "$operation_id")
if [ "$retry_count" -lt 3 ]; then
    increment_retry_count "$operation_id"
    execute_operation "$module_id" "$operation_id"
else
    fail_operation "$operation_id" "Max retries exceeded"
fi
```

### Anti-Destructive Safeguards

The error handler **blocks** destructive fixes:

```bash
# Blocked patterns:
- "az vm delete"
- "recreate.*vm"
- "start over"
- "create.*new.*vm"
- "destroy"
- "remove.*vm"
- "az vm deallocate.*delete"
```

**Philosophy**: Fix the issue, don't destroy and recreate.

---

## Legacy vs New Comparison

| Feature | Legacy (bash modules 01-04) | New (YAML engine) |
|---------|----------------------------|-------------------|
| **Config Format** | `config.env` (bash variables) | `config.yaml` (YAML) |
| **Config Location** | Scattered (per-module) | Centralized (`config.yaml`) |
| **State Tracking** | Per-module (`module/state/`) | Centralized (`state.json`) |
| **Execution Engine** | Individual `*.sh` scripts | Unified `core/engine.sh` |
| **Template System** | Direct bash/PowerShell | YAML templates with variable substitution |
| **Error Handling** | Manual retry | Auto self-healing with fixes |
| **Progress Tracking** | None | Real-time via markers |
| **Logging** | Ad-hoc text files | Structured JSONL |
| **Resume Capability** | None | Checkpoint-based resume |
| **Validation** | Manual | Built-in per operation |
| **Execution Status** | Unknown | Fully traced in `state.json` |
| **Documentation** | Per-module READMEs | Centralized `ARCHITECTURE.md` |

### Why Legacy Modules Exist

The `legacy/modules/` directory contains:
- **Valuable Azure CLI commands** for resource creation
- **PowerShell implementation details** for configuration
- **Task breakdowns** showing execution patterns
- **Comments explaining AVD best practices**

**Use them as reference** when converting to YAML format.

**Do NOT execute** the legacy bash scripts - they were never run and are deprecated.

---

## Module Status

| Module | ID | Status | Implementation |
|--------|----|--------|----------------|
| Networking | 01 | Not executed | Azure resources created manually |
| Storage | 02 | Not executed | Azure resources created manually |
| Entra ID Groups | 03 | Not executed | Groups not created |
| Host Pool & Workspace | 04 | Not executed | Azure resources created manually |
| **Golden Image** | 05 | ✅ **Complete** | **11 operations executed successfully** |
| Session Host Deployment | 06 | Pending | Awaiting YAML conversion |
| Intune | 07 | Pending | Awaiting YAML conversion |
| RBAC | 08 | Pending | Awaiting YAML conversion |
| SSO | 09 | Pending | Awaiting YAML conversion |
| Autoscaling | 10 | Pending | Awaiting YAML conversion |
| Testing | 11 | Pending | Awaiting YAML conversion |
| Cleanup & Migration | 12 | Pending | Awaiting YAML conversion |

---

## Troubleshooting

### Common Issues

#### Config Loading Fails

```bash
# Error: yq command not found
# Solution: Install yq
sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
sudo chmod +x /usr/local/bin/yq
```

#### Variable Substitution Fails

```bash
# Error: {{VARIABLE}} not replaced
# Solution: Ensure load_config() was called
source core/config-manager.sh
load_config
```

#### Operation Timeout

```bash
# Check expected vs actual duration in module.yaml
# Adjust timeout value if operation genuinely takes longer
yq eval '.operation.duration.timeout = 900' -i modules/05-golden-image/operations/01-system-prep.yaml
```

#### Resume After Failure

```bash
# Check current state
cat state.json | jq '.current_operation'

# Resume from last checkpoint
./core/engine.sh resume
```

#### View Operation Logs

```bash
# Real-time log monitoring
tail -f artifacts/logs/deployment_$(date +%Y%m%d).jsonl

# View specific operation output
cat artifacts/outputs/golden-image-install-fslogix.json | jq -r '.value[0].message'
```

---

## Additional Resources

- **Project README**: [README.md](README.md) - Quick start guide
- **Configuration Reference**: [config.yaml](config.yaml) - All available variables
- **AI Instructions**: [.claude/CLAUDE.md](.claude/CLAUDE.md) - Claude Code instructions
- **Legacy Reference**: [legacy/README.md](legacy/README.md) - Legacy module migration guide
- **Config Migration**: [docs/config-migration.md](docs/config-migration.md) - Legacy → new mapping

---

**Last Updated**: 2025-12-04
**Engine Version**: Phase 3 Complete (Self-Healing & Error Handling)
**Active Modules**: 1/12 (Module 05: Golden Image)
