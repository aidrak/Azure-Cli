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
                  │     ↓
vnet ──┬─ nsg ────┤─ subnet-2 ── vm-1
       │          │     ↓         ↓
       └─ dns ────┴─ subnet-3 ── vm-2

Dependencies:
- NSG, DNS parallel after VNet
- Subnets parallel after NSG
- VMs depend on VNet + NSG
- All depend on resource-group
```

**YAML:**
```yaml
# nsg-create.yaml
prerequisites:
  operations:
    - "vnet-create"

# dns-zone-create.yaml
prerequisites:
  operations:
    - "vnet-create"

# subnet-create.yaml (all three subnets)
prerequisites:
  operations:
    - "nsg-create"

# vm-create.yaml
prerequisites:
  operations:
    - "subnet-create"
    - "nsg-create"
```

---

### Example 4: AVD Full Stack

```
resource-group-create
        ↓
   ┌────┴────┬────────────┐
   ↓         ↓            ↓
vnet    storage      identity
   ↓         ↓            ↓
subnet    fileshare   groups
   ↓         ↓            ↓
   └─────────┴────────┬───┘
                      ↓
              hostpool-create
                      ↓
              appgroup-create
                      ↓
              workspace-create
```

---

## Dependency Resolution Algorithm

### How Engine Resolves Dependencies

The engine uses this algorithm to determine execution order:

```
1. Start with requested operations
   Example: User requests "hostpool-create"

2. For each operation:
   a. Find all required operations from prerequisites.operations
   b. Add missing dependencies to queue
   c. Mark operation as pending
   Example: hostpool requires resource-group, vnet, subnet

3. Build dependency graph
   - Topological sort
   - Identify parallel groups
   - Validate no circular dependencies

4. Execute operations:
   a. Find operations with all dependencies met
   b. Execute in parallel if possible
   c. Mark as complete
   d. Repeat until all done
```

### Example Execution

**User requests:**
```bash
./core/engine.sh run hostpool-create
```

**Engine resolves:**
```
1. hostpool-create requires:
   - resource-group-create
   - vnet-create
   - subnet-create

2. vnet-create requires:
   - resource-group-create

3. subnet-create requires:
   - vnet-create

4. Execution order:
   a. resource-group-create
   b. vnet-create
   c. subnet-create
   d. hostpool-create
```

### Circular Dependency Detection

**Invalid (circular):**
```yaml
# operation-a.yaml
prerequisites:
  operations:
    - "operation-b"

# operation-b.yaml
prerequisites:
  operations:
    - "operation-a"  # Circular!
```

**Engine detects and fails:**
```
[ERROR] Circular dependency detected:
  operation-a → operation-b → operation-a
[ERROR] Cannot resolve execution order
```

---

## Handling Dependency Failures

### When Dependency Fails

**Scenario:** vnet-create fails, subnet-create is queued.

**Options:**

**A) FAIL FAST (Default - Safest)**
```
[ERROR] vnet-create failed
[INFO] Stopping execution
[INFO] Skipping: subnet-create (dependency failed)
[INFO] Skipping: vm-create (dependency failed)
[RESULT] Deployment failed
```

**B) CONTINUE (Risky)**
```
[ERROR] vnet-create failed
[WARNING] Continuing despite failure
[INFO] Attempting: subnet-create
[ERROR] subnet-create failed (VNet doesn't exist)
[RESULT] Multiple failures
```

**C) RETRY (With Limits)**
```
[ERROR] vnet-create failed
[RETRY] Attempting retry 1/3
[SUCCESS] vnet-create succeeded
[INFO] Continuing: subnet-create
[RESULT] Deployment recovered
```

### Failure Handling Strategies

**1. Fail Fast (Default)**
- Stop immediately on first failure
- Don't attempt dependent operations
- Safest approach
- Best for production

**2. Continue Best Effort**
- Log warnings but continue
- Attempt all operations
- Useful for validation runs
- Not recommended for production

**3. Retry with Backoff**
- Retry failed operations N times
- Exponential backoff between retries
- Continue if retry succeeds
- Best for transient failures

### Configuration

```yaml
# In deployment configuration
failure_handling:
  strategy: "fail_fast"  # or "continue" or "retry"
  max_retries: 3
  backoff_seconds: [1, 2, 4]  # Exponential backoff
```

---

## Best Practices

### 1. Minimal Dependencies

Only list essential dependencies:

**Bad:**
```yaml
prerequisites:
  operations:
    - "resource-group-create"
    - "vnet-create"
    - "subnet-create"
    - "nsg-create"
    - "dns-zone-create"
    - "storage-account-create"  # Not actually needed!
```

**Good:**
```yaml
prerequisites:
  operations:
    - "subnet-create"  # Implies vnet and resource-group
    - "nsg-create"     # Only what's directly needed
```

### 2. Leverage Parallel Execution

Identify independent operations:

**Bad (Sequential):**
```yaml
# All sequential (unnecessary)
storage → dns → identity → vnet
```

**Good (Parallel):**
```yaml
# All parallel after resource-group
resource-group → [storage, dns, identity, vnet]
```

### 3. Validate Resources

Check resources exist before execution:

```yaml
prerequisites:
  resources:
    - type: "Microsoft.Network/virtualNetworks"
      name: "{{VNET_NAME}}"
```

---

## Related Documentation

- [Operation Lifecycle](04-operation-lifecycle.md) - Execution flow
- [Operation Schema](03-operation-schema.md) - prerequisites schema
- [Best Practices](12-best-practices.md) - Design guidelines

---

**Last Updated:** 2025-12-06
