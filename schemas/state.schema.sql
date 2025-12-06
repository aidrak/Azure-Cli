-- ==============================================================================
-- AZURE INFRASTRUCTURE TOOLKIT - SQLite State Management Schema
-- ==============================================================================
-- Production-grade SQLite database schema for Azure VDI deployment engine
-- Supports declarative, idempotent, and self-healing deployments
--
-- Usage:
--   sqlite3 state.db < schemas/state.schema.sql
--
-- This schema provides:
--   - Resource metadata and properties tracking
--   - Dependency graph (DAG) for resource relationships
--   - Complete operation history with resume capability
--   - Smart caching with invalidation
--   - Comprehensive audit trail
--   - Performance metrics and analytics
-- ==============================================================================

-- Enable foreign key support
PRAGMA foreign_keys = ON;

-- ==============================================================================
-- RESOURCES TABLE - Core resource metadata
-- ==============================================================================
-- Stores Azure resource information with management tracking
CREATE TABLE resources (
    -- Primary identification
    resource_id TEXT PRIMARY KEY,                   -- Azure resource ID (full path)
    resource_type TEXT NOT NULL,                    -- e.g., 'Microsoft.Compute/virtualMachines'
    name TEXT NOT NULL,                             -- Resource name
    resource_group TEXT NOT NULL,                   -- Azure resource group name
    subscription_id TEXT NOT NULL,                  -- Azure subscription ID

    -- Location and state
    location TEXT,                                  -- Azure region
    provisioning_state TEXT,                        -- 'Succeeded', 'Failed', 'Running', etc.

    -- Management tracking
    managed_by_toolkit BOOLEAN DEFAULT 0,           -- 1 = managed/created by this toolkit, 0 = external
    adopted_at INTEGER,                             -- UNIX timestamp when adopted
    created_at INTEGER,                             -- UNIX timestamp when created by toolkit

    -- Discovery and validation
    discovered_at INTEGER NOT NULL,                 -- UNIX timestamp when first discovered
    last_validated_at INTEGER,                      -- UNIX timestamp when last checked in Azure
    last_modified_at INTEGER,                       -- UNIX timestamp when last modified

    -- Full resource data (JSON)
    properties_json TEXT,                           -- Complete Azure properties JSON
    tags_json TEXT,                                 -- Resource tags as JSON object

    -- Cache invalidation
    cache_key TEXT,                                 -- Key for cache lookups
    cache_expires_at INTEGER,                       -- UNIX timestamp when cache entry expires

    -- Soft delete support
    deleted_at INTEGER,                             -- NULL if active, timestamp if soft-deleted

    -- Unique constraint on resource identification
    UNIQUE(resource_group, resource_type, name)
);

-- Indexes for common query patterns
CREATE INDEX idx_resources_type ON resources(resource_type);
CREATE INDEX idx_resources_rg ON resources(resource_group);
CREATE INDEX idx_resources_sub ON resources(subscription_id);
CREATE INDEX idx_resources_managed ON resources(managed_by_toolkit);
CREATE INDEX idx_resources_state ON resources(provisioning_state);
CREATE INDEX idx_resources_cache ON resources(cache_key, cache_expires_at);
CREATE INDEX idx_resources_active ON resources(deleted_at) WHERE deleted_at IS NULL;
CREATE INDEX idx_resources_discovered ON resources(discovered_at DESC);

-- ==============================================================================
-- DEPENDENCIES TABLE - Resource relationship graph
-- ==============================================================================
-- Tracks dependencies between resources to build deployment DAG
CREATE TABLE dependencies (
    id INTEGER PRIMARY KEY AUTOINCREMENT,

    -- Relationship definition
    resource_id TEXT NOT NULL,                      -- Dependent resource (depends on something)
    depends_on_resource_id TEXT NOT NULL,           -- Dependency target (what it depends on)
    dependency_type TEXT NOT NULL,                  -- 'required', 'optional', 'reference'

    -- Relationship metadata
    relationship TEXT,                              -- 'uses', 'contains', 'references', 'linked_by'
    discovered_at INTEGER NOT NULL,                 -- UNIX timestamp when relationship discovered
    validated_at INTEGER,                           -- UNIX timestamp when relationship was last verified

    -- Bidirectional navigation flag
    is_bidirectional BOOLEAN DEFAULT 0,             -- 1 if dependency goes both ways

    -- Foreign key constraints with CASCADE delete
    FOREIGN KEY (resource_id) REFERENCES resources(resource_id) ON DELETE CASCADE,
    FOREIGN KEY (depends_on_resource_id) REFERENCES resources(resource_id) ON DELETE CASCADE,

    -- Unique constraint per relationship
    UNIQUE(resource_id, depends_on_resource_id, relationship)
);

