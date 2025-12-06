#!/bin/bash

# Direct SQL test
DB="/mnt/cache_pool/development/azure-cli/test-direct.db"
rm -f "$DB"

# Initialize
sqlite3 "$DB" < schemas/state.schema.sql

# Test direct insert
sqlite3 "$DB" <<'SQL'
INSERT INTO resources (
    resource_id, resource_type, name, resource_group, subscription_id,
    location, provisioning_state, properties_json, tags_json,
    discovered_at, last_validated_at, cache_expires_at
) VALUES (
    '/subscriptions/test-sub/resourceGroups/test-rg/providers/Microsoft.Compute/virtualMachines/test-vm-01',
    'Microsoft.Compute/virtualMachines',
    'test-vm-01',
    'test-rg',
    'test-sub-123',
    'eastus',
    'Succeeded',
    '{"test": "data"}',
    '{"env": "test"}',
    1234567890,
    1234567890,
    1234567890
);
SQL

# Check result
count=$(sqlite3 "$DB" "SELECT COUNT(*) FROM resources;")
echo "Resources in database: $count"

if [[ "$count" -eq 1 ]]; then
    echo "✓ Direct SQL insert works"
    sqlite3 "$DB" "SELECT resource_id, name, resource_type FROM resources;"
else
    echo "✗ Direct SQL insert failed"
fi

rm -f "$DB"
