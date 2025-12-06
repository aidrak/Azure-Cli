# Operation Schema Reference

**Complete YAML schema specification for capability operations**

## Table of Contents

1. [Complete Schema Structure](#complete-schema-structure)
2. [Identity and Metadata](#identity-and-metadata)
3. [Classification](#classification)
4. [Duration](#duration)
5. [Parameters](#parameters)
6. [Prerequisites](#prerequisites)
7. [Idempotency](#idempotency)
8. [Template](#template)
9. [Validation](#validation)
10. [Rollback](#rollback)
11. [Fixes](#fixes)

---

## Complete Schema Structure

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

---

## Identity and Metadata

### Field Specifications

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | Yes | Unique operation identifier (kebab-case, e.g., "vnet-create") |
| `name` | string | Yes | Human-readable operation name |
| `description` | string | Yes | Detailed operation description (2-3 sentences) |

### Field Rules

**id:**
- MUST use kebab-case format
- MUST be unique across all capabilities
- MUST NOT include numeric prefixes
- SHOULD be descriptive and action-oriented

**Examples:**
```yaml
✓ id: "vnet-create"
✓ id: "storage-account-configure"
✓ id: "golden-image-install-apps"
✗ id: "01-create-vnet" (numeric prefix)
✗ id: "create_vnet" (snake_case)
✗ id: "CreateVNet" (PascalCase)
```

**name:**
- MUST be human-readable
- SHOULD use title case
- SHOULD be 3-8 words maximum

**Examples:**
```yaml
✓ name: "Create Virtual Network"
✓ name: "Configure Storage Account Security"
✗ name: "VNet" (too short)
✗ name: "This operation creates a virtual network..." (too long)
```

**description:**
- MUST be 2-3 sentences
- MUST describe what the operation does
- SHOULD mention key parameters or features

**Examples:**
```yaml
✓ description: "Create Azure VNet with configured address space, optional DNS servers, and region-specific deployment. Supports custom DNS and service endpoint configuration."

✗ description: "Creates VNet" (too short, not descriptive)
```

---

## Classification

### Field Specifications

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `capability` | string | Yes | Domain: `networking`, `storage`, `identity`, `compute`, `avd`, `management`, `test-capability` |
| `operation_mode` | string | Yes | Operation type: `create`, `read`, `update`, `delete`, `configure`, `validate` |
| `resource_type` | string | Yes | Azure ARM resource type (e.g., "Microsoft.Network/virtualNetworks") |

### Valid Values

**capability:**
```yaml
- networking       # Network infrastructure
- storage          # Storage accounts, file shares
- identity         # Entra ID, RBAC
- compute          # VMs, images, disks
- avd              # Azure Virtual Desktop
- management       # Resource groups, governance
- test-capability  # Testing operations
```

**operation_mode:**
```yaml
- create:    # Create new resource
- read:      # Query/retrieve resource information
- update:    # Modify existing resource
- delete:    # Remove resource
- configure: # Configure/customize resource
- validate:  # Verify resource state/configuration
```

**resource_type:**
Must be a valid Azure ARM resource type:
```yaml
# Networking
"Microsoft.Network/virtualNetworks"
"Microsoft.Network/networkSecurityGroups"
"Microsoft.Network/publicIPAddresses"

# Storage
"Microsoft.Storage/storageAccounts"

# Compute
"Microsoft.Compute/virtualMachines"
"Microsoft.Compute/images"

# AVD
"Microsoft.DesktopVirtualization/hostPools"
"Microsoft.DesktopVirtualization/workspaces"

# Identity
"Microsoft.Graph/groups"
"Microsoft.Authorization/roleAssignments"