-- Indexes for navigation in dependency graph
CREATE INDEX idx_dependencies_from ON dependencies(resource_id);
CREATE INDEX idx_dependencies_to ON dependencies(depends_on_resource_id);
CREATE INDEX idx_dependencies_type ON dependencies(dependency_type);
CREATE INDEX idx_dependencies_discovered ON dependencies(discovered_at DESC);

-- ==============================================================================
-- OPERATIONS TABLE - Complete operation history and tracking
-- ==============================================================================
-- Tracks all operations performed on resources with full lifecycle management
CREATE TABLE operations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,

    -- Operation identification
    operation_id TEXT NOT NULL UNIQUE,              -- Unique operation identifier (e.g., 'vm-create-20251206-103000')
    capability TEXT NOT NULL,                       -- Capability: 'compute', 'networking', 'storage', 'identity', 'avd'
    operation_name TEXT NOT NULL,                   -- Operation name: 'vm-create', 'vnet-adopt', 'nic-validate', etc.
    operation_type TEXT NOT NULL,                   -- Operation type: 'create', 'adopt', 'modify', 'validate', 'delete'

    -- Target resource information
    resource_id TEXT,                               -- Links to resources table
    resource_type TEXT,                             -- Type of resource being operated on
    resource_name TEXT,                             -- Name of resource being operated on

    -- Execution tracking
    status TEXT NOT NULL,                           -- 'pending', 'running', 'completed', 'failed', 'blocked'
    started_at INTEGER NOT NULL,                    -- UNIX timestamp when operation started
    completed_at INTEGER,                           -- UNIX timestamp when operation completed
    duration INTEGER,                               -- Duration in seconds

    -- Progress tracking for multi-step operations
    current_step INTEGER DEFAULT 0,                 -- Current step number
    total_steps INTEGER DEFAULT 1,                  -- Total number of steps
    step_description TEXT,                          -- Description of current step

    -- Error handling and retry logic
    error_message TEXT,                             -- Error message if operation failed
    error_code TEXT,                                -- Error code for categorization
    retry_count INTEGER DEFAULT 0,                  -- Number of retry attempts made
    max_retries INTEGER DEFAULT 3,                  -- Maximum retries allowed

    -- Resume capability
    resume_data_json TEXT,                          -- JSON state needed to resume operation
    checkpoint_data_json TEXT,                      -- JSON data from last successful checkpoint

    -- Parent/child relationships for composite operations
    parent_operation_id TEXT,                       -- Parent operation ID if this is a sub-operation

    -- Audit trail information
    triggered_by TEXT,                              -- 'user', 'auto', 'dependency'
    config_snapshot_json TEXT,                      -- Configuration snapshot at time of execution

    -- Foreign key constraints
    FOREIGN KEY (resource_id) REFERENCES resources(resource_id) ON DELETE SET NULL,
    FOREIGN KEY (parent_operation_id) REFERENCES operations(operation_id) ON DELETE CASCADE
);

-- Indexes for operation queries
CREATE INDEX idx_operations_status ON operations(status);
CREATE INDEX idx_operations_capability ON operations(capability);
CREATE INDEX idx_operations_resource ON operations(resource_id);
CREATE INDEX idx_operations_started ON operations(started_at DESC);
CREATE INDEX idx_operations_completed ON operations(completed_at DESC);
CREATE INDEX idx_operations_parent ON operations(parent_operation_id);
CREATE INDEX idx_operations_type ON operations(operation_type);
CREATE INDEX idx_operations_failed ON operations(status) WHERE status = 'failed';

-- ==============================================================================
-- OPERATION_LOGS TABLE - Detailed step-by-step operation logging
-- ==============================================================================
-- Provides granular audit trail for each operation
CREATE TABLE operation_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,

    -- Link to operation
    operation_id TEXT NOT NULL,                     -- Foreign key to operations table
    logged_at INTEGER NOT NULL,                     -- UNIX timestamp when log entry was created

    -- Log entry details
    level TEXT NOT NULL,                            -- 'INFO', 'WARN', 'ERROR', 'SUCCESS', 'PROGRESS'
    message TEXT NOT NULL,                          -- Log message text
    details_json TEXT,                              -- Additional structured data as JSON

    -- Context information
    step_number INTEGER,                            -- Step number within operation

    -- Foreign key constraint with CASCADE delete
    FOREIGN KEY (operation_id) REFERENCES operations(operation_id) ON DELETE CASCADE
);

