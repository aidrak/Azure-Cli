#!/bin/bash
# ==============================================================================
# Metrics Module - Observability and Performance Analytics
# ==============================================================================
#
# Purpose: Comprehensive metrics collection, analysis, and reporting for
#          Azure VDI Deployment Engine operations
#
# Usage:
#   source core/metrics.sh
#   record_metric "operation-id" "duration" "value"
#   get_operation_duration "operation-id"
#   get_success_rate [capability]
#   get_slowest_operations [limit]
#   export_metrics_report [output_file]
#
# Features:
#   - Operation duration tracking
#   - Success/failure rate calculation
#   - Performance analytics (slowest operations, failure trends)
#   - Metrics export to JSON format
#   - SQLite-based metrics persistence
#   - Real-time metrics queries
#   - Aggregation by capability, operation type, time ranges
#
# ==============================================================================

set -euo pipefail

# ==============================================================================
# CONFIGURATION
# ==============================================================================

# Project paths
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
STATE_DB="${STATE_DB:-${PROJECT_ROOT}/state.db}"
METRICS_EXPORT_DIR="${METRICS_EXPORT_DIR:-${PROJECT_ROOT}/artifacts/metrics}"

# Ensure metrics export directory exists
mkdir -p "$METRICS_EXPORT_DIR"

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

# Source state-manager for database functions
if [[ -f "${PROJECT_ROOT}/core/state-manager.sh" ]]; then
    source "${PROJECT_ROOT}/core/state-manager.sh"
else
    log_error "state-manager.sh not found"
    return 1
fi

# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

# Get current Unix timestamp
get_timestamp() {
    date +%s
}

# Get current timestamp in ISO 8601 format
get_iso_timestamp() {
    date -u +%Y-%m-%dT%H:%M:%SZ
}

# ==============================================================================
# DATABASE SCHEMA INITIALIZATION
# ==============================================================================

