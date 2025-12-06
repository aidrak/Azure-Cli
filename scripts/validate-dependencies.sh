#!/bin/bash
# ==============================================================================
# Dependency Validation Script
# ==============================================================================
# Validates that all operation prerequisites reference real operations
# and detects circular dependencies
#
# Usage: ./scripts/validate-dependencies.sh [path]
#
# Exit codes:
#   0 - All dependencies are valid
#   1 - One or more invalid dependencies found
# ==============================================================================

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check for Python
if ! command -v python3 &> /dev/null; then
    echo "Error: python3 is required for dependency validation"
    exit 1
fi

# Run the Python validator
python3 "$SCRIPT_DIR/validate-dependencies.py" "$@"
