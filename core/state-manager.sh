#!/bin/bash
# ==============================================================================
# State Manager - SQLite-based State Management for Azure Infrastructure Toolkit
# ==============================================================================
#
# Purpose: Production-grade state management with intelligent caching,
#          dependency tracking, operation history, and analytics
#
# Usage:
#   source core/state-manager.sh
#   init_state_db
#   store_resource "$resource_json"
#   get_resource "virtualMachines" "vm-name" "rg-name"
#   add_dependency "$resource_id" "$depends_on_id" "required" "uses"
#
# Features:
#   - Cache-first resource queries (5-minute TTL)
#   - Comprehensive operation tracking with resume capability
#   - Dependency graph management (DAG)
#   - Smart cache invalidation
#   - Full audit trail
#   - Analytics and reporting
#
# ==============================================================================

set -euo pipefail

# ==============================================================================
# CONFIGURATION
# ==============================================================================

# Project paths
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
STATE_DB="${STATE_DB:-${PROJECT_ROOT}/state.db}"
SCHEMA_FILE="${SCHEMA_FILE:-${PROJECT_ROOT}/schemas/state.schema.sql}"

# Cache TTL (seconds)
CACHE_TTL=300  # 5 minutes

# Source logger
if [[ -f "${PROJECT_ROOT}/core/logger.sh" ]]; then
    source "${PROJECT_ROOT}/core/logger.sh"
else
    # Fallback logging if logger not available
    log_info() { echo "[*] $1"; }
    log_warn() { echo "[!] WARNING: $1"; }
    log_error() { echo "[x] ERROR: $1" >&2; }
    log_success() { echo "[v] $1"; }
fi

# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

# Escape single quotes for SQL
sql_escape() {
    local input="$1"
    echo "$input" | sed "s/'/''/g"
}

# Get current Unix timestamp
get_timestamp() {
    date +%s
}

# Check if sqlite3 is available
check_sqlite3() {
    if ! command -v sqlite3 &> /dev/null; then
        log_error "sqlite3 is not installed. Please install it first."
        return 1
    fi
    return 0
}

# Execute SQLite command with error checking
execute_sql() {
    local sql="$1"
    local error_msg="${2:-SQL execution failed}"

    if ! check_sqlite3; then
        return 1
    fi

    local result
    local exit_code=0

    result=$(sqlite3 "$STATE_DB" "$sql" 2>&1) || exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        log_error "$error_msg: $result"
        return 1
    fi

    echo "$result"
    return 0
}

# Execute SQLite command with JSON output
execute_sql_json() {
    local sql="$1"
    local error_msg="${2:-SQL execution failed}"

    if ! check_sqlite3; then
        return 1
    fi

    local result
    local exit_code=0

    result=$(sqlite3 "$STATE_DB" -json "$sql" 2>&1) || exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        log_error "$error_msg: $result"
        return 1
    fi

    echo "$result"
    return 0
}

# ==============================================================================
# DATABASE INITIALIZATION
# ==============================================================================

init_state_db() {
    if ! check_sqlite3; then
        log_error "Cannot initialize database without sqlite3"
        return 1
    fi

    if [[ -f "$STATE_DB" ]]; then
        log_info "State database already exists" "state-manager"
        return 0
    fi

    log_info "Initializing state database at $STATE_DB" "state-manager"

    # Check if schema file exists
    if [[ ! -f "$SCHEMA_FILE" ]]; then
        log_error "Schema file not found: $SCHEMA_FILE"
        log_info "Creating database with inline schema..."
        create_schema_inline
    else
        # Create database from schema file
        sqlite3 "$STATE_DB" < "$SCHEMA_FILE" 2>&1 || {
            log_error "Failed to initialize database from schema file"
            return 1
        }
    fi

    log_success "State database initialized successfully" "state-manager"
    return 0
}