# Initialize metrics database tables
init_metrics_tables() {
    local sql="
CREATE TABLE IF NOT EXISTS metrics (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    operation_id TEXT NOT NULL,
    metric_name TEXT NOT NULL,
    metric_value REAL NOT NULL,
    unit TEXT,
    recorded_at INTEGER NOT NULL,
    FOREIGN KEY (operation_id) REFERENCES operations(operation_id) ON DELETE CASCADE,
    UNIQUE(operation_id, metric_name, recorded_at)
);

CREATE INDEX IF NOT EXISTS idx_metrics_operation ON metrics(operation_id);
CREATE INDEX IF NOT EXISTS idx_metrics_name ON metrics(metric_name);
CREATE INDEX IF NOT EXISTS idx_metrics_recorded ON metrics(recorded_at);

-- Aggregated metrics cache (for performance)
CREATE TABLE IF NOT EXISTS metrics_aggregated (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    period TEXT NOT NULL,
    capability TEXT,
    operation_type TEXT,
    metric_name TEXT NOT NULL,
    metric_value REAL NOT NULL,
    sample_count INTEGER,
    calculated_at INTEGER NOT NULL,
    UNIQUE(period, capability, operation_type, metric_name)
);

CREATE INDEX IF NOT EXISTS idx_metrics_agg_period ON metrics_aggregated(period);
CREATE INDEX IF NOT EXISTS idx_metrics_agg_capability ON metrics_aggregated(capability);

-- Operation performance tracking
CREATE TABLE IF NOT EXISTS operation_performance (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    operation_id TEXT NOT NULL UNIQUE,
    capability TEXT NOT NULL,
    operation_type TEXT,
    duration_seconds INTEGER,
    started_at INTEGER,
    completed_at INTEGER,
    exit_code INTEGER,
    retry_count INTEGER DEFAULT 0,
    FOREIGN KEY (operation_id) REFERENCES operations(operation_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_operation_perf_capability ON operation_performance(capability);
CREATE INDEX IF NOT EXISTS idx_operation_perf_duration ON operation_performance(duration_seconds);
CREATE INDEX IF NOT EXISTS idx_operation_perf_exit_code ON operation_performance(exit_code);
"

    if ! execute_sql "$sql" "Failed to initialize metrics tables"; then
        log_error "Could not initialize metrics tables" "metrics"
        return 1
    fi

    log_success "Metrics tables initialized" "metrics"
    return 0
}

# ==============================================================================
# METRIC RECORDING FUNCTIONS
# ==============================================================================

# Record a single metric for an operation
# Args: operation_id, metric_name, metric_value, [unit]
# Example: record_metric "vm-create-01" "duration" "120" "seconds"
record_metric() {
    local operation_id="$1"
    local metric_name="$2"
    local metric_value="$3"
    local unit="${4:-}"

    if [[ -z "$operation_id" ]] || [[ -z "$metric_name" ]] || [[ -z "$metric_value" ]]; then
        log_error "operation_id, metric_name, and metric_value are required" "metrics"
        return 1
    fi

    # Validate that metric_value is numeric
    if ! [[ "$metric_value" =~ ^[0-9]+\.?[0-9]*$ ]]; then
        log_error "metric_value must be numeric: $metric_value" "metrics"
        return 1
    fi

    # Escape for SQL
    operation_id=$(sql_escape "$operation_id")
    metric_name=$(sql_escape "$metric_name")
    unit=$(sql_escape "$unit")

    local now=$(get_timestamp)

    local unit_value="NULL"
    if [[ -n "$unit" ]]; then
        unit_value="'$unit'"
    fi

    local sql="
INSERT INTO metrics (operation_id, metric_name, metric_value, unit, recorded_at)
VALUES ('$operation_id', '$metric_name', $metric_value, $unit_value, $now)
ON CONFLICT(operation_id, metric_name, recorded_at) DO UPDATE SET
    metric_value = excluded.metric_value;
"

    if ! execute_sql "$sql" "Failed to record metric"; then
        return 1
    fi

    log_info "Recorded metric: $operation_id.$metric_name = $metric_value" "metrics"
    return 0
}

# Record operation completion with performance data
# Args: operation_id, capability, operation_type, duration_seconds, exit_code, [retry_count]
record_operation_performance() {
    local operation_id="$1"
    local capability="$2"
    local operation_type="$3"
    local duration_seconds="$4"
    local exit_code="$5"
    local retry_count="${6:-0}"

    if [[ -z "$operation_id" ]] || [[ -z "$capability" ]] || [[ -z "$duration_seconds" ]] || [[ -z "$exit_code" ]]; then
        log_error "operation_id, capability, duration_seconds, and exit_code are required" "metrics"
        return 1
    fi

    # Escape for SQL
    operation_id=$(sql_escape "$operation_id")
    capability=$(sql_escape "$capability")
    operation_type=$(sql_escape "$operation_type")

    local now=$(get_timestamp)

    local sql="
INSERT INTO operation_performance (
    operation_id, capability, operation_type, duration_seconds,
    started_at, completed_at, exit_code, retry_count
) VALUES (
    '$operation_id', '$capability', '$operation_type', $duration_seconds,
    $((now - duration_seconds)), $now, $exit_code, $retry_count
)
ON CONFLICT(operation_id) DO UPDATE SET
    duration_seconds = excluded.duration_seconds,
    completed_at = excluded.completed_at,
    exit_code = excluded.exit_code,
    retry_count = excluded.retry_count;
"

    if ! execute_sql "$sql" "Failed to record operation performance"; then
        return 1
    fi

    log_info "Recorded operation performance: $operation_id (${duration_seconds}s, exit=$exit_code)" "metrics"
    return 0
}

# ==============================================================================
# METRIC RETRIEVAL FUNCTIONS
# ==============================================================================

# Get operation duration in seconds
# Args: operation_id
# Returns: duration in seconds (or empty if not found)
get_operation_duration() {
    local operation_id="$1"

    if [[ -z "$operation_id" ]]; then
        log_error "operation_id is required" "metrics"
        return 1
    fi

    operation_id=$(sql_escape "$operation_id")

    local sql="
SELECT duration_seconds FROM operation_performance
WHERE operation_id = '$operation_id';
"

    local result
    result=$(execute_sql "$sql" "Failed to get operation duration" 2>/dev/null)

    if [[ -n "$result" ]] && [[ "$result" != "null" ]]; then
        echo "$result"
        return 0
    else
        return 1
    fi
}

# Get a specific metric value
# Args: operation_id, metric_name
# Returns: metric_value
get_metric() {
    local operation_id="$1"
    local metric_name="$2"

    if [[ -z "$operation_id" ]] || [[ -z "$metric_name" ]]; then
        log_error "operation_id and metric_name are required" "metrics"
        return 1
    fi

    operation_id=$(sql_escape "$operation_id")
    metric_name=$(sql_escape "$metric_name")

    local sql="
SELECT metric_value FROM metrics
WHERE operation_id = '$operation_id' AND metric_name = '$metric_name'
ORDER BY recorded_at DESC
LIMIT 1;
"

    local result
    result=$(execute_sql "$sql" "Failed to get metric" 2>/dev/null)

    if [[ -n "$result" ]] && [[ "$result" != "null" ]]; then
        echo "$result"
        return 0
    else
        return 1
    fi
}

# Get all metrics for an operation
# Args: operation_id
# Returns: JSON array of metrics
get_operation_metrics() {
    local operation_id="$1"

    if [[ -z "$operation_id" ]]; then
        log_error "operation_id is required" "metrics"
        return 1
    fi

    operation_id=$(sql_escape "$operation_id")

    local sql="
SELECT
    metric_name,
    metric_value,
    unit,
    datetime(recorded_at, 'unixepoch') as recorded_at
FROM metrics
WHERE operation_id = '$operation_id'
ORDER BY recorded_at;
"

    execute_sql_json "$sql" "Failed to get operation metrics"
}

# ==============================================================================
# ANALYTICS FUNCTIONS
# ==============================================================================

# Calculate success rate for operations
# Args: [capability] - Optional capability filter
# Returns: success_rate as percentage
get_success_rate() {
    local capability="${1:-}"

    local where_clause="WHERE exit_code = 0"
    if [[ -n "$capability" ]]; then
        capability=$(sql_escape "$capability")
        where_clause="WHERE capability = '$capability' AND exit_code = 0"
    fi

    local sql="
SELECT
    ROUND(100.0 * COUNT(CASE WHEN exit_code = 0 THEN 1 END) / COUNT(*), 2) as success_rate,
    COUNT(*) as total_operations,
    COUNT(CASE WHEN exit_code = 0 THEN 1 END) as successful,
    COUNT(CASE WHEN exit_code != 0 THEN 1 END) as failed
FROM operation_performance
WHERE exit_code IS NOT NULL;
"

    if [[ -n "$capability" ]]; then
        sql="
SELECT
    ROUND(100.0 * COUNT(CASE WHEN exit_code = 0 THEN 1 END) / COUNT(*), 2) as success_rate,
    COUNT(*) as total_operations,
    COUNT(CASE WHEN exit_code = 0 THEN 1 END) as successful,
    COUNT(CASE WHEN exit_code != 0 THEN 1 END) as failed,
    '$capability' as capability
FROM operation_performance
WHERE capability = '$capability' AND exit_code IS NOT NULL;
"
    fi

    execute_sql_json "$sql" "Failed to calculate success rate"
}

# Get slowest operations
# Args: [limit] - Number of operations to return (default: 10)
# Returns: JSON array of slowest operations
get_slowest_operations() {
    local limit="${1:-10}"

    # Validate limit is numeric
    if ! [[ "$limit" =~ ^[0-9]+$ ]]; then
        limit=10
    fi

    local sql="
SELECT
    operation_id,
    capability,
    operation_type,
    duration_seconds,
    exit_code,
    datetime(completed_at, 'unixepoch') as completed_at
FROM operation_performance
WHERE duration_seconds IS NOT NULL
ORDER BY duration_seconds DESC
LIMIT $limit;
"

    execute_sql_json "$sql" "Failed to get slowest operations"
}

# Get fastest operations
# Args: [limit] - Number of operations to return (default: 10)
# Returns: JSON array of fastest operations
get_fastest_operations() {
    local limit="${1:-10}"

    # Validate limit is numeric
    if ! [[ "$limit" =~ ^[0-9]+$ ]]; then
        limit=10
    fi

    local sql="
SELECT
    operation_id,
    capability,
    operation_type,
    duration_seconds,
    exit_code,
    datetime(completed_at, 'unixepoch') as completed_at
FROM operation_performance
WHERE duration_seconds IS NOT NULL
ORDER BY duration_seconds ASC
LIMIT $limit;
"

    execute_sql_json "$sql" "Failed to get fastest operations"
}

# Get average duration by capability
# Args: None
# Returns: JSON array with average durations by capability
get_duration_by_capability() {
    local sql="
SELECT
    capability,
    ROUND(AVG(duration_seconds), 2) as avg_duration,
    ROUND(MIN(duration_seconds), 0) as min_duration,
    ROUND(MAX(duration_seconds), 0) as max_duration,
    COUNT(*) as operation_count,
    ROUND(AVG(CASE WHEN exit_code = 0 THEN 1 ELSE 0 END) * 100, 2) as success_rate
FROM operation_performance
WHERE duration_seconds IS NOT NULL
GROUP BY capability
ORDER BY avg_duration DESC;
"

    execute_sql_json "$sql" "Failed to get duration by capability"
}

# Get average duration by operation type
# Args: None
# Returns: JSON array with average durations by operation type
get_duration_by_operation_type() {
    local sql="
SELECT
    operation_type,
    ROUND(AVG(duration_seconds), 2) as avg_duration,
    ROUND(MIN(duration_seconds), 0) as min_duration,
    ROUND(MAX(duration_seconds), 0) as max_duration,
    COUNT(*) as operation_count,
    ROUND(AVG(CASE WHEN exit_code = 0 THEN 1 ELSE 0 END) * 100, 2) as success_rate
FROM operation_performance
WHERE duration_seconds IS NOT NULL AND operation_type IS NOT NULL
GROUP BY operation_type
ORDER BY avg_duration DESC;
"

    execute_sql_json "$sql" "Failed to get duration by operation type"
}

# Get failure trends
# Args: [limit] - Number of days to analyze (default: 7)
# Returns: JSON array of failures grouped by day
get_failure_trends() {
    local limit="${1:-7}"

    # Validate limit is numeric
    if ! [[ "$limit" =~ ^[0-9]+$ ]]; then
        limit=7
    fi

    local sql="
SELECT
    DATE(datetime(completed_at, 'unixepoch')) as date,
    COUNT(*) as total_operations,
    COUNT(CASE WHEN exit_code != 0 THEN 1 END) as failed_operations,
    ROUND(100.0 * COUNT(CASE WHEN exit_code != 0 THEN 1 END) / COUNT(*), 2) as failure_rate
FROM operation_performance
WHERE completed_at IS NOT NULL
  AND completed_at > strftime('%s', 'now', '-$limit days')
GROUP BY DATE(datetime(completed_at, 'unixepoch'))
ORDER BY date DESC;
"

    execute_sql_json "$sql" "Failed to get failure trends"
}

# Get operation statistics (comprehensive overview)
# Args: None
# Returns: JSON object with overall statistics
get_operation_statistics() {
    local sql="
SELECT
    COUNT(*) as total_operations,
    COUNT(CASE WHEN exit_code = 0 THEN 1 END) as successful_operations,
    COUNT(CASE WHEN exit_code != 0 THEN 1 END) as failed_operations,
    ROUND(100.0 * COUNT(CASE WHEN exit_code = 0 THEN 1 END) / COUNT(*), 2) as overall_success_rate,
    ROUND(AVG(duration_seconds), 2) as avg_duration,
    MIN(duration_seconds) as min_duration,
    MAX(duration_seconds) as max_duration,
    COUNT(DISTINCT capability) as unique_capabilities,
    SUM(retry_count) as total_retries
FROM operation_performance
WHERE exit_code IS NOT NULL;
"

    execute_sql_json "$sql" "Failed to get operation statistics"
}

# ==============================================================================
# EXPORT FUNCTIONS
# ==============================================================================

# Export metrics report to JSON
# Args: [output_file] - File path to export to (default: metrics_report.json)
# Returns: 0 on success, 1 on failure
export_metrics_report() {
    local output_file="${1:-${METRICS_EXPORT_DIR}/metrics_report_$(date +%Y%m%d_%H%M%S).json}"

    log_info "Exporting metrics report to: $output_file" "metrics"

    # Create report JSON
    local report="{}"
    local timestamp=$(get_iso_timestamp)

    # Add metadata
    report=$(echo "$report" | jq --arg ts "$timestamp" '.timestamp = $ts')
    report=$(echo "$report" | jq '.export_date = now')

    # Add overall statistics
    local stats
    stats=$(get_operation_statistics)
    report=$(echo "$report" | jq --argjson stats "$stats" '.statistics = $stats')

    # Add success rates
    local success_rate
    success_rate=$(get_success_rate)
    report=$(echo "$report" | jq --argjson sr "$success_rate" '.success_rate = $sr')

    # Add slowest operations
    local slowest
    slowest=$(get_slowest_operations 20)
    report=$(echo "$report" | jq --argjson slowest "$slowest" '.slowest_operations = $slowest')

    # Add duration by capability
    local by_capability
    by_capability=$(get_duration_by_capability)
    report=$(echo "$report" | jq --argjson by_cap "$by_capability" '.duration_by_capability = $by_cap')

    # Add duration by operation type
    local by_type
    by_type=$(get_duration_by_operation_type)
    report=$(echo "$report" | jq --argjson by_type "$by_type" '.duration_by_operation_type = $by_type')

    # Add failure trends
    local trends
    trends=$(get_failure_trends 7)
    report=$(echo "$report" | jq --argjson trends "$trends" '.failure_trends_7days = $trends')

    # Write to file
    if echo "$report" | jq '.' > "$output_file" 2>/dev/null; then
        log_success "Metrics report exported to: $output_file" "metrics"
        echo "$output_file"
        return 0
    else
        log_error "Failed to export metrics report" "metrics"
        return 1
    fi
}

# Export metrics in CSV format
# Args: [output_file] - File path to export to (default: metrics_report.csv)
export_metrics_csv() {
    local output_file="${1:-${METRICS_EXPORT_DIR}/metrics_report_$(date +%Y%m%d_%H%M%S).csv}"

    log_info "Exporting metrics to CSV: $output_file" "metrics"

    local sql="
SELECT
    operation_id,
    capability,
    operation_type,
    duration_seconds,
    exit_code,
    retry_count,
    datetime(completed_at, 'unixepoch') as completed_at
FROM operation_performance
ORDER BY completed_at DESC;
"

    # Get CSV output from SQLite
    if sqlite3 "$STATE_DB" -header -csv "$sql" > "$output_file" 2>/dev/null; then
        log_success "Metrics exported to CSV: $output_file" "metrics"
        echo "$output_file"
        return 0
    else
        log_error "Failed to export metrics to CSV" "metrics"
        return 1
    fi
}

# ==============================================================================
# ANALYSIS FUNCTIONS
# ==============================================================================

# Calculate percentile operation duration
# Args: percentile (0-100)
# Returns: duration in seconds at that percentile
get_duration_percentile() {
    local percentile="$1"

    if [[ -z "$percentile" ]] || ! [[ "$percentile" =~ ^[0-9]+$ ]]; then
        log_error "percentile must be a number between 0 and 100" "metrics"
        return 1
    fi

    if [[ $percentile -lt 0 ]] || [[ $percentile -gt 100 ]]; then
        log_error "percentile must be between 0 and 100" "metrics"
        return 1
    fi

    local sql="
SELECT
    PERCENTILE_CONT($percentile / 100.0) WITHIN GROUP (ORDER BY duration_seconds) as percentile_duration
FROM operation_performance
WHERE duration_seconds IS NOT NULL;
"

    # SQLite doesn't have PERCENTILE_CONT, use approximate method
    local count
    count=$(sqlite3 "$STATE_DB" "SELECT COUNT(*) FROM operation_performance WHERE duration_seconds IS NOT NULL;")

    local offset=$((count * percentile / 100))

    local sql2="
SELECT duration_seconds FROM operation_performance
WHERE duration_seconds IS NOT NULL
ORDER BY duration_seconds ASC
LIMIT 1 OFFSET $offset;
"

    execute_sql "$sql2" "Failed to calculate percentile"
}

# Get outlier operations (significantly slower/faster than average)
# Args: [std_dev_threshold] - Number of standard deviations (default: 2)
# Returns: JSON array of outlier operations
get_outlier_operations() {
    local std_dev_threshold="${1:-2}"

    if ! [[ "$std_dev_threshold" =~ ^[0-9]+\.?[0-9]*$ ]]; then
        std_dev_threshold=2
    fi

    local sql="
WITH stats AS (
    SELECT
        AVG(duration_seconds) as avg_duration,
        SQRT(AVG((duration_seconds - (SELECT AVG(duration_seconds) FROM operation_performance)) *
                 (duration_seconds - (SELECT AVG(duration_seconds) FROM operation_performance)))) as std_dev
    FROM operation_performance
    WHERE duration_seconds IS NOT NULL
)
SELECT
    operation_id,
    capability,
    operation_type,
    duration_seconds,
    ROUND((duration_seconds - stats.avg_duration) / stats.std_dev, 2) as std_dev_count,
    exit_code
FROM operation_performance, stats
WHERE duration_seconds IS NOT NULL
  AND ABS(duration_seconds - stats.avg_duration) > $std_dev_threshold * stats.std_dev
ORDER BY duration_seconds DESC;
"

    execute_sql_json "$sql" "Failed to get outlier operations"
}

# Get most frequently failing operations
# Args: [limit] - Number of operations to return (default: 10)
# Returns: JSON array of frequently failing operations
get_failing_operations() {
    local limit="${1:-10}"

    # Validate limit is numeric
    if ! [[ "$limit" =~ ^[0-9]+$ ]]; then
        limit=10
    fi

    local sql="
SELECT
    operation_type,
    COUNT(*) as failure_count,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM operation_performance WHERE exit_code != 0), 2) as percentage,
    ROUND(AVG(duration_seconds), 2) as avg_duration
FROM operation_performance
WHERE exit_code != 0
GROUP BY operation_type
ORDER BY failure_count DESC
LIMIT $limit;
"

    execute_sql_json "$sql" "Failed to get failing operations"
}

