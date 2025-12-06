#!/bin/bash
# ==============================================================================
# State Manager Demonstration
# ==============================================================================
#
# Purpose: Demonstrate the capabilities of the state management system
#
# Usage:
#   ./demo-state-manager.sh
#
# ==============================================================================

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PROJECT_ROOT

# Colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}"
cat << 'EOF'
╔═══════════════════════════════════════════════════════════════════════╗
║                                                                       ║
║          Azure Infrastructure Toolkit - State Manager Demo           ║
║                                                                       ║
║  Production-grade SQLite state management for Azure infrastructure   ║
║                                                                       ║
╚═══════════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Clean slate
rm -f state.db

# Load state manager
echo "[*] Loading state manager..."
export CURRENT_LOG_LEVEL=2  # Reduce verbosity for demo
source core/state-manager.sh 2>/dev/null

# ==============================================================================
# DEMO 1: Database Initialization
# ==============================================================================

echo ""
echo -e "${YELLOW}═══ Demo 1: Database Initialization ═══${NC}"
echo ""

init_state_db

echo "[*] Database structure:"
sqlite3 state.db "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;" | head -10

# ==============================================================================
# DEMO 2: Resource Management
# ==============================================================================

echo ""
echo -e "${YELLOW}═══ Demo 2: Resource Management ═══${NC}"
echo ""

# Create sample resources
echo "[*] Storing resources..."

# Virtual Network
VNET_JSON='{
  "id": "/subscriptions/demo-sub/resourceGroups/rg-demo/providers/Microsoft.Network/virtualNetworks/demo-vnet",
  "name": "demo-vnet",
  "type": "Microsoft.Network/virtualNetworks",
  "location": "centralus",
  "resourceGroup": "rg-demo",
  "subscriptionId": "demo-sub-123",
  "properties": {
    "provisioningState": "Succeeded",
    "addressSpace": {"addressPrefixes": ["10.0.0.0/16"]}
  },
  "tags": {"environment": "demo", "purpose": "networking"}
}'

store_resource "$VNET_JSON" 2>/dev/null
echo "  ✓ Virtual Network stored"

# Subnet
SUBNET_JSON='{
  "id": "/subscriptions/demo-sub/resourceGroups/rg-demo/providers/Microsoft.Network/virtualNetworks/demo-vnet/subnets/default",
  "name": "default",
  "type": "Microsoft.Network/subnets",
  "location": "centralus",
  "resourceGroup": "rg-demo",
  "subscriptionId": "demo-sub-123",
  "properties": {
    "provisioningState": "Succeeded",
    "addressPrefix": "10.0.1.0/24"
  },
  "tags": {"environment": "demo"}
}'

store_resource "$SUBNET_JSON" 2>/dev/null
echo "  ✓ Subnet stored"

# Virtual Machine
VM_JSON='{
  "id": "/subscriptions/demo-sub/resourceGroups/rg-demo/providers/Microsoft.Compute/virtualMachines/demo-vm",
  "name": "demo-vm",
  "type": "Microsoft.Compute/virtualMachines",
  "location": "centralus",
  "resourceGroup": "rg-demo",
  "subscriptionId": "demo-sub-123",
  "properties": {
    "provisioningState": "Succeeded",
    "vmSize": "Standard_D4s_v6"
  },
  "tags": {"environment": "demo", "role": "compute"}
}'

store_resource "$VM_JSON" 2>/dev/null
echo "  ✓ Virtual Machine stored"

# Mark as managed
mark_as_managed "/subscriptions/demo-sub/resourceGroups/rg-demo/providers/Microsoft.Compute/virtualMachines/demo-vm" 2>/dev/null
echo "  ✓ VM marked as managed by toolkit"

# Show resources
echo ""
echo "[*] Resources in database:"
sqlite3 state.db "
SELECT
    name,
    resource_type,
    provisioning_state,
    CASE WHEN managed_by_toolkit = 1 THEN 'Yes' ELSE 'No' END as managed
FROM resources
ORDER BY name;
" -header -column

# ==============================================================================
# DEMO 3: Dependency Tracking
# ==============================================================================

echo ""
echo -e "${YELLOW}═══ Demo 3: Dependency Tracking ═══${NC}"
echo ""

echo "[*] Creating dependency graph..."

# VM depends on Subnet
add_dependency \
    "/subscriptions/demo-sub/resourceGroups/rg-demo/providers/Microsoft.Compute/virtualMachines/demo-vm" \
    "/subscriptions/demo-sub/resourceGroups/rg-demo/providers/Microsoft.Network/virtualNetworks/demo-vnet/subnets/default" \
    "required" "uses" 2>/dev/null

# Subnet depends on VNet
add_dependency \
    "/subscriptions/demo-sub/resourceGroups/rg-demo/providers/Microsoft.Network/virtualNetworks/demo-vnet/subnets/default" \
    "/subscriptions/demo-sub/resourceGroups/rg-demo/providers/Microsoft.Network/virtualNetworks/demo-vnet" \
    "required" "contains" 2>/dev/null

echo "  ✓ Dependencies added"
echo ""

# Show dependency graph
echo "[*] Dependency graph:"
sqlite3 state.db "
SELECT
    r1.name as Resource,
    d.relationship as Relationship,
    r2.name as DependsOn,
    d.dependency_type as Type
FROM dependencies d
JOIN resources r1 ON d.resource_id = r1.resource_id
JOIN resources r2 ON d.depends_on_resource_id = r2.resource_id
ORDER BY r1.name;
" -header -column

