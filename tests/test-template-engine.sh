#!/bin/bash
# ==============================================================================
# test-template-engine.sh - Test Suite for Template Engine
# ==============================================================================

# IMPORTANT: Not using -e or -u flags because we need to test failure cases
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Disable exit on error and nounset for test script
set +e
set +u

# Set up test environment
export PROJECT_ROOT

# Create test directory
TEST_DIR="${PROJECT_ROOT}/tests/test-data/template-engine"
mkdir -p "$TEST_DIR"
mkdir -p "$TEST_DIR/operations"
mkdir -p "$TEST_DIR/artifacts/scripts"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test results
test_pass() {
    local test_name="$1"
    echo "✓ PASS: $test_name"
    ((TESTS_PASSED++))
    ((TESTS_RUN++))
}

test_fail() {
    local test_name="$1"
    local reason="$2"
    echo "✗ FAIL: $test_name - $reason"
    ((TESTS_FAILED++))
    ((TESTS_RUN++))
}

# ==============================================================================
# SETUP AND TEARDOWN
# ==============================================================================

setup_test_files() {
    # Create test config.yaml for pre-parsing tests
    cat > "${PROJECT_ROOT}/config.yaml" <<'EOF'
networking:
  private_dns:
    enabled: true
    zones:
      - "privatelink.blob.core.windows.net"
      - "privatelink.file.core.windows.net"

azure:
  subscription_id: "00000000-0000-0000-0000-000000000000"
  location: "centralus"
EOF

    # Set environment variables for substitution tests
    export AZURE_RESOURCE_GROUP="test-rg"
    export AZURE_LOCATION="eastus"
    export STORAGE_ACCOUNT_NAME="teststorage123"
    export NETWORKING_VNET_NAME="test-vnet"
}

cleanup_test_files() {
    rm -rf "$TEST_DIR"
    rm -f "${PROJECT_ROOT}/config.yaml"
    unset AZURE_RESOURCE_GROUP AZURE_LOCATION STORAGE_ACCOUNT_NAME NETWORKING_VNET_NAME
}

# Source the template engine
source "${PROJECT_ROOT}/core/template-engine.sh"

# ==============================================================================
# TEST: parse_operation_yaml
# ==============================================================================

test_parse_operation_yaml_basic() {
    local test_file="${TEST_DIR}/operations/test-parse-basic.yaml"
    cat > "$test_file" <<'EOF'
operation:
  id: "test-parse-basic"
  name: "Test Parse Basic"
  description: "Basic parsing test"
  duration:
    expected: 120
    timeout: 300
    type: "NORMAL"

  template:
    type: "bash"
    command: "echo 'test'"

  powershell:
    content: |
      Write-Host "Test PowerShell"
EOF

    if parse_operation_yaml "$test_file" 2>/dev/null; then
        if [[ "$OPERATION_ID" == "test-parse-basic" ]] && \
           [[ "$OPERATION_NAME" == "Test Parse Basic" ]] && \
           [[ "$OPERATION_DURATION_EXPECTED" == "120" ]] && \
           [[ "$TEMPLATE_TYPE" == "bash" ]]; then
            test_pass "parse_operation_yaml (basic)"
        else
            test_fail "parse_operation_yaml (basic)" "Parsed values incorrect"
        fi
    else
        test_fail "parse_operation_yaml (basic)" "Failed to parse"
    fi
}

test_parse_operation_yaml_capability_format() {
    local test_file="${TEST_DIR}/operations/test-parse-capability.yaml"
    cat > "$test_file" <<'EOF'
operation:
  id: "test-capability"
  name: "Test Capability Format"
  capability: "networking"
  operation_mode: "create"
  resource_type: "Microsoft.Network/virtualNetworks"

  duration:
    expected: 60
    timeout: 120
    type: "FAST"

  idempotency:
    enabled: true
    skip_if_exists: true

  rollback:
    enabled: true

  template:
    type: "az-cli"
    command: "az network vnet create"
EOF

    if parse_operation_yaml "$test_file" 2>/dev/null; then
        if [[ "$OPERATION_CAPABILITY" == "networking" ]] && \
           [[ "$OPERATION_MODE" == "create" ]] && \
           [[ "$IDEMPOTENCY_ENABLED" == "true" ]] && \
           [[ "$ROLLBACK_ENABLED" == "true" ]]; then
            test_pass "parse_operation_yaml (capability format)"
        else
            test_fail "parse_operation_yaml (capability format)" "Capability fields not parsed correctly"
        fi
    else
        test_fail "parse_operation_yaml (capability format)" "Failed to parse"
    fi
}

