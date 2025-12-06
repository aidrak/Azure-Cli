#!/bin/bash
# ==============================================================================
# Variable Reference Validation Script
# ==============================================================================
# Validates that all {{PLACEHOLDER}} variables in operation templates have
# corresponding definitions in config.yaml or operation parameters
#
# Usage: ./scripts/validate-variables.sh [path]
#
# Exit codes:
#   0 - All variables are defined
#   1 - One or more undefined variables found
# ==============================================================================

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check for Python
if ! command -v python3 &> /dev/null; then
    echo "Error: python3 is required for variable validation"
    exit 1
fi

# Run the Python validator
python3 "$SCRIPT_DIR/validate-variables.py" "$@"
