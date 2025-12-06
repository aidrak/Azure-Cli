#!/bin/bash
# Simple Query Engine Test

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "Testing Query Engine..."
echo ""

# Load query engine
source "${PROJECT_ROOT}/core/query.sh" || {
    echo "FAIL: Could not load query.sh"
    exit 1
}

# Test 1: Functions exist
echo -n "Test 1: Core functions exist... "
if type query_resource &>/dev/null && type query_resources &>/dev/null; then
    echo "PASS"
else
    echo "FAIL"
    exit 1
fi

# Test 2: JQ filters created
echo -n "Test 2: JQ filters exist... "
if [[ -f "${QUERIES_DIR}/compute.jq" ]] && [[ -f "${QUERIES_DIR}/summary.jq" ]]; then
    echo "PASS"
else
    echo "FAIL"
    exit 1
fi

# Test 3: JQ filter application
echo -n "Test 3: JQ filter works... "
sample='[{"name":"test","type":"vm","location":"eastus","provisioningState":"Succeeded"}]'
filtered=$(apply_jq_filter "$sample" "${QUERIES_DIR}/summary.jq" 2>/dev/null)
if echo "$filtered" | jq empty 2>/dev/null; then
    echo "PASS"
else
    echo "FAIL"
    exit 1
fi

# Test 4: ensure_jq_filter_exists
echo -n "Test 4: Filter creation function... "
ensure_jq_filter_exists "compute"
if [[ -f "${QUERIES_DIR}/compute.jq" ]]; then
    echo "PASS"
else
    echo "FAIL"
    exit 1
fi

echo ""
echo "All tests passed!"
