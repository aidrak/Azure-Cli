---
name: azure-operations
description: Deploy and modify Azure infrastructure using YAML-based operations. Creates VNets, VMs, storage accounts, identity resources, AVD host pools, and configures networking. Use when deploying infrastructure, creating resources, running setup operations, or modifying Azure configurations.
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
---

# Azure Operations

Deploy and manage Azure infrastructure using the engine-based YAML operation system.

## When to use this Skill

- User asks to "deploy" or "create" Azure infrastructure
- User asks to "set up" or "configure" resources
- User wants to modify existing Azure resources
- User needs to run deployment operations
- User asks to create VNets, VMs, storage accounts, AVD resources, etc.
- User needs to configure networking, identity, or compute
- User asks "How do I deploy..." or "Can you create..."

## Core Pattern

All operations follow this standard workflow:

```bash
# 1. Load configuration (ALWAYS FIRST)
source core/config-manager.sh && load_config

# 2. List available operations
./core/engine.sh list

# 3. Run an operation
./core/engine.sh run <operation-id>

# 4. Check status
./core/engine.sh status

# 5. Resume on failure
./core/engine.sh resume
```

## Operation Categories

The system has **79 operations** across **7 capabilities**:

### Management (2 operations)
Resource group operations:
```bash
./core/engine.sh run management-resource-group-create
./core/engine.sh run management-resource-group-validate
```

### Networking (20 operations)
VNets, NSGs, subnets, VPN, DNS, load balancers:
```bash
./core/engine.sh run networking-create-vnet
./core/engine.sh run networking-create-nsg
./core/engine.sh run networking-create-subnet
./core/engine.sh run networking-nsg-rule-add
./core/engine.sh run networking-configure-dns
./core/engine.sh run networking-create-vpn-gateway
./core/engine.sh run networking-vnet-peering-create
```

### Storage (9 operations)
Storage accounts, file shares, private endpoints:
```bash
./core/engine.sh run storage-create-account
./core/engine.sh run storage-create-fileshare
./core/engine.sh run storage-private-endpoint-create
./core/engine.sh run storage-disable-public-access
```

### Identity (15 operations)
Entra ID groups, RBAC, service principals:
```bash
./core/engine.sh run identity-create-group
./core/engine.sh run identity-rbac-assign
./core/engine.sh run identity-service-principal-create
./core/engine.sh run identity-managed-identity-create
./core/engine.sh run identity-fslogix-group-create
```

### Compute (17 operations)
VMs, images, disks, availability sets:
```bash
./core/engine.sh run compute-create-vm
./core/engine.sh run compute-vm-start
./core/engine.sh run compute-vm-configure
./core/engine.sh run compute-golden-image-install-apps
./core/engine.sh run compute-golden-image-install-office
./core/engine.sh run compute-golden-image-configure-profile
./core/engine.sh run compute-image-create
```

### AVD (15 operations)
Host pools, workspaces, session hosts, autoscaling:
```bash
./core/engine.sh run avd-hostpool-create
./core/engine.sh run avd-workspace-create
./core/engine.sh run avd-appgroup-create
./core/engine.sh run avd-sessionhost-add
./core/engine.sh run avd-autoscaling-create-plan
./core/engine.sh run avd-sso-hostpool-configure
```

### Test Capability (1 operation)
For testing the system:
```bash
./core/engine.sh run test-capability-test-operation
```

## Finding Operations

### List all operations
```bash
./core/engine.sh list
```

### Search for specific operations
```bash
./core/engine.sh list | grep -i "vnet"
./core/engine.sh list | grep -i "storage"
./core/engine.sh list | grep -i "golden-image"
```

### List by capability
```bash
ls -1 capabilities/networking/operations/
ls -1 capabilities/compute/operations/
ls -1 capabilities/avd/operations/
```

## Running Operations

### Single operation
```bash
source core/config-manager.sh && load_config
./core/engine.sh run networking-create-vnet
```

### Multiple operations (sequential)
```bash
source core/config-manager.sh && load_config
./core/engine.sh run management-resource-group-create
./core/engine.sh run networking-create-vnet
./core/engine.sh run networking-create-subnet
./core/engine.sh run storage-create-account
```

### Check operation status
```bash
./core/engine.sh status

# Or query state database
sqlite3 state.db "SELECT operation_id, status FROM operations ORDER BY timestamp DESC LIMIT 10"
```

## Creating New Operations

When user needs a custom operation not in the list:

1. **Check if it exists first**:
   ```bash
   ./core/engine.sh list | grep -i "operation-name"
   ```

2. **If not found, create new YAML operation**:
   ```bash
   # Create in appropriate capability directory
   touch capabilities/{capability}/operations/{action}-{resource}.yaml
   ```

3. **Use standard YAML template**:
   ```yaml
   operation:
     id: "capability-action-resource"
     name: "Human Readable Name"

     duration:
       expected: 180
       timeout: 300
       type: "NORMAL"

     template:
       type: "az-cli"
       command: |
         az {resource} {action} \
           --resource-group "{{AZURE_RESOURCE_GROUP}}" \
           --name "{{RESOURCE_NAME}}" \
           --location "{{AZURE_LOCATION}}"

     validation:
       enabled: true
       checks:
         - type: "exit_code"
           expected: 0
   ```

4. **Test the operation**:
   ```bash
   ./core/engine.sh run {operation-id}
   ```

