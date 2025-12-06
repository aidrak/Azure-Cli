          echo "DNS resolution failed"
          exit 1
        fi
      description: "Custom DNS name resolves"
```

### Example 4: PowerShell Custom Validation

Use PowerShell for Windows-specific validation:

```yaml
validation:
  enabled: true
  checks:
    - type: "custom"
      command: |
        pwsh -Command '
          $vm = az vm show --resource-group "{{RESOURCE_GROUP}}" --name "{{VM_NAME}}" | ConvertFrom-Json
          
          # Check multiple conditions
          $valid = $true
          
          if ($vm.hardwareProfile.vmSize -ne "Standard_D4s_v3") {
            Write-Host "Invalid VM size"
            $valid = $false
          }
          
          if ($vm.tags.Environment -ne "Production") {
            Write-Host "Invalid environment tag"
            $valid = $false
          }
          
          if ($valid) {
            Write-Host "VM validation passed"
            exit 0
          } else {
            exit 1
          }
        '
      description: "VM configuration meets production standards"
```

---

## Environment-Specific Operations

### Overview

Operations that behave differently based on environment (dev, staging, prod).

### Use Cases

- **Security Levels:** More restrictive in production
- **Performance:** Different VM sizes per environment
- **Features:** Enable/disable features by environment
- **Costs:** Optimize costs in dev, maximize reliability in prod

### Example 1: Environment-Based VM Size

```yaml
operation:
  id: "vm-create"
  name: "Create Virtual Machine"
  
  parameters:
    optional:
      - name: "environment"
        type: "string"
        description: "Environment: dev|staging|prod"
        default: "{{AZURE_ENVIRONMENT}}"
        validation_enum:
          - "dev"
          - "staging"
          - "prod"
  
  template:
    type: "bash-local"
    command: |
      # Determine VM size based on environment
      case "{{AZURE_ENVIRONMENT}}" in
        prod)
          VM_SIZE="Standard_D4s_v3"
          SECURITY_TYPE="TrustedLaunch"
          ;;
        staging)
          VM_SIZE="Standard_D2s_v3"
          SECURITY_TYPE="TrustedLaunch"
          ;;
        dev)
          VM_SIZE="Standard_B2s"
          SECURITY_TYPE="Standard"
          ;;
      esac
      
      az vm create \
        --resource-group "{{RESOURCE_GROUP}}" \
        --name "{{VM_NAME}}" \
        --size "$VM_SIZE" \
        --security-type "$SECURITY_TYPE"
```

### Example 2: Environment-Based Security

```yaml
template:
  type: "powershell-local"
  command: |
    $env = "{{AZURE_ENVIRONMENT}}"
    
    if ($env -eq "prod") {
      # Production: Maximum security
      $securityType = "TrustedLaunch"
      $enableSecureBoot = $true
      $enableVtpm = $true
      $enableEncryption = $true
      $minTlsVersion = "TLS1_2"
    } elseif ($env -eq "staging") {
      # Staging: Balanced
      $securityType = "TrustedLaunch"
      $enableSecureBoot = $true
      $enableVtpm = $true
      $enableEncryption = $false
      $minTlsVersion = "TLS1_2"
    } else {
      # Dev: Minimal (faster provisioning)
      $securityType = "Standard"
      $enableSecureBoot = $false
      $enableVtpm = $false
      $enableEncryption = $false
      $minTlsVersion = "TLS1_0"
    }
    
    az vm create `
      --security-type $securityType `
      --enable-secure-boot $enableSecureBoot `
      --enable-vtpm $enableVtpm
```

### Example 3: Environment-Based Features

```yaml
template:
  type: "bash-local"
  command: |
    # Base configuration
    az desktopvirtualization hostpool create \
      --resource-group "{{RESOURCE_GROUP}}" \
      --name "{{HOST_POOL_NAME}}"
    
    # Environment-specific features
    if [ "{{AZURE_ENVIRONMENT}}" = "prod" ]; then
      # Production: Enable autoscaling
      az desktopvirtualization scaling-plan create \
        --resource-group "{{RESOURCE_GROUP}}" \
        --name "{{SCALING_PLAN_NAME}}"
      
      # Production: Configure monitoring
      az monitor diagnostic-settings create \
        --resource "{{HOST_POOL_ID}}" \
        --name "{{DIAGNOSTIC_SETTINGS_NAME}}"
    else
      # Dev/Staging: Skip autoscaling and monitoring (cost savings)
      echo "Skipping autoscaling for non-production environment"
    fi
```

### Example 4: Environment-Based Validation

```yaml
validation:
  enabled: true
  checks:
    # Always validate existence
    - type: "resource_exists"
      resource_type: "Microsoft.Compute/virtualMachines"
      resource_name: "{{VM_NAME}}"
      description: "VM exists"
    
    # Production-only validation
    - type: "custom"
      command: |
        if [ "{{AZURE_ENVIRONMENT}}" = "prod" ]; then
          # In production, require TrustedLaunch
          SECURITY_TYPE=$(az vm show \
            --resource-group "{{RESOURCE_GROUP}}" \
            --name "{{VM_NAME}}" \
            --query "securityProfile.securityType" -o tsv)
          
          if [ "$SECURITY_TYPE" = "TrustedLaunch" ]; then
            exit 0
          else
            echo "Production VMs must use TrustedLaunch"
            exit 1
          fi
        else
          # Non-production: skip check
          exit 0
        fi
      description: "Production VMs use TrustedLaunch security"
```

---

## Best Practices for Advanced Scenarios

### 1. Document Remote Execution

Clearly indicate when scripts run remotely:

```yaml
template:
  type: "powershell-remote"
  command: |
    # IMPORTANT: This script runs ON the Azure VM, not locally
    # Available variables: $env:COMPUTERNAME, $env:USERNAME, etc.
```

### 2. Handle Large Scripts Gracefully

Use separate files for scripts > 10KB:

```
✓ Store in scripts/ subdirectory
✓ Use descriptive filenames
✓ Include script documentation headers
```

### 3. Test Custom Validations

Custom validation commands should be thoroughly tested:

```bash
# Test validation command locally
VM_COUNT=$(az vm list --query "length([])" -o tsv)
echo "VM count: $VM_COUNT"
```

### 4. Environment Configuration

Store environment settings in config.yaml:

```yaml
azure:
  environment: "prod"  # or "dev", "staging"
  
  environments:
    prod:
      vm_size: "Standard_D4s_v3"
      security_type: "TrustedLaunch"
    dev:
      vm_size: "Standard_B2s"
      security_type: "Standard"
```

---

## Related Documentation

- [Operation Schema](03-operation-schema.md) - Template types
- [Validation Framework](07-validation-framework.md) - Custom validation
- [Operation Examples](10-operation-examples.md) - Real examples
- [Best Practices](12-best-practices.md) - Design guidelines

---

**Last Updated:** 2025-12-06
