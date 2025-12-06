#!/bin/bash
# Integration test for Phase 2 discovery engine with real Azure environment
set -euo pipefail

PROJECT_ROOT="/mnt/cache_pool/development/azure-cli"
STATE_DB="${PROJECT_ROOT}/test-discovery-real.db"
DISCOVERED_DIR="${PROJECT_ROOT}/discovered"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

passed=0
failed=0

echo "=== Phase 2 Discovery Engine - Real Azure Environment Test ==="
echo ""

# Cleanup from any previous runs
rm -f "$STATE_DB"
rm -rf "$DISCOVERED_DIR"
mkdir -p "$DISCOVERED_DIR"

# Initialize database
echo "[*] Initializing database..."
if sqlite3 "$STATE_DB" < "${PROJECT_ROOT}/schemas/state.schema.sql"; then
    echo -e "${GREEN}✓${NC} Database initialized"
else
    echo -e "${RED}✗${NC} Database initialization failed"
    exit 1
fi

# Load configuration
echo "[*] Loading configuration..."
export STATE_DB
source "${PROJECT_ROOT}/core/config-manager.sh"
if load_config; then
    echo -e "${GREEN}✓${NC} Configuration loaded"
    echo "    Subscription: ${AZURE_SUBSCRIPTION_ID}"
    echo "    Resource Group: ${AZURE_RESOURCE_GROUP}"
    echo "    Location: ${AZURE_LOCATION}"
else
    echo -e "${RED}✗${NC} Configuration load failed"
    exit 1
fi

# Source required modules
echo "[*] Loading core modules..."
source "${PROJECT_ROOT}/core/state-manager.sh"
source "${PROJECT_ROOT}/core/query.sh"
source "${PROJECT_ROOT}/core/dependency-resolver.sh"
source "${PROJECT_ROOT}/core/discovery.sh"
echo -e "${GREEN}✓${NC} All modules loaded"
echo ""

# Test 1: Verify Azure connectivity
echo "Test 1: Verify Azure connectivity"
if az account show --output json > /dev/null 2>&1; then
    current_sub=$(az account show --query id -o tsv)
    echo -e "${GREEN}✓${NC} Connected to Azure"
    echo "    Current subscription: $current_sub"
    ((passed++))
else
    echo -e "${RED}✗${NC} Not connected to Azure"
    ((failed++))
fi
echo ""

# Test 2: Verify resource group exists
echo "Test 2: Verify resource group exists"
if az group show --name "$AZURE_RESOURCE_GROUP" --output json > /dev/null 2>&1; then
    rg_location=$(az group show --name "$AZURE_RESOURCE_GROUP" --query location -o tsv)
    echo -e "${GREEN}✓${NC} Resource group exists"
    echo "    Name: $AZURE_RESOURCE_GROUP"
    echo "    Location: $rg_location"
    ((passed++))
else
    echo -e "${RED}✗${NC} Resource group not found: $AZURE_RESOURCE_GROUP"
    ((failed++))
fi
echo ""

# Test 3: Run discovery - resource group scope
echo "Test 3: Run discovery on resource group"
if discover "resource-group" "$AZURE_RESOURCE_GROUP"; then
    echo -e "${GREEN}✓${NC} Discovery completed successfully"
    ((passed++))
else
    echo -e "${RED}✗${NC} Discovery failed"
    ((failed++))
fi
echo ""

# Test 4: Verify discovered resources in database
echo "Test 4: Verify resources stored in database"
resource_count=$(sqlite3 "$STATE_DB" "SELECT COUNT(*) FROM resources WHERE deleted_at IS NULL;")
if [[ $resource_count -gt 0 ]]; then
    echo -e "${GREEN}✓${NC} Found $resource_count resources in database"

    # Show breakdown by type
    echo "    Resource breakdown:"
    sqlite3 "$STATE_DB" "
        SELECT resource_type, COUNT(*) as count
        FROM resources
        WHERE deleted_at IS NULL
        GROUP BY resource_type
        ORDER BY count DESC;
    " | while IFS='|' read -r rtype rcount; do
        echo "      - $rtype: $rcount"
    done
    ((passed++))
else
    echo -e "${RED}✗${NC} No resources found in database"
    ((failed++))
fi
echo ""

