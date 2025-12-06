#!/bin/bash
# Minimal discovery test with actual Azure resources
set -euo pipefail

PROJECT_ROOT="/mnt/cache_pool/development/azure-cli"
STATE_DB="${PROJECT_ROOT}/test-discovery-minimal.db"
DISCOVERED_DIR="${PROJECT_ROOT}/discovered"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=== Minimal Discovery Engine Test ==="
echo ""

# Cleanup
rm -f "$STATE_DB"
rm -rf "$DISCOVERED_DIR"
mkdir -p "$DISCOVERED_DIR"

# Initialize database
echo "[1/8] Initializing database..."
if sqlite3 "$STATE_DB" < "${PROJECT_ROOT}/schemas/state.schema.sql" 2>&1; then
    echo -e "${GREEN}✓${NC} Database initialized"
else
    echo -e "${RED}✗${NC} Failed"
    exit 1
fi

# Load modules
echo "[2/8] Loading modules..."
export STATE_DB
source "${PROJECT_ROOT}/core/state-manager.sh" || { echo -e "${RED}✗${NC} state-manager.sh failed"; exit 1; }
source "${PROJECT_ROOT}/core/query.sh" || { echo -e "${RED}✗${NC} query.sh failed"; exit 1; }
source "${PROJECT_ROOT}/core/dependency-resolver.sh" || { echo -e "${RED}✗${NC} dependency-resolver.sh failed"; exit 1; }
source "${PROJECT_ROOT}/core/discovery.sh" || { echo -e "${RED}✗${NC} discovery.sh failed"; exit 1; }
echo -e "${GREEN}✓${NC} All modules loaded"

# Test Azure connectivity
echo "[3/8] Testing Azure connectivity..."
if ! az account show --output json > /dev/null 2>&1; then
    echo -e "${RED}✗${NC} Not connected to Azure"
    exit 1
fi
subscription_id=$(az account show --query id -o tsv)
echo -e "${GREEN}✓${NC} Connected to subscription: $subscription_id"

# Find available resource group
echo "[4/8] Finding resource groups..."
rg_name=$(az group list --query "[0].name" -o tsv)
if [[ -z "$rg_name" ]]; then
    echo -e "${RED}✗${NC} No resource groups found"
    exit 1
fi
echo -e "${GREEN}✓${NC} Found resource group: $rg_name"

# List resources before discovery
echo "[5/8] Listing resources in $rg_name..."
resource_count=$(az resource list --resource-group "$rg_name" --query "length(@)" -o tsv)
echo -e "${GREEN}✓${NC} Found $resource_count resources"

if [[ $resource_count -eq 0 ]]; then
    echo -e "${YELLOW}⚠${NC} No resources to discover. Skipping discovery test."
    echo "    You can run this test again after creating some Azure resources."
    rm -f "$STATE_DB"
    exit 0
fi

# Show resource details
az resource list --resource-group "$rg_name" --query "[].{Name:name, Type:type}" -o table

# Run discovery
echo "[6/8] Running discovery on $rg_name..."
if discover "resource-group" "$rg_name" 2>&1; then
    echo -e "${GREEN}✓${NC} Discovery completed"
else
    echo -e "${RED}✗${NC} Discovery failed"
    echo "Debug: Checking STATE_DB=$STATE_DB"
    ls -lh "$STATE_DB" || echo "Database not found"
    exit 1
fi

# Verify database contents
echo "[7/8] Verifying database..."
stored_count=$(sqlite3 "$STATE_DB" "SELECT COUNT(*) FROM resources WHERE deleted_at IS NULL;" 2>&1)
if [[ $stored_count -gt 0 ]]; then
    echo -e "${GREEN}✓${NC} Found $stored_count resources in database"

    # Show what was discovered
    echo "    Resources by type:"
    sqlite3 "$STATE_DB" "
        SELECT resource_type, COUNT(*) as count
        FROM resources
        WHERE deleted_at IS NULL
        GROUP BY resource_type;
    " | while IFS='|' read -r rtype rcount; do
        echo "      - $rtype: $rcount"
    done
else
    echo -e "${RED}✗${NC} No resources in database (expected $resource_count)"
    exit 1
fi

# Check outputs
echo "[8/8] Checking outputs..."
outputs_created=0

yaml_file="${DISCOVERED_DIR}/summary-${rg_name}-$(date +%Y%m%d).yaml"
if [[ -f "$yaml_file" ]]; then
    echo -e "${GREEN}✓${NC} YAML: $yaml_file ($(wc -l < "$yaml_file") lines)"
    ((outputs_created++))
fi

json_file="${DISCOVERED_DIR}/full-${rg_name}-$(date +%Y%m%d).json"
if [[ -f "$json_file" ]]; then
    echo -e "${GREEN}✓${NC} JSON: $json_file ($(wc -l < "$json_file") lines)"
    ((outputs_created++))
fi

dot_file="${DISCOVERED_DIR}/dependency-graph-${rg_name}-$(date +%Y%m%d).dot"
if [[ -f "$dot_file" ]]; then
    echo -e "${GREEN}✓${NC} DOT: $dot_file ($(wc -l < "$dot_file") lines)"
    ((outputs_created++))
fi

if [[ $outputs_created -eq 3 ]]; then
    echo -e "${GREEN}✓${NC} All outputs created"
else
    echo -e "${YELLOW}⚠${NC} Only $outputs_created/3 outputs created"
fi

echo ""
echo "========================================"
echo -e "${GREEN}Discovery test passed!${NC}"
echo "========================================"
echo "Discovered $stored_count resources from Azure"
echo "Database: $STATE_DB ($(du -h "$STATE_DB" | cut -f1))"
echo "Outputs: $DISCOVERED_DIR"
echo ""

# Cleanup
echo "Cleaning up test database..."
rm -f "$STATE_DB"
echo "Done!"