test_parse_operation_yaml_missing_file() {
    if ! parse_operation_yaml "/nonexistent/file.yaml" 2>/dev/null; then
        test_pass "parse_operation_yaml (missing file)"
    else
        test_fail "parse_operation_yaml (missing file)" "Should fail for missing file"
    fi
}

# ==============================================================================
# TEST: preparse_config_values
# ==============================================================================

test_preparse_config_values() {
    local test_file="${TEST_DIR}/operations/test-preparse.yaml"
    cat > "$test_file" <<'EOF'
operation:
  id: "test-preparse"
  name: "Test Pre-parse"

  template:
    type: "bash"
    command: "echo 'test'"
    pre_parse:
      - source: ".networking.private_dns.enabled"
        variable: "PRIVATE_DNS_ENABLED"
      - source: ".networking.private_dns.zones"
        variable: "DNS_ZONES_JSON"
        format: "json"
EOF

    if preparse_config_values "$test_file" 2>/dev/null; then
        if [[ "$PRIVATE_DNS_ENABLED" == "true" ]] && \
           [[ -n "$DNS_ZONES_JSON" ]]; then
            test_pass "preparse_config_values (success)"
        else
            test_fail "preparse_config_values (success)" "Pre-parsed values not set correctly"
        fi
    else
        test_fail "preparse_config_values (success)" "Failed to pre-parse"
    fi

    unset PRIVATE_DNS_ENABLED DNS_ZONES_JSON
}

test_preparse_config_values_no_section() {
    local test_file="${TEST_DIR}/operations/test-no-preparse.yaml"
    cat > "$test_file" <<'EOF'
operation:
  id: "test-no-preparse"
  name: "Test No Pre-parse"

  template:
    type: "bash"
    command: "echo 'test'"
EOF

    if preparse_config_values "$test_file" 2>/dev/null; then
        test_pass "preparse_config_values (no section)"
    else
        test_fail "preparse_config_values (no section)" "Should succeed with no pre_parse section"
    fi
}

# ==============================================================================
# TEST: substitute_variables
# ==============================================================================

test_substitute_variables_simple() {
    local template='Resource Group: {{AZURE_RESOURCE_GROUP}}, Location: {{AZURE_LOCATION}}'
    local result
    result=$(substitute_variables "$template")

    if [[ "$result" == *"test-rg"* ]] && [[ "$result" == *"eastus"* ]]; then
        test_pass "substitute_variables (simple)"
    else
        test_fail "substitute_variables (simple)" "Variables not substituted correctly: $result"
    fi
}

test_substitute_variables_multiple() {
    local template='Storage: {{STORAGE_ACCOUNT_NAME}}, VNet: {{NETWORKING_VNET_NAME}}'
    local result
    result=$(substitute_variables "$template")

    if [[ "$result" == *"teststorage123"* ]] && [[ "$result" == *"test-vnet"* ]]; then
        test_pass "substitute_variables (multiple)"
    else
        test_fail "substitute_variables (multiple)" "Multiple variables not substituted: $result"
    fi
}

test_substitute_variables_project_root() {
    local template='Path: {{PROJECT_ROOT}}/config.yaml'
    local result
    result=$(substitute_variables "$template")

    if [[ "$result" == *"$PROJECT_ROOT/config.yaml"* ]]; then
        test_pass "substitute_variables (project_root)"
    else
        test_fail "substitute_variables (project_root)" "PROJECT_ROOT not substituted: $result"
    fi
}

test_substitute_variables_missing() {
    unset UNDEFINED_VARIABLE
    local template='Value: {{UNDEFINED_VARIABLE}}'
    local result
    result=$(substitute_variables "$template")

    # Should replace with empty string
    if [[ "$result" == "Value: " ]]; then
        test_pass "substitute_variables (missing)"
    else
        test_fail "substitute_variables (missing)" "Missing variable not handled: $result"
    fi
}

# ==============================================================================
# TEST: extract_powershell_script
# ==============================================================================

test_extract_powershell_script_content() {
    local test_file="${TEST_DIR}/operations/test-ps-content.yaml"
    cat > "$test_file" <<'EOF'
operation:
  id: "test-ps-content"
  name: "Test PowerShell Content"

  template:
    type: "powershell-direct"
    command: "pwsh -File script.ps1"

  powershell:
    content: |
      Write-Host "Test PowerShell Script"
      exit 0
EOF

    parse_operation_yaml "$test_file" >/dev/null 2>&1

    local ps_script
    ps_script=$(extract_powershell_script "$test_file" 2>/dev/null)

    if [[ -n "$ps_script" ]] && [[ -f "$ps_script" ]]; then
        if grep -q "Test PowerShell Script" "$ps_script"; then
            test_pass "extract_powershell_script (content)"
        else
            test_fail "extract_powershell_script (content)" "PowerShell content not extracted correctly"
        fi
    else
        test_fail "extract_powershell_script (content)" "PowerShell script not created"
    fi
}

