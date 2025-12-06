# Dependency Management

**Managing prerequisites and execution order for complex deployments**

## Table of Contents

1. [Using requires Field](#using-requires-field)
2. [Dependency Chains](#dependency-chains)
3. [Parallel Execution Groups](#parallel-execution-groups)
4. [Dependency Graph Examples](#dependency-graph-examples)
5. [Dependency Resolution Algorithm](#dependency-resolution-algorithm)
6. [Handling Dependency Failures](#handling-dependency-failures)

---

## Using requires Field

### Overview

Operations can specify dependencies on other operations and Azure resources.

### Structure

```yaml
operation:
  id: "hostpool-create"
  
  prerequisites:
    operations:
      - "resource-group-create"
      - "vnet-create"
      - "subnet-create"
    resources:
      - type: "Microsoft.Network/virtualNetworks"
        name: "{{NETWORKING_VNET_NAME}}"
      - type: "Microsoft.Resources/resourceGroups"
        name: "{{AZURE_RESOURCE_GROUP}}"
```

### Interpretation

**operations:**
- Lists operation IDs that must complete successfully first
- Engine ensures these run before current operation
- Used for operation-level dependencies

**resources:**
- Lists Azure resources that must exist
- Engine can validate before execution
- Each resource has `type` and `name`

### Example

```yaml
operation:
  id: "hostpool-create"
  name: "Create AVD Host Pool"
  
  prerequisites:
    operations:
      - "resource-group-create"
      - "vnet-create"
      - "subnet-create"
    resources:
      - type: "Microsoft.Resources/resourceGroups"
        name: "{{AZURE_RESOURCE_GROUP}}"
      - type: "Microsoft.Network/virtualNetworks"
        name: "{{NETWORKING_VNET_NAME}}"
```

**Means:**
1. `resource-group-create` must complete before hostpool-create
2. `vnet-create` must complete before hostpool-create
3. Resource group must exist in Azure
4. VNet must exist in Azure

---

## Dependency Chains

### Simple Linear Chain

Logical execution chains emerge from requires fields.

```
resource-group-create
        ↓
    vnet-create
        ↓
    subnet-create
        ↓
    nsg-create
        ↓
    vm-create
        ↓
    image-create
        ↓
    hostpool-create
        ↓
    appgroup-create
```

**Execution:**
- Operations run sequentially
- Each waits for previous to complete
- Total duration = sum of all operation durations

### Branching Dependencies

One operation can depend on multiple predecessors:

```
resource-group-create
        ↓
    vnet-create
        ↓
   ┌────┴────┐
   ↓         ↓
subnet-1   subnet-2
   ↓         ↓
   └────┬────┘
        ↓
    vm-create
```

**Execution:**
- subnet-1 and subnet-2 can run in parallel after vnet-create
- vm-create waits for BOTH subnets to complete

### Complex Network

Multi-path dependencies:

```
resource-group-create
        ↓
    vnet-create
        ↓
   ┌────┴────┐
   ↓         ↓
nsg-create  dns-zone-create
   ↓         ↓
subnet-create (depends on both nsg and dns)
   ↓
vm-create
```

---

## Parallel Execution Groups

### Overview

Independent operations can execute in parallel to reduce total deployment time.

### Parallel Group Example

```
resource-group-create (1)
        ↓
┌───────┼───────┐
↓       ↓       ↓
(2a)  (2b)    (2c)
storage vnet  identity
        ↓       ↓
        └───┬───┘
            ↓
    All continue (3)
```

**Execution:**
- (1) runs first
- (2a), (2b), (2c) all run in parallel after (1) completes
- Total duration: (1) + max((2a), (2b), (2c))

### Real-World Example

```yaml
# These can run in parallel (no dependencies between them)
Parallel Group 1:
├─ storage-account-create
├─ dns-zone-create
└─ fslogix-group-create

# All depend on resource-group-create
```

**Duration Calculation:**
```
Sequential: 
  resource-group (60s) + storage (90s) + dns (120s) + group (30s) = 300s

Parallel:
  resource-group (60s) + max(90s, 120s, 30s) = 180s

Savings: 120s (40% faster)
```

---

## Dependency Graph Examples

### Example 1: Simple Linear Chain

```
resource-group → vnet → subnet → nsg → vm → image
   (1)          (2)    (3)      (4)  (5)   (6)

Execution: 1→2→3→4→5→6 (sequential)
Duration: Sum of all timeouts
```

**YAML:**
```yaml
# vnet-create.yaml
prerequisites:
  operations:
    - "resource-group-create"

# subnet-create.yaml
prerequisites:
  operations:
    - "vnet-create"

# nsg-create.yaml
prerequisites:
  operations:
    - "vnet-create"

# vm-create.yaml
prerequisites:
  operations:
    - "subnet-create"
    - "nsg-create"
```

---

### Example 2: Branching Dependency

```
                    ┌─ storage-account (2a)
                    │
resource-group (1)  ├─ vnet (2b)
                    │
                    └─ identity-groups (2c)

Parallel: 2a, 2b, 2c all start after (1) completes
Duration: (1) + max((2a), (2b), (2c))
```

**YAML:**
```yaml
# storage-account-create.yaml
prerequisites:
  operations:
    - "resource-group-create"

# vnet-create.yaml
prerequisites:
  operations:
    - "resource-group-create"

# group-create.yaml
prerequisites:
  operations:
    - "resource-group-create"
```

---

### Example 3: Complex Network

```
                  ┌─ subnet-1
