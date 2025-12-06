#!/bin/bash
# ==============================================================================
# State File Validator and Migrator
# ==============================================================================
#
# Purpose: Validates and migrates state.json to ensure consistency
# Usage: ./tools/validate-state.sh [--fix]
#
# ==============================================================================

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_FILE="${PROJECT_ROOT}/state.json"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

FIX_MODE=false
if [[ "${1:-}" == "--fix" ]]; then
    FIX_MODE=true
fi

echo "========================================================================"
echo "  State File Validation"
echo "========================================================================"
echo ""

if [[ ! -f "$STATE_FILE" ]]; then
    echo -e "${RED}[x] ERROR: State file not found: $STATE_FILE${NC}"
    exit 1
fi

echo "[*] Checking state file: $STATE_FILE"
echo ""

# Validate JSON syntax
if ! jq empty "$STATE_FILE" 2>/dev/null; then
    echo -e "${RED}[x] ERROR: Invalid JSON syntax${NC}"
    exit 1
fi
echo -e "${GREEN}[✓]${NC} JSON syntax valid"

# Check for operation ID inconsistencies
echo ""
echo "[*] Checking for operation ID inconsistencies..."

ISSUES_FOUND=0

# Check golden-image operations
for op_id in $(jq -r '.operations | keys[] | select(startswith("golden-image"))' "$STATE_FILE"); do
    # Check if operation ID matches the expected pattern: module-NN-name
    if [[ ! "$op_id" =~ ^golden-image-[0-9]{2}- ]]; then
        echo -e "${YELLOW}[!] Found inconsistent operation ID: $op_id${NC}"
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
    fi
done

# Report results
echo ""
if [[ $ISSUES_FOUND -eq 0 ]]; then
    echo -e "${GREEN}[✓] No issues found${NC}"
    exit 0
else
    echo -e "${YELLOW}[!] Found $ISSUES_FOUND issue(s)${NC}"

    if [[ "$FIX_MODE" == true ]]; then
        echo ""
        echo "[*] Running automatic fixes..."

        # Create backup
        cp "$STATE_FILE" "${STATE_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
        echo "[*] Created backup: ${STATE_FILE}.backup.$(date +%Y%m%d_%H%M%S)"

        # Apply fixes
        jq '
        # Fix golden-image operation IDs
        if .operations["golden-image-create-vm"] then
            .operations["golden-image-00-create-vm"] = .operations["golden-image-create-vm"] |
            del(.operations["golden-image-create-vm"])
        else . end |

        if .operations["golden-image-validate-vm"] then
            .operations["golden-image-01-validate-vm"] = .operations["golden-image-validate-vm"] |
            del(.operations["golden-image-validate-vm"])
        else . end |

        # Remove old/incorrect entries
        del(.operations["golden-image-system-prep"]) |
        del(.operations["golden-image-install-fslogix"]) |
        del(.operations["golden-image-install-adobe"]) |
        del(.operations["golden-image-install-chrome"]) |
        del(.operations["golden-image-install-apps-parallel"])
        ' "$STATE_FILE" > "${STATE_FILE}.tmp"

        mv "${STATE_FILE}.tmp" "$STATE_FILE"
        echo -e "${GREEN}[✓] Fixes applied${NC}"

        # Re-validate
        echo ""
        echo "[*] Re-validating..."
        exec "$0"
    else
        echo ""
        echo "Run with --fix to automatically correct these issues"
        exit 1
    fi
fi