test_extract_powershell_script_none() {
    local test_file="${TEST_DIR}/operations/test-no-ps.yaml"
    cat > "$test_file" <<'EOF'
operation:
  id: "test-no-ps"
  name: "Test No PowerShell"

  template:
    type: "bash"
    command: "echo 'no powershell'"
EOF

    parse_operation_yaml "$test_file" >/dev/null 2>&1

    local ps_script
    ps_script=$(extract_powershell_script "$test_file" 2>/dev/null)

    if [[ -z "$ps_script" ]]; then
        test_pass "extract_powershell_script (none)"
    else
        test_fail "extract_powershell_script (none)" "Should return empty for bash-only operations"
    fi
}

# ==============================================================================
# TEST: render_command
# ==============================================================================

test_render_command_bash() {
    local test_file="${TEST_DIR}/operations/test-render-bash.yaml"
    cat > "$test_file" <<'EOF'
operation:
  id: "test-render-bash"
  name: "Test Render Bash"

  template:
    type: "bash"
    command: "echo 'RG: {{AZURE_RESOURCE_GROUP}}'"
EOF

    local result
    result=$(render_command "$test_file" 2>/dev/null)

    if [[ "$result" == *"test-rg"* ]]; then
        test_pass "render_command (bash)"
    else
        test_fail "render_command (bash)" "Command not rendered correctly: $result"
    fi
}

test_render_command_powershell_direct() {
    local test_file="${TEST_DIR}/operations/test-render-ps-direct.yaml"
    cat > "$test_file" <<'EOF'
operation:
  id: "test-render-ps-direct"
  name: "Test Render PowerShell Direct"

  template:
    type: "powershell-direct"
    command: ""

  powershell:
    content: |
      Write-Host "Direct PowerShell"
EOF

    local result
    result=$(render_command "$test_file" 2>/dev/null)

    if [[ "$result" == *"pwsh"* ]] && [[ "$result" == *"powershell-direct"* ]]; then
        test_pass "render_command (powershell-direct)"
    else
        test_fail "render_command (powershell-direct)" "PowerShell direct command not rendered: $result"
    fi
}

# ==============================================================================
# TEST: validate_prerequisites
# ==============================================================================

test_validate_prerequisites_none() {
    local test_file="${TEST_DIR}/operations/test-no-prereqs.yaml"
    cat > "$test_file" <<'EOF'
operation:
  id: "test-no-prereqs"
  name: "Test No Prerequisites"

  template:
    type: "bash"
    command: "echo 'test'"
EOF

    if validate_prerequisites "$test_file" 2>/dev/null; then
        test_pass "validate_prerequisites (none)"
    else
        test_fail "validate_prerequisites (none)" "Should succeed with no prerequisites"
    fi
}

test_validate_prerequisites_with_requires() {
    # Create state.json for prerequisite checking
    cat > "${PROJECT_ROOT}/state.json" <<'EOF'
{
  "operations": {
    "networking-vnet-create": {
      "status": "completed"
    }
  }
}
EOF

    local test_file="${TEST_DIR}/operations/test-with-prereqs.yaml"
    cat > "$test_file" <<'EOF'
operation:
  id: "test-with-prereqs"
  name: "Test With Prerequisites"

  requires:
    - operation: "networking-vnet-create"
      status: "completed"

  template:
    type: "bash"
    command: "echo 'test'"
EOF

    if validate_prerequisites "$test_file" 2>/dev/null; then
        test_pass "validate_prerequisites (with requires)"
    else
        test_fail "validate_prerequisites (with requires)" "Should succeed when prerequisites met"
    fi

    rm -f "${PROJECT_ROOT}/state.json"
}

# ==============================================================================
# TEST: edit_powershell_in_template
# ==============================================================================

test_edit_powershell_in_template() {
    local test_file="${TEST_DIR}/operations/test-edit-ps.yaml"
    cat > "$test_file" <<'EOF'
operation:
  id: "test-edit-ps"
  name: "Test Edit PowerShell"

  template:
    type: "powershell-direct"
    command: "pwsh"

  powershell:
    content: |
      Write-Host "Original Content"
EOF

    local new_content='Write-Host "Updated Content"'

    if edit_powershell_in_template "$test_file" "$new_content" 2>/dev/null; then
        local updated_content
        updated_content=$(yq e '.operation.powershell.content' "$test_file")

        if [[ "$updated_content" == *"Updated Content"* ]]; then
            test_pass "edit_powershell_in_template (success)"
        else
            test_fail "edit_powershell_in_template (success)" "Content not updated correctly"
        fi
    else
        test_fail "edit_powershell_in_template (success)" "Failed to update content"
    fi
}