## Critical Guidelines

### ALWAYS
- Load config first: `source core/config-manager.sh && load_config`
- Use YAML operations only (not standalone scripts)
- Use `{{VARIABLES}}` from config.yaml (never hardcode)
- Use `@filename` syntax for PowerShell scripts
- ASCII markers in PowerShell: `[*] [v] [x] [!] [i]` (NO emoji)
- Let output go to stdout (captured by state.db)

### NEVER
- Create standalone scripts outside capabilities/
- Hardcode values (subscription IDs, names, etc.)
- Use PowerShell remoting (WinRM, RDP)
- Redirect output to files (breaks state tracking)
- Skip config loading step

## Operation Types

### Azure CLI Operations
```yaml
template:
  type: "az-cli"
  command: |
    az network vnet create \
      --resource-group "{{AZURE_RESOURCE_GROUP}}" \
      --name "{{NETWORKING_VNET_NAME}}" \
      --address-prefix "{{NETWORKING_VNET_ADDRESS_SPACE}}"
```

### VM Remote Command Operations
```yaml
template:
  type: "az-vm-run-command"
  command: |
    az vm run-command invoke \
      --resource-group "{{AZURE_RESOURCE_GROUP}}" \
      --name "{{COMPUTE_VM_GOLDEN_IMAGE_NAME}}" \
      --scripts "@capabilities/compute/operations/install-apps.ps1"

powershell:
  content: |
    Write-Host "[START] Installing applications"
    # PowerShell code here
    Write-Host "[v] Installation complete"
    exit 0
```

## Variable Resolution

All `{{VARIABLES}}` come from config.yaml:

```yaml
# config.yaml
azure:
  subscription_id: "your-sub-id"
  location: "centralus"
  resource_group: "RG-Azure-VDI-01"

networking:
  vnet:
    name: "vnet-avd-prod"
    address_space: "10.0.0.0/16"
```

Becomes environment variables:
- `{{AZURE_SUBSCRIPTION_ID}}` → `$AZURE_SUBSCRIPTION_ID`
- `{{AZURE_LOCATION}}` → `$AZURE_LOCATION`
- `{{NETWORKING_VNET_NAME}}` → `$NETWORKING_VNET_NAME`

## Dependencies

Operations may have dependencies. The engine handles:
- **Checkpointing**: Auto-saves state before critical operations
- **Dependency ordering**: Ensures prerequisites run first
- **State tracking**: Records success/failure in SQLite database
- **Resume capability**: Continue from failure point

## Examples

### Example 1: Deploy full networking stack
```bash
source core/config-manager.sh && load_config

# Create resource group
./core/engine.sh run management-resource-group-create

# Create VNet
./core/engine.sh run networking-create-vnet

# Create subnets
./core/engine.sh run networking-create-subnet

# Create NSG
./core/engine.sh run networking-create-nsg

# Attach NSG to subnet
./core/engine.sh run networking-nsg-attach

# Validate
./core/engine.sh run networking-validate
```

### Example 2: Deploy storage with private endpoint
```bash
source core/config-manager.sh && load_config

# Create storage account
./core/engine.sh run storage-create-account

# Create file share
./core/engine.sh run storage-create-fileshare

# Disable public access
./core/engine.sh run storage-disable-public-access

# Create private DNS zone
./core/engine.sh run storage-private-dns-zone-create

# Create private endpoint
./core/engine.sh run storage-private-endpoint-create
```

### Example 3: Create golden image VM
```bash
source core/config-manager.sh && load_config

# Create VM
./core/engine.sh run compute-create-vm

# Start VM
./core/engine.sh run compute-vm-start

# Validate VM is ready
./core/engine.sh run compute-golden-image-validate-vm-ready

# Install applications
./core/engine.sh run compute-golden-image-install-apps

# Install Office
./core/engine.sh run compute-golden-image-install-office

# Configure profile
./core/engine.sh run compute-golden-image-configure-profile

# Validate
./core/engine.sh run compute-golden-image-validate
```

### Example 4: Deploy AVD environment
```bash
source core/config-manager.sh && load_config

# Create host pool
./core/engine.sh run avd-hostpool-create

# Create workspace
./core/engine.sh run avd-workspace-create

# Create app group
./core/engine.sh run avd-appgroup-create

# Associate workspace
./core/engine.sh run avd-workspace-associate

# Add session host
./core/engine.sh run avd-sessionhost-add

# Configure autoscaling
./core/engine.sh run avd-autoscaling-create-plan
```

## Handling Failures

If an operation fails:

```bash
# Engine auto-creates checkpoint
./core/engine.sh resume

# If resume doesn't work, check logs
tail -f artifacts/logs/deployment_*.jsonl | grep -i error

# Query state database for details
sqlite3 state.db "SELECT operation_id, error_message FROM operations WHERE status = 'FAILED' ORDER BY timestamp DESC LIMIT 1"
```

## Next Steps

For detailed guidance:
- **Operation creation**: `docs/capability-system/12a-best-practices-part1.md`
- **Executor overview**: `docs/guides/executor-overview.md`
- **Remote execution**: `docs/features/remote-execution-part1.md`
- **Azure CLI reference**: `docs/reference/azure-cli-core.md`

## Related Skills

- **azure-state-query**: Check current Azure infrastructure state
- **azure-troubleshooting**: Debug and fix deployment failures