# Create schema inline (fallback if schema file doesn't exist)
create_schema_inline() {
    log_warn "Using inline schema creation (schema file not found)"

    sqlite3 "$STATE_DB" <<'EOF'
-- RESOURCES TABLE
CREATE TABLE IF NOT EXISTS resources (
    resource_id TEXT PRIMARY KEY,
    resource_type TEXT NOT NULL,
    name TEXT NOT NULL,
    resource_group TEXT NOT NULL,
    subscription_id TEXT NOT NULL,
    location TEXT,
    provisioning_state TEXT,
    managed_by_toolkit BOOLEAN DEFAULT 0,
    adopted_at INTEGER,
    created_at INTEGER,
    discovered_at INTEGER NOT NULL,
    last_validated_at INTEGER,
    last_modified_at INTEGER,
    properties_json TEXT,
    tags_json TEXT,
    cache_key TEXT,
    cache_expires_at INTEGER,
    deleted_at INTEGER,
    UNIQUE(resource_group, resource_type, name)
);

CREATE INDEX IF NOT EXISTS idx_resources_type ON resources(resource_type);
CREATE INDEX IF NOT EXISTS idx_resources_rg ON resources(resource_group);
CREATE INDEX IF NOT EXISTS idx_resources_managed ON resources(managed_by_toolkit);
CREATE INDEX IF NOT EXISTS idx_resources_cache ON resources(cache_key, cache_expires_at);

-- DEPENDENCIES TABLE
CREATE TABLE IF NOT EXISTS dependencies (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    resource_id TEXT NOT NULL,
    depends_on_resource_id TEXT NOT NULL,
    dependency_type TEXT NOT NULL,
    relationship TEXT,
    discovered_at INTEGER NOT NULL,
    validated_at INTEGER,
    is_bidirectional BOOLEAN DEFAULT 0,
    FOREIGN KEY (resource_id) REFERENCES resources(resource_id) ON DELETE CASCADE,
    FOREIGN KEY (depends_on_resource_id) REFERENCES resources(resource_id) ON DELETE CASCADE,
    UNIQUE(resource_id, depends_on_resource_id, relationship)
);

CREATE INDEX IF NOT EXISTS idx_dependencies_from ON dependencies(resource_id);
CREATE INDEX IF NOT EXISTS idx_dependencies_to ON dependencies(depends_on_resource_id);

-- OPERATIONS TABLE
CREATE TABLE IF NOT EXISTS operations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    operation_id TEXT NOT NULL UNIQUE,
    capability TEXT NOT NULL,
    operation_name TEXT NOT NULL,
    operation_type TEXT NOT NULL,
    resource_id TEXT,
    resource_type TEXT,
    resource_name TEXT,
    status TEXT NOT NULL,
    started_at INTEGER NOT NULL,
    completed_at INTEGER,
    duration INTEGER,
    current_step INTEGER DEFAULT 0,
    total_steps INTEGER DEFAULT 1,
    step_description TEXT,
    error_message TEXT,
    error_code TEXT,
    retry_count INTEGER DEFAULT 0,
    max_retries INTEGER DEFAULT 3,
    resume_data_json TEXT,
    checkpoint_data_json TEXT,
    parent_operation_id TEXT,
    triggered_by TEXT,
    config_snapshot_json TEXT,
    FOREIGN KEY (resource_id) REFERENCES resources(resource_id) ON DELETE SET NULL,
    FOREIGN KEY (parent_operation_id) REFERENCES operations(operation_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_operations_status ON operations(status);
CREATE INDEX IF NOT EXISTS idx_operations_capability ON operations(capability);
CREATE INDEX IF NOT EXISTS idx_operations_resource ON operations(resource_id);

-- OPERATION_LOGS TABLE
CREATE TABLE IF NOT EXISTS operation_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    operation_id TEXT NOT NULL,
    logged_at INTEGER NOT NULL,
    level TEXT NOT NULL,
    message TEXT NOT NULL,
    details_json TEXT,
    step_number INTEGER,
    FOREIGN KEY (operation_id) REFERENCES operations(operation_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_operation_logs_operation ON operation_logs(operation_id, logged_at);

-- CACHE_METADATA TABLE
CREATE TABLE IF NOT EXISTS cache_metadata (
    cache_key TEXT PRIMARY KEY,
    cached_at INTEGER NOT NULL,
    expires_at INTEGER NOT NULL,
    hit_count INTEGER DEFAULT 0,
    result_type TEXT NOT NULL,
    result_json TEXT NOT NULL,
    invalidated_at INTEGER,
    invalidation_reason TEXT
);

CREATE INDEX IF NOT EXISTS idx_cache_expires ON cache_metadata(expires_at);

-- VIEWS
CREATE VIEW IF NOT EXISTS active_resources AS
SELECT * FROM resources WHERE deleted_at IS NULL;

CREATE VIEW IF NOT EXISTS managed_resources AS
SELECT * FROM resources WHERE managed_by_toolkit = 1 AND deleted_at IS NULL;

CREATE VIEW IF NOT EXISTS failed_operations AS
SELECT * FROM operations
WHERE status = 'failed' AND retry_count < max_retries
ORDER BY started_at DESC;

CREATE VIEW IF NOT EXISTS running_operations AS
SELECT * FROM operations WHERE status = 'running' ORDER BY started_at DESC;
EOF

    if [[ $? -eq 0 ]]; then
        log_success "Database schema created successfully"
        return 0
    else
        log_error "Failed to create database schema"
        return 1
    fi
}

# ==============================================================================
# RESOURCE MANAGEMENT
# ==============================================================================

# Store or update resource in database
# Args: resource_json (full Azure resource JSON)
store_resource() {
    local resource_json="$1"

    if [[ -z "$resource_json" ]] || [[ "$resource_json" == "null" ]]; then
        log_error "Invalid resource JSON provided to store_resource"
        return 1
    fi

    # Extract fields from JSON
    local resource_id=$(echo "$resource_json" | jq -r '.id // empty')
    local resource_type=$(echo "$resource_json" | jq -r '.type // empty')
    local name=$(echo "$resource_json" | jq -r '.name // empty')
    local resource_group=$(echo "$resource_json" | jq -r '.resourceGroup // ""')
    local subscription_id=$(echo "$resource_json" | jq -r '.subscriptionId // ""')
    local location=$(echo "$resource_json" | jq -r '.location // ""')
    local provisioning_state=$(echo "$resource_json" | jq -r '.properties.provisioningState // ""')
    local tags_json=$(echo "$resource_json" | jq -c '.tags // {}')
    local properties_json=$(echo "$resource_json" | jq -c '.')

    # Validate required fields
    if [[ -z "$resource_id" ]] || [[ -z "$resource_type" ]] || [[ -z "$name" ]]; then
        log_error "Missing required fields in resource JSON (id, type, or name)"
        return 1
    fi

    # Escape for SQL
    resource_id=$(sql_escape "$resource_id")
    resource_type=$(sql_escape "$resource_type")
    name=$(sql_escape "$name")
    resource_group=$(sql_escape "$resource_group")
    subscription_id=$(sql_escape "$subscription_id")
    location=$(sql_escape "$location")
    provisioning_state=$(sql_escape "$provisioning_state")
    properties_json=$(sql_escape "$properties_json")
    tags_json=$(sql_escape "$tags_json")

    local now=$(get_timestamp)
    local cache_expires_at=$((now + CACHE_TTL))

    local sql="
INSERT INTO resources (
    resource_id, resource_type, name, resource_group, subscription_id,
    location, provisioning_state, properties_json, tags_json,
    discovered_at, last_validated_at, cache_expires_at
) VALUES (
    '$resource_id',
    '$resource_type',
    '$name',
    '$resource_group',
    '$subscription_id',
    '$location',
    '$provisioning_state',
    '$properties_json',
    '$tags_json',
    $now,
    $now,
    $cache_expires_at
)
ON CONFLICT(resource_id) DO UPDATE SET
    provisioning_state = excluded.provisioning_state,
    properties_json = excluded.properties_json,
    tags_json = excluded.tags_json,
    last_validated_at = excluded.last_validated_at,
    cache_expires_at = excluded.cache_expires_at;
"

    execute_sql "$sql" "Failed to store resource: $name" || return 1

    log_info "Stored resource: $name ($resource_type)" "state-manager"
    return 0
}

# Get resource from cache or query Azure
# Args: resource_type, resource_name, resource_group (optional, defaults to AZURE_RESOURCE_GROUP)
get_resource() {
    local resource_type="$1"
    local resource_name="$2"
    local resource_group="${3:-${AZURE_RESOURCE_GROUP:-}}"

    if [[ -z "$resource_type" ]] || [[ -z "$resource_name" ]]; then
        log_error "resource_type and resource_name are required"
        return 1
    fi

    # Escape for SQL
    resource_type=$(sql_escape "$resource_type")
    resource_name=$(sql_escape "$resource_name")
    resource_group=$(sql_escape "$resource_group")

    # Check cache first
    local now=$(get_timestamp)
    local sql="
SELECT properties_json FROM resources
WHERE resource_type LIKE '%/$resource_type'
AND name = '$resource_name'
AND resource_group = '$resource_group'
AND cache_expires_at > $now
AND deleted_at IS NULL;
"

    local cached_resource
    cached_resource=$(execute_sql "$sql" "Cache lookup failed")

    if [[ -n "$cached_resource" ]] && [[ "$cached_resource" != "null" ]]; then
        log_info "Cache HIT: $resource_name" "state-manager"
        echo "$cached_resource"
        return 0
    fi

    log_info "Cache MISS: $resource_name, querying Azure..." "state-manager"

    # Query Azure
    local azure_result
    azure_result=$(query_azure_resource "$resource_type" "$resource_name" "$resource_group")

    if [[ -n "$azure_result" ]] && [[ "$azure_result" != "null" ]]; then
        # Store in database
        store_resource "$azure_result"
        echo "$azure_result"
        return 0
    else
        log_warn "Resource not found in Azure: $resource_name"
        return 1
    fi
}

# Query Azure CLI for resource (helper function)
# Args: resource_type, resource_name, resource_group
query_azure_resource() {
    local resource_type="$1"
    local resource_name="$2"
    local resource_group="$3"

    # Map resource type to Azure CLI command
    local az_type=""
    case "$resource_type" in
        "virtualMachines"|"Microsoft.Compute/virtualMachines")
            az_type="vm"
            ;;
        "virtualNetworks"|"Microsoft.Network/virtualNetworks")
            az_type="network vnet"
            ;;
        "storageAccounts"|"Microsoft.Storage/storageAccounts")
            az_type="storage account"
            ;;
        *)
            # Generic resource query
            az_type="resource"
            ;;
    esac

    local result
    if [[ "$az_type" == "resource" ]]; then
        result=$(az resource show \
            --name "$resource_name" \
            --resource-group "$resource_group" \
            --resource-type "$resource_type" \
            2>/dev/null || echo "null")
    else
        result=$(az $az_type show \
            --name "$resource_name" \
            --resource-group "$resource_group" \
            2>/dev/null || echo "null")
    fi

    echo "$result"
}