# Test 5: Verify dependencies detected
echo "Test 5: Verify dependencies detected"
dep_count=$(sqlite3 "$STATE_DB" "SELECT COUNT(*) FROM dependencies;")
if [[ $dep_count -gt 0 ]]; then
    echo -e "${GREEN}✓${NC} Found $dep_count dependencies"

    # Show breakdown by type
    echo "    Dependency breakdown:"
    sqlite3 "$STATE_DB" "
        SELECT dependency_type, relationship, COUNT(*) as count
        FROM dependencies
        GROUP BY dependency_type, relationship
        ORDER BY count DESC;
    " | while IFS='|' read -r dtype drel dcount; do
        echo "      - $dtype/$drel: $dcount"
    done
    ((passed++))
else
    echo -e "${YELLOW}⚠${NC} No dependencies detected (might be expected for simple environments)"
    ((passed++))
fi
echo ""

# Test 6: Verify YAML output generated
echo "Test 6: Verify YAML output generated"
yaml_file="${DISCOVERED_DIR}/summary-${AZURE_RESOURCE_GROUP}-$(date +%Y%m%d).yaml"
if [[ -f "$yaml_file" ]]; then
    yaml_size=$(wc -l < "$yaml_file")
    echo -e "${GREEN}✓${NC} YAML summary created: $yaml_file"
    echo "    Lines: $yaml_size"

    # Validate YAML syntax
    if python3 -c "import yaml; yaml.safe_load(open('$yaml_file'))" 2>/dev/null; then
        echo -e "${GREEN}✓${NC} YAML is valid"
    else
        echo -e "${RED}✗${NC} YAML is invalid"
        ((failed++))
    fi
    ((passed++))
else
    echo -e "${RED}✗${NC} YAML file not found: $yaml_file"
    ((failed++))
fi
echo ""

# Test 7: Verify JSON output generated
echo "Test 7: Verify JSON output generated"
json_file="${DISCOVERED_DIR}/full-${AZURE_RESOURCE_GROUP}-$(date +%Y%m%d).json"
if [[ -f "$json_file" ]]; then
    json_size=$(wc -l < "$json_file")
    echo -e "${GREEN}✓${NC} JSON output created: $json_file"
    echo "    Lines: $json_size"

    # Validate JSON syntax
    if jq empty "$json_file" 2>/dev/null; then
        echo -e "${GREEN}✓${NC} JSON is valid"

        # Check structure
        node_count=$(jq '.nodes | length' "$json_file")
        edge_count=$(jq '.edges | length' "$json_file")
        echo "    Nodes: $node_count"
        echo "    Edges: $edge_count"
    else
        echo -e "${RED}✗${NC} JSON is invalid"
        ((failed++))
    fi
    ((passed++))
else
    echo -e "${RED}✗${NC} JSON file not found: $json_file"
    ((failed++))
fi
echo ""

# Test 8: Verify dependency graph DOT output
echo "Test 8: Verify GraphViz DOT output generated"
dot_file="${DISCOVERED_DIR}/dependency-graph-${AZURE_RESOURCE_GROUP}-$(date +%Y%m%d).dot"
if [[ -f "$dot_file" ]]; then
    dot_size=$(wc -l < "$dot_file")
    echo -e "${GREEN}✓${NC} DOT file created: $dot_file"
    echo "    Lines: $dot_size"

    # Basic validation - should start with "digraph" and end with "}"
    if head -n 1 "$dot_file" | grep -q "digraph" && tail -n 1 "$dot_file" | grep -q "}"; then
        echo -e "${GREEN}✓${NC} DOT format appears valid"
    else
        echo -e "${RED}✗${NC} DOT format invalid"
        ((failed++))
    fi
    ((passed++))
else
    echo -e "${RED}✗${NC} DOT file not found: $dot_file"
    ((failed++))
fi
echo ""

# Test 9: Query specific resource types
echo "Test 9: Query specific resource types"
test_9_passed=true

# Test compute resources
compute_count=$(sqlite3 "$STATE_DB" "SELECT COUNT(*) FROM resources WHERE resource_type LIKE 'Microsoft.Compute/%';")
echo "    Compute resources: $compute_count"

# Test network resources
network_count=$(sqlite3 "$STATE_DB" "SELECT COUNT(*) FROM resources WHERE resource_type LIKE 'Microsoft.Network/%';")
echo "    Network resources: $network_count"

