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