# ==============================================================================
# TEST: add_fix_to_template
# ==============================================================================

test_add_fix_to_template() {
    local test_file="${TEST_DIR}/operations/test-add-fix.yaml"
    cat > "$test_file" <<'EOF'
operation:
  id: "test-add-fix"
  name: "Test Add Fix"

  template:
    type: "bash"
    command: "echo 'test'"
EOF

    if add_fix_to_template "$test_file" "Test issue" "Test fix description" "2025-01-01" 2>/dev/null; then
        local fixes
        fixes=$(yq e '.operation.fixes | length' "$test_file")

        if [[ "$fixes" -eq 1 ]]; then
            local issue
            issue=$(yq e '.operation.fixes[0].issue' "$test_file")

            if [[ "$issue" == "Test issue" ]]; then
                test_pass "add_fix_to_template (success)"
            else
                test_fail "add_fix_to_template (success)" "Fix issue not recorded correctly"
            fi
        else
            test_fail "add_fix_to_template (success)" "Fix not added"
        fi
    else
        test_fail "add_fix_to_template (success)" "Failed to add fix"
    fi
}

# ==============================================================================
# TEST: update_operation_duration
# ==============================================================================

test_update_operation_duration() {
    local test_file="${TEST_DIR}/operations/test-update-duration.yaml"
    cat > "$test_file" <<'EOF'
operation:
  id: "test-update-duration"
  name: "Test Update Duration"

  duration:
    expected: 60
    timeout: 120
    type: "FAST"

  template:
    type: "bash"
    command: "echo 'test'"
EOF

    if update_operation_duration "$test_file" 180 360 2>/dev/null; then
        local expected
        local timeout
        expected=$(yq e '.operation.duration.expected' "$test_file")
        timeout=$(yq e '.operation.duration.timeout' "$test_file")

        if [[ "$expected" -eq 180 ]] && [[ "$timeout" -eq 360 ]]; then
            test_pass "update_operation_duration (success)"
        else
            test_fail "update_operation_duration (success)" "Duration not updated correctly"
        fi
    else
        test_fail "update_operation_duration (success)" "Failed to update duration"
    fi
}

# ==============================================================================
# TEST: add_validation_check
# ==============================================================================

test_add_validation_check_file_exists() {
    local test_file="${TEST_DIR}/operations/test-add-validation.yaml"
    cat > "$test_file" <<'EOF'
operation:
  id: "test-add-validation"
  name: "Test Add Validation"

  template:
    type: "bash"
    command: "echo 'test'"
EOF

    if add_validation_check "$test_file" "file_exists" "C:\\test\\file.txt" 2>/dev/null; then
        local enabled
        local check_type
        enabled=$(yq e '.operation.validation.enabled' "$test_file")
        check_type=$(yq e '.operation.validation.checks[0].type' "$test_file")

        if [[ "$enabled" == "true" ]] && [[ "$check_type" == "file_exists" ]]; then
            test_pass "add_validation_check (file_exists)"
        else
            test_fail "add_validation_check (file_exists)" "Validation check not added correctly"
        fi
    else
        test_fail "add_validation_check (file_exists)" "Failed to add validation check"
    fi
}

# ==============================================================================
# RUN ALL TESTS
# ==============================================================================

echo "=============================================="
echo "Template Engine Test Suite"
echo "=============================================="
echo ""

setup_test_files

echo "Testing YAML Parsing..."
test_parse_operation_yaml_basic
test_parse_operation_yaml_capability_format
test_parse_operation_yaml_missing_file

echo ""
echo "Testing Pre-parsing..."
test_preparse_config_values
test_preparse_config_values_no_section

echo ""
echo "Testing Variable Substitution..."
test_substitute_variables_simple
test_substitute_variables_multiple
test_substitute_variables_project_root
test_substitute_variables_missing

echo ""
echo "Testing PowerShell Script Extraction..."
test_extract_powershell_script_content
test_extract_powershell_script_none

echo ""
echo "Testing Command Rendering..."
test_render_command_bash
test_render_command_powershell_direct

echo ""
echo "Testing Prerequisites Validation..."
test_validate_prerequisites_none
test_validate_prerequisites_with_requires

echo ""
echo "Testing Template Modification..."
test_edit_powershell_in_template
test_add_fix_to_template
test_update_operation_duration
test_add_validation_check_file_exists

cleanup_test_files

echo ""
echo "=============================================="
echo "Test Results"
echo "=============================================="
echo "Total Tests: $TESTS_RUN"
echo "Passed: $TESTS_PASSED"
echo "Failed: $TESTS_FAILED"
echo ""

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo "✓ All tests passed!"
    exit 0
else
    echo "✗ Some tests failed"
    exit 1
fi
