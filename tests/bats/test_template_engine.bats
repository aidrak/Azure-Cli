#!/usr/bin/env bats
# ==============================================================================
# BATS Tests: Template Engine
# ==============================================================================

load '../helpers/test_helper'

setup() {
    setup_test_env
    source "${PROJECT_ROOT}/core/template-engine.sh" 2>/dev/null || true
}

teardown() {
    teardown_test_env
}

# ==============================================================================
# Variable Substitution Tests
# ==============================================================================

@test "substitute_variables replaces single variable" {
    export TEST_VAR="hello"
    local result
    result=$(substitute_variables "value: {{TEST_VAR}}")
    [[ "$result" == "value: hello" ]]
}

@test "substitute_variables replaces multiple variables" {
    export VAR_ONE="first"
    export VAR_TWO="second"
    local result
    result=$(substitute_variables "{{VAR_ONE}} and {{VAR_TWO}}")
    [[ "$result" == "first and second" ]]
}

@test "substitute_variables handles missing variables gracefully" {
    unset UNDEFINED_VAR 2>/dev/null || true
    local result
    result=$(substitute_variables "value: {{UNDEFINED_VAR}}")
    [[ "$result" == "value: " ]]
}

@test "substitute_variables replaces PROJECT_ROOT" {
    export PROJECT_ROOT="/test/path"
    local result
    result=$(substitute_variables "path: {{PROJECT_ROOT}}/config")
    [[ "$result" == "path: /test/path/config" ]]
}

@test "substitute_variables handles Azure naming conventions" {
    export AZURE_RESOURCE_GROUP="rg-test"
    export AZURE_LOCATION="eastus"
    local result
    result=$(substitute_variables "--resource-group {{AZURE_RESOURCE_GROUP}} --location {{AZURE_LOCATION}}")
    [[ "$result" == "--resource-group rg-test --location eastus" ]]
}

# ==============================================================================
# Operation Parsing Tests
# ==============================================================================

@test "parse_operation_yaml extracts operation ID" {
    skip_if_missing yq

    local yaml_file
    yaml_file=$(create_mock_operation "test-op")

    parse_operation_yaml "$yaml_file"
    [[ "$OPERATION_ID" == "test-op" ]]
}

@test "parse_operation_yaml extracts operation name" {
    skip_if_missing yq

    local yaml_file
    yaml_file=$(create_mock_operation "test-op")

    parse_operation_yaml "$yaml_file"
    [[ "$OPERATION_NAME" == "Test Operation: test-op" ]]
}

@test "parse_operation_yaml extracts duration settings" {
    skip_if_missing yq

    local yaml_file
    yaml_file=$(create_mock_operation "test-op")

    parse_operation_yaml "$yaml_file"
    [[ "$OPERATION_DURATION_EXPECTED" == "60" ]]
    [[ "$OPERATION_DURATION_TIMEOUT" == "120" ]]
    [[ "$OPERATION_DURATION_TYPE" == "FAST" ]]
}

@test "parse_operation_yaml fails on missing file" {
    run parse_operation_yaml "/nonexistent/file.yaml"
    [[ $status -ne 0 ]]
}

# ==============================================================================
# Pre-Parse Config Tests
# ==============================================================================

@test "preparse_config_values handles missing pre_parse section" {
    skip_if_missing yq

    local yaml_file
    yaml_file=$(create_mock_operation "no-preparse")

    # Should succeed silently with no pre_parse section
    run preparse_config_values "$yaml_file"
    [[ $status -eq 0 ]]
}

# ==============================================================================
# Render Command Tests
# ==============================================================================

@test "render_command produces executable command for powershell-direct" {
    skip_if_missing yq

    local yaml_file
    yaml_file=$(create_mock_operation "render-test")

    local command
    command=$(render_command "$yaml_file")

    # Should contain pwsh command
    [[ "$command" == *"pwsh"* ]]
}

@test "render_command substitutes variables in template" {
    skip_if_missing yq

    export AZURE_RESOURCE_GROUP="rg-test"

    # Create operation with variable in template
    local yaml_file="${TEST_TEMP}/var-test.yaml"
    cat > "$yaml_file" <<EOF
operation:
  id: "var-test"
  name: "Variable Test"
  capability: "test"
  operation_mode: "create"
  resource_type: "test/resource"
  duration:
    expected: 60
    timeout: 120
    type: "FAST"
  template:
    type: "powershell-direct"
  powershell:
    content: |
      \$rg = "{{AZURE_RESOURCE_GROUP}}"
      Write-Host "RG: \$rg"
      exit 0
EOF

    local command
    command=$(render_command "$yaml_file")

    # Should contain substituted value
    [[ "$command" == *"rg-test"* ]]
}
