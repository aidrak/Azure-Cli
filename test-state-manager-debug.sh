#!/bin/bash
set -x  # Debug mode

PROJECT_ROOT="/mnt/cache_pool/development/azure-cli"
STATE_DB="${PROJECT_ROOT}/test-debug.db"
AZURE_RESOURCE_GROUP="test-rg"

# Clean up
rm -f "$STATE_DB"

# Initialize database directly
sqlite3 "$STATE_DB" < "${PROJECT_ROOT}/schemas/state.schema.sql"

# Source state manager
source "${PROJECT_ROOT}/core/state-manager.sh"

# Try to store a resource
vm_json='{
  "id": "/subscriptions/test-sub/resourceGroups/test-rg/providers/Microsoft.Compute/virtualMachines/test-vm-01",
  "type": "Microsoft.Compute/virtualMachines",
  "name": "test-vm-01",
  "resourceGroup": "test-rg",
  "subscriptionId": "test-sub-123",
  "location": "eastus",
  "properties": {"provisioningState": "Succeeded"},
  "tags": {"env": "test"}
}'

echo "=== Calling store_resource ==="
store_resource "$vm_json"
result=$?
echo "=== store_resource returned: $result ==="

echo "=== Checking database ==="
sqlite3 "$STATE_DB" "SELECT COUNT(*) AS count FROM resources;"
sqlite3 "$STATE_DB" "SELECT * FROM resources;" || echo "No resources found"

rm -f "$STATE_DB"
