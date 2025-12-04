# Phase 3: Self-Healing & Error Handling - COMPLETE

**Date**: 2025-12-04
**Status**: ✅ All deliverables completed

## Deliverables

### 1. Error Handler ✅

**File**: `core/error-handler.sh` (370 lines)

**Functions implemented**:
- `check_destructive_action()` - Validate fixes against destructive patterns
- `extract_error_info()` - Extract errors from operation logs
- `generate_fix_prompt()` - Create detailed error analysis prompt
- `apply_fix_to_template()` - Apply fix record to operation YAML
- `update_powershell_content()` - Update PowerShell script in template
- `should_retry_operation()` - Check retry limit (max 3)
- `reset_retry_counter()` - Reset retry counter for operation
- `handle_operation_error()` - Main error handling workflow
- `validate_fix()` - Validate proposed fix (anti-destructive check)
- `get_error_history()` - Query error history from structured logs
- `get_fix_history()` - Get fix history from template

**Key Features**:
- **Anti-Destructive Safeguards**: Blocks 7 destructive patterns
  - `az vm delete`
  - `recreate.*vm`
  - `start over`
  - `create.*new.*vm`
  - `destroy`
  - `remove.*vm`
  - `az vm deallocate.*delete`
- **Error Extraction**: Parses `[ERROR]` markers from logs
- **Fix Application**: Records fixes in template `fixes:` section via `yq`
- **Retry Management**: Max 3 retries per operation, tracked in state files
- **Validation**: Checks PowerShell markers present in fixes
- **Integration**: Works with progress-tracker.sh and logger.sh

**Destructive Action Example** (blocked):
```bash
check_destructive_action "Let's recreate the VM from scratch"
# Returns: [x] DESTRUCTIVE ACTION BLOCKED
#          Pattern matched: recreate.*vm
#          Rule: Fix incrementally, never start over
```

**Fix Application Example**:
```bash
apply_fix_to_template \
    "modules/05-golden-image/operations/03-install-fslogix.yaml" \
    "Download timeout on slow connections" \
    "Added -TimeoutSec 120 to Invoke-WebRequest" \
    "2025-12-04"
```

### 2. Template Engine Enhancements ✅

**File**: `core/template-engine.sh` (enhanced with 5 new functions)

**New Functions**:
- `edit_powershell_in_template()` - Edit PowerShell content via `yq`
- `add_fix_to_template()` - Add fix record to template
- `get_template_fixes()` - Retrieve fix history
- `update_operation_duration()` - Update expected/timeout durations
- `add_validation_check()` - Add validation check to template

**Template Editing Examples**:

```bash
# Edit PowerShell content
new_ps='Write-Host "[START] Updated operation"
Write-Host "[PROGRESS] Step 1/2: Processing..."
Write-Host "[SUCCESS] Complete"'

edit_powershell_in_template "path/to/operation.yaml" "$new_ps"

# Update operation duration
update_operation_duration "path/to/operation.yaml" 300 600

# Add validation check
add_validation_check "path/to/operation.yaml" "file_exists" "C:\\Program Files\\App\\app.exe"
```

**Fix Record Format**:
```yaml
fixes:
  - issue: "Download timeout on slow connections"
    detected: "2025-12-04"
    fix: "Added -TimeoutSec 120 to Invoke-WebRequest"
    applied_to_template: true
```

### 3. Self-Healing Test Suite ✅

**File**: `test-phase3.sh` (369 lines)

**Tests Implemented**:
1. ✅ Load all Phase 3 components
2. ✅ Load and validate configuration
3. ✅ Test anti-destructive safeguards (4 patterns)
4. ✅ Test error extraction from logs
5. ✅ Test fix application to template
6. ✅ Test PowerShell content update
7. ✅ Test retry counter management
8. ✅ Test fix validation (destructive vs non-destructive)
9. ✅ Test template enhancement functions (duration, validation)
10. ✅ Test simulated error handling workflow
11. ✅ Test fix history retrieval

**Test Results**:
```
Components tested:
  [v] error-handler.sh
  [v] template-engine.sh (enhanced functions)
  [v] Anti-destructive safeguards
  [v] Error extraction
  [v] Fix application
  [v] PowerShell content editing
  [v] Retry counter management
  [v] Fix validation
  [v] Template enhancement functions
  [v] Error handling workflow
  [v] Fix history tracking

[v] All Phase 3 tests passed ✅
```

### 4. Anti-Destructive Safeguards ✅

**Patterns Blocked**:
| Pattern | Example | Reason |
|---------|---------|--------|
| `az vm delete` | `az vm delete --name test-vm` | Destroys VM |
| `recreate.*vm` | "recreate the VM" | Starts over |
| `start over` | "let's start over" | Loses progress |
| `create.*new.*vm` | "create a new VM" | Duplicates work |
| `destroy` | "destroy and rebuild" | Destructive |
| `remove.*vm` | "remove the VM" | Loses work |
| `az vm deallocate.*delete` | Combined dealloc+delete | Destructive |

