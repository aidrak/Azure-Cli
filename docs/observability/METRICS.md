# Metrics Module - Observability & Performance Analytics

The Metrics Module provides comprehensive metrics collection, analysis, and reporting for Azure VDI Deployment Engine operations.

## Quick Start

```bash
# Source the metrics module
source core/metrics.sh

# Initialize metrics tables (one time setup)
init_metrics_tables

# Record operation performance
record_operation_performance "vm-create-001" "compute" "vm-create" 120 0 0

# Get operation duration
get_operation_duration "vm-create-001"  # Output: 120

# Get success rate
get_success_rate                        # Overall success rate
get_success_rate "networking"           # By capability

# Get slowest operations
get_slowest_operations 10

# Export metrics report
export_metrics_report

# Print summary to console
print_metrics_summary
```

## Core Functions

### Recording Metrics

#### `record_metric(operation_id, metric_name, metric_value, [unit])`

Record a single metric for an operation.

**Arguments:**
- `operation_id`: Unique operation identifier
- `metric_name`: Name of the metric (e.g., "duration", "memory_usage")
- `metric_value`: Numeric value of the metric
- `unit`: Optional unit of measurement (e.g., "seconds", "MB")

**Example:**
```bash
record_metric "vm-create-001" "duration" "120" "seconds"
record_metric "vm-create-001" "memory_used" "512" "MB"
record_metric "vm-create-001" "cpu_percent" "85.5" "%"
```

#### `record_operation_performance(operation_id, capability, operation_type, duration_seconds, exit_code, [retry_count])`

Record comprehensive operation completion metrics.

**Arguments:**
- `operation_id`: Unique operation identifier
- `capability`: Capability name (e.g., "compute", "networking", "storage")
- `operation_type`: Operation type (e.g., "vm-create", "vnet-deploy")
- `duration_seconds`: Operation duration in seconds (numeric)
- `exit_code`: Operation exit code (0 = success, non-zero = failure)
- `retry_count`: Optional number of retries (default: 0)

**Example:**
```bash
# Successful operation
record_operation_performance "vm-create-001" "compute" "vm-create" 120 0 0

# Failed operation
record_operation_performance "vm-create-002" "compute" "vm-create" 45 1 2

# Operation with retries
record_operation_performance "nsg-deploy-001" "networking" "nsg-deploy" 60 0 1
```

### Retrieving Metrics

#### `get_operation_duration(operation_id)`

Get the duration of a completed operation.

**Returns:** Duration in seconds

**Example:**
```bash
duration=$(get_operation_duration "vm-create-001")
echo "Operation took: ${duration}s"
```

#### `get_metric(operation_id, metric_name)`

Get a specific metric value for an operation.

**Returns:** Metric value

**Example:**
```bash
memory=$(get_metric "vm-create-001" "memory_used")
echo "Memory used: ${memory}MB"
```

#### `get_operation_metrics(operation_id)`

Get all metrics recorded for an operation.

**Returns:** JSON array of metrics

**Example:**
```bash
metrics=$(get_operation_metrics "vm-create-001")
echo "$metrics" | jq '.'
```

### Analytics Functions

#### `get_success_rate([capability])`

Calculate success rate for operations.

**Arguments:**
- `capability`: Optional capability filter (e.g., "compute", "networking")

**Returns:** JSON with success rate statistics

**Example:**
```bash
# Overall success rate
overall=$(get_success_rate)
echo "$overall" | jq '.[] | "\(.success_rate)% success rate"'

# By capability
compute=$(get_success_rate "compute")
echo "$compute" | jq '.[] | "\(.capability): \(.success_rate)%"'
```

#### `get_slowest_operations([limit])`

Get the slowest operations by duration.

**Arguments:**
- `limit`: Number of operations to return (default: 10)

**Returns:** JSON array of operations sorted by duration

**Example:**
```bash
slow=$(get_slowest_operations 5)
echo "$slow" | jq '.[] | "\(.operation_id): \(.duration_seconds)s"'
```

#### `get_fastest_operations([limit])`

Get the fastest operations by duration.

**Arguments:**
- `limit`: Number of operations to return (default: 10)

**Returns:** JSON array of operations sorted by duration

#### `get_duration_by_capability()`