-- Indexes for efficient log queries
CREATE INDEX idx_operation_logs_operation ON operation_logs(operation_id, logged_at);
CREATE INDEX idx_operation_logs_level ON operation_logs(level);
CREATE INDEX idx_operation_logs_time ON operation_logs(logged_at DESC);

-- ==============================================================================
-- CACHE_METADATA TABLE - Smart caching layer
-- ==============================================================================
-- Manages query result caching with TTL and invalidation tracking
CREATE TABLE cache_metadata (
    cache_key TEXT PRIMARY KEY,                     -- Cache key identifier

    -- Cache timing
    cached_at INTEGER NOT NULL,                     -- UNIX timestamp when cached
    expires_at INTEGER NOT NULL,                    -- UNIX timestamp when cache expires (TTL)
    hit_count INTEGER DEFAULT 0,                    -- Number of cache hits

    -- Result storage
    result_type TEXT NOT NULL,                      -- 'resource', 'list', 'query', 'dependency'
    result_json TEXT NOT NULL,                      -- Cached result as JSON

    -- Invalidation tracking
    invalidated_at INTEGER,                         -- NULL if valid, timestamp if invalidated
    invalidation_reason TEXT                        -- Reason for invalidation
);

-- Indexes for cache management
CREATE INDEX idx_cache_expires ON cache_metadata(expires_at);
CREATE INDEX idx_cache_valid ON cache_metadata(invalidated_at) WHERE invalidated_at IS NULL;
CREATE INDEX idx_cache_type ON cache_metadata(result_type);

-- ==============================================================================
-- RESOURCE_TAGS TABLE - Tag tracking across resources
-- ==============================================================================
-- Tracks tags applied to resources for filtering and management
CREATE TABLE resource_tags (
    id INTEGER PRIMARY KEY AUTOINCREMENT,

    -- Tag identification
    resource_id TEXT NOT NULL,                      -- Resource being tagged
    tag_key TEXT NOT NULL,                          -- Tag key/name
    tag_value TEXT NOT NULL,                        -- Tag value

    -- Tracking
    set_at INTEGER NOT NULL,                        -- UNIX timestamp when tag was set
    set_by TEXT,                                    -- Source: 'user', 'tool', 'azure'

    -- Foreign key constraint with CASCADE delete
    FOREIGN KEY (resource_id) REFERENCES resources(resource_id) ON DELETE CASCADE,

    -- Unique constraint per resource and tag key
    UNIQUE(resource_id, tag_key)
);

-- Indexes for tag queries
CREATE INDEX idx_tags_resource ON resource_tags(resource_id);
CREATE INDEX idx_tags_key ON resource_tags(tag_key);
CREATE INDEX idx_tags_value ON resource_tags(tag_value);
CREATE INDEX idx_tags_set_by ON resource_tags(set_by);

-- ==============================================================================
-- EXECUTION_METRICS TABLE - Performance tracking and analytics
-- ==============================================================================
-- Stores execution metrics for performance analysis and optimization
CREATE TABLE execution_metrics (
    id INTEGER PRIMARY KEY AUTOINCREMENT,

    -- Link to operation
    operation_id TEXT NOT NULL,                     -- Foreign key to operations table

    -- Metric data
    metric_name TEXT NOT NULL,                      -- Metric identifier (e.g., 'api_calls', 'duration', 'memory')
    metric_value REAL NOT NULL,                     -- Numeric metric value
    metric_unit TEXT,                               -- Unit: 'seconds', 'count', 'bytes', 'ms'

    -- Timestamp
    recorded_at INTEGER NOT NULL,                   -- UNIX timestamp when metric was recorded

    -- Foreign key constraint with CASCADE delete
    FOREIGN KEY (operation_id) REFERENCES operations(operation_id) ON DELETE CASCADE
);

-- Indexes for metrics queries
CREATE INDEX idx_metrics_operation ON execution_metrics(operation_id);
CREATE INDEX idx_metrics_name ON execution_metrics(metric_name);
CREATE INDEX idx_metrics_recorded ON execution_metrics(recorded_at DESC);

-- ==============================================================================
-- VIEWS - Convenient query interfaces
-- ==============================================================================

-- Active (non-deleted) resources only
CREATE VIEW active_resources AS
SELECT
    resource_id,
    resource_type,
    name,
    resource_group,
    subscription_id,
    location,
    provisioning_state,
    managed_by_toolkit,
    adopted_at,
    created_at,
    discovered_at,
    last_validated_at,
    last_modified_at,
    properties_json,
    tags_json,
    cache_key,
    cache_expires_at
