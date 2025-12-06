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
