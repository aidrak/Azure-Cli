#!/bin/bash
# ==============================================================================
# Operation Validator
# ==============================================================================
# Validates all operation YAML files against the capability schema
# ==============================================================================

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CAPABILITIES_DIR="${PROJECT_ROOT}/capabilities"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "========================================================================"
echo "  Validating Capability Operations"
echo "========================================================================"
echo "Project Root: $PROJECT_ROOT"
echo "Capabilities Dir: $CAPABILITIES_DIR"
echo ""

total_files=0
valid_files=0
invalid_files=0

# Function to validate a single file
validate_file() {
    local file="$1"
    local relative_path="${file#$PROJECT_ROOT/}"
    local errors=()

    # 1. YAML Syntax Check
    if ! yq eval '.' "$file" >/dev/null 2>&1; then
        echo -e "${RED}[FAIL]${NC} $relative_path - Invalid YAML syntax"
        return 1
    fi

    # 2. Schema Compliance
    local id=$(yq eval '.operation.id' "$file")
    local name=$(yq eval '.operation.name' "$file")
    local capability=$(yq eval '.operation.capability' "$file")
    local mode=$(yq eval '.operation.operation_mode' "$file")
    local template_cmd=$(yq eval '.operation.template.command' "$file")

    if [[ "$id" == "null" ]]; then errors+=("Missing operation.id"); fi
    if [[ "$name" == "null" ]]; then errors+=("Missing operation.name"); fi
    if [[ "$capability" == "null" ]]; then errors+=("Missing operation.capability"); fi
    if [[ "$mode" == "null" ]]; then errors+=("Missing operation.operation_mode"); fi
    
    # Check if it has a command (template.command) OR steps (legacy)
    if [[ "$template_cmd" == "null" ]]; then
        local steps=$(yq eval '.steps' "$file")
        if [[ "$steps" == "null" ]]; then
            errors+=("Missing operation.template.command (and no legacy steps found)")
        fi
    fi

    if [[ ${#errors[@]} -gt 0 ]]; then
        echo -e "${RED}[FAIL]${NC} $relative_path"
        for err in "${errors[@]}"; do
            echo "  - $err"
        done
        return 1
    else
        echo -e "${GREEN}[PASS]${NC} $relative_path"
        return 0
    fi
}

# Find all operation files
# Use while loop to handle file paths safely
find "$CAPABILITIES_DIR" -name "*.yaml" | grep "/operations/" | sort | while read -r file; do
    ((total_files++)) || true # || true prevents set -e from exiting if calculation fails (unlikely)
    
    if validate_file "$file"; then
        ((valid_files++)) || true
    else
        ((invalid_files++)) || true
    fi
    
    # Update summary counts in parent shell? 
    # Note: Piping to while loop runs in subshell, so variables won't update in parent.
    # Workaround: Print results to temp file or stdout and count lines.
done > validation_results.txt

# Process results
cat validation_results.txt

# Count passes/fails from output
total_files=$(wc -l < validation_results.txt)
valid_files=$(grep -c "\[PASS\]" validation_results.txt || true)
invalid_files=$(grep -c "\[FAIL\]" validation_results.txt || true)

echo ""
echo "========================================================================"
echo "  Summary"
echo "========================================================================"
echo "Total Files: $total_files"
echo -e "Valid:       ${GREEN}$valid_files${NC}"
echo -e "Invalid:     ${RED}$invalid_files${NC}"
echo ""

rm validation_results.txt

if [[ $invalid_files -gt 0 ]]; then
    exit 1
else
    exit 0
fi
