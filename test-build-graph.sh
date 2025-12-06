#!/bin/bash
PROJECT_ROOT="/mnt/cache_pool/development/azure-cli"
STATE_DB="${PROJECT_ROOT}/test-graph.db"
AZURE_RESOURCE_GROUP="test-rg"

rm -f "$STATE_DB"
sqlite3 "$STATE_DB" < "${PROJECT_ROOT}/schemas/state.schema.sql"

source "${PROJECT_ROOT}/core/state-manager.sh"
source "${PROJECT_ROOT}/core/dependency-resolver.sh"

# Add some test data
vm_id="/subscriptions/test/resourceGroups/rg/providers/Microsoft.Compute/virtualMachines/vm1"
nic_id="/subscriptions/test/resourceGroups/rg/providers/Microsoft.Network/networkInterfaces/nic1"

# Store resources
sqlite3 "$STATE_DB" <<SQL
INSERT INTO resources (resource_id, resource_type, name, resource_group, subscription_id, discovered_at, last_validated_at, cache_expires_at)
VALUES 
('$vm_id', 'Microsoft.Compute/virtualMachines', 'vm1', 'rg', 'test-sub', 1234567890, 1234567890, 9999999999),
('$nic_id', 'Microsoft.Network/networkInterfaces', 'nic1', 'rg', 'test-sub', 1234567890, 1234567890, 9999999999);

INSERT INTO dependencies (resource_id, depends_on_resource_id, dependency_type, relationship, discovered_at)
VALUES ('$vm_id', '$nic_id', 'required', 'uses', 1234567890);
SQL

echo "=== Building graph ==="
graph=$(build_dependency_graph 2>&1)
echo "Graph output:"
echo "$graph"
echo ""
echo "=== Checking JSON validity ==="
echo "$graph" | jq '.' || echo "Invalid JSON"

rm -f "$STATE_DB"
