# Architecture Overview

**System design and organizational principles of the capability-based architecture**

## Table of Contents

1. [Capability-Based Organization Concept](#capability-based-organization-concept)
2. [Migration Rationale](#migration-rationale)
3. [Benefits Comparison](#benefits-comparison)

---

## Capability-Based Organization Concept

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

### Key Organizational Principles

**1. Domain-Based Grouping**
- Operations are organized by Azure service/resource domain
- Each capability represents a logical grouping of related operations
- Operations within a capability share common resource types and patterns

**2. Flat Operation Structure**
- Within each capability, operations are stored in a flat `operations/` directory
- No nested hierarchies to navigate
- Each operation is a standalone YAML file

**3. Semantic Naming**
- Operation IDs use kebab-case descriptive names
- No numeric prefixes or ordering dependencies
- Names clearly indicate purpose: `vnet-create`, `storage-account-configure`

---

## Migration Rationale

### Why Capabilities Over Modules

**1. Discoverability**
- Operations are grouped by domain, not execution order
- Developers can find operations by what they do, not when they run
- Example: Need storage? Look in `capabilities/storage/operations/`

**2. Reusability**
- Operations can be composed from any capability without coupling
- No dependency on module number or sequence
- Mix and match operations to create custom deployments

**3. Composability**
- Multiple capabilities can be mixed in a single deployment
- Dependency resolution handles execution order automatically
- Example: Network + Storage + Compute + AVD in one deployment

**4. Scalability**
- New operations fit naturally into existing domains
- No need to renumber or reorganize existing operations
- Capabilities can grow independently

**5. Clarity**
- Self-documenting structure reflects Azure resource types
- Capability names match Azure service categories
- Easier onboarding for new developers familiar with Azure

### Migration from Modules

The old system used numbered modules (01-15) with operations executing in strict sequence. This created tight coupling and made it difficult to:
- Reuse individual operations
- Add new operations without renumbering
- Understand dependencies between operations
- Compose custom deployment scenarios

The capability-based system solves these problems by:
- Removing numeric prefixes and sequential ordering
- Making dependencies explicit in operation YAML
- Enabling parallel execution of independent operations
- Providing clear domain boundaries

---

## Benefits Comparison

### Comprehensive Feature Comparison

| Aspect | Module-Based | Capability-Based |
|--------|-------------|-----------------|
| **Discovery** | By number/sequence | By domain/function |
| **Reusability** | Tightly coupled | Loosely coupled |
| **Organization** | Execution order | Logical domains |
| **Metadata** | Minimal | Rich (type, mode, validation) |
| **Idempotency** | Inline checks | Formal specification |
| **Self-healing** | Not tracked | Documented fixes |
| **Dependencies** | Implicit (sequence) | Explicit (requires field) |
| **Parallel Execution** | Not supported | Automatic when possible |
| **Adding Operations** | Renumber modules | Add to capability |
| **Understanding** | Read all modules | Read capability domain |

### Practical Examples

**Discovery Example:**

```bash
# OLD: Finding VNet creation (archived in legacy/)
# Look through numbered modules until you find networking
ls legacy/modules/01-*/operations/  # Is it in 01?
ls legacy/modules/02-*/operations/  # Maybe 02?
# Eventually find it in legacy/modules/01-networking/

# NEW: Finding VNet creation (current system)
# Go directly to networking capability
ls capabilities/networking/operations/vnet-create.yaml
```

**Reusability Example:**

```bash
# OLD: Want to create storage account in different deployment
# Must include module 02 in correct sequence with all dependencies

# NEW: Want to create storage account
# Just reference storage-account-create operation
# Dependency system handles prerequisites automatically
```

**Composability Example:**

```yaml
# OLD: Fixed deployment sequence
modules:
  - 01-networking
  - 02-storage
  - 03-identity
  # Can't skip or reorder

# NEW: Flexible composition
operations:
  - storage-account-create
  - vnet-create
  - group-create
# Engine handles ordering based on dependencies
```

### Metadata Benefits

**Module-Based (Limited):**
```yaml
operation:
  id: "01-create-vnet"
  script: |
    # PowerShell script
```

**Capability-Based (Rich):**
```yaml
operation:
  id: "vnet-create"
  capability: "networking"
  operation_mode: "create"
  resource_type: "Microsoft.Network/virtualNetworks"
  duration:
    expected: 60
    timeout: 300
    type: "FAST"
  idempotency:
    enabled: true
    check_command: "..."
  validation:
    enabled: true
    checks: [...]
  rollback:
    enabled: true
    steps: [...]
```

This rich metadata enables:
- Automated dependency resolution
- Intelligent retry logic
- Self-healing capabilities
- Better error messages
- Execution time estimates
- Automatic rollback on failures

---

## Related Documentation

- [Capability Domains](02-capability-domains.md) - Detailed breakdown of all 7 capabilities
- [Operation Schema](03-03a1-operation-schema-core-part1.md) - Complete YAML schema reference
- [Migration Guide](11-migration-guide.md) - How to convert module-based operations

---

**Last Updated:** 2025-12-06
