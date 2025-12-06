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
