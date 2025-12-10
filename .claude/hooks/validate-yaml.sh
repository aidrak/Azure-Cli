#!/bin/bash
# Hook: Validate YAML operation files before Write/Edit
# Runs on PostToolUse for Write and Edit tools

set -euo pipefail

# Get file paths from environment variable (space-separated)
FILE_PATHS="${CLAUDE_FILE_PATHS:-}"

if [[ -z "$FILE_PATHS" ]]; then
    exit 0
fi

# Check each file
for FILE_PATH in $FILE_PATHS; do
    # Only validate .yaml files in capabilities/
    if [[ "$FILE_PATH" =~ capabilities/.*/operations/.*\.yaml$ ]]; then
        echo "[HOOK] Validating YAML operation: $FILE_PATH" >&2
        
        # Check if yq is available
        if ! command -v yq &> /dev/null; then
            echo "[HOOK] yq not found, skipping validation" >&2
            exit 0
        fi
        
        # Validate YAML syntax
        if ! yq eval '.' "$FILE_PATH" > /dev/null 2>&1; then
            echo "[HOOK] ERROR: Invalid YAML syntax in $FILE_PATH" >&2
            exit 2  # Exit 2 blocks the operation
        fi
        
        # Check required fields
        REQUIRED_FIELDS=("operation.id" "operation.name" "operation.template")
        for field in "${REQUIRED_FIELDS[@]}"; do
            value=$(yq eval ".$field" "$FILE_PATH" 2>/dev/null)
            if [[ "$value" == "null" ]] || [[ -z "$value" ]]; then
                echo "[HOOK] ERROR: Missing required field '$field' in $FILE_PATH" >&2
                exit 2
            fi
        done
        
        echo "[HOOK] ✓ YAML validation passed" >&2
    fi
done

exit 0