# Mark resource as managed by toolkit
# Args: resource_id
mark_as_managed() {
    local resource_id="$1"

    if [[ -z "$resource_id" ]]; then
        log_error "resource_id is required"
        return 1
    fi

    resource_id=$(sql_escape "$resource_id")
    local now=$(get_timestamp)

    local sql="
UPDATE resources
SET managed_by_toolkit = 1,
    adopted_at = $now
WHERE resource_id = '$resource_id';
"

    execute_sql "$sql" "Failed to mark resource as managed" || return 1

    # Tag in Azure (best effort)
    tag_resource_in_azure "$resource_id" "managed-by" "azure-toolkit" || true

    log_success "Marked as managed: $resource_id" "state-manager"
    return 0
}

# Mark resource as created by toolkit
# Args: resource_id
mark_as_created() {
    local resource_id="$1"

    if [[ -z "$resource_id" ]]; then
        log_error "resource_id is required"
        return 1
    fi

    resource_id=$(sql_escape "$resource_id")
    local now=$(get_timestamp)

    local sql="
UPDATE resources
SET managed_by_toolkit = 1,
    created_at = $now
WHERE resource_id = '$resource_id';
"

    execute_sql "$sql" "Failed to mark resource as created" || return 1

    # Tag in Azure (best effort)
    tag_resource_in_azure "$resource_id" "created-by" "azure-toolkit" || true

    log_success "Marked as created: $resource_id" "state-manager"
    return 0
}

