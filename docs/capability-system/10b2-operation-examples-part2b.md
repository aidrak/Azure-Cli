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
- [Operation Schema](03-operation-schema.md) - Schema reference
- [Best Practices](12-best-practices.md) - Design guidelines
- [Migration Guide](11-migration-guide.md) - Converting to capability format

---

**Last Updated:** 2025-12-06