Get average, min, and max duration grouped by capability.

**Returns:** JSON array of capabilities with duration statistics

**Example:**
```bash
perf=$(get_duration_by_capability)
echo "$perf" | jq '.[] | "\(.capability): avg=\(.avg_duration)s, success=\(.success_rate)%"'
```

#### `get_duration_by_operation_type()`

Get average, min, and max duration grouped by operation type.

**Returns:** JSON array of operation types with duration statistics

#### `get_failure_trends([days])`

Analyze failure trends over a time period.

**Arguments:**
- `days`: Number of days to analyze (default: 7)

**Returns:** JSON array of daily failure statistics

**Example:**
```bash
trends=$(get_failure_trends 7)
echo "$trends" | jq '.[] | "\(.date): \(.failure_rate)% failures"'
```

#### `get_operation_statistics()`

Get comprehensive operation statistics.

**Returns:** JSON object with overall statistics

**Example:**
```bash
stats=$(get_operation_statistics)
echo "$stats" | jq '.[] | {
  total: .total_operations,
  success_rate: .overall_success_rate,
  avg_duration: .avg_duration,
  unique_capabilities: .unique_capabilities
}'
```

### Advanced Analysis

#### `get_duration_percentile(percentile)`

Calculate operation duration at a specific percentile (0-100).

**Arguments:**
- `percentile`: Percentile value (0-100)

**Returns:** Duration in seconds at that percentile

**Example:**
```bash
p95=$(get_duration_percentile 95)
echo "95th percentile operation time: ${p95}s"
```

#### `get_outlier_operations([std_dev_threshold])`

Identify operations with anomalous durations.

**Arguments:**
- `std_dev_threshold`: Number of standard deviations (default: 2)

**Returns:** JSON array of outlier operations

**Example:**
```bash
outliers=$(get_outlier_operations 2)
echo "$outliers" | jq '.[] | "\(.operation_id): \(.std_dev_count) std dev from mean"'
```

#### `get_failing_operations([limit])`

Get most frequently failing operation types.

**Arguments:**
- `limit`: Number of operation types to return (default: 10)

**Returns:** JSON array of failing operation types

**Example:**
```bash
failures=$(get_failing_operations)
echo "$failures" | jq '.[] | "\(.operation_type): \(.failure_count) failures"'
```

### Export Functions

#### `export_metrics_report([output_file])`

Export comprehensive metrics report to JSON file.

**Arguments:**
- `output_file`: Output file path (default: `artifacts/metrics/metrics_report_<timestamp>.json`)

**Returns:** Output file path

**Contents:**
- Overall statistics
- Success rates
- Top 20 slowest operations
- Performance by capability
- Performance by operation type
- Failure trends (7 days)

**Example:**
```bash
report=$(export_metrics_report)
echo "Report exported to: $report"

report=$(export_metrics_report "/path/to/custom_report.json")
```

#### `export_metrics_csv([output_file])`

Export operation metrics to CSV format.

**Arguments:**
- `output_file`: Output file path (default: `artifacts/metrics/metrics_report_<timestamp>.csv`)

**Returns:** Output file path

**Columns:**
- operation_id
- capability
- operation_type
- duration_seconds
- exit_code
- retry_count
- completed_at

**Example:**
```bash
csv=$(export_metrics_csv)
echo "CSV exported to: $csv"
```

### Console Reporting

#### `print_metrics_summary()`

Print formatted metrics summary to console.

**Output:**
```
========================================================================
  Operation Metrics Summary
========================================================================

Total Operations:        500
Successful Operations:   485
Failed Operations:       15
Overall Success Rate:    97.00%

Duration Stats:
  Average:               120.5s
  Minimum:               15s
  Maximum:               890s

Unique Capabilities:     7
Total Retries:           23

========================================================================
```

#### `print_capability_performance()`

Print performance metrics grouped by capability.

**Output:**
```
========================================================================
  Performance by Capability
========================================================================

Capability                    Avg(s)  Min(s)  Max(s)  Ops  Success%
------------------------------------------------------------------------
compute                       125.5   45      450     120  98.33%
networking                    95.2    20      320     85   99.00%
storage                       67.8    10      200     95   96.84%
```

## Database Schema

### Tables

