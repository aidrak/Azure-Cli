#!/usr/bin/env bats
# ==============================================================================
# BATS Tests: State Manager
# ==============================================================================

load '../helpers/test_helper'

setup() {
    setup_test_env
    source "${PROJECT_ROOT}/core/state-manager.sh" 2>/dev/null || true
}

teardown() {
    teardown_test_env
}

# ==============================================================================
# Database Initialization Tests
# ==============================================================================

@test "init_state_db creates database file" {
    skip_if_missing sqlite3

    init_state_db
    assert_file_exists "$STATE_DB"
}

@test "init_state_db creates required tables" {
    skip_if_missing sqlite3

    init_state_db

    # Check resources table exists
    local tables
    tables=$(sqlite3 "$STATE_DB" ".tables")
    [[ "$tables" == *"resources"* ]]
    [[ "$tables" == *"operations"* ]]
    [[ "$tables" == *"dependencies"* ]]
}

@test "init_state_db is idempotent" {
    skip_if_missing sqlite3

    init_state_db
    init_state_db  # Should not fail on second call

    assert_file_exists "$STATE_DB"
}

# ==============================================================================
# Operation Output Tests (New Feature)
# ==============================================================================

@test "store_operation_output stores value in database" {
    skip_if_missing sqlite3

    init_state_db
    store_operation_output "test-op" "output_key" "output_value"

    local result
    result=$(get_operation_output "test-op" "output_key")
    [[ "$result" == "output_value" ]]
}

@test "store_operation_output updates existing value" {
    skip_if_missing sqlite3

    init_state_db
    store_operation_output "test-op" "key1" "value1"
    store_operation_output "test-op" "key1" "value2"

    local result
    result=$(get_operation_output "test-op" "key1")
    [[ "$result" == "value2" ]]
}

@test "get_operation_output returns empty for missing key" {
    skip_if_missing sqlite3

    init_state_db

    run get_operation_output "nonexistent-op" "missing_key"
    [[ $status -ne 0 ]] || [[ -z "$output" ]]
}

@test "get_output_by_key retrieves most recent value" {
    skip_if_missing sqlite3

    init_state_db
    store_operation_output "op1" "shared_key" "value_from_op1"
    store_operation_output "op2" "shared_key" "value_from_op2"

    local result
    result=$(get_output_by_key "shared_key")
    [[ "$result" == "value_from_op2" ]]
}

@test "get_operation_outputs returns all outputs for operation" {
    skip_if_missing sqlite3
    skip_if_missing jq

    init_state_db
    store_operation_output "multi-op" "key1" "value1"
    store_operation_output "multi-op" "key2" "value2"

    local outputs
    outputs=$(get_operation_outputs "multi-op")

    # Should be valid JSON array with 2 items
    local count
    count=$(echo "$outputs" | jq 'length')
    [[ "$count" == "2" ]]
}

# ==============================================================================
# Resource Management Tests
# ==============================================================================

@test "store_resource stores valid resource JSON" {
    skip_if_missing sqlite3
    skip_if_missing jq

    init_state_db

    local resource_json='{"id":"/subscriptions/123/resourceGroups/rg/providers/Microsoft.Compute/virtualMachines/vm1","type":"Microsoft.Compute/virtualMachines","name":"vm1","resourceGroup":"rg","subscriptionId":"123","location":"eastus","properties":{"provisioningState":"Succeeded"}}'

    store_resource "$resource_json"

    # Query should return the resource
    local result
    result=$(sqlite3 "$STATE_DB" "SELECT name FROM resources WHERE name='vm1'")
    [[ "$result" == "vm1" ]]
}

@test "store_resource rejects invalid JSON" {
    skip_if_missing sqlite3

    init_state_db

    run store_resource "not-valid-json"
    [[ $status -ne 0 ]]
}

# ==============================================================================
# Operation Management Tests
# ==============================================================================

@test "create_operation stores operation record" {
    skip_if_missing sqlite3

    init_state_db
    create_operation "test-exec-id" "storage" "Create Storage" "create"

    local result
    result=$(sqlite3 "$STATE_DB" "SELECT operation_name FROM operations WHERE operation_id='test-exec-id'")
    [[ "$result" == "Create Storage" ]]
}

@test "update_operation_status changes status" {
    skip_if_missing sqlite3

    init_state_db
    create_operation "status-test" "test" "Status Test" "create"
    update_operation_status "status-test" "running"

    local result
    result=$(sqlite3 "$STATE_DB" "SELECT status FROM operations WHERE operation_id='status-test'")
    [[ "$result" == "running" ]]
}

@test "update_operation_status records error message on failure" {
    skip_if_missing sqlite3

    init_state_db
    create_operation "fail-test" "test" "Fail Test" "create"
    update_operation_status "fail-test" "failed" "Connection timeout"

    local result
    result=$(sqlite3 "$STATE_DB" "SELECT error_message FROM operations WHERE operation_id='fail-test'")
    [[ "$result" == "Connection timeout" ]]
}

# ==============================================================================
# Dependency Management Tests
# ==============================================================================

@test "add_dependency creates relationship" {
    skip_if_missing sqlite3

    init_state_db

    # Store two mock resources first
    local res1='{"id":"/res1","type":"Microsoft.Test/resource","name":"res1","resourceGroup":"rg","subscriptionId":"123","properties":{}}'
    local res2='{"id":"/res2","type":"Microsoft.Test/resource","name":"res2","resourceGroup":"rg","subscriptionId":"123","properties":{}}'
    store_resource "$res1"
    store_resource "$res2"

    add_dependency "/res1" "/res2" "required" "uses"

    local count
    count=$(sqlite3 "$STATE_DB" "SELECT COUNT(*) FROM dependencies WHERE resource_id='/res1'")
    [[ "$count" == "1" ]]
}