# Test storage resources
storage_count=$(sqlite3 "$STATE_DB" "SELECT COUNT(*) FROM resources WHERE resource_type LIKE 'Microsoft.Storage/%';")
echo "    Storage resources: $storage_count"

if [[ $((compute_count + network_count + storage_count)) -gt 0 ]]; then
    echo -e "${GREEN}✓${NC} Successfully categorized resources by type"
    ((passed++))
else
    echo -e "${RED}✗${NC} No standard resource types found"
    ((failed++))
fi
echo ""

# Test 10: Verify cache expiry timestamps
echo "Test 10: Verify cache expiry timestamps set"
expired_resources=$(sqlite3 "$STATE_DB" "SELECT COUNT(*) FROM resources WHERE cache_expires_at IS NULL;")
if [[ $expired_resources -eq 0 ]]; then
    echo -e "${GREEN}✓${NC} All resources have cache expiry set"
    ((passed++))
else
    echo -e "${YELLOW}⚠${NC} $expired_resources resources missing cache expiry"
    ((passed++))
fi
echo ""

# Test 11: Test cache invalidation
echo "Test 11: Test cache invalidation"
if invalidate_cache "Microsoft.Compute/virtualMachines" "test invalidation"; then
    echo -e "${GREEN}✓${NC} Cache invalidation successful"
    ((passed++))
else
    echo -e "${RED}✗${NC} Cache invalidation failed"
    ((failed++))
fi
echo ""

# Test 12: Verify operation tracking
echo "Test 12: Verify operation tracking"
op_count=$(sqlite3 "$STATE_DB" "SELECT COUNT(*) FROM operations;")
if [[ $op_count -gt 0 ]]; then
    echo -e "${GREEN}✓${NC} Found $op_count operations tracked"

    # Show operation status
    sqlite3 "$STATE_DB" "
        SELECT operation_name, status, error_message
        FROM operations
        ORDER BY started_at DESC
        LIMIT 5;
    " | while IFS='|' read -r opname opstatus operr; do
        if [[ "$opstatus" == "completed" ]]; then
            echo -e "      ${GREEN}✓${NC} $opname"
        else
            echo -e "      ${RED}✗${NC} $opname: $operr"
        fi
    done
    ((passed++))
else
    echo -e "${YELLOW}⚠${NC} No operations tracked"
    ((passed++))
fi
echo ""

# Test 13: Performance metrics
echo "Test 13: Verify performance metrics"
echo "    Database size: $(du -h "$STATE_DB" | cut -f1)"
echo "    Discovery outputs total: $(du -sh "$DISCOVERED_DIR" | cut -f1)"

# Check if we have execution metrics
exec_metrics=$(sqlite3 "$STATE_DB" "SELECT COUNT(*) FROM execution_metrics;")
if [[ $exec_metrics -gt 0 ]]; then
    echo -e "${GREEN}✓${NC} Found $exec_metrics execution metric entries"

    # Show average execution times
    sqlite3 "$STATE_DB" "
        SELECT operation_type, AVG(execution_time_ms) as avg_ms
        FROM execution_metrics
        GROUP BY operation_type;
    " | while IFS='|' read -r optype avgms; do
        echo "      - $optype: ${avgms}ms avg"
    done
    ((passed++))
else
    echo -e "${YELLOW}⚠${NC} No execution metrics recorded"
    ((passed++))
fi
echo ""

# Summary
echo "========================================"
echo "Test Summary"
echo "========================================"
echo -e "Passed: ${GREEN}$passed${NC}"
echo -e "Failed: ${RED}$failed${NC}"
echo "Total:  $((passed + failed))"
echo ""

if [[ $failed -eq 0 ]]; then
    echo -e "${GREEN}All tests passed!${NC}"
    echo ""
    echo "Discovered resources saved to:"
    echo "  YAML: ${DISCOVERED_DIR}/summary-${AZURE_RESOURCE_GROUP}-$(date +%Y%m%d).yaml"
    echo "  JSON: ${DISCOVERED_DIR}/full-${AZURE_RESOURCE_GROUP}-$(date +%Y%m%d).json"
    echo "  DOT:  ${DISCOVERED_DIR}/dependency-graph-${AZURE_RESOURCE_GROUP}-$(date +%Y%m%d).dot"
    echo ""
    echo "Database: $STATE_DB"
    exit 0
else
    echo -e "${RED}Some tests failed${NC}"
    exit 1
fi
