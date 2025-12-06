#!/bin/bash
# ==============================================================================
# YAML Syntax Validation Script
# ==============================================================================
# Validates YAML syntax for all operation files
# Usage: ./scripts/validate-yaml-syntax.sh [path]
#
# Exit codes:
#   0 - All files have valid YAML syntax
#   1 - One or more files have YAML syntax errors
# ==============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Determine search path
SEARCH_PATH="${1:-capabilities}"

if [ ! -e "$SEARCH_PATH" ]; then
    echo -e "${RED}Error: Path '$SEARCH_PATH' does not exist${NC}"
    exit 1
fi

echo "======================================================================"
echo "YAML Syntax Validation"
echo "======================================================================"
echo ""

passed=0
failed=0
total=0
failed_files=()

# Check if yq is available
if command -v yq &> /dev/null; then
    YAML_TOOL="yq"
    YAML_CMD="yq eval '.'"
elif command -v python3 &> /dev/null; then
    YAML_TOOL="python"
    YAML_CMD="python3 -c 'import yaml, sys; yaml.safe_load(sys.stdin)'"
else
    echo -e "${RED}Error: Neither yq nor python3 is available${NC}"
    echo "Please install yq or python3 to validate YAML syntax"
    exit 1
fi

echo "Using validator: $YAML_TOOL"
echo ""

# Find all YAML files
if [ -f "$SEARCH_PATH" ]; then
    # Single file
    files=("$SEARCH_PATH")
else
    # Directory - find all operation YAML files
    mapfile -t files < <(find "$SEARCH_PATH" -type f -path "*/operations/*.yaml" | sort)
fi

if [ ${#files[@]} -eq 0 ]; then
    echo -e "${YELLOW}No operation files found in $SEARCH_PATH${NC}"
    exit 1
fi

# Validate each file
for file in "${files[@]}"; do
    ((total++))

    if [ "$YAML_TOOL" = "yq" ]; then
        if yq eval '.' "$file" >/dev/null 2>&1; then
            echo -e "${GREEN}✓${NC} $file"
            ((passed++))
        else
            echo -e "${RED}✗${NC} $file - YAML syntax error"
            # Show the error details
            yq eval '.' "$file" 2>&1 | head -5 | sed 's/^/  /'
            ((failed++))
            failed_files+=("$file")
        fi
    else
        # Use Python YAML parser
        if python3 -c "import yaml; yaml.safe_load(open('$file'))" >/dev/null 2>&1; then
            echo -e "${GREEN}✓${NC} $file"
            ((passed++))
        else
            echo -e "${RED}✗${NC} $file - YAML syntax error"
            # Show the error details
            python3 -c "import yaml; yaml.safe_load(open('$file'))" 2>&1 | head -5 | sed 's/^/  /'
            ((failed++))
            failed_files+=("$file")
        fi
    fi
done

echo ""
echo "======================================================================"
echo "YAML Syntax Validation Summary"
echo "======================================================================"
echo "  Total:  $total"
echo "  Passed: $passed"
echo "  Failed: $failed"
echo ""

if [ $failed -gt 0 ]; then
    echo "Failed files:"
    for file in "${failed_files[@]}"; do
        echo "  - $file"
    done
    echo ""
    exit 1
else
    echo -e "${GREEN}✓${NC} All files have valid YAML syntax"
    exit 0
fi
