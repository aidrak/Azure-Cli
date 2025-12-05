#!/bin/bash
# ==============================================================================
# Error Handler - Self-Healing Error Detection and Fix Management
# ==============================================================================
#
# Purpose: Detect errors, prompt for fixes, apply to templates, retry operations
# Usage:
#   source core/error-handler.sh
#   handle_operation_error "golden-image-install-fslogix" "artifacts/logs/fslogix.log" 1
#
# ==============================================================================

set -euo pipefail

# Project paths
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

# Source dependencies
source "${PROJECT_ROOT}/core/logger.sh"

# ==============================================================================
# Anti-Destructive Patterns
# ==============================================================================
DESTRUCTIVE_PATTERNS=(
    "az vm delete"
    "az vm deallocate.*delete"
    "recreate.*vm"
    "start over"
    "create.*new.*vm"
    "destroy"
    "remove.*vm"
)

# ==============================================================================
# Check for Destructive Actions
# ==============================================================================
check_destructive_action() {
    local proposed_fix="$1"

    for pattern in "${DESTRUCTIVE_PATTERNS[@]}"; do
        if echo "$proposed_fix" | grep -iE "$pattern" >/dev/null 2>&1; then
            echo "[x] DESTRUCTIVE ACTION BLOCKED"
            echo "    Pattern matched: $pattern"
            echo ""
            echo "    Rule: Fix incrementally, never start over"
            echo "    - Use trial-and-error fixes"
            echo "    - Preserve completed work"
            echo "    - Retry operation, don't recreate resources"
            return 1
        fi
    done

    return 0
}

# ==============================================================================
# Extract Error Information from Log
# ==============================================================================
extract_error_info() {
    local log_file="$1"

    if [[ ! -f "$log_file" ]]; then
        echo "ERROR: Log file not found: $log_file"
        return 1
    fi

    # Extract error markers
    local errors
    errors=$(grep -E "\[ERROR\]" "$log_file" | tail -10)

    if [[ -z "$errors" ]]; then
        # Check for exit code errors
        errors=$(grep -iE "error|failed|exception" "$log_file" | tail -10)
    fi

    echo "$errors"
}

# ==============================================================================
# Analyze Error and Generate Fix Prompt
# ==============================================================================
generate_fix_prompt() {
    local operation_id="$1"
    local yaml_file="$2"
    local log_file="$3"
    local exit_code="$4"

    local error_info
    error_info=$(extract_error_info "$log_file")

    cat <<EOF

================================================================================
  ERROR DETECTED - Self-Healing Analysis Required
================================================================================

Operation ID: $operation_id
YAML File: $yaml_file
Log File: $log_file
Exit Code: $exit_code

Error Information:
$error_info

================================================================================
  ANALYSIS NEEDED
================================================================================

Please analyze this error and propose a fix:

1. What caused the error?
2. What needs to be changed in the operation template?
3. Provide the specific fix to apply to the YAML/PowerShell

IMPORTANT CONSTRAINTS:
- Fix must be INCREMENTAL (no "start over" or "recreate VM")
- Fix must be applied to the operation template
- Fix must be testable via retry

================================================================================

EOF
}

# ==============================================================================
# Apply Fix to Operation Template
# ==============================================================================
apply_fix_to_template() {
    local yaml_file="$1"
    local fix_description="$2"
    local fix_date="${3:-$(date +%Y-%m-%d)}"

    if [[ ! -f "$yaml_file" ]]; then
        echo "[x] Template file not found: $yaml_file"
        return 1
    fi

    log_info "Applying fix to template: $yaml_file" "error-handler"

    # Check if fixes section exists
    local has_fixes
    has_fixes=$(yq e '.operation.fixes' "$yaml_file")

    if [[ "$has_fixes" == "null" ]]; then
        # Initialize fixes array
        yq e -i '.operation.fixes = []' "$yaml_file"
    fi

    # Get current number of fixes
    local fix_count
    fix_count=$(yq e '.operation.fixes | length' "$yaml_file")

    # Add new fix entry
    yq e -i ".operation.fixes[$fix_count].issue = \"$fix_description\"" "$yaml_file"
    yq e -i ".operation.fixes[$fix_count].detected = \"$fix_date\"" "$yaml_file"
    yq e -i ".operation.fixes[$fix_count].applied_to_template = true" "$yaml_file"

    log_success "Fix applied to template" "error-handler"
    return 0
}

# ==============================================================================
# Update PowerShell Content in Template
# ==============================================================================
update_powershell_content() {
    local yaml_file="$1"
    local new_content="$2"

    if [[ ! -f "$yaml_file" ]]; then
        echo "[x] Template file not found: $yaml_file"
        return 1
    fi

    log_info "Updating PowerShell content in template" "error-handler"

    # Create temporary file with new content
    local temp_file
    temp_file=$(mktemp)
    echo "$new_content" > "$temp_file"

    # Use yq to update the powershell.content field
    yq e -i ".operation.powershell.content = load_str(\"$temp_file\")" "$yaml_file"

    rm -f "$temp_file"

    log_success "PowerShell content updated" "error-handler"
    return 0
}