#### `metrics`
Stores individual metric measurements.

```sql
CREATE TABLE metrics (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    operation_id TEXT NOT NULL,
    metric_name TEXT NOT NULL,
    metric_value REAL NOT NULL,
    unit TEXT,
    recorded_at INTEGER NOT NULL,
    FOREIGN KEY (operation_id) REFERENCES operations(operation_id) ON DELETE CASCADE,
    UNIQUE(operation_id, metric_name, recorded_at)
);
```

#### `operation_performance`
Stores operation completion data.

```sql
CREATE TABLE operation_performance (
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
```

#### `metrics_aggregated`
Cache for aggregated metrics (performance optimization).

```sql
CREATE TABLE metrics_aggregated (
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
```

## Integration with Engine

### In Operation Handlers

Record metrics when operations complete:

```bash
#!/bin/bash
source core/config-manager.sh
source core/metrics.sh

operation_id="my-operation-001"
capability="compute"
operation_type="vm-create"

start_time=$(date +%s)

# ... perform operation ...

exit_code=$?
end_time=$(date +%s)
duration=$((end_time - start_time))

# Record performance metrics
record_operation_performance "$operation_id" "$capability" "$operation_type" "$duration" "$exit_code" 0

# Record additional custom metrics
if [[ $exit_code -eq 0 ]]; then
    record_metric "$operation_id" "custom_metric" "value" "unit"
fi

exit $exit_code
```

### In Workflows

```bash
#!/bin/bash
source core/config-manager.sh
source core/metrics.sh

# Initialize metrics tables
init_metrics_tables

# Run operations and record metrics...

# Export report after workflow completes
export_metrics_report

# Print summary
print_metrics_summary
```

## Usage Patterns

### Performance Monitoring

```bash
# Track performance over time
for i in {1..100}; do
    record_operation_performance "vm-create-$(printf "%03d" $i)" "compute" "vm-create" "$((RANDOM % 300))" 0 0
done

# Analyze
slowest=$(get_slowest_operations 10)
percentile_95=$(get_duration_percentile 95)
success=$(get_success_rate "compute")
```

### Capacity Planning

```bash
# Get performance baseline by capability
perf=$(get_duration_by_capability)

# Calculate total time needed for batch operations
total_ops=1000
avg_duration=$(echo "$perf" | jq '.[0].avg_duration')
estimated_time=$((total_ops * avg_duration / 60))  # Convert to minutes

echo "Estimated time for $total_ops operations: ${estimated_time} minutes"
```

### Troubleshooting

```bash
# Find problematic operations
outliers=$(get_outlier_operations 2)
failures=$(get_failing_operations 5)

# Analyze failure trends
trends=$(get_failure_trends 7)
echo "$trends" | jq '.[] | select(.failure_rate > 5)'

# Get operation details
get_operation_metrics "failing-operation-001"
```

## Best Practices

1. **Initialize tables on startup**: Call `init_metrics_tables()` once during application initialization
2. **Record immediately**: Record metrics right after operation completion while context is fresh
3. **Use consistent operation_ids**: Ensure operation IDs are globally unique for accurate tracking
4. **Export regularly**: Schedule metrics exports to maintain historical records
5. **Monitor outliers**: Review outlier operations to identify systemic performance issues
6. **Track retries**: Record retry_count to understand operation stability
7. **Analyze trends**: Review failure_trends regularly to catch emerging issues
8. **Export reports**: Export JSON/CSV reports for long-term analysis and trending

## Performance Considerations

- Metrics queries use indexed columns for fast lookups
- Aggregated metrics table enables efficient reporting on large datasets
- Clean up old metrics regularly to maintain database performance
- CSV exports are more suitable for Excel/analysis tools than JSON

## Troubleshooting

**No metrics found**
- Ensure `init_metrics_tables()` was called
- Check that operations are being recorded with `record_operation_performance()`

**Slow queries**
- Check database size with `sqlite3 state.db "SELECT page_count * page_size / 1024 / 1024 as size_mb FROM pragma_page_count(), pragma_page_size();"`
- Consider exporting and archiving old metrics

**NULL values in results**
- Not all metrics may be recorded for all operations
- Use optional filtering (e.g., `WHERE exit_code IS NOT NULL`)