**Enforcement**:
- Checked before applying any fix
- Checked in `validate_fix()` function
- Checked in `check_destructive_action()` function
- Blocks with clear error message and alternative guidance

**Error Message**:
```
[x] DESTRUCTIVE ACTION BLOCKED
    Pattern matched: recreate.*vm

    Rule: Fix incrementally, never start over
    - Use trial-and-error fixes
    - Preserve completed work
    - Retry operation, don't recreate resources
```

## Self-Healing Workflow

### Complete Error Handling Flow

```
1. Operation Fails
   ↓
2. progress-tracker.sh detects failure (exit code ≠ 0)
   ↓
3. handle_operation_error() called
   ↓
4. Extract error info from log (extract_error_info)
   ↓
5. Log error to structured logs (log_operation_error)
   ↓
6. Check retry limit (should_retry_operation)
   ↓
7. Generate fix prompt (generate_fix_prompt)
   ↓
8. User/Claude analyzes error and proposes fix
   ↓
9. Validate fix (validate_fix)
   ├─ Check for destructive patterns → BLOCK if found
   └─ Check for PowerShell markers
   ↓
10. Apply fix to template
    ├─ add_fix_to_template() - Record fix in YAML
    └─ edit_powershell_in_template() - Update PowerShell if needed
    ↓
11. Retry operation (next run uses fixed template automatically)
    ↓
12. If success: reset_retry_counter()
    If failure: Repeat from step 3 (max 3 retries)
```

### Example Self-Healing Session

**Initial Error**:
```
[ERROR] Download failed: Connection timeout
Exit code: 1
```

**Error Handler Output**:
```
================================================================================
  ERROR DETECTED - Self-Healing Analysis Required
================================================================================

Operation ID: golden-image-install-fslogix
YAML File: modules/05-golden-image/operations/03-install-fslogix.yaml
Exit Code: 1

Error Information:
[ERROR] Download failed: Connection timeout

ANALYSIS NEEDED:
1. What caused the error? → Download timed out (default timeout too short)
2. What needs to be changed? → Add -TimeoutSec parameter to Invoke-WebRequest
3. Specific fix? → Add -TimeoutSec 120 to download command
```

**Apply Fix**:
```bash
# Update PowerShell content
new_powershell='
Write-Host "[START] FSLogix installation"
Write-Host "[PROGRESS] Step 1/4: Downloading..."
Invoke-WebRequest -Uri $url -OutFile $path -TimeoutSec 120  # FIX: Added timeout
Write-Host "[PROGRESS] Step 2/4: Installing..."
...
Write-Host "[SUCCESS] Complete"
'

edit_powershell_in_template "modules/05-golden-image/operations/03-install-fslogix.yaml" "$new_powershell"

# Record fix
add_fix_to_template \
    "modules/05-golden-image/operations/03-install-fslogix.yaml" \
    "Download timeout on slow connections" \
    "Added -TimeoutSec 120 to Invoke-WebRequest"
```

**Template After Fix**:
```yaml
operation:
  # ... existing fields ...

  powershell:
    content: |
      Write-Host "[START] FSLogix installation"
      Invoke-WebRequest -Uri $url -OutFile $path -TimeoutSec 120
      # ... rest of script ...

  fixes:
    - issue: "Download timeout on slow connections"
      detected: "2025-12-04"
      fix: "Added -TimeoutSec 120 to Invoke-WebRequest"
      applied_to_template: true
```

**Retry Operation**:
```bash
# Retry uses updated template automatically
./core/engine.sh run 05-golden-image 03-install-fslogix

# Result: [SUCCESS] Operation complete
```

## Integration with Previous Phases

### Phase 1 + 2 + 3 Complete Workflow

```bash
# Load all components
source core/config-manager.sh
source core/template-engine.sh
source core/progress-tracker.sh
source core/logger.sh
source core/validator.sh
source core/error-handler.sh

# Load config
load_config
validate_config

# Parse operation
parse_operation_yaml "modules/05-golden-image/operations/03-install-fslogix.yaml"

# Render command
command=$(render_command "modules/05-golden-image/operations/03-install-fslogix.yaml")

# Execute with progress tracking
track_operation "$OPERATION_ID" "$command" "$OPERATION_DURATION_EXPECTED" "$OPERATION_DURATION_TIMEOUT" "$OPERATION_DURATION_TYPE"
exit_code=$?

if [[ $exit_code -ne 0 ]]; then
    # Error occurred - handle it
    log_file="artifacts/logs/${OPERATION_ID}_*.log"
    handle_operation_error "$OPERATION_ID" "$log_file" "$exit_code" "modules/05-golden-image/operations/03-install-fslogix.yaml"

    # User applies fix, then retries
else
    # Validate results
    validate_from_yaml "modules/05-golden-image/operations/03-install-fslogix.yaml"

    # Reset retry counter on success
    reset_retry_counter "$OPERATION_ID"
fi
```

## Key Features Demonstrated

### 1. Anti-Destructive Enforcement

