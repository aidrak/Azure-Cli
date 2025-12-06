```yaml
rollback:
  enabled: true
  steps:
    - name: "Delete Virtual Network"
      description: "Remove the VNet"
      command: |
        az network vnet delete \
          --resource-group "{{AZURE_RESOURCE_GROUP}}" \
          --name "{{NETWORKING_VNET_NAME}}" \
          --yes
      continue_on_error: false
```

**Execution:**
```
[ROLLBACK] Step 1/1: Delete Virtual Network
[INFO] Deleting VNet: avd-vnet-prod
[SUCCESS] VNet deleted
[ROLLBACK] Complete
```

---

## Phase 8: Self-Healing

### Overview

Apply known fixes for common issues and retry automatically.

### Self-Healing Process

```
1. Operation fails with specific error
   ↓
2. Match error to known issue_code in fixes array
   ↓
3. Apply fix_command
   ↓
4. Retry operation (up to retry_count times)
   ↓
5. Track success/failure
   ↓
6. Update fix history
```

### Example

```yaml
fixes:
  - issue_code: "DNS_RESOLUTION_FAILED"
    description: "DNS server temporarily unavailable"
    fix_command: |
      sleep 5  # Wait for DNS to recover
      retry_current_operation
    retry_count: 3
```

**Execution:**
```
[ERROR] VNet creation failed: DNS resolution timeout
[HEALING] Applying fix: DNS_RESOLUTION_FAILED
[HEALING] Waiting 5 seconds for DNS recovery...
[HEALING] Retrying operation (attempt 1/3)
[SUCCESS] VNet created successfully
```

### Fix History

```json
{
  "operation_id": "vnet-create",
  "issue_code": "DNS_RESOLUTION_FAILED",
  "applied_at": "2025-12-06T14:23:45Z",
  "retry_count": 1,
  "success": true,
  "execution_time_ms": 5234
}
```

---

## ASCII Flow Diagram

```
┌─────────────────────────────────────────┐
│ Engine discovers operation              │
│ capabilities/compute/operations/vm.yaml │
└────────────┬────────────────────────────┘
             │
             ↓
      ┌──────────────────┐
      │ Load & validate  │
      │ schema           │
      └────────┬─────────┘
               │
             ┌─┴──────────────────────┐
             │ Parameters OK?         │
             └─┬──────────────────────┘
               │
      ┌────────↓─────────┐
      │ Run idempotency  │
      │ check_command    │
      └────────┬─────────┘
               │
         ┌─────┴──────┐
      YES│            │NO
         │            │
    Skip ↓         ┌──↓──────────────┐
         │         │ Substitute      │
         │         │ {{PLACEHOLDERS}}│
         │         └────────┬────────┘
         │                  │
         │              ┌───↓────────────┐
         │              │ Execute script │
         │              │ w/ timeout     │
         │              └────────┬───────┘
         │                       │
         │                  ┌────↓─────────┐
         │                  │ Timeout?     │
         │                  └────┬─────┬───┘
         │                       │     │
         │                    YES│     │NO
         │                       │     │
         │                   Rollback  │
         │                       │  ┌──↓──────────────────┐
         │                       │  │ Run validation      │
         │                       │  │ checks              │
         │                       │  └───────┬─────────────┘
         │                       │          │
         │                       │   All OK?├──┐
         │                       │      │    │  │NO
         │                       │      ↓    │  │
         ├───────────────────────┴─→ Update   │  │
         │                      state.json   │  │
         │                                   ↓  │
         │                           Apply fixes│
         │                            (self-heal)
         │                                   │
         ↓                                   ↓
      SUCCESS                            RETRY
                                      (max 3 times)
                                           │
                                     ┌─────┴─────┐
                                     │ All retry?│
                                     └──┬────┬───┘
                                   YES│    │NO
                                      │    │
                                  Continue
                                      │
                                      ↓
                                    FAIL
```

---

## Related Documentation

- [Operation Schema](03-operation-schema.md) - YAML schema details
- [Idempotency](06-idempotency.md) - Detailed idempotency patterns
- [Validation Framework](07-validation-framework.md) - Validation check details
- [Rollback Procedures](08-rollback-procedures.md) - Rollback design
- [Self-Healing](09-self-healing.md) - Self-healing system

---

**Last Updated:** 2025-12-06