# ==============================================================================
# REPORTING FUNCTIONS
# ==============================================================================

# Print human-readable metrics summary to console
print_metrics_summary() {
    local stats
    stats=$(get_operation_statistics)

    echo ""
    echo "========================================================================"
    echo "  Operation Metrics Summary"
    echo "========================================================================"
    echo ""
    echo "Total Operations:        $(echo "$stats" | jq -r '.[0].total_operations')"
    echo "Successful Operations:   $(echo "$stats" | jq -r '.[0].successful_operations')"
    echo "Failed Operations:       $(echo "$stats" | jq -r '.[0].failed_operations')"
    echo "Overall Success Rate:    $(echo "$stats" | jq -r '.[0].overall_success_rate')%"
    echo ""
    echo "Duration Stats:"
    echo "  Average:               $(echo "$stats" | jq -r '.[0].avg_duration')s"
    echo "  Minimum:               $(echo "$stats" | jq -r '.[0].min_duration')s"
    echo "  Maximum:               $(echo "$stats" | jq -r '.[0].max_duration')s"
    echo ""
    echo "Unique Capabilities:     $(echo "$stats" | jq -r '.[0].unique_capabilities')"
    echo "Total Retries:           $(echo "$stats" | jq -r '.[0].total_retries')"
    echo ""
    echo "========================================================================"
    echo ""
}

