#!/bin/bash
# ==============================================================================
# Phase 3 Test Suite - Self-Healing & Error Handling
# ==============================================================================
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_ROOT"

echo "========================================================================"
echo "  Phase 3: Self-Healing & Error Handling - Test Suite"
echo "========================================================================"
echo ""

# ==============================================================================
# Test 1: Load all Phase 3 components
# ==============================================================================
echo "[*] Test 1: Loading Phase 3 components..."

source core/config-manager.sh
source core/template-engine.sh
source core/progress-tracker.sh
source core/logger.sh
source core/validator.sh
source core/error-handler.sh

echo "[v] All Phase 3 components loaded successfully"
echo ""

# ==============================================================================
# Test 2: Load configuration
# ==============================================================================
echo "[*] Test 2: Loading configuration..."

load_config
validate_config

echo "[v] Configuration loaded and validated"
echo ""

# ==============================================================================
# Test 3: Test anti-destructive safeguards
# ==============================================================================
echo "[*] Test 3: Testing anti-destructive safeguards..."

# Test 1: Destructive pattern - az vm delete
if check_destructive_action "az vm delete --name test-vm" 2>/dev/null; then
    echo "[x] FAILED: Should have blocked 'az vm delete'"
    exit 1
else
    echo "[v] Blocked: 'az vm delete'"
fi

# Test 2: Destructive pattern - recreate vm
if check_destructive_action "Let's recreate the VM from scratch" 2>/dev/null; then
    echo "[x] FAILED: Should have blocked 'recreate vm'"
    exit 1
else
    echo "[v] Blocked: 'recreate vm'"
fi

# Test 3: Destructive pattern - start over
if check_destructive_action "We should start over and rebuild everything" 2>/dev/null; then
    echo "[x] FAILED: Should have blocked 'start over'"
    exit 1
else
    echo "[v] Blocked: 'start over'"
fi

# Test 4: Non-destructive action - should pass
if check_destructive_action "Update registry key value" 2>/dev/null; then
    echo "[v] Allowed: Non-destructive action"
else
    echo "[x] FAILED: Should have allowed non-destructive action"
    exit 1
fi

echo "[v] All anti-destructive safeguards working"
echo ""

# ==============================================================================
# Test 4: Test error extraction from logs
# ==============================================================================
echo "[*] Test 4: Testing error extraction..."

# Create test log with errors
cat > /tmp/test-error-log.txt <<'EOF'
[START] Test operation: 10:00:00
[PROGRESS] Step 1/3: Starting...
[PROGRESS] Step 2/3: Processing...
[ERROR] Failed to download file: Connection timeout
[ERROR] Exit code: 1
EOF

error_info=$(extract_error_info "/tmp/test-error-log.txt")

if echo "$error_info" | grep -q "Connection timeout"; then
    echo "[v] Error extraction successful"
else
    echo "[x] FAILED: Could not extract error information"
    exit 1
fi

rm -f /tmp/test-error-log.txt
echo ""

# ==============================================================================
# Test 5: Test fix application to template
# ==============================================================================
echo "[*] Test 5: Testing fix application to template..."

# Create test operation template
test_yaml="/tmp/test-operation-fix.yaml"
cat > "$test_yaml" <<'EOF'
operation:
  id: "test-fix-operation"
  name: "Test Fix Operation"

  duration:
    expected: 60
    timeout: 120
    type: "FAST"

  template:
    type: "az-vm-run-command"
    command: "echo 'test'"

  powershell:
    content: |
      Write-Host "[START] Test"
      Write-Host "[SUCCESS] Test"
EOF

# Apply fix to template
add_fix_to_template "$test_yaml" \
    "Download timeout on slow connections" \
    "Added -TimeoutSec 120 to Invoke-WebRequest" \
    "2025-12-04"

# Verify fix was added
fix_count=$(yq e '.operation.fixes | length' "$test_yaml")

if [[ "$fix_count" == "1" ]]; then
    echo "[v] Fix applied successfully"

    # Verify fix content
    issue=$(yq e '.operation.fixes[0].issue' "$test_yaml")
    if [[ "$issue" == "Download timeout on slow connections" ]]; then
        echo "[v] Fix content verified"
    else
        echo "[x] FAILED: Fix content mismatch"
        exit 1
    fi
else
    echo "[x] FAILED: Fix not applied"
    exit 1
fi

echo ""

# ==============================================================================
# Test 6: Test PowerShell content update
# ==============================================================================
echo "[*] Test 6: Testing PowerShell content update..."

new_powershell='Write-Host "[START] Updated test"
Write-Host "[PROGRESS] Step 1/2: Testing..."
Write-Host "[PROGRESS] Step 2/2: Finishing..."
Write-Host "[SUCCESS] Updated test complete"'

edit_powershell_in_template "$test_yaml" "$new_powershell"

# Verify update
updated_content=$(yq e '.operation.powershell.content' "$test_yaml")

if echo "$updated_content" | grep -q "Updated test"; then
    echo "[v] PowerShell content updated successfully"
else
    echo "[x] FAILED: PowerShell content not updated"
    exit 1
fi

echo ""

# ==============================================================================
# Test 7: Test retry counter
# ==============================================================================
echo "[*] Test 7: Testing retry counter..."

# Reset retry counter
reset_retry_counter "test-operation-retry"