FROM resources
WHERE deleted_at IS NULL;

-- Managed resources (created or adopted by toolkit)
CREATE VIEW managed_resources AS
SELECT
    resource_id,
    resource_type,
    name,
    resource_group,
    subscription_id,
    location,
    provisioning_state,
    adopted_at,
    created_at,
    discovered_at,
    last_validated_at,
    properties_json,
    tags_json
FROM resources
WHERE managed_by_toolkit = 1
AND deleted_at IS NULL
ORDER BY created_at DESC;

-- Failed operations needing attention
CREATE VIEW failed_operations AS
SELECT
    operation_id,
    capability,
    operation_name,
    operation_type,
    resource_id,
    resource_type,
    resource_name,
    status,
    started_at,
    completed_at,
    duration,
    error_message,
    error_code,
    retry_count,
    max_retries
FROM operations
WHERE status = 'failed'
AND retry_count < max_retries
ORDER BY started_at DESC;

-- Currently running operations
CREATE VIEW running_operations AS
SELECT
    operation_id,
    capability,
    operation_name,
    operation_type,
    resource_id,
    resource_name,
    status,
    started_at,
    current_step,
    total_steps,
    step_description
FROM operations
WHERE status = 'running'
ORDER BY started_at DESC;

-- Blocked operations (waiting for dependencies)
CREATE VIEW blocked_operations AS
SELECT
    operation_id,
    capability,
    operation_name,
    resource_id,
    resource_name,
    status,
    started_at
FROM operations
WHERE status = 'blocked'
ORDER BY started_at DESC;

-- Resource dependency tree (recursive CTE for full transitive closure)
CREATE VIEW resource_dependencies AS
WITH RECURSIVE dep_tree AS (
    -- Base case: direct dependencies
    SELECT
        d.resource_id,
        d.depends_on_resource_id,
        d.dependency_type,
        d.relationship,
        r1.name as resource_name,
        r2.name as depends_on_name,
        1 as depth
    FROM dependencies d
    JOIN resources r1 ON d.resource_id = r1.resource_id
    JOIN resources r2 ON d.depends_on_resource_id = r2.resource_id
    WHERE r1.deleted_at IS NULL AND r2.deleted_at IS NULL

    UNION ALL

    -- Recursive case: transitive dependencies (up to 10 levels deep)
    SELECT
        dt.resource_id,
        d.depends_on_resource_id,
        d.dependency_type,
        d.relationship,
        dt.resource_name,
        r.name as depends_on_name,
        dt.depth + 1
    FROM dependencies d
    JOIN dep_tree dt ON d.resource_id = dt.depends_on_resource_id
    JOIN resources r ON d.depends_on_resource_id = r.resource_id
    WHERE dt.depth < 10
    AND r.deleted_at IS NULL
)
SELECT
    resource_id,
    depends_on_resource_id,
    resource_name,
    depends_on_name,
    dependency_type,
    relationship,
    depth
FROM dep_tree;

-- Operation statistics and analytics
CREATE VIEW operation_stats AS
SELECT
    capability,
    operation_type,
    status,
    COUNT(*) as count,
    AVG(CAST(duration AS FLOAT)) as avg_duration_sec,
    MIN(duration) as min_duration_sec,
    MAX(duration) as max_duration_sec,
    SUM(CASE WHEN status = 'failed' THEN 1 ELSE 0 END) as failed_count,
    ROUND(100.0 * SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) / COUNT(*), 2) as success_rate_pct
FROM operations
WHERE completed_at IS NOT NULL
GROUP BY capability, operation_type, status
ORDER BY capability, operation_type, status;

-- Resource statistics by type
CREATE VIEW resource_stats AS
SELECT
    resource_type,
    COUNT(*) as total_count,
    SUM(CASE WHEN managed_by_toolkit = 1 THEN 1 ELSE 0 END) as managed_count,
    SUM(CASE WHEN managed_by_toolkit = 0 THEN 1 ELSE 0 END) as external_count,
    SUM(CASE WHEN provisioning_state = 'Succeeded' THEN 1 ELSE 0 END) as succeeded_count,
    SUM(CASE WHEN provisioning_state = 'Failed' THEN 1 ELSE 0 END) as failed_count
FROM active_resources
GROUP BY resource_type
ORDER BY total_count DESC;