# Soft delete resource
# Args: resource_id
soft_delete_resource() {
    local resource_id="$1"

    if [[ -z "$resource_id" ]]; then
        log_error "resource_id is required"
        return 1
    fi

    resource_id=$(sql_escape "$resource_id")
    local now=$(get_timestamp)

    local sql="
UPDATE resources
SET deleted_at = $now
WHERE resource_id = '$resource_id';
"

    execute_sql "$sql" "Failed to soft delete resource" || return 1

    log_info "Soft deleted: $resource_id" "state-manager"
    return 0
}

# Tag resource in Azure
# Args: resource_id, tag_key, tag_value
tag_resource_in_azure() {
    local resource_id="$1"
    local tag_key="$2"
    local tag_value="$3"

    if [[ -z "$resource_id" ]] || [[ -z "$tag_key" ]] || [[ -z "$tag_value" ]]; then
        log_error "resource_id, tag_key, and tag_value are required"
        return 1
    fi

    # Update tags in Azure (best effort, don't fail if it doesn't work)
    az tag update \
        --resource-id "$resource_id" \
        --operation merge \
        --tags "$tag_key=$tag_value" \
        &>/dev/null || {
        log_warn "Failed to tag resource in Azure: $resource_id"
        return 1
    }

    log_info "Tagged resource in Azure: $tag_key=$tag_value" "state-manager"
    return 0
}