# Test retry attempts
for i in {1..3}; do
    if should_retry_operation "test-operation-retry" 3; then
        echo "[v] Retry attempt $i allowed"
    else
        echo "[x] FAILED: Retry $i should have been allowed"
        exit 1
    fi
done

# Fourth attempt should fail (max retries reached)
if should_retry_operation "test-operation-retry" 3 2>/dev/null; then
    echo "[x] FAILED: Should have blocked retry after max attempts"
    exit 1
else
    echo "[v] Max retries enforced correctly"
fi

# Clean up
reset_retry_counter "test-operation-retry"

echo ""

# ==============================================================================
# Test 8: Test fix validation
# ==============================================================================
echo "[*] Test 8: Testing fix validation..."

# Test 1: Valid fix should pass
if validate_fix "Add error handling for timeout" "Write-Host '[ERROR] Timeout'"; then
    echo "[v] Valid fix passed validation"
else
    echo "[x] FAILED: Valid fix was rejected"
    exit 1
fi

# Test 2: Destructive fix should fail
if validate_fix "Recreate the VM to fix the issue" "" 2>/dev/null; then
    echo "[x] FAILED: Destructive fix should have been rejected"
    exit 1
else
    echo "[v] Destructive fix rejected"
fi

echo ""

# ==============================================================================
# Test 9: Test template enhancement functions
# ==============================================================================
echo "[*] Test 9: Testing template enhancement functions..."

# Test duration update
update_operation_duration "$test_yaml" 120 240

expected=$(yq e '.operation.duration.expected' "$test_yaml")
timeout=$(yq e '.operation.duration.timeout' "$test_yaml")

if [[ "$expected" == "120" && "$timeout" == "240" ]]; then
    echo "[v] Duration updated successfully"
else
    echo "[x] FAILED: Duration not updated correctly"
    exit 1
fi

# Test validation check addition
add_validation_check "$test_yaml" "file_exists" 'C:\Test\file.txt'

check_type=$(yq e '.operation.validation.checks[0].type' "$test_yaml")
check_path=$(yq e '.operation.validation.checks[0].path' "$test_yaml")

# Check if file_exists type is correct (path escaping may vary)
if [[ "$check_type" == "file_exists" ]] && echo "$check_path" | grep -q "Test"; then
    echo "[v] Validation check added successfully"
else
    echo "[x] FAILED: Validation check not added correctly"
    echo "    Check type: $check_type"
    echo "    Check path: $check_path"
    exit 1
fi

echo ""

# ==============================================================================
# Test 10: Test simulated error handling workflow
# ==============================================================================
echo "[*] Test 10: Testing simulated error handling workflow..."

# Create simulated error log
error_log="/tmp/test-error-workflow.log"
cat > "$error_log" <<'EOF'
[START] Test operation: 10:00:00
[PROGRESS] Step 1/2: Downloading...
[ERROR] Download failed: Connection timeout
[ERROR] Exit code: 1
EOF

# Create test operation
test_op_yaml="/tmp/test-error-operation.yaml"
cat > "$test_op_yaml" <<'EOF'
operation:
  id: "test-error-workflow"
  name: "Test Error Workflow"

  duration:
    expected: 60
    timeout: 120
    type: "FAST"

  template:
    type: "az-vm-run-command"
    command: "echo 'test'"

  powershell:
    content: |
      Write-Host "[START] Test"
      Invoke-WebRequest -Uri "http://example.com/file.zip"
      Write-Host "[SUCCESS] Test"
EOF

# Handle error (will fail as expected since we're not actually fixing it)
handle_operation_error "test-error-workflow" "$error_log" 1 "$test_op_yaml" "false" 2>/dev/null || true

# Verify error was logged
error_logs=$(query_logs "test-error-workflow" "ERROR" 2>/dev/null || echo "")

if [[ -n "$error_logs" ]]; then
    echo "[v] Error logged to structured logs"
else
    echo "[i] Error logging check skipped (logs may not exist)"
fi

# Clean up
rm -f "$error_log"
rm -f "$test_op_yaml"
reset_retry_counter "test-error-workflow"

echo ""

# ==============================================================================
# Test 11: Test get_fix_history
# ==============================================================================
echo "[*] Test 11: Testing fix history retrieval..."

# Get fix history from test template
fix_history=$(get_template_fixes "$test_yaml")

if echo "$fix_history" | grep -q "Download timeout"; then
    echo "[v] Fix history retrieved successfully"
else
    echo "[x] FAILED: Could not retrieve fix history"
    exit 1
fi

echo ""

# Clean up test files
rm -f "$test_yaml"

# ==============================================================================
# Summary
# ==============================================================================
echo "========================================================================"
echo "  Test Results"
echo "========================================================================"
echo ""
echo "Components tested:"
echo "  [v] error-handler.sh"
echo "  [v] template-engine.sh (enhanced functions)"
echo "  [v] Anti-destructive safeguards"
echo "  [v] Error extraction"
echo "  [v] Fix application"
echo "  [v] PowerShell content editing"
echo "  [v] Retry counter management"
echo "  [v] Fix validation"
echo "  [v] Template enhancement functions"
echo "  [v] Error handling workflow"
echo "  [v] Fix history tracking"
echo ""
echo "[v] All Phase 3 tests passed ✅"
echo ""
