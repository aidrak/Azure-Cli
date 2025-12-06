# Best Practices

**Design guidelines and standards for creating capability operations**

## Table of Contents

1. [Operation Naming Conventions](#operation-naming-conventions)
2. [Description Writing Guidelines](#description-writing-guidelines)
3. [Parameter Documentation Standards](#parameter-documentation-standards)
4. [Idempotency Check Design](#idempotency-check-design)
5. [Validation Check Design](#validation-check-design)
6. [Rollback Procedure Design](#rollback-procedure-design)

---

## Operation Naming Conventions

### Kebab-Case IDs

**Format:** lowercase words separated by hyphens

**Good:**
```
✓ vnet-create
✓ storage-account-configure
✓ group-delete
✓ golden-image-install-apps
```

**Bad:**
```
✗ create_vnet (snake_case)
✗ CreateVnet (PascalCase)
✗ createVnet (camelCase)
✗ 01-vnet (numeric prefix)
✗ VNET-CREATE (UPPERCASE)
```

### Semantic Names

**Format:** action-resource or action-what

**Good:**
```
✓ vnet-create (action-resource)
✓ public-access-disable (action-what)
✓ rbac-assign (action-what)
✓ sessionhost-drain (action-what)
```

**Bad:**
```
✗ operation-1 (meaningless)
✗ vnet-op (vague)
✗ do-thing (unclear)
✗ vnet (no action)
```

### Naming Patterns

**Create Operations:**
```
{resource}-create
Examples: vnet-create, vm-create, group-create
```

**Configure Operations:**
```
{resource}-configure OR {what}-configure
Examples: storage-account-configure, sso-hostpool-configure
```

**Delete Operations:**
```
{resource}-delete
Examples: vnet-delete, group-delete
```

**Validation Operations:**
```
{resource}-validate OR {what}-validate
Examples: vm-validate, networking-validate
```

---

## Description Writing Guidelines

### Good Descriptions

Clear, specific, mentions key parameters and features.

**Examples:**
```yaml
✓ "Create Azure VNet with configured address space, optional DNS servers, and region-specific deployment"
✓ "Configure NSG rules for session host ingress/egress with security best practices"
✓ "Assign RBAC roles for storage access and compute login permissions"
✓ "Install core AVD applications including browsers, productivity tools, and media players"
```

### Poor Descriptions

Too vague, doesn't provide useful information.

**Examples:**
```yaml
✗ "Create VNet" (too short, no details)
✗ "This operation creates a virtual network" (redundant with name)
✗ "VNet" (not even a sentence)
✗ "Networking operation" (meaningless)
```

### Description Template

```
[ACTION] Azure [RESOURCE] [PURPOSE/SPECIFICS]
```

**Components:**
1. **Action:** What the operation does (Create, Configure, Delete, etc.)
2. **Resource:** What Azure resource is affected
3. **Purpose:** Why or how (key features, parameters, specifics)

**Examples:**
- Create Azure VNet with configured address space and DNS servers
- Configure NSG rules for session host ingress/egress
- Assign RBAC roles for storage access and compute login
- Delete Azure resource group and all contained resources

### Length Guidelines

**Ideal:** 10-25 words (1-2 sentences)
- Minimum: 5 words
- Maximum: 40 words

**Too short:**
```yaml
✗ description: "Create VNet"  # 2 words
```

**Just right:**
```yaml
✓ description: "Create Azure VNet with configured address space, optional DNS servers, and region-specific deployment"  # 14 words
```

**Too long:**
```yaml
✗ description: "This operation will create a virtual network in Azure using the specified resource group and location parameters, with configurable address space and optional DNS server settings, supporting both IPv4 and IPv6, and integrating with Azure DNS for name resolution, while also supporting service endpoints and private link configurations for enhanced security"  # 54 words - too verbose
```

---

## Parameter Documentation Standards

### Complete Parameter Definition

Every parameter should have all relevant fields.

**Template:**
```yaml
- name: "parameter_name"
  type: "string|integer|boolean"
  description: "Clear description with constraints (range, format, etc.)"
  default: "{{PLACEHOLDER}}" or literal value
  sensitive: false  # true for secrets
  validation_regex: "^pattern$"  # optional
  validation_enum: ["option1", "option2"]  # optional
```

**Example:**
```yaml
- name: "max_sessions"
  type: "integer"
  description: "Maximum concurrent sessions per session host (1-999)"
  default: 8
  validation_regex: "^[1-9][0-9]{0,2}$"
  validation_enum: null
  sensitive: false
```

### Required Field Rules

| Field | When Required | Notes |
|-------|---------------|-------|
| `name` | Always | Unique, snake_case (vnet_name not vnetName) |
| `type` | Always | string, integer, boolean, array |
| `description` | Always | Clear, mentions constraints |
| `default` | Always | Use {{PLACEHOLDER}} for dynamic values |
| `sensitive` | Required if true | Masks value in logs (passwords, keys) |
| `validation_regex` | If constrained | Optional validation pattern |
| `validation_enum` | If limited options | List of valid values |

### Parameter Naming

**Use snake_case:**
```
✓ vnet_name
✓ resource_group
✓ max_sessions
✗ vnetName (camelCase)
✗ VnetName (PascalCase)
✗ vnet-name (kebab-case)
```

**Be descriptive:**
```
✓ storage_account_name
✓ enable_secure_boot
✓ dns_servers
✗ name (ambiguous)
✗ flag (unclear)
✗ value (generic)
```

### Sensitive Parameters

Mark passwords, secrets, API keys as sensitive:

```yaml
- name: "admin_password"
  type: "string"
  description: "Administrator password"
  default: "{{VM_ADMIN_PASSWORD}}"
  sensitive: true  # Masks in logs
```

---

## Idempotency Check Design

### Design Principles

**1. Specificity - Check for exact resource**
```bash
✓ az network vnet show --name "{{VNET_NAME}}"
✗ az network vnet list  # Too broad, slower
```

**2. Silent Failure - Output redirected to /dev/null**
```bash
✓ ... 2>/dev/null
✗ ...  # Error messages pollute logs
```

**3. Clean Exit Codes - 0 for exists, non-zero for missing**
```bash
✓ ... --output none  # Silent success
✗ ... --output json  # Produces output
```

