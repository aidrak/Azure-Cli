#!/bin/bash
# ==============================================================================
# Phase 2 Component Tests
# ==============================================================================
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_ROOT"

echo "========================================================================"
echo "  Phase 2 Component Tests"
echo "========================================================================"
echo ""

# Test 1: Load all Phase 2 components
echo "[Test 1] Loading Phase 2 components..."
source core/config-manager.sh
source core/template-engine.sh
source core/progress-tracker.sh
source core/logger.sh
source core/validator.sh

echo "[v] All components loaded successfully"
echo ""

# Test 2: Load configuration
echo "[Test 2] Loading configuration..."
load_config
validate_config
echo "[v] Configuration loaded and validated"
echo ""

# Test 3: Test logger
echo "[Test 3] Testing structured logger..."
log_info "Test info message" "test-operation"
log_warn "Test warning message" "test-operation"
log_success "Test success message" "test-operation"
echo "[v] Logger test complete"
echo ""

# Test 4: Test operation lifecycle logging
echo "[Test 4] Testing operation lifecycle logging..."
log_operation_start "test-op-001" "Test Operation" 60
sleep 2
log_operation_progress "test-op-001" "Halfway through" 30
sleep 2
log_operation_complete "test-op-001" 62 0 60
echo "[v] Operation lifecycle test complete"
echo ""

# Test 5: Test progress tracking with simple command
echo "[Test 5] Testing progress tracker with echo command..."
cat > /tmp/test-progress.sh <<'EOF'
#!/bin/bash
echo "[START] Test operation: $(date +%H:%M:%S)"
sleep 2
echo "[PROGRESS] Step 1/3: Starting..."
sleep 2
echo "[PROGRESS] Step 2/3: Processing..."
sleep 2
echo "[PROGRESS] Step 3/3: Finishing..."
sleep 2
echo "[VALIDATE] Checking results..."
sleep 1
echo "[SUCCESS] Test complete"
exit 0
EOF
chmod +x /tmp/test-progress.sh

track_operation "test-progress-001" "/tmp/test-progress.sh" 10 20 "FAST"
echo "[v] Progress tracking test complete"
echo ""

# Test 6: Test checkpoint creation
echo "[Test 6] Testing checkpoint creation..."
create_checkpoint "test-op-001" "completed" 62 "artifacts/logs/test-op-001.log"
echo "[v] Checkpoint test complete"
echo ""

# Test 7: Query structured logs
echo "[Test 7] Querying structured logs..."
query_logs "test-operation" "INFO"
echo "[v] Log query test complete"
echo ""

# Test 8: Parse operation YAML template
echo "[Test 8] Testing template parsing..."
if [[ -f "modules/05-golden-image/operations/03-install-fslogix.yaml" ]]; then
    parse_operation_yaml "modules/05-golden-image/operations/03-install-fslogix.yaml"
    echo "  Operation ID: $OPERATION_ID"
    echo "  Operation Name: $OPERATION_NAME"
    echo "  Expected Duration: ${OPERATION_DURATION_EXPECTED}s"
    echo "  Timeout: ${OPERATION_DURATION_TIMEOUT}s"
    echo "  Type: $OPERATION_DURATION_TYPE"
    echo "[v] Template parsing test complete"
else
    echo "[!] Example operation template not found, skipping"
fi
echo ""

# Test 9: Variable substitution
echo "[Test 9] Testing variable substitution..."
test_template="Resource Group: {{AZURE_RESOURCE_GROUP}}, Location: {{AZURE_LOCATION}}"
result=$(substitute_variables "$test_template")
echo "  Input: $test_template"
echo "  Output: $result"
echo "[v] Variable substitution test complete"
echo ""

# Summary
echo "========================================================================"
echo "  Phase 2 Tests Complete"
echo "========================================================================"
echo ""
echo "Components tested:"
echo "  [v] config-manager.sh"
echo "  [v] template-engine.sh"
echo "  [v] progress-tracker.sh"
echo "  [v] logger.sh"
echo "  [v] validator.sh"
echo ""
echo "Artifacts created:"
echo "  - Structured logs: artifacts/logs/deployment_$(date +%Y%m%d).jsonl"
echo "  - Progress logs: artifacts/logs/test-progress-001_*.log"
echo "  - Checkpoints: artifacts/checkpoint_test-op-001.json"
echo ""
echo "Next steps:"
echo "  1. Review structured logs: cat artifacts/logs/deployment_$(date +%Y%m%d).jsonl | jq"
echo "  2. Review progress log: ls -la artifacts/logs/test-progress-001_*.log"
echo "  3. Review checkpoint: cat artifacts/checkpoint_test-op-001.json | jq"
echo ""
