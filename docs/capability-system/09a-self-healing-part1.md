# Self-Healing System

**Automated detection and correction of known issues**

## Table of Contents

1. [Purpose and Goals](#purpose-and-goals)
2. [Fixes Array Structure](#fixes-array-structure)
3. [Automated Correction Tracking](#automated-correction-tracking)
4. [Historical Fix Log](#historical-fix-log)
5. [Self-Healing Examples](#self-healing-examples)

---

## Purpose and Goals

### Purpose

Automatically detect and fix known issues without manual intervention.

### Goals

**1. Automation**
- Reduce manual remediation efforts
- Apply known fixes automatically
- Learn from past failures

**2. Reliability**
- Increase successful deployments
- Handle transient failures gracefully
- Recover from common errors

**3. Learning**
- Track and document common failures
- Build knowledge base of fixes
- Improve over time

**4. Transparency**
- Document all applied fixes
- Provide audit trail
- Enable analysis and optimization

---

## Fixes Array Structure

### Complete Structure

```yaml
fixes:
  - issue_code: "ISSUE_CODE"
    description: "Issue description"
    applied_at: "2025-12-06T14:23:45Z"
    fix_command: |
      # Fix command
    retry_count: integer
    success: boolean
```

### Field Reference

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `issue_code` | string | Yes | Unique identifier for the issue |
| `description` | string | Yes | Human-readable description |
| `applied_at` | string | Yes | ISO 8601 timestamp when fix was applied |
| `fix_command` | string | Yes | Command to execute for fix |
| `retry_count` | integer | Yes | Number of times to retry (0-5) |
| `success` | boolean | No | Whether fix was successful (filled at runtime) |

### Example Fix Definition

```yaml
fixes:
  - issue_code: "VNET_CREATION_TIMEOUT"
    description: "VNet creation timed out due to DNS resolution"
    applied_at: "2025-12-06T14:23:45Z"
    fix_command: |
      az network vnet update \
        --resource-group "{{AZURE_RESOURCE_GROUP}}" \
        --name "{{NETWORKING_VNET_NAME}}" \
        --set "dnsSetting.dnsServers=@['8.8.8.8','8.8.4.4']"
    retry_count: 2
    success: true
```

---

## Automated Correction Tracking

### When Fix Applied

**Trigger Conditions:**
1. Operation fails with specific error
2. Error message matches known issue pattern
3. Matching fix found in `fixes` array
4. Fix is applicable to current state

**Application Process:**
```
1. Operation fails
   ↓
2. Parse error message
   ↓
3. Match to issue_code
   ↓
4. Find fix in fixes array
   ↓
5. Execute fix_command
   ↓
6. Record result with timestamp
   ↓
7. If successful, resume operation
   ↓
8. If failed, add to retry queue
```

### Retry Policy

**Maximum Retries:** 3 times (configurable via `retry_count`)

**Backoff Strategy:** Exponential
```
Attempt 1: Immediate
Attempt 2: 1 second delay
Attempt 3: 2 seconds delay
Attempt 4: 4 seconds delay
```

**Conditions to Retry:**
- Transient errors only
- Network timeouts
- Rate limiting
- DNS resolution failures

**Do Not Retry:**
- Authentication failures
- Authorization errors
- Quota exceeded
- Invalid configuration

### Tracking During Execution

```json
{
  "operation_id": "vnet-create",
  "execution_id": "exec-20251206-142345",
  "fix_applied": {
    "issue_code": "VNET_TIMEOUT",
    "applied_at": "2025-12-06T14:23:45Z",
    "fix_command": "...",
    "retry_attempt": 1,
    "success": true,
    "execution_time_ms": 2341
  }
}
```

---

## Historical Fix Log

### Storage Location

**Path:** `artifacts/fixes/fix-history.json`

**Purpose:**
- Track all fixes applied across all operations
- Analyze common failure patterns
- Optimize fix strategies
- Generate reports

### Structure

```json
{
  "operations_healed": 45,
  "total_fixes_applied": 127,
  "last_updated": "2025-12-06T14:30:00Z",
  "fixes": [
    {
      "operation_id": "vnet-create",
      "issue_code": "VNET_TIMEOUT",
      "applied_at": "2025-12-06T14:23:45Z",
      "execution_time_ms": 2341,
      "success": true
    },
    {
      "operation_id": "storage-account-create",
      "issue_code": "STORAGE_NAME_INVALID",
      "applied_at": "2025-12-06T14:24:30Z",
      "execution_time_ms": 450,
      "success": false,
      "error": "Name still invalid after fix"
    }
  ]
}
```

### Metrics Tracked

**Success Rate:**
```
successful_fixes / total_fixes_applied = 92.5%
```

**Most Common Issues:**
```json
{
  "issue_frequency": {
    "DNS_RESOLUTION_FAILED": 45,
    "VNET_TIMEOUT": 23,
    "STORAGE_NAME_INVALID": 18,
    "QUOTA_EXCEEDED": 12
  }
}
```

**Average Fix Time:**
```
avg_execution_time_ms = 1850
```

---

## Self-Healing Examples

### Example 1: Transient DNS Failure

**Issue:** DNS server temporarily unavailable during VNet creation.
