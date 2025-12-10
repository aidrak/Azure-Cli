#!/bin/bash
# ==============================================================================
# BATS Test Helper - Common utilities for test files
# ==============================================================================

# Set up test environment
setup_test_env() {
    export PROJECT_ROOT="${BATS_TEST_DIRNAME}/../.."
    export TEST_FIXTURES="${BATS_TEST_DIRNAME}/../fixtures"

    # Create temp directory for test artifacts
    export TEST_TEMP=$(mktemp -d)

    # Mock state database
    export STATE_DB="${TEST_TEMP}/state.db"

    # Mock config file
    export TEST_CONFIG="${TEST_FIXTURES}/config/test-config.yaml"
}

# Clean up after tests
teardown_test_env() {
    if [[ -d "${TEST_TEMP:-}" ]]; then
        rm -rf "$TEST_TEMP"
    fi
}

# Assert file exists
assert_file_exists() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        echo "Expected file to exist: $file" >&2
        return 1
    fi
}

# Assert file contains pattern
assert_file_contains() {
    local file="$1"
    local pattern="$2"
    if ! grep -q "$pattern" "$file"; then
        echo "Expected file '$file' to contain pattern: $pattern" >&2
        return 1
    fi
}

# Assert command succeeds
assert_success() {
    if [[ $status -ne 0 ]]; then
        echo "Expected success (exit 0) but got exit code: $status" >&2
        echo "Output: $output" >&2
        return 1
    fi
}

# Assert command fails
assert_failure() {
    if [[ $status -eq 0 ]]; then
        echo "Expected failure (exit non-zero) but got exit code: 0" >&2
        echo "Output: $output" >&2
        return 1
    fi
}

# Assert output contains pattern
assert_output_contains() {
    local pattern="$1"
    if [[ ! "$output" =~ $pattern ]]; then
        echo "Expected output to contain: $pattern" >&2
        echo "Actual output: $output" >&2
        return 1
    fi
}

# Assert output equals exact value
assert_output_equals() {
    local expected="$1"
    if [[ "$output" != "$expected" ]]; then
        echo "Expected output: $expected" >&2
        echo "Actual output: $output" >&2
        return 1
    fi
}

# Create mock YAML operation file
create_mock_operation() {
    local name="$1"
    local output_file="${TEST_TEMP}/${name}.yaml"

    cat > "$output_file" <<EOF
operation:
  id: "${name}"
  name: "Test Operation: ${name}"
  description: "Mock operation for testing"
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
      Write-Host "[SUCCESS] Mock operation completed"
      exit 0
EOF

    echo "$output_file"
}

# Mock Azure CLI command
mock_az_command() {
    local command="$1"
    local output="$2"
    local exit_code="${3:-0}"

    # Create mock script
    local mock_script="${TEST_TEMP}/mock_az"

    cat > "$mock_script" <<EOF
#!/bin/bash
if [[ "\$*" == *"$command"* ]]; then
    echo "$output"
    exit $exit_code
fi
# Fall through to real command
exec /usr/bin/az "\$@"
EOF

    chmod +x "$mock_script"
    export PATH="${TEST_TEMP}:$PATH"
}

# Initialize mock state database
init_mock_state_db() {
    if [[ -f "${PROJECT_ROOT}/core/state-manager.sh" ]]; then
        source "${PROJECT_ROOT}/core/state-manager.sh"
        init_state_db
    fi
}

# Skip test if command not available
skip_if_missing() {
    local cmd="$1"
    if ! command -v "$cmd" &>/dev/null; then
        skip "$cmd not available"
    fi
}
