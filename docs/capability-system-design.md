---
title: "Capability System Design"
description: "Complete reference guide for the capability-based Azure CLI operation architecture"
tags: ["architecture", "operations", "capabilities", "design", "reference"]
last_updated: "2025-12-06"
---

# Capability System Design

**Complete reference guide for the capability-based Azure CLI operation system**

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Capability Domains](#capability-domains)
3. [Operation Schema Reference](#operation-schema-reference)
4. [Operation Lifecycle](#operation-lifecycle)
5. [Parameter System](#parameter-system)
6. [Idempotency Pattern](#idempotency-pattern)
7. [Validation Framework](#validation-framework)
8. [Rollback Procedures](#rollback-procedures)
9. [Self-Healing System](#self-healing-system)
10. [Operation Examples](#operation-examples)
11. [Migration Guide](#migration-guide)
12. [Best Practices](#best-practices)
13. [Dependency Management](#dependency-management)

---

## Architecture Overview

### Capability-Based Organization Concept

The Azure CLI deployment engine uses a **capability-based architecture** to organize and discover operations. Instead of numbering modules sequentially (01-networking, 02-storage, etc.), operations are grouped into logical capability domains that represent distinct areas of Azure infrastructure management.

```
OLD: Module-Based Structure          NEW: Capability-Based Structure
├── 01-networking/                   ├── capabilities/
├── 02-storage/                      │   ├── networking/
├── 03-entra-group/                  │   │   ├── operations/
├── 04-host-pool/                    │   │   │   ├── vnet-create.yaml
├── 05-compute/                      │   │   │   ├── subnet-create.yaml
└── ...                              │   │   │   └── nsg-create.yaml
                                     │   ├── storage/
                                     │   ├── identity/
                                     │   ├── compute/
                                     │   ├── avd/
                                     │   └── management/
```

### Migration Rationale

**Why Capabilities Over Modules:**

1. **Discoverability** - Operations are grouped by domain, not execution order
2. **Reusability** - Operations can be composed from any capability without coupling
3. **Composability** - Multiple capabilities can be mixed in a single deployment
4. **Scalability** - New operations fit naturally into existing domains
5. **Clarity** - Self-documenting structure reflects Azure resource types

### Benefits

| Aspect | Module-Based | Capability-Based |
|--------|-------------|-----------------|
| Discovery | By number/sequence | By domain/function |
| Reusability | Tightly coupled | Loosely coupled |
| Organization | Execution order | Logical domains |
| Metadata | Minimal | Rich (type, mode, validation) |
| Idempotency | Inline checks | Formal specification |
| Self-healing | Not tracked | Documented fixes |

---

## Capability Domains

### Overview

Seven capability domains organize all Azure operations:

| Capability | Operations | Description | Key Operations |
|-----------|------------|-------------|-----------------|
| **networking** | 23 | Virtual networks, subnets, NSGs, DNS, VPN, peering | vnet-create, nsg-create, vpn-gateway-create |
| **storage** | 9 | Storage accounts, file shares, blobs, private endpoints | account-create, fileshare-create, private-endpoint-create |
| **identity** | 18 | Entra ID groups, RBAC, service principals, SSO | group-create, rbac-assign, service-principal-create |
| **compute** | 17 | VMs, disks, images, golden image preparation | vm-create, image-create, golden-image-install-* |
| **avd** | 15 | Host pools, workspaces, app groups, autoscaling | hostpool-create, appgroup-create, scaling-plan-create |
| **management** | 2 | Resource groups, validation | resource-group-create, resource-group-validate |
| **test-capability** | 1 | Testing framework | test-operation |

**Total: 85 operations**

### Capability Domain Details

#### Networking (23 operations)
Core network infrastructure for Azure deployments.

**Core Resources:**
- VNets and subnets (vnet-create, subnet-create)
- Network security (nsg-create, nsg-attach, nsg-rule-add)
- Public connectivity (public-ip-create, load-balancer-create)
- DNS and routing (dns-zone-create, route-table-create, vnet-peering-create)
- VPN and gateways (vpn-gateway-create, vpn-connection-create, local-network-gateway-create)
- Advanced features (service-endpoint-configure, vnet-adopt)

**Relationships:**
- VNets contain subnets
- Subnets attach to NSGs
- Route tables configure routing
- DNS zones link to VNets
- VPN gateways enable connectivity

#### Storage (9 operations)
Persistent storage and file sharing infrastructure.

**Core Resources:**
- Storage accounts (account-create, account-configure, account-delete)
- File shares (fileshare-create, blob-container-create)
- Security (private-endpoint-create, public-access-disable)
- DNS and validation (private-dns-zone-create, private-links-validate)

**Relationships:**
- Storage accounts contain file shares and blob containers
- Private endpoints connect storage to VNets
- Private DNS zones resolve storage endpoints
- RBAC controls access to storage

#### Identity (18 operations)
Azure Entra ID (formerly Azure AD) and access control.

**Core Resources:**
- Groups (group-create, group-delete, group-member-add)
- Service principals (service-principal-create, managed-identity-create)
- RBAC assignments (rbac-assign, storage-rbac-assign, vm-login-rbac-assign, appgroup-rbac-assign)
- Special groups (fslogix-group-create, network-group-create, security-group-create)
- Validation (groups-validate, rbac-assignments-verify)
- SSO (sso-service-principal-configure)

**Relationships:**
- Groups contain user members
- Service principals have role assignments
- RBAC assignments grant permissions
- Groups are assigned to AVD app groups

#### Compute (17 operations)
Virtual machines and image management.

**Core Resources:**
- VMs (vm-create, vm-configure, vm-validate, vm-start)
- Disks and storage (disk-create, availability-set-create)
- Images (image-create, vm-extension-add)
- Golden image pipeline (9 operations for preparation, validation)

**Relationships:**
- VMs created from images
- VMs attached to subnets
- Availability sets group VMs
- Golden image VMs become reusable images
- Images used to create AVD session hosts

#### AVD (15 operations)
Azure Virtual Desktop deployment and management.

**Core Resources:**
- Host pools (hostpool-create, hostpool-update)
- Workspaces (workspace-create, workspace-associate)
- App groups (appgroup-create, application-add)
- Session hosts (sessionhost-add, sessionhost-drain, sessionhost-remove)
- Scaling (autoscaling-assign-rbac, autoscaling-create-plan, autoscaling-verify-configuration, scaling-plan-create)
- Configuration (sso-hostpool-configure, sso-configuration-verify)

**Relationships:**
- Host pools contain session hosts
- Workspaces associate to app groups
- App groups assign applications
- Session hosts are created from compute VMs
- Scaling plans automate capacity management

#### Management (2 operations)
Azure resource governance and validation.

**Core Resources:**
- Resource groups (resource-group-create, resource-group-validate)

**Relationships:**
- Resource groups contain all Azure resources
- Typically created first in deployment sequence
- Used throughout for resource scoping

---

## Operation Schema Reference

### Complete Schema Structure

Every operation defines a YAML document with this structure:

```yaml
operation:
  # Identity and metadata
  id: string                          # Unique operation ID (kebab-case)
  name: string                        # Human-readable name
  description: string                 # Detailed operation description

  # Classification
  capability: string                  # Domain: networking|storage|identity|compute|avd|management
  operation_mode: string              # CRUD: create|read|update|delete|configure|validate
  resource_type: string               # Azure ARM resource type (Microsoft.Network/virtualNetworks)

  # Duration and timeout
  duration:
    expected: integer                 # Expected execution time (seconds)
    timeout: integer                  # Maximum allowed time (seconds)
    type: string                      # FAST (<5min) | NORMAL (5-10min) | WAIT (10+min)

  # Parameters
  parameters:
    required: [...]                   # Must be provided by user
    optional: [...]                   # Optional with defaults

  # Pre and post execution
  prerequisites:
    operations: [...]                 # Required prior operations
    resources: [...]                  # Required existing resources

  # Idempotency
  idempotency:
    enabled: boolean                  # Whether idempotency is checked
    check_command: string             # Command to verify existence
    skip_if_exists: boolean           # Skip if resource exists

  # Execution template
  template:
    type: string                      # powershell-local|powershell-remote|bash-local
    command: string                   # Full script/command

  # Validation after execution
  validation:
    enabled: boolean
    checks: [...]                     # Post-execution verification checks

  # Rollback on failure
  rollback:
    enabled: boolean
    steps: [...]                      # Cleanup procedures

  # Self-healing
  fixes: [...]                        # Applied fixes with timestamps
```

### Field Details

#### Identity and Metadata

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | Yes | Unique operation identifier (kebab-case, e.g., "vnet-create") |
| `name` | string | Yes | Human-readable operation name |
| `description` | string | Yes | Detailed operation description (2-3 sentences) |

#### Classification

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `capability` | string | Yes | Domain: `networking`, `storage`, `identity`, `compute`, `avd`, `management`, `test-capability` |
| `operation_mode` | string | Yes | Operation type: `create`, `read`, `update`, `delete`, `configure`, `validate` |
| `resource_type` | string | Yes | Azure ARM resource type (e.g., "Microsoft.Network/virtualNetworks") |

**Valid operation_mode Values:**

```
- create:    Create new resource
- read:      Query/retrieve resource information
- update:    Modify existing resource
- delete:    Remove resource
- configure: Configure/customize resource
- validate:  Verify resource state/configuration
```

#### Duration

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `duration.expected` | integer | Yes | Expected execution time in seconds |
| `duration.timeout` | integer | Yes | Maximum allowed time in seconds |
| `duration.type` | string | Yes | Duration category: `FAST`, `NORMAL`, or `WAIT` |

**Duration Type Guidelines:**

```
FAST   <  5 minutes   (e.g., group creation, NSG rules)
NORMAL 5-10 minutes   (e.g., storage account, DNS zone)
WAIT   > 10 minutes   (e.g., VM creation, VPN gateway)
```

#### Parameters

Parameters are split into required and optional:

```yaml
parameters:
  required:
    - name: "vnet_name"
      type: "string"
      description: "Name of the virtual network"
      default: "{{NETWORKING_VNET_NAME}}"

  optional:
    - name: "dns_servers"
      type: "string"
      description: "Custom DNS servers (space-separated)"
      default: "{{NETWORKING_DNS_SERVERS}}"
      sensitive: false              # Set true for passwords/secrets
```

**Parameter Types:**

```
string      - Text values (e.g., names, IDs, paths)
integer     - Numeric values (e.g., port numbers, session limits)
boolean     - True/false values (e.g., enable_encryption)
array       - List values (e.g., multiple addresses)
```

**Parameter Features:**

- `default` - Default value (supports {{PLACEHOLDER}} syntax)
- `sensitive` - If true, value is masked in logs (passwords, secrets)
- `validation_regex` - Optional regex pattern for validation
- `validation_enum` - Optional list of allowed values

#### Idempotency

```yaml
idempotency:
  enabled: true
  check_command: |
    az network vnet show \
      --resource-group "{{AZURE_RESOURCE_GROUP}}" \
      --name "{{NETWORKING_VNET_NAME}}" \
      --output none 2>/dev/null
  skip_if_exists: true
```

**Fields:**

| Field | Type | Purpose |
|-------|------|---------|
| `enabled` | boolean | Whether to check for existing resource |
| `check_command` | string | Command that returns 0 if exists, non-zero if missing |
| `skip_if_exists` | boolean | Skip execution if resource already exists |

#### Template

```yaml
template:
  type: "powershell-local"
  command: |
    # Full PowerShell script with variable substitution
    $vnetName = "{{NETWORKING_VNET_NAME}}"
    # ... rest of script
```

**Valid template types:**

```
powershell-local   - PowerShell script on local machine
powershell-remote  - PowerShell script on Azure VM
bash-local         - Bash script on local machine
```

#### Validation Checks

```yaml
validation:
  enabled: true
  checks:
    - type: "resource_exists"
      resource_type: "Microsoft.Network/virtualNetworks"
      resource_name: "{{NETWORKING_VNET_NAME}}"
      description: "VNet exists"

    - type: "provisioning_state"
      expected: "Succeeded"
      description: "VNet provisioned successfully"
```

**Check Types:**

| Type | Purpose | Parameters |
|------|---------|-----------|
| `resource_exists` | Verify resource exists in Azure | `resource_type`, `resource_name` |
| `provisioning_state` | Verify provisioning state | `expected` (usually "Succeeded") |
| `property_equals` | Verify property value | `property`, `expected` |
| `group_exists` | Verify Entra ID group | `group_name` |
| `group_type` | Verify group type | `expected` (e.g., "Security") |
| Custom command | Execute custom verification | `command` returns 0 for success |

#### Rollback Steps

```yaml
rollback:
  enabled: true
  steps:
    - name: "Delete Virtual Network"
      description: "Remove the VNet and associated resources"
      command: |
        az network vnet delete \
          --resource-group "{{AZURE_RESOURCE_GROUP}}" \
          --name "{{NETWORKING_VNET_NAME}}" \
          --yes
      continue_on_error: false
```

**Step Fields:**

| Field | Type | Purpose |
|-------|------|---------|
| `name` | string | Step identifier |
| `description` | string | Step description |
| `command` | string | Command to execute |
| `continue_on_error` | boolean | Continue even if command fails |

---

## Operation Lifecycle

### Complete Execution Flow

```
1. DISCOVERY
   ├─ Engine scans capabilities/{capability}/operations/
   ├─ Loads operation YAML
   └─ Validates schema
        │
        ↓
2. VALIDATION
   ├─ Check all parameters provided
   ├─ Validate parameter types
   ├─ Verify {{PLACEHOLDER}} substitution
   └─ Check prerequisites satisfied
        │
        ↓
3. IDEMPOTENCY CHECK
   ├─ Run check_command
   ├─ If exits with 0: resource exists
   └─ If skip_if_exists=true: skip execution
        │
        ↓
4. EXECUTION
   ├─ Substitute all {{PLACEHOLDERS}}
   ├─ Write script to temp file
   ├─ Execute template command
   ├─ Monitor duration (fail if timeout)
   └─ Capture output and errors
        │
        ↓
5. VALIDATION CHECKS
   ├─ Run each validation check
   ├─ Verify expected states
   ├─ Store results in artifacts
   └─ Fail if critical checks fail
        │
        ↓
6. STATE TRACKING
   ├─ Log execution results
   ├─ Record timestamps
   ├─ Store artifact outputs
   └─ Update state.json
        │
        ↓
7. ROLLBACK (on failure)
   ├─ Execute rollback steps in order
   ├─ Respect continue_on_error flags
   └─ Log rollback results
        │
        ↓
8. SELF-HEALING (if applicable)
   ├─ Apply recorded fixes
   ├─ Retry up to 3 times
   ├─ Track fix history
   └─ Log healing outcomes
```

### ASCII Flow Diagram

```
┌─────────────────────────────────────────┐
│ Engine discovers operation              │
│ capabilities/compute/operations/vm.yaml │
└────────────┬────────────────────────────┘
             │
             ↓
      ┌──────────────────┐
      │ Load & validate  │
      │ schema           │
      └────────┬─────────┘
               │
             ┌─┴──────────────────────┐
             │ Parameters OK?         │
             └─┬──────────────────────┘
               │
      ┌────────↓─────────┐
      │ Run idempotency  │
      │ check_command    │
      └────────┬─────────┘
               │
         ┌─────┴──────┐
      YES│            │NO
         │            │
    Skip ↓         ┌──↓──────────────┐
         │         │ Substitute      │
         │         │ {{PLACEHOLDERS}}│
         │         └────────┬────────┘
         │                  │
         │              ┌───↓────────────┐
         │              │ Execute script │
         │              │ w/ timeout     │
         │              └────────┬───────┘
         │                       │
         │                  ┌────↓─────────┐
         │                  │ Timeout?     │
         │                  └────┬─────┬───┘
         │                       │     │
         │                    YES│     │NO
         │                       │     │
         │                   Rollback  │
         │                       │  ┌──↓──────────────────┐
         │                       │  │ Run validation      │
         │                       │  │ checks              │
         │                       │  └───────┬─────────────┘
         │                       │          │
         │                       │   All OK?├──┐
         │                       │      │    │  │NO
         │                       │      ↓    │  │
         ├───────────────────────┴─→ Update   │  │
         │                      state.json   │  │
         │                                   ↓  │
         │                           Apply fixes│
         │                            (self-heal)
         │                                   │
         ↓                                   ↓
      SUCCESS                            RETRY
                                      (max 3 times)
                                           │
                                     ┌─────┴─────┐
                                     │ All retry?│
                                     └──┬────┬───┘
                                   YES│    │NO
                                      │    │
                                  Continue
                                      │
                                      ↓
                                    FAIL
```

---

## Parameter System

### Required vs Optional Parameters

**Required Parameters:**
- Must be provided for operation to run
- Typically include: resource names, resource groups, locations
- Can have defaults from `config.yaml` via `{{PLACEHOLDER}}` syntax

**Optional Parameters:**
- May be omitted (uses default value)
- Provide customization or advanced configuration
- Examples: custom tags, security settings, performance tuning

### Parameter Types

#### String Parameters

```yaml
- name: "vnet_name"
  type: "string"
  description: "Name of the virtual network"
  default: "{{NETWORKING_VNET_NAME}}"
```

Usage in PowerShell:
```powershell
$vnetName = "{{NETWORKING_VNET_NAME}}"
az network vnet create --name $vnetName ...
```

#### Integer Parameters

```yaml
- name: "max_sessions"
  type: "integer"
  description: "Maximum sessions per host"
  default: 10
```

Usage in PowerShell:
```powershell
$maxSessions = 10
az desktopvirtualization hostpool create --max-session-limit $maxSessions ...
```

#### Boolean Parameters

```yaml
- name: "enable_secure_boot"
  type: "boolean"
  description: "Enable Secure Boot"
  default: true
```

Usage in PowerShell:
```powershell
if ($enableSecureBoot) {
    $securityType = "TrustedLaunch"
}
```

#### Array Parameters

```yaml
- name: "address_space"
  type: "string"
  description: "Address space (space-separated)"
  default: "10.0.0.0/16 10.1.0.0/16"
```

Usage in PowerShell:
```powershell
$addressPrefixArray = "{{NETWORKING_VNET_ADDRESS_SPACE}}".Split(' ')
az network vnet create --address-prefixes @addressPrefixArray ...
```

### Placeholder Syntax

**Format:** `{{VARIABLE_NAME}}`

**Substitution Rules:**
1. Placeholders are replaced at execution time
2. Derived from `config.yaml` variables
3. Case-sensitive (e.g., `{{VNET_NAME}}` ≠ `{{vnet_name}}`)
4. Supports nested paths: `{{PATH.TO.VALUE}}`

**Example from config.yaml:**
```yaml
networking:
  vnet:
    name: "avd-vnet-prod"
    address_space: ["10.0.0.0/16"]
    dns_servers: ["8.8.8.8", "8.8.4.4"]
```

**Placeholder mapping (environment variable format):**
```
{{NETWORKING_VNET_NAME}}           → networking.vnet.name
{{NETWORKING_VNET_ADDRESS_SPACE}}  → networking.vnet.address_space
{{NETWORKING_DNS_SERVERS}}         → networking.vnet.dns_servers
```

### Variable Substitution Examples

**String substitution:**
```powershell
$vnetName = "{{NETWORKING_VNET_NAME}}"
# Result: $vnetName = "avd-vnet-prod"
```

**Multiple placeholders:**
```bash
az network vnet create \
  --resource-group "{{AZURE_RESOURCE_GROUP}}" \
  --name "{{NETWORKING_VNET_NAME}}" \
  --location "{{AZURE_LOCATION}}"
```

**Conditional substitution:**
```powershell
if (-not [string]::IsNullOrEmpty("{{CUSTOM_DNS_SERVERS}}")) {
    $dnsServers = "{{CUSTOM_DNS_SERVERS}}"
}
```

**Array expansion:**
```powershell
$addresses = @(yq e '.networking.vnet.address_space | join(" ")' config.yaml)
$addressArray = $addresses -split ' '
az network vnet create --address-prefixes @addressArray ...
```

---

## Idempotency Pattern

### Purpose and Benefits

**Purpose:** Ensure operations are safe to run multiple times with same parameters

**Benefits:**
1. **Safety** - Can safely retry failed operations
2. **Resumability** - Resume interrupted deployments
3. **Replayability** - Replay operations in same environment
4. **Automation** - Automated remediation without manual checks
5. **Peace of mind** - No accidental duplicate resources

### Check Command Execution

The `check_command` determines if resource already exists:

```yaml
idempotency:
  enabled: true
  check_command: |
    az network vnet show \
      --resource-group "{{AZURE_RESOURCE_GROUP}}" \
      --name "{{NETWORKING_VNET_NAME}}" \
      --output none 2>/dev/null
  skip_if_exists: true
```

**Execution Logic:**

```bash
# Run check command
check_command...

# Check exit code
if [ $? -eq 0 ]; then
    # Resource exists (exit code 0)
    if [ skip_if_exists = true ]; then
        echo "[INFO] Resource already exists, skipping"
        exit 0  # Success
    fi
else
    # Resource doesn't exist (exit code non-zero)
    # Proceed with creation
fi
```

### skip_if_exists Behavior

**When `skip_if_exists: true`:**
- If check_command succeeds → skip operation, return success
- If check_command fails → proceed with creation

**When `skip_if_exists: false`:**
- If check_command succeeds → proceed anyway (for updates)
- If check_command fails → operation will likely fail

### Real Operation Examples

#### Example 1: VNet Creation (Create Only)

```yaml
idempotency:
  enabled: true
  check_command: |
    az network vnet show \
      --resource-group "{{AZURE_RESOURCE_GROUP}}" \
      --name "{{NETWORKING_VNET_NAME}}" \
      --output none 2>/dev/null
  skip_if_exists: true
```

**Behavior:** If VNet exists, skip creation. If missing, create it.

#### Example 2: Storage Account (Create with Config)

```yaml
idempotency:
  enabled: true
  check_command: |
    az storage account show \
      --resource-group "{{AZURE_RESOURCE_GROUP}}" \
      --name "{{STORAGE_ACCOUNT_NAME}}" \
      --output none 2>/dev/null
  skip_if_exists: true
```

**Behavior:** Check if storage account exists before attempting creation.

#### Example 3: Entra ID Group (Idempotent Creation)

```yaml
idempotency:
  enabled: true
  check_command: |
    az ad group list \
      --filter "displayName eq '{{ENTRA_GROUP_USERS_STANDARD}}'" \
      --query "[0].id" -o tsv 2>/dev/null
  skip_if_exists: true
```

**Behavior:** Query groups and skip if already exists.

---

## Validation Framework

### Validation Check Types

Validation checks run **after** successful operation execution to verify results.

#### Type: resource_exists

Verifies Azure resource was created:

```yaml
- type: "resource_exists"
  resource_type: "Microsoft.Network/virtualNetworks"
  resource_name: "{{NETWORKING_VNET_NAME}}"
  description: "VNet exists"
```

**Command Generated:**
```bash
az resource show \
  --resource-type "Microsoft.Network/virtualNetworks" \
  --name "{{NETWORKING_VNET_NAME}}" \
  --output none
```

#### Type: provisioning_state

Verifies resource provisioning completed:

```yaml
- type: "provisioning_state"
  expected: "Succeeded"
  description: "VNet provisioned successfully"
```

**Execution:**
```bash
az resource show \
  --query "provisioningState" -o tsv
# Expected: "Succeeded"
```

#### Type: property_equals

Verifies specific property value:

```yaml
- type: "property_equals"
  property: "sku.name"
  expected: "Premium_LRS"
  description: "Storage SKU is Premium_LRS"
```

**Execution:**
```bash
az storage account show \
  --query "sku.name" -o tsv
# Expected: "Premium_LRS"
```

#### Type: group_exists

Verifies Entra ID group:

```yaml
- type: "group_exists"
  group_name: "{{ENTRA_GROUP_USERS_STANDARD}}"
  description: "Users group exists"
```

**Execution:**
```bash
az ad group show \
  --group "{{ENTRA_GROUP_USERS_STANDARD}}" \
  --output none
```

#### Type: group_type

Verifies group type (Security vs Microsoft 365):

```yaml
- type: "group_type"
  expected: "Security"
  description: "Group is a security group"
```

#### Custom Command Check

Execute arbitrary command:

```yaml
- type: "custom"
  command: |
    $count = az vm list --query "length([])" -o tsv
    if [ "$count" -gt 0 ]; then exit 0; else exit 1; fi
  description: "At least one VM exists"
```

### Post-Execution Verification

**Verification Sequence:**

```
1. Operation script completes
   ↓
2. Check if script exit code = 0
   ├─ Yes → Proceed to validation checks
   └─ No → Operation failed, rollback
   ↓
3. Run each validation check in order
   ├─ All pass → Operation succeeded
   ├─ Some fail → Check if critical
   │   ├─ Critical → Rollback
   │   └─ Warning → Continue with notification
   └─ Check if should apply fixes
   ↓
4. If fixes available, attempt self-healing
   └─ Retry validation checks
```

### Validation Examples

#### Network Resource Validation

```yaml
validation:
  enabled: true
  checks:
    - type: "resource_exists"
      resource_type: "Microsoft.Network/virtualNetworks"
      resource_name: "{{NETWORKING_VNET_NAME}}"
      description: "VNet exists"

    - type: "provisioning_state"
      expected: "Succeeded"
      description: "VNet provisioned successfully"

    - type: "property_equals"
      property: "addressSpace.addressPrefixes[0]"
      expected: "10.0.0.0/16"
      description: "Address space configured correctly"
```

#### Identity Resource Validation

```yaml
validation:
  enabled: true
  checks:
    - type: "group_exists"
      group_name: "{{ENTRA_GROUP_USERS_STANDARD}}"
      description: "Users group exists"

    - type: "group_type"
      expected: "Security"
      description: "Group is security-enabled"
```

---

## Rollback Procedures

### Purpose and Use Cases

**Purpose:** Automatically clean up resources if operation fails

**Use Cases:**
1. **Partial failures** - Created some resources but failed midway
2. **Timeout failures** - Resource created but didn't validate
3. **Configuration errors** - Created with wrong parameters
4. **Integration failures** - Resource created but can't integrate with others

### Rollback Step Structure

```yaml
rollback:
  enabled: true
  steps:
    - name: "Delete Virtual Network"
      description: "Remove the VNet and associated resources"
      command: |
        az network vnet delete \
          --resource-group "{{AZURE_RESOURCE_GROUP}}" \
          --name "{{NETWORKING_VNET_NAME}}" \
          --yes
      continue_on_error: false

    - name: "Remove DNS records"
      description: "Clean up associated DNS records"
      command: |
        az network dns zone delete \
          --resource-group "{{AZURE_RESOURCE_GROUP}}" \
          --name "{{DNS_ZONE_NAME}}" \
          --yes
      continue_on_error: true
```

### continue_on_error Flag

**`continue_on_error: false`** (CRITICAL)
- If step fails, stop rollback immediately
- Used for essential cleanup steps
- Example: Deleting main resource

**`continue_on_error: true`** (OPTIONAL)
- If step fails, continue to next step
- Used for secondary cleanup
- Example: Removing DNS records, updating documentation

### Step Execution Order

Rollback steps execute **sequentially** in order defined:

```
Step 1 (Delete main resource)
   ↓ (if succeeds or continue_on_error=true)
Step 2 (Remove associated resources)
   ↓ (if succeeds or continue_on_error=true)
Step 3 (Update metadata)
   ↓
Rollback complete
```

### Rollback Examples

#### VNet Deletion Rollback

```yaml
rollback:
  enabled: true
  steps:
    - name: "Delete Virtual Network"
      description: "Remove the VNet and all associated resources"
      command: |
        az network vnet delete \
          --resource-group "{{AZURE_RESOURCE_GROUP}}" \
          --name "{{NETWORKING_VNET_NAME}}" \
          --yes
      continue_on_error: false
```

#### Storage Account Rollback (Multi-step)

```yaml
rollback:
  enabled: true
  steps:
    - name: "Delete File Shares"
      description: "Remove all file shares from storage account"
      command: |
        az storage share delete \
          --account-name "{{STORAGE_ACCOUNT_NAME}}" \
          --name "{{STORAGE_SHARE_NAME}}"
      continue_on_error: true

    - name: "Delete Storage Account"
      description: "Remove the storage account"
      command: |
        az storage account delete \
          --resource-group "{{AZURE_RESOURCE_GROUP}}" \
          --name "{{STORAGE_ACCOUNT_NAME}}" \
          --yes
      continue_on_error: false
```

#### Complex Rollback (AVD Host Pool)

```yaml
rollback:
  enabled: true
  steps:
    - name: "Remove Session Hosts"
      description: "Delete all session hosts from host pool"
      command: |
        az desktopvirtualization hostpool update \
          --resource-group "{{AZURE_RESOURCE_GROUP}}" \
          --name "{{HOST_POOL_NAME}}" \
          --status Unavailable
      continue_on_error: true

    - name: "Delete Application Groups"
      description: "Remove application groups"
      command: |
        az desktopvirtualization applicationgroup delete \
          --resource-group "{{AZURE_RESOURCE_GROUP}}" \
          --name "{{APP_GROUP_NAME}}" \
          --yes
      continue_on_error: true

    - name: "Delete Host Pool"
      description: "Remove the host pool itself"
      command: |
        az desktopvirtualization hostpool delete \
          --resource-group "{{AZURE_RESOURCE_GROUP}}" \
          --name "{{HOST_POOL_NAME}}" \
          --yes
      continue_on_error: false
```

---

## Self-Healing System

### Purpose

Automatically detect and fix known issues without manual intervention.

**Goals:**
1. **Automation** - Reduce manual remediation
2. **Reliability** - Increase successful deployments
3. **Learning** - Track and fix common failures
4. **Transparency** - Document all applied fixes

### Fixes Array Structure

```yaml
fixes:
  - issue_code: "VNET_CREATION_TIMEOUT"
    description: "VNet creation timed out due to DNS resolution"
    applied_at: "2025-12-06T14:23:45Z"
    fix_command: |
      az network vnet update \
        --resource-group "{{AZURE_RESOURCE_GROUP}}" \
        --name "{{NETWORKING_VNET_NAME}}" \
        --set "dnsSetting.dnsServers=@['8.8.8.8','8.8.4.4']"
    retry_count: 2
    success: true

  - issue_code: "STORAGE_ACCOUNT_NAMING"
    description: "Storage account name didn't conform to Azure rules"
    applied_at: "2025-12-06T14:24:30Z"
    fix_command: |
      # Rename storage account (requires new account)
      az storage account create \
        --resource-group "{{AZURE_RESOURCE_GROUP}}" \
        --name "{{STORAGE_ACCOUNT_NAME}}-fixed" \
        --location "{{AZURE_LOCATION}}"
    retry_count: 1
    success: true
```

### Automated Correction Tracking

**When Fix Applied:**
1. Issue detected during operation
2. Matching fix found in `fixes` array
3. Fix command executed
4. Result recorded with timestamp
5. If successful, resume operation
6. If failed, add to retry queue

**Retry Policy:**
```
Max retries: 3 times
Backoff: exponential (1s, 2s, 4s)
Conditions to retry: transient errors only
```

### Historical Fix Log

**Location:** `artifacts/fixes/fix-history.json`

**Structure:**
```json
{
  "operations_healed": 45,
  "total_fixes_applied": 127,
  "fixes": [
    {
      "operation_id": "vnet-create",
      "issue_code": "VNET_TIMEOUT",
      "applied_at": "2025-12-06T14:23:45Z",
      "execution_time_ms": 2341,
      "success": true
    },
    {
      "operation_id": "storage-account-create",
      "issue_code": "STORAGE_NAME_INVALID",
      "applied_at": "2025-12-06T14:24:30Z",
      "execution_time_ms": 450,
      "success": false,
      "error": "Name still invalid after fix"
    }
  ]
}
```

### Self-Healing Examples

#### Example 1: Transient DNS Failure

```yaml
fixes:
  - issue_code: "DNS_RESOLUTION_FAILED"
    description: "DNS server temporarily unavailable"
    fix_command: |
      sleep 5  # Wait for DNS to recover
      retry_current_operation
    retry_count: 3
```

**When Applied:**
```
1. VNet creation fails: "DNS resolution timed out"
2. Issue code matches: DNS_RESOLUTION_FAILED
3. Fix applied: Wait 5 seconds
4. Operation retried
5. If succeeds: Continue
6. If fails again: Repeat up to 3 times
```

#### Example 2: Naming Policy Violation

```yaml
fixes:
  - issue_code: "NAME_POLICY_VIOLATION"
    description: "Resource name violates Azure naming policy"
    fix_command: |
      # Replace invalid characters
      FIXED_NAME="${{RESOURCE_NAME//-/_}}"
      # Retry with fixed name
      update_placeholder "RESOURCE_NAME" "$FIXED_NAME"
    retry_count: 1
```

#### Example 3: Quota Exceeded

```yaml
fixes:
  - issue_code: "QUOTA_EXCEEDED"
    description: "Subscription quota exceeded"
    fix_command: |
      # Log details for manual intervention
      echo "Quota exceeded for {{RESOURCE_TYPE}}"
      echo "Request increase: az vm list-usage --location {{AZURE_LOCATION}}"
    retry_count: 0
```

---

## Operation Examples

### Example 1: Networking - VNet Creation

**File:** `/mnt/cache_pool/development/azure-cli/capabilities/networking/operations/vnet-create.yaml`

**Key Features:**
- FAST operation (1 minute expected)
- Creates VNet with configurable address space
- Idempotent: checks if VNet exists
- Validation: provisioning state, resource existence
- Rollback: deletes VNet on failure

**Execution Flow:**
```
1. Check if VNet already exists
2. If yes: skip (idempotent)
3. If no: create with address space
4. Validate provisioning state = "Succeeded"
5. Store VNet ID in artifacts
```

### Example 2: Storage - Account Creation

**File:** `/mnt/cache_pool/development/azure-cli/capabilities/storage/operations/account-create.yaml`

**Key Features:**
- NORMAL operation (90 seconds expected)
- Premium FileStorage account (for FSLogix)
- Auto-generates account name if not provided
- TLS 1.2 minimum enforced
- Public access disabled by default

**Configuration:**
```yaml
sku: "Premium_LRS"
kind: "FileStorage"
min_tls_version: "TLS1_2"
allow_blob_public_access: false
https_only: true
```

### Example 3: Identity - Group Creation

**File:** `/mnt/cache_pool/development/azure-cli/capabilities/identity/operations/group-create.yaml`

**Key Features:**
- FAST operation (30 seconds)
- Creates Entra ID security group
- Mail nickname auto-derived from name
- Validation: group existence and type
- Rollback: deletes group on failure

**Idempotency Check:**
```bash
az ad group list \
  --filter "displayName eq 'GROUP_NAME'" \
  --query "[0].id" -o tsv
```

### Example 4: Compute - VM Creation

**File:** `/mnt/cache_pool/development/azure-cli/capabilities/compute/operations/vm-create.yaml`

**Key Features:**
- WAIT operation (7 minutes expected, 15 minute timeout)
- TrustedLaunch security by default
- Secure Boot and vTPM enabled
- Custom image support (publisher/offer/sku/version)
- Network interface configuration

**Security Settings:**
```yaml
security_type: "TrustedLaunch"
enable_secure_boot: true
enable_vtpm: true
```

### Example 5: AVD - Host Pool Creation

**File:** `/mnt/cache_pool/development/azure-cli/capabilities/avd/operations/hostpool-create.yaml`

**Key Features:**
- NORMAL operation (2 minutes)
- Configurable pool type (Pooled/Personal)
- Load balancer strategy (BreadthFirst/DepthFirst/Persistent)
- Session limit configuration
- Environmental tagging

**Configuration Options:**
```yaml
host_pool_type: "Pooled"
max_sessions: 8
load_balancer: "BreadthFirst"
environment: "Production"
```

---

## Migration Guide

### Step 1: Identify Legacy Operation

Find the old operation in `modules/` directory:

```bash
find modules/ -name "*create*" -type f
# Example: modules/01-networking/operations/01-create-vnet.yaml
```

### Step 2: Analyze PowerShell Script

Extract the PowerShell/bash script from the legacy operation:

```yaml
# Old format
operation:
  id: "01-create-vnet"
  script: |
    # PowerShell script here
```

### Step 3: Create New Capability Operation

Create new file in appropriate capability:

```bash
mkdir -p capabilities/CAPABILITY/operations/
touch capabilities/CAPABILITY/operations/OPERATION_NAME.yaml
```

**Capability mapping:**
```
01-networking        → capabilities/networking/
02-storage           → capabilities/storage/
03-entra-group       → capabilities/identity/
04-host-pool         → capabilities/avd/
05-golden-image      → capabilities/compute/
06-session-host      → capabilities/avd/
08-rbac              → capabilities/identity/
09-sso               → capabilities/identity/ + avd/
10-autoscaling       → capabilities/avd/
```

### Step 4: Map Schema Elements

**Old Operation → New Schema:**

```yaml
# OLD
operation:
  id: "01-create-vnet"
  name: "Create VNet"
  description: "..."
  script: "..."

# NEW
operation:
  id: "vnet-create"  # Remove numeric prefix
  name: "Create Virtual Network"
  description: "Create Azure VNet with configured address space"
  capability: "networking"
  operation_mode: "create"
  resource_type: "Microsoft.Network/virtualNetworks"
  # ... rest of new schema
```

### Step 5: Extract Parameters

Identify parameters from PowerShell script:

```powershell
# Look for variable assignments
$vnetName = "avd-vnet"
$resourceGroup = "RG-AVD"
$location = "centralus"
$addressSpace = "10.0.0.0/16"
```

Map to new parameters section:

```yaml
parameters:
  required:
    - name: "vnet_name"
      type: "string"
      description: "Name of the virtual network"
      default: "{{NETWORKING_VNET_NAME}}"
    - name: "resource_group"
      type: "string"
      description: "Azure resource group name"
      default: "{{AZURE_RESOURCE_GROUP}}"
  optional:
    - name: "address_space"
      type: "string"
      description: "Address space for the VNet"
      default: "{{NETWORKING_VNET_ADDRESS_SPACE}}"
```

### Step 6: Define Idempotency

Create check_command that detects existing resource:

```yaml
idempotency:
  enabled: true
  check_command: |
    az network vnet show \
      --resource-group "{{AZURE_RESOURCE_GROUP}}" \
      --name "{{NETWORKING_VNET_NAME}}" \
      --output none 2>/dev/null
  skip_if_exists: true
```

### Step 7: Add Validation Checks

Define post-execution validation:

```yaml
validation:
  enabled: true
  checks:
    - type: "resource_exists"
      resource_type: "Microsoft.Network/virtualNetworks"
      resource_name: "{{NETWORKING_VNET_NAME}}"
      description: "VNet exists"

    - type: "provisioning_state"
      expected: "Succeeded"
      description: "VNet provisioned successfully"
```

### Step 8: Define Rollback

Create cleanup steps:

```yaml
rollback:
  enabled: true
  steps:
    - name: "Delete Virtual Network"
      description: "Remove the VNet and associated resources"
      command: |
        az network vnet delete \
          --resource-group "{{AZURE_RESOURCE_GROUP}}" \
          --name "{{NETWORKING_VNET_NAME}}" \
          --yes
      continue_on_error: false
```

### Step 9: Preserve PowerShell Script

Copy original script into template section (100% preserved):

```yaml
template:
  type: "powershell-local"
  command: |
    cat > /tmp/networking-vnet-create-wrapper.ps1 << 'PSWRAPPER'
    # Original PowerShell script (unchanged)
    Write-Host "[START] VNet creation..."
    ...
    PSWRAPPER
    pwsh -NoProfile -NonInteractive -File /tmp/networking-vnet-create-wrapper.ps1
    rm -f /tmp/networking-vnet-create-wrapper.ps1
```

### Step 10: Test Migration

Validate the new operation:

```bash
# Check YAML syntax
yamllint capabilities/networking/operations/vnet-create.yaml

# Validate schema
# (engine will validate when executed)

# Compare with old operation
diff modules/01-networking/operations/01-create-vnet.yaml \
     capabilities/networking/operations/vnet-create.yaml
```

### Step 11: Commit Changes

Create git commit:

```bash
git add capabilities/networking/operations/vnet-create.yaml
git commit -m "Migrate: networking vnet-create operation to capability format"
```

### Migration Checklist

- [ ] Operation file created in correct capability
- [ ] ID uses kebab-case (no numeric prefixes)
- [ ] All required fields populated
- [ ] Parameters extracted and typed
- [ ] Idempotency check defined
- [ ] Validation checks specified
- [ ] Rollback procedures documented
- [ ] PowerShell script 100% preserved
- [ ] YAML syntax valid
- [ ] Placeholders use {{UPPERCASE}} format
- [ ] Duration/timeout realistic
- [ ] Description clear and concise
- [ ] Git commit message follows convention

### Common Pitfalls to Avoid

1. **Changing PowerShell Logic**
   - WRONG: Modifying or reformatting script
   - RIGHT: Copy script exactly as-is

2. **Hardcoding Values**
   - WRONG: `--name "avd-vnet"`
   - RIGHT: `--name "{{NETWORKING_VNET_NAME}}"`

3. **Wrong Capability Assignment**
   - Check resource type (Microsoft.Network/* → networking)
   - Some operations span capabilities (SSO in both identity and avd)

4. **Missing Idempotency**
   - Every create/update must have check_command
   - Ensures safe retry and resumption

5. **Incomplete Validation**
   - Minimum: resource_exists + provisioning_state
   - More: property_equals for critical settings

6. **Inadequate Rollback**
   - Must clean up all created resources
   - Use continue_on_error wisely

---

## Best Practices

### Operation Naming Conventions

**Kebab-Case IDs:**
```
✓ vnet-create
✓ storage-account-configure
✓ group-delete
✗ create_vnet (snake_case)
✗ CreateVnet (PascalCase)
✗ 01-vnet (numeric prefix)
```

**Semantic Names:**
```
✓ vnet-create (action-resource)
✓ public-access-disable (action-what)
✓ rbac-assign (action-what)
✗ operation-1 (meaningless)
✗ vnet-op (vague)
```

### Description Writing Guidelines

**Good Descriptions:**

```yaml
description: "Create Azure VNet with configured address space, optional DNS servers, and region-specific deployment"
# Clear, specific, mentions key parameters
```

**Poor Descriptions:**

```yaml
description: "Create VNet"
# Too vague, doesn't mention parameters or specifics
```

**Template:**
```
[ACTION] Azure [RESOURCE] [PURPOSE/SPECIFICS]

Examples:
- Create Azure VNet with configured address space and DNS servers
- Configure NSG rules for session host ingress/egress
- Assign RBAC roles for storage access and compute login
```

### Parameter Documentation Standards

**Complete Parameter Definition:**

```yaml
- name: "max_sessions"
  type: "integer"
  description: "Maximum concurrent sessions per session host (1-999)"
  default: 8
  validation_regex: "^[1-9][0-9]{0,2}$"
  validation_enum: null
  sensitive: false
```

**Required Field Rules:**

| Field | When Required | Notes |
|-------|---------------|-------|
| `name` | Always | Unique, snake_case |
| `type` | Always | string, integer, boolean, array |
| `description` | Always | Clear, mentions constraints |
| `default` | Always | Use {{PLACEHOLDER}} for dynamic values |
| `sensitive` | Required if true | Masks value in logs |
| `validation_regex` | If constrained | Optional validation pattern |

### Idempotency Check Design

**Design Principles:**

1. **Specificity** - Check for exact resource
   ```bash
   ✓ az network vnet show --name "{{VNET_NAME}}"
   ✗ az network vnet list  # Too broad
   ```

2. **Silent Failure** - Output redirected to /dev/null
   ```bash
   ✓ ... 2>/dev/null
   ✗ ... (error messages leak)
   ```

3. **Clean Exit Codes** - 0 for exists, non-zero for missing
   ```bash
   ✓ ... --output none (silent success)
   ✗ ... --output json (produces output)
   ```

4. **Timeout Consideration** - Should complete quickly
   ```bash
   ✓ Check single specific resource (~1-2 seconds)
   ✗ Enumerate all resources (may be slow)
   ```

### Validation Check Design

**Design Principles:**

1. **Critical vs Optional** - Fail only on critical
   ```yaml
   critical: true   # Must succeed
   critical: false  # Log warning but continue
   ```

2. **Clear Expectations** - Specific expected values
   ```yaml
   ✓ expected: "Succeeded"
   ✓ expected: "Premium_LRS"
   ✗ expected: "OK" (ambiguous)
   ```

3. **Meaningful Descriptions** - What does check verify?
   ```yaml
   ✓ description: "VNet provisioned successfully"
   ✗ description: "Check 1" (meaningless)
   ```

4. **Logical Order** - Existence before properties
   ```yaml
   1. resource_exists     # Does resource exist?
   2. provisioning_state  # Is it ready?
   3. property_equals     # Are settings correct?
   ```

### Rollback Procedure Design

**Design Principles:**

1. **Reverse Order** - Undo in opposite sequence
   ```yaml
   Create:
   1. Create VNet
   2. Create Subnet
   3. Create NSG

   Rollback:
   1. Delete NSG       # Reverse of step 3
   2. Delete Subnet    # Reverse of step 2
   3. Delete VNet      # Reverse of step 1
   ```

2. **Dependency Awareness** - Delete dependents first
   ```yaml
   ✓ Delete subnets before VNet
   ✗ Delete VNet first (subnets still attached)
   ```

3. **Error Tolerance** - Allow some failures
   ```yaml
   # Critical deletion
   continue_on_error: false

   # Optional cleanup
   continue_on_error: true
   ```

4. **Idempotent Rollback** - Safe to run multiple times
   ```yaml
   ✓ az network vnet delete ... --yes
   ✗ rm -rf / (destructive, non-idempotent)
   ```

---

## Dependency Management

### Using requires Field

Operations can specify dependencies on other operations:

```yaml
operation:
  id: "hostpool-create"
  requires:
    operations:
      - "resource-group-create"
      - "vnet-create"
      - "subnet-create"
    resources:
      - type: "Microsoft.Network/virtualNetworks"
        name: "{{NETWORKING_VNET_NAME}}"
```

**Interpretation:**
- `hostpool-create` cannot run until `resource-group-create` succeeds
- `vnet-create` must be complete before attempting host pool
- VNet resource must exist in Azure

### Dependency Chains

Logical execution chains emerge from requires:

```
resource-group-create
        ↓
    vnet-create
        ↓
    subnet-create → nsg-create
        ↓                ↓
    vm-create ←──────────┘
        ↓
    image-create
        ↓
    hostpool-create
        ↓
    appgroup-create
```

### Parallel Execution Groups

Independent operations can execute in parallel:

```
Parallel Group 1          Parallel Group 2
├─ storage-create         ├─ identity-groups
└─ dns-zone-create        └─ rbac-assign

(Both groups need resource-group-create first)
```

### Dependency Graph Examples

#### Simple Linear Chain

```
resource-group → vnet → subnet → nsg → vm → image
   (1)          (2)    (3)      (4)  (5)   (6)

Execution: 1→2→3→4→5→6 (sequential)
Duration: Sum of all timeouts
```

#### Branching Dependency

```
                    ┌─ storage-account (2a)
resource-group (1)  │
                    ├─ vnet (2b)
                    │
                    └─ identity-groups (2c)

Parallel: 2a, 2b, 2c all start after (1) completes
Duration: (1) + max((2a), (2b), (2c))
```

#### Complex Network

```
                  ┌─ subnet-1
                  │     ↓
vnet ──┬─ nsg ────┤─ subnet-2 ── vm-1
       │          │     ↓         ↓
       └─ dns ────┴─ subnet-3 ── vm-2

Dependencies:
- NSG, DNS parallel after VNet
- Subnets parallel after NSG
- VMs depend on VNet + NSG
- All depend on resource-group
```

### Dependency Resolution Algorithm

**Engine uses this to determine execution order:**

```
1. Start with requested operations
2. For each operation:
   a. Find all required operations
   b. Add missing dependencies to queue
   c. Mark as pending
3. Execute operations:
   a. Find operations with all dependencies met
   b. Execute in parallel if possible
   c. Mark as complete
   d. Repeat until all done
```

### Handling Dependency Failures

**When dependency fails:**

```
Scenario: vnet-create fails, subnet-create queued

Options:
A) FAIL FAST: Stop immediately, don't attempt subnet-create
B) CONTINUE: Log warning, attempt subnet-create (may also fail)
C) RETRY: Retry vnet-create N times, then fail/continue

Default: FAIL FAST (safest)
```

---

## Advanced Topics

### Remote PowerShell Execution

Some operations execute PowerShell on Azure VMs:

```yaml
template:
  type: "powershell-remote"
  command: |
    # This script runs ON the VM, not locally
    # Executed via: az vm run-command invoke

    Write-Host "Running on Azure VM"

    # Install software
    choco install vlc -y

    # Configure settings
    Set-ItemProperty -Path "..." -Value "..."
```

**Usage Pattern:**

```bash
# For VM customization (golden image)
az vm run-command invoke \
  --resource-group "{{RESOURCE_GROUP}}" \
  --vm-name "{{VM_NAME}}" \
  --command-id "RunPowerShellScript" \
  --scripts @script.ps1
```

### Handling Large PowerShell Scripts

Scripts larger than 10KB stored separately:

```
capabilities/compute/operations/
├── golden-image-install-apps.yaml
└── scripts/
    └── golden-image-install-apps.ps1
```

Operation references script:

```yaml
template:
  type: "powershell-remote"
  command: |
    # Load large script from file
    $scriptPath = "capabilities/compute/operations/scripts/golden-image-install-apps.ps1"
    & $scriptPath
```

### Custom Validation Commands

Complex validations using scripts:

```yaml
validation:
  enabled: true
  checks:
    - type: "custom"
      command: |
        # Complex validation logic
        $vmCount = az vm list \
          --resource-group "{{RESOURCE_GROUP}}" \
          --query "length([])" -o tsv

        if [ "$vmCount" -ge 1 ]; then
          exit 0  # Success
        else
          exit 1  # Failure
        fi
      description: "At least one VM exists in resource group"
```

### Environment-Specific Operations

Some operations behave differently per environment:

```yaml
operation:
  id: "vm-create"
  parameters:
    optional:
      - name: "environment"
        type: "string"
        description: "Environment: dev|staging|prod"
        default: "{{AZURE_ENVIRONMENT}}"

  template:
    type: "powershell-local"
    command: |
      if ("{{AZURE_ENVIRONMENT}}" -eq "prod") {
        # Production: TrustedLaunch, encryption
        $securityType = "TrustedLaunch"
      } else {
        # Dev: Standard, faster provisioning
        $securityType = "Standard"
      }
```

---

## Conclusion

The capability-based operation system provides a **structured, scalable, and maintainable** approach to Azure infrastructure automation. By organizing operations into logical capability domains, the system enables:

- **Discoverability** through domain-based organization
- **Reusability** via loose coupling and composition
- **Reliability** through formal idempotency and validation
- **Maintainability** with clear schemas and documentation
- **Automation** via self-healing and rollback procedures

### Key Takeaways

1. **Capabilities > Modules** - Domain-based organization scales better
2. **Schema > Scripts** - Formal structure enables tooling and automation
3. **Idempotency > Brittle Scripts** - Safe to retry and resume
4. **Validation > Assumptions** - Verify state, don't assume success
5. **Rollback > Manual Cleanup** - Automated error recovery

### Next Steps

- Review example operations in `capabilities/*/operations/`
- Use this guide as reference when creating new operations
- Follow best practices for consistency
- Leverage dependency management for complex deployments
- Enable self-healing for critical operations

---

**Document Last Updated:** 2025-12-06
**Capability System Version:** 1.0
**Total Operations:** 85 across 7 capabilities