# ==============================================================================
# DEPENDENCY MANAGEMENT
# ==============================================================================

# Add dependency relationship
# Args: resource_id, depends_on_id, dependency_type (optional), relationship (optional)
add_dependency() {
    local resource_id="$1"
    local depends_on_id="$2"
    local dependency_type="${3:-required}"  # required, optional, reference
    local relationship="${4:-uses}"         # uses, contains, references

    if [[ -z "$resource_id" ]] || [[ -z "$depends_on_id" ]]; then
        log_error "resource_id and depends_on_id are required"
        return 1
    fi

    # Escape for SQL
    resource_id=$(sql_escape "$resource_id")
    depends_on_id=$(sql_escape "$depends_on_id")
    dependency_type=$(sql_escape "$dependency_type")
    relationship=$(sql_escape "$relationship")

    local now=$(get_timestamp)

    local sql="
INSERT INTO dependencies (
    resource_id, depends_on_resource_id, dependency_type, relationship, discovered_at
) VALUES (
    '$resource_id', '$depends_on_id', '$dependency_type', '$relationship', $now
)
ON CONFLICT(resource_id, depends_on_resource_id, relationship) DO UPDATE SET
    validated_at = $now;
"

    execute_sql "$sql" "Failed to add dependency" || return 1

    log_info "Added dependency: $resource_id → $depends_on_id ($relationship)" "state-manager"
    return 0
}

# Get resource dependencies (what this resource depends on)
# Args: resource_id
get_dependencies() {
    local resource_id="$1"

    if [[ -z "$resource_id" ]]; then
        log_error "resource_id is required"
        return 1
    fi

    resource_id=$(sql_escape "$resource_id")

    local sql="
SELECT
    r.resource_id,
    r.name,
    r.resource_type,
    d.dependency_type,
    d.relationship
FROM dependencies d
JOIN resources r ON d.depends_on_resource_id = r.resource_id
WHERE d.resource_id = '$resource_id'
AND r.deleted_at IS NULL;
"

    execute_sql_json "$sql" "Failed to get dependencies"
}

# Get resources that depend on this one (dependents)
# Args: resource_id
get_dependents() {
    local resource_id="$1"

    if [[ -z "$resource_id" ]]; then
        log_error "resource_id is required"
        return 1
    fi

    resource_id=$(sql_escape "$resource_id")

    local sql="
SELECT
    r.resource_id,
    r.name,
    r.resource_type,
    d.dependency_type,
    d.relationship
FROM dependencies d
JOIN resources r ON d.resource_id = r.resource_id
WHERE d.depends_on_resource_id = '$resource_id'
AND r.deleted_at IS NULL;
"

    execute_sql_json "$sql" "Failed to get dependents"
}

# Check if all dependencies are satisfied
# Args: resource_id
# Returns: 0 if satisfied, 1 if not
check_dependencies_satisfied() {
    local resource_id="$1"

    if [[ -z "$resource_id" ]]; then
        log_error "resource_id is required"
        return 1
    fi

    resource_id=$(sql_escape "$resource_id")

    local sql="
SELECT COUNT(*) FROM dependencies d
LEFT JOIN resources r ON d.depends_on_resource_id = r.resource_id
WHERE d.resource_id = '$resource_id'
AND d.dependency_type = 'required'
AND (r.resource_id IS NULL OR r.provisioning_state != 'Succeeded' OR r.deleted_at IS NOT NULL);
"

    local unsatisfied
    unsatisfied=$(execute_sql "$sql" "Failed to check dependencies")

    if [[ "$unsatisfied" -eq 0 ]]; then
        log_info "All dependencies satisfied for: $resource_id" "state-manager"
        return 0
    else
        log_warn "Unsatisfied dependencies: $unsatisfied" "state-manager"
        return 1
    fi
}

# ==============================================================================
# OPERATION MANAGEMENT
# ==============================================================================