# Print performance by capability
print_capability_performance() {
    local perf
    perf=$(get_duration_by_capability)

    echo ""
    echo "========================================================================"
    echo "  Performance by Capability"
    echo "========================================================================"
    echo ""
    echo "Capability                    Avg(s)  Min(s)  Max(s)  Ops  Success%"
    echo "------------------------------------------------------------------------"

    echo "$perf" | jq -r '.[] |
        "\(.capability | ljust(30)) " +
        "\(.avg_duration | tostring | ljust(7)) " +
        "\(.min_duration | tostring | ljust(7)) " +
        "\(.max_duration | tostring | ljust(7)) " +
        "\(.operation_count | tostring | ljust(4)) " +
        "\(.success_rate | tostring)%"'

    echo ""
}

# ==============================================================================
# EXPORT PUBLIC FUNCTIONS
# ==============================================================================

export -f get_timestamp get_iso_timestamp
export -f init_metrics_tables
export -f record_metric record_operation_performance
export -f get_operation_duration get_metric get_operation_metrics
export -f get_success_rate get_slowest_operations get_fastest_operations
export -f get_duration_by_capability get_duration_by_operation_type
export -f get_failure_trends get_operation_statistics
export -f get_duration_percentile get_outlier_operations get_failing_operations
export -f export_metrics_report export_metrics_csv
export -f print_metrics_summary print_capability_performance

# ==============================================================================
# INITIALIZATION
# ==============================================================================

log_info "Metrics module loaded" "metrics"
