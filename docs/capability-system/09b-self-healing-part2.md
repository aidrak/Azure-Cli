
**Fix Definition:**
```yaml
fixes:
  - issue_code: "DNS_RESOLUTION_FAILED"
    description: "DNS server temporarily unavailable"
    applied_at: "2025-12-06T14:23:45Z"
    fix_command: |
      sleep 5  # Wait for DNS to recover
      # Retry will happen automatically
    retry_count: 3
    success: true
```

**Execution Flow:**
```
[ERROR] VNet creation failed: DNS resolution timeout
[HEALING] Matching issue: DNS_RESOLUTION_FAILED
[HEALING] Applying fix: Wait 5 seconds for DNS recovery
[HEALING] Retrying operation (attempt 1/3)
[SUCCESS] VNet created successfully
[HEALING] Fix recorded in history
```

---

### Example 2: Naming Policy Violation

**Issue:** Resource name violates Azure naming policy.

**Fix Definition:**
```yaml
fixes:
  - issue_code: "NAME_POLICY_VIOLATION"
    description: "Resource name violates Azure naming policy"
    applied_at: "2025-12-06T14:24:00Z"
    fix_command: |
      # Replace invalid characters
      ORIGINAL_NAME="{{RESOURCE_NAME}}"
      FIXED_NAME="${ORIGINAL_NAME//-/_}"

      # Update configuration
      export RESOURCE_NAME="$FIXED_NAME"
      echo "[FIX] Updated name: $ORIGINAL_NAME → $FIXED_NAME"
    retry_count: 1
    success: true
```

**Execution Flow:**
```
[ERROR] Storage account creation failed: InvalidResourceName
[HEALING] Matching issue: NAME_POLICY_VIOLATION
[HEALING] Applying fix: Replace hyphens with underscores
[FIX] Updated name: avd-stor-prod → avd_stor_prod
[HEALING] Retrying operation (attempt 1/1)
[SUCCESS] Storage account created: avd_stor_prod
```

---

### Example 3: Quota Exceeded (No Auto-Fix)

**Issue:** Subscription quota exceeded, requires manual intervention.

**Fix Definition:**
```yaml
fixes:
  - issue_code: "QUOTA_EXCEEDED"
    description: "Subscription quota exceeded - manual intervention required"
    applied_at: "2025-12-06T14:25:00Z"
    fix_command: |
      # Log details for manual intervention
      echo "[ACTION REQUIRED] Quota exceeded for {{RESOURCE_TYPE}}"
      echo "Current quota: $(az vm list-usage --location {{AZURE_LOCATION}} --query '[?name.value==\"cores\"].currentValue' -o tsv)"
      echo "Request increase: https://portal.azure.com/#blade/Microsoft_Azure_Support/HelpAndSupportBlade"

      # Do not retry (quota increase needed)
      exit 1
    retry_count: 0
    success: false
```

**Execution Flow:**
```
[ERROR] VM creation failed: QuotaExceeded
[HEALING] Matching issue: QUOTA_EXCEEDED
[HEALING] Applying diagnostic logging
[ACTION REQUIRED] Quota exceeded for Microsoft.Compute/virtualMachines
Current quota: 100/100 cores
Request increase: https://portal.azure.com/#blade/...
[HEALING] Fix not retryable - manual action required
[FAILURE] Operation failed - quota increase needed
```

---

### Example 4: Rate Limiting

**Issue:** API rate limit hit, need to back off and retry.

**Fix Definition:**
```yaml
fixes:
  - issue_code: "RATE_LIMIT_EXCEEDED"
    description: "Azure API rate limit exceeded"
    applied_at: "2025-12-06T14:26:00Z"
    fix_command: |
      echo "[HEALING] Rate limit hit, backing off..."

      # Exponential backoff based on retry attempt
      BACKOFF_SECONDS=$((2 ** RETRY_ATTEMPT))
      echo "[HEALING] Waiting ${BACKOFF_SECONDS}s before retry"
      sleep $BACKOFF_SECONDS
    retry_count: 5
    success: true
```

**Execution Flow:**
```
[ERROR] Operation failed: TooManyRequests
[HEALING] Matching issue: RATE_LIMIT_EXCEEDED
[HEALING] Rate limit hit, backing off...
[HEALING] Waiting 1s before retry (attempt 1/5)
[HEALING] Retrying operation...
[ERROR] Still rate limited
[HEALING] Waiting 2s before retry (attempt 2/5)
[HEALING] Retrying operation...
[SUCCESS] Operation succeeded
```

---

### Example 5: Network Timeout with Progressive Retry

**Issue:** Network timeout during large file upload.

**Fix Definition:**
```yaml
fixes:
  - issue_code: "NETWORK_TIMEOUT"
    description: "Network timeout during operation"
    applied_at: "2025-12-06T14:27:00Z"
    fix_command: |
      echo "[HEALING] Network timeout detected"

      # Increase timeout progressively
      case $RETRY_ATTEMPT in
        1) TIMEOUT=300 ;;   # 5 minutes
        2) TIMEOUT=600 ;;   # 10 minutes
        3) TIMEOUT=900 ;;   # 15 minutes
      esac

      echo "[HEALING] Increasing timeout to ${TIMEOUT}s"
      export OPERATION_TIMEOUT=$TIMEOUT
    retry_count: 3
    success: true
```

---

## Fix Design Patterns

### Pattern 1: Wait and Retry

**Use for:** Transient failures, temporary unavailability.

```yaml
fix_command: |
  sleep ${BACKOFF_SECONDS}
retry_count: 3
```

---

### Pattern 2: Configuration Fix

**Use for:** Invalid configuration that can be auto-corrected.

```yaml
fix_command: |
  # Fix configuration
  FIXED_VALUE=$(transform "$ORIGINAL_VALUE")
  export PARAMETER="$FIXED_VALUE"
retry_count: 1
```

---

### Pattern 3: Diagnostic Only

**Use for:** Issues requiring manual intervention.

```yaml
fix_command: |
  # Log diagnostic information
  echo "[ACTION REQUIRED] ..."
  exit 1  # Do not retry
retry_count: 0
```

---

### Pattern 4: Progressive Adjustment

**Use for:** Resource constraints that need gradual adjustment.

```yaml
fix_command: |
  # Adjust based on retry count
  ADJUSTED_VALUE=$((BASE_VALUE * (RETRY_ATTEMPT + 1)))
  export PARAMETER="$ADJUSTED_VALUE"
retry_count: 3
```

---

## Related Documentation

- [Operation Lifecycle](04-operation-lifecycle.md) - Where self-healing fits in execution
- [Validation Framework](07-validation-framework.md) - What triggers self-healing
- [Rollback Procedures](08-rollback-procedures.md) - Alternative to self-healing

---

**Last Updated:** 2025-12-06