# Check if dependencies satisfied
echo ""
echo "[*] Checking if VM dependencies are satisfied..."
if check_dependencies_satisfied "/subscriptions/demo-sub/resourceGroups/rg-demo/providers/Microsoft.Compute/virtualMachines/demo-vm" 2>/dev/null; then
    echo -e "  ${GREEN}✓ All dependencies satisfied${NC}"
else
    echo "  ✗ Dependencies not satisfied"
fi

# ==============================================================================
# DEMO 4: Operation Tracking
# ==============================================================================

echo ""
echo -e "${YELLOW}═══ Demo 4: Operation Tracking ═══${NC}"
echo ""

echo "[*] Creating operations..."

# Create a golden image operation
OP1_ID="golden-image-$(date +%s)"
create_operation "$OP1_ID" "compute" "create-golden-image" "create" "" 2>/dev/null
update_operation_status "$OP1_ID" "running" 2>/dev/null
sleep 1
update_operation_progress "$OP1_ID" 1 3 "Installing FSLogix" 2>/dev/null
sleep 1
update_operation_progress "$OP1_ID" 2 3 "Configuring OS" 2>/dev/null
sleep 1
update_operation_progress "$OP1_ID" 3 3 "Capturing image" 2>/dev/null
update_operation_status "$OP1_ID" "completed" 2>/dev/null
log_operation "$OP1_ID" "SUCCESS" "Golden image created successfully" 2>/dev/null

# Create a deployment operation
OP2_ID="deploy-vm-$(date +%s)"
create_operation "$OP2_ID" "compute" "deploy-session-host" "create" "/subscriptions/demo-sub/resourceGroups/rg-demo/providers/Microsoft.Compute/virtualMachines/demo-vm" 2>/dev/null
update_operation_status "$OP2_ID" "running" 2>/dev/null
sleep 1
update_operation_status "$OP2_ID" "completed" 2>/dev/null
log_operation "$OP2_ID" "SUCCESS" "VM deployed successfully" 2>/dev/null

# Create a failed operation
OP3_ID="failed-op-$(date +%s)"
create_operation "$OP3_ID" "networking" "create-vnet" "create" "" 2>/dev/null
update_operation_status "$OP3_ID" "running" 2>/dev/null
sleep 1
update_operation_status "$OP3_ID" "failed" "Network quota exceeded" 2>/dev/null
log_operation "$OP3_ID" "ERROR" "Failed to create VNet" '{"error_code": "QuotaExceeded"}' 2>/dev/null

echo "  ✓ Operations created"
echo ""

# Show operations
echo "[*] Operations in database:"
sqlite3 state.db "
SELECT
    operation_id,
    capability,
    operation_name,
    status,
    duration,
    error_message
FROM operations
ORDER BY started_at DESC;
" -header -column

# ==============================================================================
# DEMO 5: Analytics
# ==============================================================================

echo ""
echo -e "${YELLOW}═══ Demo 5: Analytics & Reporting ═══${NC}"
echo ""

# Resource statistics
echo "[*] Resource statistics:"
managed_count=$(get_managed_resources_count 2>/dev/null)
echo "  • Managed resources: $managed_count"

total_resources=$(sqlite3 state.db "SELECT COUNT(*) FROM active_resources;")
echo "  • Total active resources: $total_resources"

# Operation statistics
echo ""
echo "[*] Operation statistics:"
sqlite3 state.db "
SELECT
    status,
    COUNT(*) as count,
    ROUND(AVG(duration), 2) as avg_duration_sec
FROM operations
GROUP BY status;
" -header -column

# Resources by type
echo ""
echo "[*] Resources by type:"
sqlite3 state.db "
SELECT
    SUBSTR(resource_type, INSTR(resource_type, '/') + 1) as type,
    COUNT(*) as count,
    SUM(CASE WHEN managed_by_toolkit = 1 THEN 1 ELSE 0 END) as managed
FROM active_resources
GROUP BY resource_type;
" -header -column

# ==============================================================================
# DEMO 6: Cache Performance
# ==============================================================================

echo ""
echo -e "${YELLOW}═══ Demo 6: Cache Management ═══${NC}"
echo ""

# Show cache info
echo "[*] Cache information:"
cache_entries=$(sqlite3 state.db "SELECT COUNT(*) FROM resources WHERE cache_expires_at > strftime('%s', 'now');")
echo "  • Valid cache entries: $cache_entries"
echo "  • Cache TTL: ${CACHE_TTL}s (5 minutes)"

# ==============================================================================
# SUMMARY
# ==============================================================================

echo ""
echo -e "${GREEN}"
cat << 'EOF'
╔═══════════════════════════════════════════════════════════════════════╗
║                                                                       ║
║                        Demo Complete!                                 ║
║                                                                       ║
║  The state.db database now contains:                                 ║
║    • 3 resources (VNet, Subnet, VM)                                  ║
║    • 2 dependency relationships                                      ║
║    • 3 operations (2 completed, 1 failed)                            ║
║    • Full audit trail and analytics                                  ║
║                                                                       ║
║  Key Features Demonstrated:                                          ║
║    ✓ Resource storage and management                                ║
║    ✓ Dependency graph tracking                                      ║
║    ✓ Operation lifecycle management                                 ║
║    ✓ Smart caching with TTL                                          ║
║    ✓ Analytics and reporting                                        ║
║                                                                       ║
║  Explore the database:                                               ║
║    sqlite3 state.db                                                  ║
║    .tables                                                           ║
║    SELECT * FROM resources;                                          ║
║    SELECT * FROM operations;                                         ║
║                                                                       ║
╚═══════════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"
