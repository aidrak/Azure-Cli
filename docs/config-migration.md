# Configuration Migration Guide

## Overview

This guide documents how legacy `config.env` files map to the new centralized `config.yaml` format.

## Migration Summary

**Before (Legacy)**:
- Multiple `config.env` files scattered across modules
- Bash variable exports
- No validation
- Duplicate definitions

**After (New)**:
- Single `config.yaml` file
- YAML structure
- Built-in validation
- DRY (Don't Repeat Yourself)

---

## Module 01: Networking

### Legacy (01-networking/config.env)

```bash
# VNet Configuration
export VNET_NAME="${VNET_NAME:-avd-vnet}"
export VNET_CIDR="${VNET_CIDR:-10.0.0.0/16}"
export SUBNET_NAME="${SUBNET_NAME:-avd-subnet}"
export SUBNET_CIDR="${SUBNET_CIDR:-10.0.1.0/24}"

# NSG Configuration
export NSG_NAME="${NSG_NAME:-avd-nsg}"
```

### New (config.yaml)

```yaml
networking:
  vnet_name: "avd-vnet"
  vnet_cidr: "10.0.0.0/16"
  subnet_name: "avd-subnet"
  subnet_cidr: "10.0.1.0/24"
  nsg_name: "avd-nsg"
```

### Variable Mapping

| Legacy Bash Variable | New YAML Path | Template Variable |
|---------------------|---------------|-------------------|
| `$VNET_NAME` | `networking.vnet_name` | `{{NETWORKING_VNET_NAME}}` |
| `$VNET_CIDR` | `networking.vnet_cidr` | `{{NETWORKING_VNET_CIDR}}` |
| `$SUBNET_NAME` | `networking.subnet_name` | `{{NETWORKING_SUBNET_NAME}}` |
| `$SUBNET_CIDR` | `networking.subnet_cidr` | `{{NETWORKING_SUBNET_CIDR}}` |
| `$NSG_NAME` | `networking.nsg_name` | `{{NETWORKING_NSG_NAME}}` |

---

## Module 02: Storage

### Legacy (02-storage/config.env)

```bash
# Storage Account
export STORAGE_ACCOUNT_NAME="${STORAGE_ACCOUNT_NAME:-}"  # Auto-generated
export STORAGE_SHARE_NAME="${STORAGE_SHARE_NAME:-fslogix-profiles}"
export STORAGE_QUOTA_GB="${STORAGE_QUOTA_GB:-1024}"
export STORAGE_TIER="${STORAGE_TIER:-Premium}"
```

### New (config.yaml)

```yaml
storage:
  account_name: ""                      # Auto-generated if empty
  share_name: "fslogix-profiles"
  quota_gb: 1024
  tier: "Premium"                       # Premium or Standard
```

### Variable Mapping

| Legacy Bash Variable | New YAML Path | Template Variable |
|---------------------|---------------|-------------------|
| `$STORAGE_ACCOUNT_NAME` | `storage.account_name` | `{{STORAGE_ACCOUNT_NAME}}` |
| `$STORAGE_SHARE_NAME` | `storage.share_name` | `{{STORAGE_SHARE_NAME}}` |
| `$STORAGE_QUOTA_GB` | `storage.quota_gb` | `{{STORAGE_QUOTA_GB}}` |
| `$STORAGE_TIER` | `storage.tier` | `{{STORAGE_TIER}}` |

---

## Module 03: Entra ID Groups

### Legacy (03-entra-group/config.env)

```bash
# User Groups
export AVD_USERS_GROUP_NAME="${AVD_USERS_GROUP_NAME:-AVD-Users}"
export AVD_ADMINS_GROUP_NAME="${AVD_ADMINS_GROUP_NAME:-AVD-Admins}"

# Service Principal
export AUTOMATION_SP_NAME="${AUTOMATION_SP_NAME:-avd-automation}"
```

### New (config.yaml)

```yaml
entra_id:
  # User groups
  group_users_standard: "AVD-Users-Standard"
  group_users_admins: "AVD-Users-Admins"

  # Device groups
  group_devices_sso: "AVD-Devices-Pooled-SSO"
  group_devices_fslogix: "AVD-Devices-Pooled-FSLogix"
  group_devices_network: "AVD-Devices-Pooled-Network"
  group_devices_security: "AVD-Devices-Pooled-Security"
```

### Variable Mapping

| Legacy Bash Variable | New YAML Path | Template Variable |
|---------------------|---------------|-------------------|
| `$AVD_USERS_GROUP_NAME` | `entra_id.group_users_standard` | `{{ENTRA_ID_GROUP_USERS_STANDARD}}` |
| `$AVD_ADMINS_GROUP_NAME` | `entra_id.group_users_admins` | `{{ENTRA_ID_GROUP_USERS_ADMINS}}` |
| `$AUTOMATION_SP_NAME` | Not migrated | Handled by engine |

---

## Module 04: Host Pool & Workspace

### Legacy (04-host-pool-workspace/config.env)

```bash
# Host Pool
export HOST_POOL_NAME="${HOST_POOL_NAME:-Pool-Pooled-Prod}"
export HOST_POOL_TYPE="${HOST_POOL_TYPE:-Pooled}"
export MAX_SESSIONS="${MAX_SESSIONS:-10}"
export LOAD_BALANCER="${LOAD_BALANCER:-BreadthFirst}"

# Workspace
export WORKSPACE_NAME="${WORKSPACE_NAME:-AVD-Workspace-Prod}"
export WORKSPACE_FRIENDLY_NAME="${WORKSPACE_FRIENDLY_NAME:-Azure Virtual Desktop}"

# Application Group
export APP_GROUP_NAME="${APP_GROUP_NAME:-Desktop-Prod}"
export APP_GROUP_TYPE="${APP_GROUP_TYPE:-Desktop}"
```

### New (config.yaml)

```yaml
host_pool:
  name: "Pool-Pooled-Prod"
  type: "Pooled"                        # Pooled or Personal
  max_sessions: 10
  load_balancer: "BreadthFirst"         # BreadthFirst or DepthFirst

workspace:
  name: "AVD-Workspace-Prod"
  friendly_name: "Azure Virtual Desktop"
  description: "Production AVD workspace"

app_group:
  name: "Desktop-Prod"
  type: "Desktop"                       # Desktop or RemoteApp
  friendly_name: "Desktop"
```

### Variable Mapping

| Legacy Bash Variable | New YAML Path | Template Variable |
|---------------------|---------------|-------------------|
| `$HOST_POOL_NAME` | `host_pool.name` | `{{HOST_POOL_NAME}}` |
| `$HOST_POOL_TYPE` | `host_pool.type` | `{{HOST_POOL_TYPE}}` |
| `$MAX_SESSIONS` | `host_pool.max_sessions` | `{{HOST_POOL_MAX_SESSIONS}}` |
| `$LOAD_BALANCER` | `host_pool.load_balancer` | `{{HOST_POOL_LOAD_BALANCER}}` |
| `$WORKSPACE_NAME` | `workspace.name` | `{{WORKSPACE_NAME}}` |
| `$WORKSPACE_FRIENDLY_NAME` | `workspace.friendly_name` | `{{WORKSPACE_FRIENDLY_NAME}}` |
| `$APP_GROUP_NAME` | `app_group.name` | `{{APP_GROUP_NAME}}` |
| `$APP_GROUP_TYPE` | `app_group.type` | `{{APP_GROUP_TYPE}}` |

---

## Module 05: Golden Image

### Legacy (05-golden-image/config.env)

```bash
# Temporary VM
export TEMP_VM_NAME="${TEMP_VM_NAME:-gm-temp-vm}"
export VM_SIZE="${VM_SIZE:-Standard_D4s_v6}"

# Windows Image
export IMAGE_PUBLISHER="${IMAGE_PUBLISHER:-MicrosoftWindowsDesktop}"
export IMAGE_OFFER="${IMAGE_OFFER:-windows-11}"
export IMAGE_SKU="${IMAGE_SKU:-win11-25h2-avd}"

# Credentials
export ADMIN_USERNAME="${ADMIN_USERNAME:-entra-admin}"
export ADMIN_PASSWORD="${ADMIN_PASSWORD:-}"  # From environment

# Software Versions
export FSLOGIX_VERSION="${FSLOGIX_VERSION:-2.9.8653.48899}"
export VDOT_VERSION="${VDOT_VERSION:-3.8}"

# Timezone
export TIMEZONE="${TIMEZONE:-Central Standard Time}"
```

### New (config.yaml)

```yaml
golden_image:
  # Temporary VM for image creation
  temp_vm_name: "gm-temp-vm"
  vm_size: "Standard_D4s_v6"

  # Windows base image
  image_publisher: "MicrosoftWindowsDesktop"
  image_offer: "windows-11"
  image_sku: "win11-25h2-avd"
  image_version: "latest"

  # VM credentials (password should be set via environment variable)
  admin_username: "entra-admin"
  admin_password: ""                    # NEVER commit password - use environment variable

  # Azure Compute Gallery
  gallery_name: "avd_gallery"
  definition_name: "windows11-golden-image"
  image_sku_name: "Win11-Pooled-FSLogix"
  image_publisher_name: "YourCompany"
  image_offer_name: "AVD"

  # Timezone
  timezone: "Central Standard Time"
  timezone_redirection_enabled: true

  # Software versions
  fslogix_version: "2.9.8653.48899"
  vdot_version: "3.8"
```

### Variable Mapping

| Legacy Bash Variable | New YAML Path | Template Variable |
|---------------------|---------------|-------------------|
| `$TEMP_VM_NAME` | `golden_image.temp_vm_name` | `{{GOLDEN_IMAGE_TEMP_VM_NAME}}` |
| `$VM_SIZE` | `golden_image.vm_size` | `{{GOLDEN_IMAGE_VM_SIZE}}` |
| `$IMAGE_PUBLISHER` | `golden_image.image_publisher` | `{{GOLDEN_IMAGE_IMAGE_PUBLISHER}}` |
| `$IMAGE_OFFER` | `golden_image.image_offer` | `{{GOLDEN_IMAGE_IMAGE_OFFER}}` |
| `$IMAGE_SKU` | `golden_image.image_sku` | `{{GOLDEN_IMAGE_IMAGE_SKU}}` |
| `$ADMIN_USERNAME` | `golden_image.admin_username` | `{{GOLDEN_IMAGE_ADMIN_USERNAME}}` |
| `$ADMIN_PASSWORD` | `golden_image.admin_password` | `{{GOLDEN_IMAGE_ADMIN_PASSWORD}}` |
| `$FSLOGIX_VERSION` | `golden_image.fslogix_version` | `{{GOLDEN_IMAGE_FSLOGIX_VERSION}}` |
| `$VDOT_VERSION` | `golden_image.vdot_version` | `{{GOLDEN_IMAGE_VDOT_VERSION}}` |
| `$TIMEZONE` | `golden_image.timezone` | `{{GOLDEN_IMAGE_TIMEZONE}}` |

---

## Module 06: Session Host Deployment

### Legacy (06-session-host-deployment/config.env)

```bash
# Session Host Configuration
export SESSION_HOST_COUNT="${SESSION_HOST_COUNT:-2}"
export SESSION_HOST_SIZE="${SESSION_HOST_SIZE:-Standard_D4s_v6}"
export SESSION_HOST_PREFIX="${SESSION_HOST_PREFIX:-avd-sh}"
export USE_GOLDEN_IMAGE="${USE_GOLDEN_IMAGE:-true}"
```

### New (config.yaml)

```yaml
session_host:
  vm_count: 1
  vm_size: "Standard_D4s_v6"
  name_prefix: "avd-sh"

  # Image source (from golden image)
  use_golden_image: true
```

### Variable Mapping

| Legacy Bash Variable | New YAML Path | Template Variable |
|---------------------|---------------|-------------------|
| `$SESSION_HOST_COUNT` | `session_host.vm_count` | `{{SESSION_HOST_VM_COUNT}}` |
| `$SESSION_HOST_SIZE` | `session_host.vm_size` | `{{SESSION_HOST_VM_SIZE}}` |
| `$SESSION_HOST_PREFIX` | `session_host.name_prefix` | `{{SESSION_HOST_NAME_PREFIX}}` |
| `$USE_GOLDEN_IMAGE` | `session_host.use_golden_image` | `{{SESSION_HOST_USE_GOLDEN_IMAGE}}` |

---

## Global Azure Settings

### Legacy (Scattered across multiple config.env files)

```bash
export SUBSCRIPTION_ID="${SUBSCRIPTION_ID:-00000000-0000-0000-0000-000000000000}"
export TENANT_ID="${TENANT_ID:-00000000-0000-0000-0000-000000000000}"
export LOCATION="${LOCATION:-centralus}"
export RESOURCE_GROUP="${RESOURCE_GROUP:-RG-Azure-VDI-01}"
```

### New (config.yaml - Centralized)

```yaml
azure:
  subscription_id: "00000000-0000-0000-0000-000000000000"
  tenant_id: "00000000-0000-0000-0000-000000000000"
  location: "centralus"
  resource_group: "RG-Azure-VDI-01"
  environment: "prod"
```

### Variable Mapping

| Legacy Bash Variable | New YAML Path | Template Variable |
|---------------------|---------------|-------------------|
| `$SUBSCRIPTION_ID` | `azure.subscription_id` | `{{AZURE_SUBSCRIPTION_ID}}` |
| `$TENANT_ID` | `azure.tenant_id` | `{{AZURE_TENANT_ID}}` |
| `$LOCATION` | `azure.location` | `{{AZURE_LOCATION}}` |
| `$RESOURCE_GROUP` | `azure.resource_group` | `{{AZURE_RESOURCE_GROUP}}` |

---

## Configuration Loading

### Legacy Approach

```bash
# Each module had to:
cd 01-networking
source config.env
source ../config/avd-config.sh  # Fallback
```

### New Approach

```bash
# Once at startup:
source core/config-manager.sh
load_config  # Parses config.yaml, exports all variables
```

**Result**: 50+ environment variables exported automatically:
- `$AZURE_RESOURCE_GROUP`
- `$NETWORKING_VNET_NAME`
- `$GOLDEN_IMAGE_TEMP_VM_NAME`
- etc.

---

## Template Variable Usage

### In YAML Operation Templates

```yaml
operation:
  template:
    command: |
      az vm run-command invoke \
        --resource-group "{{AZURE_RESOURCE_GROUP}}" \
        --name "{{GOLDEN_IMAGE_TEMP_VM_NAME}}" \
        --scripts "@capabilities/compute/operations/golden-image-system-prep.ps1"

  powershell:
    content: |
      $VNetName = "{{NETWORKING_VNET_NAME}}"
      $SubnetName = "{{NETWORKING_SUBNET_NAME}}"
```

**Substitution happens at runtime** via `core/template-engine.sh`.

---

## Benefits of New System

1. **Single Source of Truth** - No duplicate definitions
2. **Type Safety** - YAML structure prevents typos
3. **Validation** - Built-in config validation via `validate_config`
4. **Centralized** - All settings in one file
5. **Namespaced** - Module-specific sections prevent conflicts
6. **DRY** - Global azure settings reused across all modules
7. **Version Control** - Single file to track changes
8. **Documentation** - Self-documenting structure

---

## Migration Checklist

- [x] Remove all `config.env` files from legacy modules
- [x] Create centralized `config.yaml`
- [x] Update `.claude/CLAUDE.md` to reference config.yaml
- [x] Document variable mappings
- [x] Test configuration loading
- [x] Validate all variables exported correctly

---

**See also**:
- [ARCHITECTURE.md](../ARCHITECTURE.md) → Configuration System
- [config.yaml](../config.yaml) → Current configuration
- [.claude/CLAUDE.md](../.claude/CLAUDE.md) → Usage instructions