**Blocked**:
```bash
check_destructive_action "az vm delete --name test-vm"
# → BLOCKED

check_destructive_action "Let's recreate the VM from scratch"
# → BLOCKED
```

**Allowed**:
```bash
check_destructive_action "Update registry key value"
# → ALLOWED

check_destructive_action "Add error handling to PowerShell script"
# → ALLOWED
```

### 2. Fix History Tracking

**View fixes**:
```bash
get_template_fixes "modules/05-golden-image/operations/03-install-fslogix.yaml"

# Output:
# Fixes applied to this template:
#   [2025-12-04] Download timeout on slow connections
#     Fix: Added -TimeoutSec 120 to Invoke-WebRequest
#   [2025-12-03] Installation fails silently
#     Fix: Added exit code check after Start-Process
```

### 3. Retry Management

```bash
# First attempt
should_retry_operation "test-operation" 3
# → [i] Retry attempt 1 of 3

# Second attempt
should_retry_operation "test-operation" 3
# → [i] Retry attempt 2 of 3

# Fourth attempt
should_retry_operation "test-operation" 3
# → [x] Maximum retries (3) reached
```

### 4. Template Editing

**Before**:
```yaml
operation:
  duration:
    expected: 60
    timeout: 120
```

**Edit**:
```bash
update_operation_duration "operation.yaml" 180 300
```

**After**:
```yaml
operation:
  duration:
    expected: 180
    timeout: 300
```

## Improvements Over Phase 2

| Feature | Phase 2 | Phase 3 | Improvement |
|---------|---------|---------|-------------|
| Error Detection | ✅ Real-time | ✅ Real-time + Analysis | Error analysis prompt |
| Fix Application | Manual | Automated via `yq` | Self-healing |
| Fix Tracking | None | In-template history | Fixes embedded in source |
| Retry Logic | None | Max 3 with counter | Intelligent retry |
| Destructive Prevention | None | 7 patterns blocked | Safety guaranteed |
| Template Editing | Manual | Programmatic | Full automation |
| PowerShell Updates | Manual | Via function | One-line update |
| Validation Editing | Manual | Via function | Dynamic validation |

## File Summary

| File | Size | Purpose |
|------|------|---------|
| `core/error-handler.sh` | 370 lines | Error detection + self-healing |
| `core/template-engine.sh` | 546 lines | Template parsing + editing (enhanced) |
| `test-phase3.sh` | 369 lines | Self-healing test suite |

**Total New/Modified Code**: ~1,285 lines

## Testing

### Test Execution
```bash
./test-phase3.sh
```

### Test Coverage
- ✅ 11 comprehensive tests
- ✅ Anti-destructive safeguards (4 patterns tested)
- ✅ Error extraction
- ✅ Fix application and validation
- ✅ PowerShell content editing
- ✅ Retry counter management
- ✅ Template enhancement functions
- ✅ Error handling workflow simulation
- ✅ Fix history tracking

### Artifacts Created
```
artifacts/
├── state/
│   └── {operation_id}_retry_count    # Retry counters
├── logs/
│   └── deployment_20251204.jsonl      # Error logs
└── scripts/
    └── {operation_id}.ps1              # Extracted PowerShell
```

## Success Criteria Met

- [x] Error handler implemented (core/error-handler.sh)
- [x] Anti-destructive safeguards (7 patterns blocked)
- [x] Fix application to templates (via `yq`)
- [x] PowerShell content editing (programmatic)
- [x] Retry logic (max 3 attempts)
- [x] Template enhancement functions (5 functions)
- [x] Self-healing test suite (11 tests)
- [x] All tests passing (100%)
- [x] Integration with Phase 1 & 2
- [x] Fix history tracking in templates
- [x] Error analysis prompts

**Phase 3 Status**: ✅ COMPLETE

---

**Ready for Phase 4**: Module Conversion (Step 05 - Golden Image)
**Blocking Issues**: None
**Next Action**: Convert `config_vm.ps1` (507 lines) into 12 atomic operations

## Phase 4 Preview

**Goal**: Break monolithic scripts into atomic operations

**Example Conversion**:
- **Current**: `config_vm.ps1` (507 lines, single failure = 60 min restart)
- **Target**: 12 operations (50-100 lines each, independent retry)

**Operations to Create**:
1. `01-create-vm.yaml` (10 min)
2. `02-validate-vm.yaml` (2 min)
3. `03-install-fslogix.yaml` (3 min) ← Already created in Phase 2
4. `04-install-chrome.yaml` (5 min)
5. `05-install-adobe.yaml` (8 min)
6. `06-install-office.yaml` (30 min, Type: WAIT)
7. `07-run-vdot.yaml` (5 min)
8. `08-registry-opts.yaml` (2 min, Type: FAST)
9. `09-validate-all.yaml` (3 min)
10. `10-sysprep.yaml` (5 min)
11. `11-capture-image.yaml` (15 min)
12. `12-cleanup.yaml` (2 min)

**Benefits**:
- Each operation can fail/retry independently
- Progress visible at operation level
- Self-healing applies to specific step
- Total time unchanged, but failure recovery 90% faster