# Create operation record
# Args: operation_id, capability, operation_name, operation_type, resource_id (optional)
create_operation() {
    local operation_id="$1"
    local capability="$2"
    local operation_name="$3"
    local operation_type="$4"
    local resource_id="${5:-}"

    if [[ -z "$operation_id" ]] || [[ -z "$capability" ]] || [[ -z "$operation_name" ]] || [[ -z "$operation_type" ]]; then
        log_error "operation_id, capability, operation_name, and operation_type are required"
        return 1
    fi

    # Escape for SQL
    operation_id=$(sql_escape "$operation_id")
    capability=$(sql_escape "$capability")
    operation_name=$(sql_escape "$operation_name")
    operation_type=$(sql_escape "$operation_type")

    local now=$(get_timestamp)

    local resource_id_value="NULL"
    if [[ -n "$resource_id" ]]; then
        resource_id=$(sql_escape "$resource_id")
        resource_id_value="'$resource_id'"
    fi

    local sql="
INSERT INTO operations (
    operation_id, capability, operation_name, operation_type,
    resource_id, status, started_at
) VALUES (
    '$operation_id', '$capability', '$operation_name', '$operation_type',
    $resource_id_value, 'pending', $now
);
"

    execute_sql "$sql" "Failed to create operation" || return 1

    log_info "Created operation: $operation_id" "state-manager"
    return 0
}

# Update operation status
# Args: operation_id, status, error_message (optional)
update_operation_status() {
    local operation_id="$1"
    local status="$2"
    local error_message="${3:-}"

    if [[ -z "$operation_id" ]] || [[ -z "$status" ]]; then
        log_error "operation_id and status are required"
        return 1
    fi

    # Escape for SQL
    operation_id=$(sql_escape "$operation_id")
    status=$(sql_escape "$status")

    local now=$(get_timestamp)
    local sql=""

    case "$status" in
        running)
            sql="
UPDATE operations
SET status = '$status',
    started_at = $now
WHERE operation_id = '$operation_id';
"
            ;;
        completed|failed)
            local error_value="NULL"
            if [[ -n "$error_message" ]]; then
                error_message=$(sql_escape "$error_message")
                error_value="'$error_message'"
            fi

            sql="
UPDATE operations
SET status = '$status',
    completed_at = $now,
    duration = $now - started_at,
    error_message = $error_value
WHERE operation_id = '$operation_id';
"
            ;;
        *)
            sql="
UPDATE operations
SET status = '$status'
WHERE operation_id = '$operation_id';
"
            ;;
    esac

    execute_sql "$sql" "Failed to update operation status" || return 1

    log_info "Updated operation $operation_id: $status" "state-manager"
    return 0
}

# Update operation progress
# Args: operation_id, current_step, total_steps, step_description (optional)
update_operation_progress() {
    local operation_id="$1"
    local current_step="$2"
    local total_steps="$3"
    local step_description="${4:-}"

    if [[ -z "$operation_id" ]] || [[ -z "$current_step" ]] || [[ -z "$total_steps" ]]; then
        log_error "operation_id, current_step, and total_steps are required"
        return 1
    fi

    # Escape for SQL
    operation_id=$(sql_escape "$operation_id")

    local step_desc_value="NULL"
    if [[ -n "$step_description" ]]; then
        step_description=$(sql_escape "$step_description")
        step_desc_value="'$step_description'"
    fi

    local sql="
UPDATE operations
SET current_step = $current_step,
    total_steps = $total_steps,
    step_description = $step_desc_value
WHERE operation_id = '$operation_id';
"

    execute_sql "$sql" "Failed to update operation progress" || return 1

    log_info "$current_step/$total_steps: $step_description" "state-manager"
    return 0
}

# Log operation message
# Args: operation_id, level, message, details (optional JSON)
log_operation() {
    local operation_id="$1"
    local level="$2"
    local message="$3"
    local details="${4:-}"

    if [[ -z "$operation_id" ]] || [[ -z "$level" ]] || [[ -z "$message" ]]; then
        log_error "operation_id, level, and message are required"
        return 1
    fi

    # Escape for SQL
    operation_id=$(sql_escape "$operation_id")
    level=$(sql_escape "$level")
    message=$(sql_escape "$message")

    local now=$(get_timestamp)

    local details_value="NULL"
    if [[ -n "$details" ]]; then
        details=$(sql_escape "$details")
        details_value="'$details'"
    fi

    local sql="
INSERT INTO operation_logs (operation_id, logged_at, level, message, details_json)
VALUES (
    '$operation_id',
    $now,
    '$level',
    '$message',
    $details_value
);
"

    execute_sql "$sql" "Failed to log operation message" || return 1
    return 0
}

# Get operation status
# Args: operation_id
get_operation_status() {
    local operation_id="$1"

    if [[ -z "$operation_id" ]]; then
        log_error "operation_id is required"
        return 1
    fi

    operation_id=$(sql_escape "$operation_id")

    local sql="
SELECT
    operation_id,
    capability,
    operation_name,
    operation_type,
    status,
    datetime(started_at, 'unixepoch') as started_at,
    datetime(completed_at, 'unixepoch') as completed_at,
    duration,
    current_step,
    total_steps,
    step_description,
    error_message
FROM operations
WHERE operation_id = '$operation_id';
"

    execute_sql_json "$sql" "Failed to get operation status"
}

