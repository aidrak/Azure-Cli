#!/bin/bash
# ==============================================================================
# Pre-Commit Validation Script
# ==============================================================================
#
# Purpose: Validates code before committing to prevent common issues
# Usage: Run manually or install as git pre-commit hook
#
# To install as git hook:
#   ln -s ../../tools/pre-commit-check.sh .git/hooks/pre-commit
#
# ==============================================================================

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "========================================================================"
echo "  Pre-Commit Validation"
echo "========================================================================"
echo ""

ERRORS=0

# ==============================================================================
# 1. Validate Bash Syntax
# ==============================================================================
echo "[*] Checking bash script syntax..."
for script in "${PROJECT_ROOT}/core"/*.sh; do
    if [[ -f "$script" ]]; then
        if ! bash -n "$script" 2>/dev/null; then
            echo -e "${RED}[x] Syntax error in: $script${NC}"
            bash -n "$script"
            ERRORS=$((ERRORS + 1))
        else
            echo -e "${GREEN}[✓]${NC} $(basename "$script")"
        fi
    fi
done

# ==============================================================================
# 2. Validate Operation YAML Files
# ==============================================================================
echo ""
echo "[*] Checking operation YAML syntax..."
for yaml_file in "${PROJECT_ROOT}/modules"/**/operations/*.yaml; do
    if [[ -f "$yaml_file" ]]; then
        if ! yq eval '.' "$yaml_file" >/dev/null 2>&1; then
            echo -e "${RED}[x] Invalid YAML: $yaml_file${NC}"
            ERRORS=$((ERRORS + 1))
        fi
    fi
done
echo -e "${GREEN}[✓]${NC} All YAML files valid"

# ==============================================================================
# 3. Check Operation ID Naming Convention
# ==============================================================================
echo ""
echo "[*] Checking operation ID naming conventions..."
for yaml_file in "${PROJECT_ROOT}/modules"/**/operations/*.yaml; do
    if [[ -f "$yaml_file" ]]; then
        op_id=$(yq e '.operation.id' "$yaml_file" 2>/dev/null || echo "")
        filename=$(basename "$yaml_file" .yaml)

        # Extract module name from path
        module_dir=$(dirname "$(dirname "$yaml_file")")
        module_name=$(basename "$module_dir")

        # Check if operation ID matches expected pattern
        # Expected: {module-name}-{filename}
        expected_prefix="${module_name}-${filename}"

        if [[ -n "$op_id" && "$op_id" != "$expected_prefix" ]]; then
            echo -e "${YELLOW}[!] Potential mismatch:${NC}"
            echo "    File: $yaml_file"
            echo "    Operation ID: $op_id"
            echo "    Expected: $expected_prefix"
            echo ""
        fi
    fi
done

# ==============================================================================
# 4. Validate State File (if exists)
# ==============================================================================
if [[ -f "${PROJECT_ROOT}/state.json" ]]; then
    echo ""
    echo "[*] Validating state file..."
    if "${PROJECT_ROOT}/tools/validate-state.sh" > /dev/null 2>&1; then
        echo -e "${GREEN}[✓]${NC} State file valid"
    else
        echo -e "${YELLOW}[!] State file has issues - run: ./tools/validate-state.sh --fix${NC}"
    fi
fi

# ==============================================================================
# 5. Check for Secrets in Config Files
# ==============================================================================
echo ""
echo "[*] Checking for potential secrets..."
if [[ -f "${PROJECT_ROOT}/config.yaml" ]]; then
    if grep -qE '(password|secret|key):\s*[^"]*[a-zA-Z0-9]{8,}' "${PROJECT_ROOT}/config.yaml"; then
        echo -e "${RED}[x] Potential secret found in config.yaml${NC}"
        echo "    Secrets should be in secrets.yaml (which is gitignored)"
        ERRORS=$((ERRORS + 1))
    else
        echo -e "${GREEN}[✓]${NC} No secrets detected in config.yaml"
    fi
fi

# ==============================================================================
# Summary
# ==============================================================================
echo ""
echo "========================================================================"
if [[ $ERRORS -eq 0 ]]; then
    echo -e "${GREEN}[✓] All checks passed - ready to commit${NC}"
    echo "========================================================================"
    exit 0
else
    echo -e "${RED}[x] Found $ERRORS error(s) - please fix before committing${NC}"
    echo "========================================================================"
    exit 1
fi