-- Recent operations with full context
CREATE VIEW recent_operations AS
SELECT
    o.operation_id,
    o.capability,
    o.operation_name,
    o.operation_type,
    o.status,
    o.started_at,
    o.completed_at,
    o.duration,
    o.resource_id,
    o.resource_name,
    r.resource_type,
    r.name as full_resource_name,
    r.provisioning_state
FROM operations o
LEFT JOIN resources r ON o.resource_id = r.resource_id
ORDER BY o.started_at DESC
LIMIT 100;

-- Cache health metrics
CREATE VIEW cache_health AS
SELECT
    result_type,
    COUNT(*) as total_entries,
    SUM(hit_count) as total_hits,
    AVG(hit_count) as avg_hits,
    SUM(CASE WHEN invalidated_at IS NULL AND expires_at > strftime('%s', 'now') THEN 1 ELSE 0 END) as valid_entries,
    SUM(CASE WHEN invalidated_at IS NOT NULL THEN 1 ELSE 0 END) as invalidated_entries
FROM cache_metadata
GROUP BY result_type;

-- Resource dependency count
CREATE VIEW resource_dependency_counts AS
SELECT
    r.resource_id,
    r.name,
    r.resource_type,
    COUNT(DISTINCT CASE WHEN d.resource_id = r.resource_id THEN d.depends_on_resource_id END) as dependency_count,
    COUNT(DISTINCT CASE WHEN d.depends_on_resource_id = r.resource_id THEN d.resource_id END) as dependent_count
FROM resources r
LEFT JOIN dependencies d ON r.resource_id = d.resource_id OR r.resource_id = d.depends_on_resource_id
WHERE r.deleted_at IS NULL
GROUP BY r.resource_id
ORDER BY (dependency_count + dependent_count) DESC;

-- ==============================================================================
-- TRIGGERS - Automatic maintenance and validation
-- ==============================================================================

-- Trigger: Update last_modified_at when properties change
CREATE TRIGGER resources_update_modified_time
AFTER UPDATE OF properties_json, tags_json, provisioning_state ON resources
BEGIN
    UPDATE resources
    SET last_modified_at = CAST(strftime('%s', 'now') AS INTEGER)
    WHERE resource_id = NEW.resource_id;
END;

-- Trigger: Validate operation status transitions
CREATE TRIGGER validate_operation_status
BEFORE UPDATE OF status ON operations
WHEN NEW.status NOT IN ('pending', 'running', 'completed', 'failed', 'blocked')
BEGIN
    SELECT RAISE(ABORT, 'Invalid operation status');
END;

-- Trigger: Auto-complete operation when all steps done
CREATE TRIGGER auto_complete_operation
AFTER UPDATE OF current_step ON operations
WHEN NEW.current_step >= NEW.total_steps AND NEW.status = 'running'
BEGIN
    UPDATE operations
    SET status = 'completed',
        completed_at = CAST(strftime('%s', 'now') AS INTEGER),
        duration = CAST(strftime('%s', 'now') AS INTEGER) - started_at
    WHERE id = NEW.id;
END;

-- Trigger: Invalidate related cache when resource changes
CREATE TRIGGER invalidate_cache_on_resource_change
AFTER UPDATE OF provisioning_state, properties_json ON resources
BEGIN
    UPDATE cache_metadata
    SET invalidated_at = CAST(strftime('%s', 'now') AS INTEGER),
        invalidation_reason = 'resource_modified'
    WHERE cache_key LIKE '%:' || NEW.resource_type || ':%'
    AND invalidated_at IS NULL;
END;

-- ==============================================================================
-- INITIALIZATION - Default configuration
-- ==============================================================================

-- Create a metadata table for schema versioning
CREATE TABLE IF NOT EXISTS schema_metadata (
    key TEXT PRIMARY KEY,
    value TEXT,
    updated_at INTEGER NOT NULL
);

-- Insert schema version and initialization timestamp
INSERT OR REPLACE INTO schema_metadata (key, value, updated_at)
VALUES ('schema_version', '1.0.0', CAST(strftime('%s', 'now') AS INTEGER));

INSERT OR REPLACE INTO schema_metadata (key, value, updated_at)
VALUES ('initialized_at', CAST(strftime('%s', 'now') AS INTEGER), CAST(strftime('%s', 'now') AS INTEGER));

-- ==============================================================================
-- END OF SCHEMA
-- ==============================================================================
-- This schema is production-ready and supports:
--   - Full resource lifecycle management
--   - Comprehensive operation tracking with resume capability
--   - Intelligent caching with invalidation
--   - Dependency graph navigation
--   - Complete audit trail
--   - Performance analytics
-- ==============================================================================