# Get failed operations
get_failed_operations() {
    local sql="SELECT * FROM failed_operations LIMIT 20;"
    execute_sql_json "$sql" "Failed to get failed operations"
}

# Get running operations
get_running_operations() {
    local sql="SELECT * FROM running_operations;"
    execute_sql_json "$sql" "Failed to get running operations"
}

# ==============================================================================
# OPERATION OUTPUTS (Inter-Operation State Passing)
# ==============================================================================
# These functions replace file-based state passing (e.g., /tmp/storage-account-name.txt)
# with persistent SQLite storage for passing values between operations.

# Store operation output value
# Args: operation_id, output_key, output_value
# Example: store_operation_output "account-create" "storage_account_name" "stfslogix001"
store_operation_output() {
    local operation_id="$1"
    local output_key="$2"
    local output_value="$3"

    if [[ -z "$operation_id" ]] || [[ -z "$output_key" ]]; then
        log_error "operation_id and output_key are required"
        return 1
    fi

    # Escape for SQL
    operation_id=$(sql_escape "$operation_id")
    output_key=$(sql_escape "$output_key")
    output_value=$(sql_escape "$output_value")

    local now=$(get_timestamp)

    # First ensure the operation_outputs table exists
    local create_table_sql="
CREATE TABLE IF NOT EXISTS operation_outputs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    operation_id TEXT NOT NULL,
    output_key TEXT NOT NULL,
    output_value TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    updated_at INTEGER,
    UNIQUE(operation_id, output_key)
);
CREATE INDEX IF NOT EXISTS idx_operation_outputs_op ON operation_outputs(operation_id);
CREATE INDEX IF NOT EXISTS idx_operation_outputs_key ON operation_outputs(output_key);
"
    execute_sql "$create_table_sql" "Failed to create operation_outputs table" 2>/dev/null || true

    local sql="
INSERT INTO operation_outputs (operation_id, output_key, output_value, created_at)
VALUES ('$operation_id', '$output_key', '$output_value', $now)
ON CONFLICT(operation_id, output_key) DO UPDATE SET
    output_value = excluded.output_value,
    updated_at = $now;
"

    execute_sql "$sql" "Failed to store operation output" || return 1

    log_info "Stored output: $operation_id.$output_key = $output_value" "state-manager"
    return 0
}

# Get operation output value
# Args: operation_id, output_key
# Returns: output_value (or empty if not found)
# Example: storage_name=$(get_operation_output "account-create" "storage_account_name")
get_operation_output() {
    local operation_id="$1"
    local output_key="$2"

    if [[ -z "$operation_id" ]] || [[ -z "$output_key" ]]; then
        log_error "operation_id and output_key are required"
        return 1
    fi

    # Escape for SQL
    operation_id=$(sql_escape "$operation_id")
    output_key=$(sql_escape "$output_key")

    local sql="
SELECT output_value FROM operation_outputs
WHERE operation_id = '$operation_id' AND output_key = '$output_key';
"

    local result
    result=$(execute_sql "$sql" "Failed to get operation output" 2>/dev/null)

    if [[ -n "$result" ]]; then
        echo "$result"
        return 0
    else
        # Not found, return empty
        return 1
    fi
}

# Get all outputs for an operation
# Args: operation_id
# Returns: JSON array of outputs
get_operation_outputs() {
    local operation_id="$1"

    if [[ -z "$operation_id" ]]; then
        log_error "operation_id is required"
        return 1
    fi

    operation_id=$(sql_escape "$operation_id")

    local sql="
SELECT output_key, output_value, datetime(created_at, 'unixepoch') as created_at
FROM operation_outputs
WHERE operation_id = '$operation_id';
"

    execute_sql_json "$sql" "Failed to get operation outputs"
}

# Get output by key (any operation)
# Useful when you know the key but not which operation created it
# Args: output_key
# Returns: most recent output_value for that key
get_output_by_key() {
    local output_key="$1"

    if [[ -z "$output_key" ]]; then
        log_error "output_key is required"
        return 1
    fi

    output_key=$(sql_escape "$output_key")

    local sql="
SELECT output_value FROM operation_outputs
WHERE output_key = '$output_key'
ORDER BY COALESCE(updated_at, created_at) DESC
LIMIT 1;
"

    local result
    result=$(execute_sql "$sql" "Failed to get output by key" 2>/dev/null)

    if [[ -n "$result" ]]; then
        echo "$result"
        return 0
    else
        return 1
    fi
}

