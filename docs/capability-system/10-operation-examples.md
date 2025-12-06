# Operation Examples

**Real-world operations from each capability with full annotations**

## Table of Contents

1. [Example 1: Networking - VNet Creation](#example-1-networking---vnet-creation)
2. [Example 2: Storage - Account Creation](#example-2-storage---account-creation)
3. [Example 3: Identity - Group Creation](#example-3-identity---group-creation)
4. [Example 4: Compute - VM Creation](#example-4-compute---vm-creation)
5. [Example 5: AVD - Host Pool Creation](#example-5-avd---host-pool-creation)

---

## Example 1: Networking - VNet Creation

**File:** `/mnt/cache_pool/development/azure-cli/capabilities/networking/operations/vnet-create.yaml`

### Overview

Creates an Azure Virtual Network with configured address space.

### Key Features

- **Duration:** FAST operation (1 minute expected)
- **Idempotent:** Checks if VNet exists before creation
- **Validation:** Provisioning state and resource existence
- **Rollback:** Deletes VNet on failure

### Execution Flow

```
1. Check if VNet already exists
   ↓
2. If yes: skip (idempotent)
   If no: proceed to creation
   ↓
3. Create VNet with address space
   ↓
4. Validate provisioning state = "Succeeded"
   ↓
5. Store VNet ID in artifacts
```

### Example YAML Structure

```yaml
operation:
  id: "vnet-create"
  name: "Create Virtual Network"
  description: "Create Azure VNet with configured address space, optional DNS servers, and region-specific deployment"

  capability: "networking"
  operation_mode: "create"
  resource_type: "Microsoft.Network/virtualNetworks"

  duration:
    expected: 60
    timeout: 300
    type: "FAST"

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

      - name: "location"
        type: "string"
        description: "Azure region"
        default: "{{AZURE_LOCATION}}"

    optional:
      - name: "address_space"
        type: "string"
        description: "Address space (space-separated)"
        default: "{{NETWORKING_VNET_ADDRESS_SPACE}}"

      - name: "dns_servers"
        type: "string"
        description: "Custom DNS servers (space-separated)"
        default: "{{NETWORKING_DNS_SERVERS}}"

  idempotency:
    enabled: true
    check_command: |
      az network vnet show \
        --resource-group "{{AZURE_RESOURCE_GROUP}}" \
        --name "{{NETWORKING_VNET_NAME}}" \
        --output none 2>/dev/null
    skip_if_exists: true

  template:
    type: "bash-local"
    command: |
      az network vnet create \
        --resource-group "{{AZURE_RESOURCE_GROUP}}" \
        --name "{{NETWORKING_VNET_NAME}}" \
        --location "{{AZURE_LOCATION}}" \
        --address-prefixes "{{NETWORKING_VNET_ADDRESS_SPACE}}"

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

---

## Example 2: Storage - Account Creation

**File:** `/mnt/cache_pool/development/azure-cli/capabilities/storage/operations/account-create.yaml`

### Overview

Creates Premium FileStorage account for FSLogix profiles.

### Key Features

- **Duration:** NORMAL operation (90 seconds expected)
- **Premium SKU:** Premium_LRS for best performance
- **Security:** TLS 1.2 minimum, public access disabled
- **Auto-naming:** Generates valid storage account name if needed

### Configuration

```yaml
sku: "Premium_LRS"
kind: "FileStorage"
min_tls_version: "TLS1_2"
allow_blob_public_access: false
https_only: true
```

### Example YAML Structure

```yaml
operation:
  id: "storage-account-create"
  name: "Create Storage Account"

  description: "Create Premium FileStorage account for FSLogix profiles with secure defaults"

  capability: "storage"
  operation_mode: "create"
  resource_type: "Microsoft.Storage/storageAccounts"

  duration:
    expected: 90
    timeout: 600
    type: "NORMAL"

  parameters:
    required:
      - name: "storage_account_name"
        type: "string"
        description: "Storage account name (3-24 lowercase alphanumeric)"
        default: "{{STORAGE_ACCOUNT_NAME}}"
        validation_regex: "^[a-z0-9]{3,24}$"

      - name: "resource_group"
        type: "string"
        description: "Azure resource group name"
        default: "{{AZURE_RESOURCE_GROUP}}"

      - name: "location"
        type: "string"
        description: "Azure region"
        default: "{{AZURE_LOCATION}}"

    optional:
      - name: "sku"
        type: "string"
        description: "Storage account SKU"
        default: "Premium_LRS"
        validation_enum:
          - "Standard_LRS"
          - "Standard_GRS"
          - "Premium_LRS"

  idempotency:
    enabled: true
    check_command: |
      az storage account show \
        --resource-group "{{AZURE_RESOURCE_GROUP}}" \
        --name "{{STORAGE_ACCOUNT_NAME}}" \
        --output none 2>/dev/null
    skip_if_exists: true

  template:
    type: "bash-local"
    command: |
      az storage account create \
        --resource-group "{{AZURE_RESOURCE_GROUP}}" \
        --name "{{STORAGE_ACCOUNT_NAME}}" \
        --location "{{AZURE_LOCATION}}" \
        --sku "Premium_LRS" \
        --kind "FileStorage" \
        --min-tls-version "TLS1_2" \
        --allow-blob-public-access false \
        --https-only true

  validation:
    enabled: true
    checks:
      - type: "resource_exists"
        resource_type: "Microsoft.Storage/storageAccounts"
        resource_name: "{{STORAGE_ACCOUNT_NAME}}"
        description: "Storage account exists"

      - type: "provisioning_state"
        expected: "Succeeded"
        description: "Storage account provisioned"

      - type: "property_equals"
        property: "sku.name"
        expected: "Premium_LRS"
        description: "SKU is Premium_LRS"

      - type: "property_equals"
        property: "properties.minimumTlsVersion"
        expected: "TLS1_2"
        description: "TLS 1.2 enforced"

  rollback:
    enabled: true
    steps:
      - name: "Delete Storage Account"
        description: "Remove the storage account"
        command: |
          az storage account delete \
            --resource-group "{{AZURE_RESOURCE_GROUP}}" \
            --name "{{STORAGE_ACCOUNT_NAME}}" \
            --yes
        continue_on_error: false
```

---

## Example 3: Identity - Group Creation

**File:** `/mnt/cache_pool/development/azure-cli/capabilities/identity/operations/group-create.yaml`

### Overview

Creates Entra ID security group for user access control.

### Key Features

- **Duration:** FAST operation (30 seconds)
- **Security Group:** Creates security-enabled group
- **Mail Nickname:** Auto-derived from display name
- **Validation:** Group existence and type verification
- **Rollback:** Deletes group on failure

### Idempotency Check

```bash
az ad group list \
  --filter "displayName eq 'GROUP_NAME'" \
  --query "[0].id" -o tsv
```

Returns group ID if exists, empty if not found.

### Example YAML Structure

```yaml
operation:
  id: "group-create"
  name: "Create Entra ID Group"
  description: "Create Entra ID security group for AVD user access control"

  capability: "identity"
  operation_mode: "create"
  resource_type: "Microsoft.Graph/groups"

  duration:
    expected: 30
    timeout: 300
    type: "FAST"

  parameters:
    required:
      - name: "group_name"
        type: "string"
        description: "Display name of the group"
        default: "{{ENTRA_GROUP_USERS_STANDARD}}"

    optional:
      - name: "description"
        type: "string"
        description: "Group description"
        default: "AVD standard users group"

  idempotency:
    enabled: true
    check_command: |
      az ad group list \
        --filter "displayName eq '{{ENTRA_GROUP_USERS_STANDARD}}'" \
        --query "[0].id" -o tsv 2>/dev/null | grep -q .
    skip_if_exists: true

  template:
    type: "bash-local"
    command: |

      # Create security-enabled group
      az ad group create \
        --display-name "{{ENTRA_GROUP_USERS_STANDARD}}" \
        --mail-nickname "$(echo '{{ENTRA_GROUP_USERS_STANDARD}}' | tr ' ' '-')" \
        --description "AVD standard users group"

  validation:
    enabled: true
    checks:
      - type: "group_exists"
        group_name: "{{ENTRA_GROUP_USERS_STANDARD}}"
        description: "Users group exists"

      - type: "group_type"
        expected: "Security"
        description: "Group is security-enabled"

  rollback:
    enabled: true
    steps:
      - name: "Delete Entra ID Group"
        description: "Remove the security group"
        command: |
          GROUP_ID=$(az ad group list \
            --filter "displayName eq '{{ENTRA_GROUP_USERS_STANDARD}}'" \
            --query "[0].id" -o tsv)

          if [ -n "$GROUP_ID" ]; then
            az ad group delete --group "$GROUP_ID"
          fi
        continue_on_error: false
```

---

## Example 4: Compute - VM Creation

**File:** `/mnt/cache_pool/development/azure-cli/capabilities/compute/operations/vm-create.yaml`

### Overview

Creates virtual machine with TrustedLaunch security.

### Key Features

- **Duration:** WAIT operation (7 minutes expected, 15 minute timeout)
- **Security:** TrustedLaunch with Secure Boot and vTPM
- **Image Support:** Custom image or marketplace image
- **Network:** Attaches to existing subnet

### Security Settings

```yaml
security_type: "TrustedLaunch"
enable_secure_boot: true
enable_vtpm: true
```

### Example YAML Structure

```yaml
operation:
  id: "vm-create"
  name: "Create Virtual Machine"
  description: "Create Azure VM with TrustedLaunch security and custom image support"

  capability: "compute"
  operation_mode: "create"
  resource_type: "Microsoft.Compute/virtualMachines"

  duration:
    expected: 420
    timeout: 900
    type: "WAIT"

  parameters:
    required:
      - name: "vm_name"
        type: "string"
        description: "Name of the virtual machine"
        default: "{{VM_NAME}}"

      - name: "resource_group"
        type: "string"
        description: "Azure resource group name"
        default: "{{AZURE_RESOURCE_GROUP}}"

      - name: "vm_size"
        type: "string"
        description: "VM size/SKU"
        default: "Standard_D4s_v3"

    optional:
      - name: "admin_username"
        type: "string"
        description: "Administrator username"
        default: "azureadmin"

      - name: "admin_password"
        type: "string"
        description: "Administrator password"
        default: "{{VM_ADMIN_PASSWORD}}"
        sensitive: true

      - name: "enable_secure_boot"
        type: "boolean"
        description: "Enable Secure Boot"
        default: true

      - name: "enable_vtpm"
        type: "boolean"
        description: "Enable vTPM"
        default: true

  idempotency:
    enabled: true
    check_command: |
      az vm show \
        --resource-group "{{AZURE_RESOURCE_GROUP}}" \
        --name "{{VM_NAME}}" \
        --output none 2>/dev/null
    skip_if_exists: true

  template:
    type: "bash-local"
    command: |
      az vm create \
        --resource-group "{{AZURE_RESOURCE_GROUP}}" \
        --name "{{VM_NAME}}" \
        --size "{{VM_SIZE}}" \
        --admin-username "{{VM_ADMIN_USERNAME}}" \
        --admin-password "{{VM_ADMIN_PASSWORD}}" \
        --security-type "TrustedLaunch" \
        --enable-secure-boot true \
        --enable-vtpm true \
        --image "{{VM_IMAGE}}" \
        --vnet-name "{{NETWORKING_VNET_NAME}}" \
        --subnet "{{SUBNET_NAME}}"

  validation:
    enabled: true
    checks:
      - type: "resource_exists"
        resource_type: "Microsoft.Compute/virtualMachines"
        resource_name: "{{VM_NAME}}"
        description: "VM exists"

      - type: "provisioning_state"
        expected: "Succeeded"
        description: "VM provisioned successfully"

      - type: "property_equals"
        property: "properties.hardwareProfile.vmSize"
        expected: "{{VM_SIZE}}"
        description: "VM size is correct"

  rollback:
    enabled: true
    steps:
      - name: "Delete Virtual Machine"
        description: "Remove the VM and associated resources"
        command: |
          az vm delete \

            --resource-group "{{AZURE_RESOURCE_GROUP}}" \
            --name "{{VM_NAME}}" \
            --yes --force-deletion yes
        continue_on_error: false
```

---

## Example 5: AVD - Host Pool Creation

**File:** `/mnt/cache_pool/development/azure-cli/capabilities/avd/operations/hostpool-create.yaml`

### Overview

Creates Azure Virtual Desktop host pool with configurable settings.

### Key Features

- **Duration:** NORMAL operation (2 minutes)
- **Pool Type:** Configurable (Pooled/Personal)
- **Load Balancing:** BreadthFirst, DepthFirst, or Persistent
- **Session Limits:** Configurable maximum sessions per host
- **Tagging:** Environmental metadata

### Configuration Options

```yaml
host_pool_type: "Pooled"
max_sessions: 8
load_balancer: "BreadthFirst"
environment: "Production"
```

### Example YAML Structure

```yaml
operation:
  id: "hostpool-create"
  name: "Create AVD Host Pool"
  description: "Create Azure Virtual Desktop host pool with session management and load balancing"

  capability: "avd"
  operation_mode: "create"
  resource_type: "Microsoft.DesktopVirtualization/hostPools"

  duration:
    expected: 120
    timeout: 600
    type: "NORMAL"

  parameters:
    required:
      - name: "hostpool_name"
        type: "string"
        description: "Name of the host pool"
        default: "{{HOST_POOL_NAME}}"

      - name: "resource_group"
        type: "string"
        description: "Azure resource group name"
        default: "{{AZURE_RESOURCE_GROUP}}"

      - name: "location"
        type: "string"
        description: "Azure region"
        default: "{{AZURE_LOCATION}}"

    optional:
      - name: "host_pool_type"
        type: "string"
        description: "Host pool type"
        default: "Pooled"
        validation_enum:
          - "Pooled"
          - "Personal"

      - name: "max_sessions"
        type: "integer"
        description: "Maximum sessions per host"
        default: 8
        validation_regex: "^[1-9][0-9]{0,2}$"

      - name: "load_balancer"
        type: "string"
        description: "Load balancer type"
        default: "BreadthFirst"
        validation_enum:
          - "BreadthFirst"
          - "DepthFirst"
          - "Persistent"

  idempotency:
    enabled: true
    check_command: |
      az desktopvirtualization hostpool show \
        --resource-group "{{AZURE_RESOURCE_GROUP}}" \
        --name "{{HOST_POOL_NAME}}" \
        --output none 2>/dev/null
    skip_if_exists: true

  template:
    type: "bash-local"
    command: |
      az desktopvirtualization hostpool create \
        --resource-group "{{AZURE_RESOURCE_GROUP}}" \
        --name "{{HOST_POOL_NAME}}" \
        --location "{{AZURE_LOCATION}}" \
        --host-pool-type "{{HOST_POOL_TYPE}}" \
        --max-session-limit {{MAX_SESSIONS}} \
        --load-balancer-type "{{LOAD_BALANCER}}" \
        --tags Environment="{{AZURE_ENVIRONMENT}}"

  validation:
    enabled: true
    checks:
      - type: "resource_exists"
        resource_type: "Microsoft.DesktopVirtualization/hostPools"
        resource_name: "{{HOST_POOL_NAME}}"
        description: "Host pool exists"

      - type: "provisioning_state"
        expected: "Succeeded"
        description: "Host pool provisioned"

      - type: "property_equals"
        property: "properties.hostPoolType"
        expected: "{{HOST_POOL_TYPE}}"
        description: "Host pool type is correct"

      - type: "property_equals"
        property: "properties.maxSessionLimit"
        expected: "{{MAX_SESSIONS}}"
        description: "Session limit configured"

      - type: "property_equals"
        property: "properties.loadBalancerType"
        expected: "{{LOAD_BALANCER}}"
        description: "Load balancer type correct"

  rollback:
    enabled: true
    steps:
      - name: "Delete Host Pool"
        description: "Remove the host pool"
        command: |
          az desktopvirtualization hostpool delete \
            --resource-group "{{AZURE_RESOURCE_GROUP}}" \
            --name "{{HOST_POOL_NAME}}" \
            --yes
        continue_on_error: false
```

---

## Related Documentation

- [Capability Domains](02-capability-domains.md) - All capability details
- [Operation Schema](03-03a1-operation-schema-core-part1.md) - Schema reference
- [Best Practices](12-best-practices.md) - Design guidelines
- [Migration Guide](11-migration-guide.md) - Converting to capability format

---

**Last Updated:** 2025-12-06
