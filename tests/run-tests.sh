#!/bin/bash
# ==============================================================================
# Azure VDI Deployment Engine - Test Suite Runner
# ==============================================================================
#
# Usage:
#   ./tests/run-tests.sh              # Run all tests
#   ./tests/run-tests.sh template     # Run template engine tests only
#   ./tests/run-tests.sh state        # Run state manager tests only
#
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BATS_DIR="${SCRIPT_DIR}/bats"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "========================================"
echo "  Azure VDI Engine Test Suite"
echo "========================================"
echo ""

# Check dependencies
check_dependencies() {
    local missing=0

    echo "[*] Checking dependencies..."

    if ! command -v bats &>/dev/null; then
        echo -e "${YELLOW}[!] BATS not installed${NC}"
        echo "    Install with: git clone https://github.com/bats-core/bats-core.git /tmp/bats && sudo /tmp/bats/install.sh /usr/local"
        missing=1
    else
        echo -e "${GREEN}[v] BATS: $(bats --version)${NC}"
    fi

    if ! command -v sqlite3 &>/dev/null; then
        echo -e "${YELLOW}[!] sqlite3 not installed${NC}"
        echo "    Install with: sudo apt-get install sqlite3"
        missing=1
    else
        echo -e "${GREEN}[v] sqlite3: $(sqlite3 --version | head -1)${NC}"
    fi

    if ! command -v yq &>/dev/null; then
        echo -e "${YELLOW}[!] yq not installed${NC}"
        echo "    Install with: sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 && sudo chmod +x /usr/local/bin/yq"
        missing=1
    else
        echo -e "${GREEN}[v] yq: $(yq --version)${NC}"
    fi

    if ! command -v jq &>/dev/null; then
        echo -e "${YELLOW}[!] jq not installed${NC}"
        echo "    Install with: sudo apt-get install jq"
        missing=1
    else
        echo -e "${GREEN}[v] jq: $(jq --version)${NC}"
    fi

    echo ""

    if [[ $missing -eq 1 ]]; then
        echo -e "${YELLOW}[!] Some dependencies are missing. Tests may be skipped.${NC}"
        echo ""
    fi
}

# Install BATS if not present
install_bats() {
    if ! command -v bats &>/dev/null; then
        echo "[*] Installing BATS..."
        local tmp_dir=$(mktemp -d)
        git clone --depth 1 https://github.com/bats-core/bats-core.git "$tmp_dir/bats-core"
        cd "$tmp_dir/bats-core"
        sudo ./install.sh /usr/local
        cd "$PROJECT_ROOT"
        rm -rf "$tmp_dir"
        echo -e "${GREEN}[v] BATS installed${NC}"
    fi
}

# Run specific test file or all tests
run_tests() {
    local test_filter="${1:-}"

    if [[ ! -d "$BATS_DIR" ]]; then
        echo -e "${RED}[x] BATS test directory not found: $BATS_DIR${NC}"
        exit 1
    fi

    local test_files=()

    if [[ -n "$test_filter" ]]; then
        # Run specific tests based on filter
        case "$test_filter" in
            template|template-engine)
                test_files=("$BATS_DIR/test_template_engine.bats")
                ;;
            state|state-manager)
                test_files=("$BATS_DIR/test_state_manager.bats")
                ;;
            config|config-manager)
                test_files=("$BATS_DIR/test_config_manager.bats")
                ;;
            *)
                # Try to match filter as glob
                shopt -s nullglob
                test_files=("$BATS_DIR"/*"$test_filter"*.bats)
                shopt -u nullglob

                if [[ ${#test_files[@]} -eq 0 ]]; then
                    echo -e "${RED}[x] No test files found matching: $test_filter${NC}"
                    exit 1
                fi
                ;;
        esac
    else
        # Run all tests
        shopt -s nullglob
        test_files=("$BATS_DIR"/*.bats)
        shopt -u nullglob
    fi

    if [[ ${#test_files[@]} -eq 0 ]]; then
        echo -e "${YELLOW}[!] No test files found${NC}"
        exit 0
    fi

    echo "[*] Running ${#test_files[@]} test file(s)..."
    echo ""

    # Export PROJECT_ROOT for tests
    export PROJECT_ROOT

    # Run tests
    local failed=0
    for test_file in "${test_files[@]}"; do
        if [[ -f "$test_file" ]]; then
            echo "----------------------------------------"
            echo "Running: $(basename "$test_file")"
            echo "----------------------------------------"

            if bats "$test_file"; then
                echo -e "${GREEN}[v] $(basename "$test_file") passed${NC}"
            else
                echo -e "${RED}[x] $(basename "$test_file") failed${NC}"
                failed=1
            fi
            echo ""
        fi
    done

    echo "========================================"
    if [[ $failed -eq 0 ]]; then
        echo -e "${GREEN}  All tests passed!${NC}"
    else
        echo -e "${RED}  Some tests failed${NC}"
    fi
    echo "========================================"

    return $failed
}

# Main
main() {
    cd "$PROJECT_ROOT"

    check_dependencies

    # Try to install BATS if missing
    if ! command -v bats &>/dev/null; then
        read -p "BATS not found. Install it? [y/N] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            install_bats
        else
            echo -e "${RED}[x] Cannot run tests without BATS${NC}"
            exit 1
        fi
    fi

    run_tests "${1:-}"
}

main "$@"