# ==============================================================================
# Check if Operation Should Be Retried
# ==============================================================================
should_retry_operation() {
    local operation_id="$1"
    local max_retries="${2:-3}"

    # Check state directory for retry count
    local state_file="${PROJECT_ROOT}/artifacts/state/${operation_id}_retry_count"

    mkdir -p "${PROJECT_ROOT}/artifacts/state"

    local retry_count=0
    if [[ -f "$state_file" ]]; then
        retry_count=$(cat "$state_file")
    fi

    if [[ $retry_count -ge $max_retries ]]; then
        echo "[x] Maximum retries ($max_retries) reached for $operation_id"
        return 1
    fi

    # Increment retry count
    echo $((retry_count + 1)) > "$state_file"

    echo "[i] Retry attempt $((retry_count + 1)) of $max_retries"
    return 0
}

# ==============================================================================
# Reset Retry Counter
# ==============================================================================
reset_retry_counter() {
    local operation_id="$1"
    local state_file="${PROJECT_ROOT}/artifacts/state/${operation_id}_retry_count"

    if [[ -f "$state_file" ]]; then
        rm -f "$state_file"
        log_info "Retry counter reset for $operation_id" "error-handler"
    fi
}

# ==============================================================================
# Main Error Handling Workflow
# ==============================================================================
handle_operation_error() {
    local operation_id="$1"
    local log_file="$2"
    local exit_code="$3"
    local yaml_file="${4:-}"
    local auto_retry="${5:-false}"

    # Extract error info for logging
    local error_info
    error_info=$(extract_error_info "$log_file")

    # Log the error (operation_id, error_message, error_code, elapsed)
    log_operation_error "$operation_id" "$error_info" "$exit_code" "0"

    echo ""
    echo "========================================================================"
    echo "  Operation Failed: $operation_id"
    echo "========================================================================"
    echo "Exit Code: $exit_code"
    echo "Log File: $log_file"
    echo ""

    # Display error information (already extracted above)
    if [[ -n "$error_info" ]]; then
        echo "Error Details:"
        echo "$error_info"
        echo ""
    fi

    # Check if YAML file provided
    if [[ -z "$yaml_file" ]]; then
        echo "[!] No YAML template provided - cannot apply fix"
        echo "    Manual intervention required"
        return 1
    fi

    # Check retry limit
    if ! should_retry_operation "$operation_id" 3; then
        echo "[!] Maximum retries exceeded"
        echo "    Manual intervention required"
        return 1
    fi

    # Generate fix prompt
    if [[ "$auto_retry" == "false" ]]; then
        generate_fix_prompt "$operation_id" "$yaml_file" "$log_file" "$exit_code"

        echo "========================================================================"
        echo "  Next Steps"
        echo "========================================================================"
        echo "1. Analyze the error above"
        echo "2. Apply fix to template: $yaml_file"
        echo "3. Use apply_fix_to_template() to record the fix"
        echo "4. Use update_powershell_content() if PowerShell needs changes"
        echo "5. Retry the operation"
        echo ""
        echo "Functions available:"
        echo "  apply_fix_to_template \"$yaml_file\" \"Fix description\""
        echo "  update_powershell_content \"$yaml_file\" \"New PowerShell content\""
        echo ""

        return 1
    fi

    return 0
}

# ==============================================================================
# Validate Fix Before Apply
# ==============================================================================
validate_fix() {
    local fix_description="$1"
    local powershell_content="${2:-}"

    echo "[*] Validating proposed fix..."

    # Check for destructive patterns
    if ! check_destructive_action "$fix_description"; then
        return 1
    fi

    if [[ -n "$powershell_content" ]] && ! check_destructive_action "$powershell_content"; then
        return 1
    fi

    # Check for basic PowerShell syntax if content provided
    if [[ -n "$powershell_content" ]]; then
        # Verify markers present
        if ! echo "$powershell_content" | grep -q "\[START\]"; then
            echo "[!] Warning: PowerShell content missing [START] marker"
        fi

        if ! echo "$powershell_content" | grep -qE "\[SUCCESS\]|\[ERROR\]"; then
            echo "[!] Warning: PowerShell content missing completion marker"
        fi
    fi

    echo "[v] Fix validation passed"
    return 0
}

# ==============================================================================
# Get Error History for Operation
# ==============================================================================
get_error_history() {
    local operation_id="$1"

    # Query structured logs for errors
    query_logs "$operation_id" "ERROR" 2>/dev/null || echo "No error history found"
}

# ==============================================================================
# Get Fix History from Template
# ==============================================================================
get_fix_history() {
    local yaml_file="$1"

    if [[ ! -f "$yaml_file" ]]; then
        echo "Template not found: $yaml_file"
        return 1
    fi

    local fixes
    fixes=$(yq e '.operation.fixes' "$yaml_file")

    if [[ "$fixes" == "null" || "$fixes" == "[]" ]]; then
        echo "No fixes applied to this template yet"
        return 0
    fi

    echo "Fix History:"
    echo "$fixes" | yq e '.[] | "  - [" + .detected + "] " + .issue' -
}

# ==============================================================================
# Export functions
# ==============================================================================
export -f check_destructive_action
export -f extract_error_info
export -f generate_fix_prompt
export -f apply_fix_to_template
export -f update_powershell_content
export -f should_retry_operation
export -f reset_retry_counter
export -f handle_operation_error
export -f validate_fix
export -f get_error_history
export -f get_fix_history