# Delete operation outputs (cleanup)
# Args: operation_id (optional - if not provided, deletes all old outputs)
delete_operation_outputs() {
    local operation_id="${1:-}"

    if [[ -n "$operation_id" ]]; then
        operation_id=$(sql_escape "$operation_id")
        local sql="DELETE FROM operation_outputs WHERE operation_id = '$operation_id';"
        execute_sql "$sql" "Failed to delete operation outputs" || return 1
        log_info "Deleted outputs for operation: $operation_id" "state-manager"
    else
        # Delete outputs older than 7 days
        local cutoff=$(($(get_timestamp) - 604800))
        local sql="DELETE FROM operation_outputs WHERE created_at < $cutoff;"
        execute_sql "$sql" "Failed to delete old operation outputs" || return 1
        log_info "Deleted operation outputs older than 7 days" "state-manager"
    fi

    return 0
}

# ==============================================================================
# CACHE MANAGEMENT
# ==============================================================================

# Invalidate cache for pattern
# Args: pattern (SQL LIKE pattern), reason (optional)
invalidate_cache() {
    local pattern="${1:-*}"
    local reason="${2:-manual}"

    # Escape for SQL
    pattern=$(sql_escape "$pattern")
    reason=$(sql_escape "$reason")

    local now=$(get_timestamp)

    # Invalidate cache_metadata
    local sql1="
UPDATE cache_metadata
SET invalidated_at = $now,
    invalidation_reason = '$reason'
WHERE cache_key LIKE '$pattern'
AND invalidated_at IS NULL;
"

    # Invalidate resources cache
    local sql2="
UPDATE resources
SET cache_expires_at = 0
WHERE resource_type LIKE '$pattern';
"

    execute_sql "$sql1" "Failed to invalidate cache metadata" || return 1
    execute_sql "$sql2" "Failed to invalidate resources cache" || return 1

    log_info "Invalidated cache: $pattern (reason: $reason)" "state-manager"
    return 0
}

# Clean expired cache entries
clean_expired_cache() {
    local now=$(get_timestamp)

    local sql="
DELETE FROM cache_metadata
WHERE expires_at < $now OR invalidated_at IS NOT NULL;
"

    execute_sql "$sql" "Failed to clean expired cache" || return 1

    log_info "Cleaned expired cache entries" "state-manager"
    return 0
}

# ==============================================================================
# ANALYTICS & REPORTING
# ==============================================================================

# Get operation statistics
get_operation_stats() {
    local sql="
SELECT
    capability,
    operation_type,
    status,
    COUNT(*) as count,
    AVG(duration) as avg_duration,
    MIN(duration) as min_duration,
    MAX(duration) as max_duration
FROM operations
WHERE completed_at IS NOT NULL
GROUP BY capability, operation_type, status
ORDER BY count DESC;
"

    execute_sql_json "$sql" "Failed to get operation stats"
}

# Get managed resources count
get_managed_resources_count() {
    local sql="SELECT COUNT(*) FROM managed_resources;"
    execute_sql "$sql" "Failed to get managed resources count"
}

# Get resources by type
get_resources_by_type() {
    local sql="
SELECT
    resource_type,
    COUNT(*) as count,
    SUM(CASE WHEN managed_by_toolkit = 1 THEN 1 ELSE 0 END) as managed_count
FROM active_resources
GROUP BY resource_type
ORDER BY count DESC;
"

    execute_sql_json "$sql" "Failed to get resources by type"
}

# ==============================================================================
# EXPORT FUNCTIONS
# ==============================================================================

export -f init_state_db
export -f store_resource get_resource
export -f mark_as_managed mark_as_created soft_delete_resource
export -f query_azure_resource tag_resource_in_azure
export -f add_dependency get_dependencies get_dependents check_dependencies_satisfied
export -f create_operation update_operation_status update_operation_progress
export -f log_operation get_operation_status get_failed_operations get_running_operations
export -f store_operation_output get_operation_output get_operation_outputs get_output_by_key delete_operation_outputs
export -f invalidate_cache clean_expired_cache
export -f get_operation_stats get_managed_resources_count get_resources_by_type
export -f sql_escape execute_sql execute_sql_json

# ==============================================================================
# INITIALIZATION
# ==============================================================================

log_info "State Manager loaded" "state-manager"
