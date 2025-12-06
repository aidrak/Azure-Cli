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
