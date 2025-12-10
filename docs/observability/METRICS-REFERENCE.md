# Metrics Module - Complete Reference Guide

## Overview

The Metrics Module (`core/metrics.sh`) provides production-grade observability for the Azure VDI Deployment Engine. It tracks operation performance, calculates success rates, identifies performance bottlenecks, and generates comprehensive analytics reports.

## Module Architecture

```
core/metrics.sh
├── Configuration & Initialization
├── Database Schema Management
├── Recording Functions
│   ├── record_metric()
│   ├── record_operation_performance()
│   └── init_metrics_tables()
├── Retrieval Functions
│   ├── get_operation_duration()
│   ├── get_metric()
│   ├── get_operation_metrics()
├── Analytics Functions
│   ├── get_success_rate()
│   ├── get_slowest_operations()
│   ├── get_duration_by_capability()
│   ├── get_failure_trends()
│   ├── get_outlier_operations()
│   └── get_operation_statistics()
├── Export Functions
│   ├── export_metrics_report()
│   └── export_metrics_csv()
└── Reporting Functions
    ├── print_metrics_summary()
    └── print_capability_performance()
```

## Function Reference

### Initialization

#### `init_metrics_tables()`

Initialize the SQLite metrics tables on first use.

**Syntax:**
```bash
init_metrics_tables
```

**Returns:** 0 on success, 1 on failure

**Description:**
Creates three tables:
- `metrics` - Individual metric measurements
- `operation_performance` - Operation completion data
- `metrics_aggregated` - Pre-calculated aggregates for performance

**Example:**
```bash
if init_metrics_tables; then
    log_info "Metrics initialized"
else
    log_error "Failed to initialize metrics"
    exit 1
fi
```

---

### Recording Functions

#### `record_metric(operation_id, metric_name, metric_value, [unit])`

Record a custom metric for an operation.

**Syntax:**
```bash
record_metric "operation-id" "metric-name" "value" ["unit"]
```

**Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| operation_id | string | Yes | Unique operation identifier |
| metric_name | string | Yes | Name of the metric (alphanumeric, hyphens) |
| metric_value | number | Yes | Numeric value (integer or float) |
| unit | string | No | Unit of measurement (e.g., "seconds", "MB", "%") |

**Returns:** 0 on success, 1 on failure

**Examples:**
```bash
# Record duration
record_metric "vm-create-001" "duration" "120" "seconds"

# Record memory usage
record_metric "vm-create-001" "memory-used" "512.5" "MB"

# Record CPU utilization
record_metric "vm-create-001" "cpu-utilization" "85.3" "%"

# Without unit
record_metric "vm-create-001" "retry-count" "2"
```

---

#### `record_operation_performance(operation_id, capability, operation_type, duration_seconds, exit_code, [retry_count])`

Record comprehensive operation completion metrics.

**Syntax:**
```bash
record_operation_performance "op-id" "capability" "type" duration exit_code [retry_count]
```

**Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| operation_id | string | Yes | Unique operation identifier |
| capability | string | Yes | Capability name (compute, networking, storage, identity, avd, management) |
| operation_type | string | Yes | Operation type (vm-create, vnet-deploy, etc.) |
| duration_seconds | int | Yes | Operation duration in seconds |
| exit_code | int | Yes | 0 = success, non-zero = failure |
| retry_count | int | No | Number of retries (default: 0) |

**Returns:** 0 on success, 1 on failure

**Examples:**
```bash
# Successful operation
record_operation_performance "vm-001" "compute" "vm-create" 120 0

# Failed operation with retries
record_operation_performance "storage-001" "storage" "account-create" 45 1 2

# Successful operation with retries
record_operation_performance "vnet-001" "networking" "vnet-create" 60 0 1
```

---

### Retrieval Functions

#### `get_operation_duration(operation_id)`

Get the duration of a completed operation.

**Syntax:**
```bash
duration=$(get_operation_duration "operation-id")
```

**Returns:** Duration in seconds, or empty if not found

**Example:**
```bash
if duration=$(get_operation_duration "vm-create-001"); then
    echo "Duration: ${duration}s"
else
    echo "Operation not found"
fi
```

---

#### `get_metric(operation_id, metric_name)`

Retrieve a specific metric value.

**Syntax:**
```bash
value=$(get_metric "operation-id" "metric-name")
```

**Returns:** Metric value, or empty if not found

**Example:**
```bash
memory=$(get_metric "vm-create-001" "memory-used")
if [[ -n "$memory" ]]; then
    echo "Memory used: ${memory} MB"
fi
```

---

#### `get_operation_metrics(operation_id)`

Get all metrics for a specific operation.

**Syntax:**
```bash
metrics=$(get_operation_metrics "operation-id")
```

**Returns:** JSON array of metric objects

**JSON Structure:**
```json
[
  {
    "metric_name": "duration",
    "metric_value": 120.5,
    "unit": "seconds",
    "recorded_at": "2024-12-10T14:30:45Z"
  },
  {
    "metric_name": "memory-used",
    "metric_value": 512,
    "unit": "MB",
    "recorded_at": "2024-12-10T14:32:45Z"
  }
]
```

**Example:**
```bash
metrics=$(get_operation_metrics "vm-create-001")
echo "$metrics" | jq '.[] | "\(.metric_name): \(.metric_value) \(.unit)"'
```

---

### Analytics Functions

#### `get_success_rate([capability])`

Calculate operation success rate, optionally filtered by capability.

**Syntax:**
```bash
rates=$(get_success_rate)              # Overall
rates=$(get_success_rate "compute")    # By capability
```

**Returns:** JSON array with success metrics

**JSON Structure:**
```json
[
  {
    "success_rate": 97.50,
    "total_operations": 200,
    "successful": 195,
    "failed": 5,
    "capability": "compute"
  }
]
```

**Example:**
```bash
# Check overall success
overall=$(get_success_rate)
success_pct=$(echo "$overall" | jq -r '.[0].success_rate')
echo "Success rate: ${success_pct}%"

# Check by capability
for cap in compute networking storage; do
    result=$(get_success_rate "$cap")
    pct=$(echo "$result" | jq -r '.[0].success_rate')
    echo "$cap: ${pct}%"
done
```

---

#### `get_slowest_operations([limit])`

Get slowest operations by duration.

**Syntax:**
```bash
slowest=$(get_slowest_operations)      # Top 10 (default)
slowest=$(get_slowest_operations 20)   # Top 20
```

**Parameters:**
| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| limit | int | 10 | Number of operations to return |

**Returns:** JSON array of operations

**JSON Structure:**
```json
[
  {
    "operation_id": "vm-create-001",
    "capability": "compute",
    "operation_type": "vm-create",
    "duration_seconds": 450,
    "exit_code": 0,
    "completed_at": "2024-12-10T14:30:00Z"
  }
]
```

---

#### `get_fastest_operations([limit])`

Get fastest operations by duration.

**Syntax:**
```bash
fastest=$(get_fastest_operations)      # Top 10
fastest=$(get_fastest_operations 5)    # Top 5
```

**Returns:** JSON array of operations

---

#### `get_duration_by_capability()`

Performance statistics grouped by capability.

**Syntax:**
```bash
stats=$(get_duration_by_capability)
```

**Returns:** JSON array of capability statistics

**JSON Structure:**
```json
[
  {
    "capability": "compute",
    "avg_duration": 125.5,
    "min_duration": 45,
    "max_duration": 450,
    "operation_count": 120,
    "success_rate": 98.33
  }
]
```

---

#### `get_duration_by_operation_type()`

Performance statistics grouped by operation type.

**Syntax:**
```bash
stats=$(get_duration_by_operation_type)
```

**Returns:** JSON array of operation type statistics

---

#### `get_failure_trends([days])`

Analyze failure trends over time.

**Syntax:**
```bash
trends=$(get_failure_trends)        # Last 7 days (default)
trends=$(get_failure_trends 30)     # Last 30 days
```

**Parameters:**
| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| days | int | 7 | Number of days to analyze |

**Returns:** JSON array of daily failure statistics

**JSON Structure:**
```json
[
  {
    "date": "2024-12-10",
    "total_operations": 50,
    "failed_operations": 2,
    "failure_rate": 4.00
  }
]
```

---

#### `get_operation_statistics()`

Comprehensive operation statistics overview.

**Syntax:**
```bash
stats=$(get_operation_statistics)
```

**Returns:** JSON object with aggregated statistics

**JSON Structure:**
```json
[
  {
    "total_operations": 500,
    "successful_operations": 485,
    "failed_operations": 15,
    "overall_success_rate": 97.00,
    "avg_duration": 120.5,
    "min_duration": 15,
    "max_duration": 890,
    "unique_capabilities": 7,
    "total_retries": 23
  }
]
```

---

#### `get_duration_percentile(percentile)`

Calculate operation duration at specific percentile.

**Syntax:**
```bash
duration=$(get_duration_percentile 95)  # 95th percentile
```

**Parameters:**
| Parameter | Type | Range | Description |
|-----------|------|-------|-------------|
| percentile | int | 0-100 | Percentile value |

**Returns:** Duration in seconds at that percentile

**Examples:**
```bash
p50=$(get_duration_percentile 50)  # Median
p95=$(get_duration_percentile 95)  # 95th percentile
p99=$(get_duration_percentile 99)  # 99th percentile

echo "P50: ${p50}s, P95: ${p95}s, P99: ${p99}s"
```

---

#### `get_outlier_operations([std_dev_threshold])`

Identify operations with anomalous durations.

**Syntax:**
```bash
outliers=$(get_outlier_operations)      # 2 std dev (default)
outliers=$(get_outlier_operations 3)    # 3 std dev
```

**Parameters:**
| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| std_dev_threshold | float | 2 | Standard deviations from mean |

**Returns:** JSON array of outlier operations

**JSON Structure:**
```json
[
  {
    "operation_id": "vm-create-001",
    "capability": "compute",
    "operation_type": "vm-create",
    "duration_seconds": 890,
    "std_dev_count": 3.45,
    "exit_code": 0
  }
]
```

---

#### `get_failing_operations([limit])`

Most frequently failing operation types.

**Syntax:**
```bash
failures=$(get_failing_operations)      # Top 10
failures=$(get_failing_operations 5)    # Top 5
```

**Returns:** JSON array of failing operation types

**JSON Structure:**
```json
[
  {
    "operation_type": "vm-create",
    "failure_count": 12,
    "percentage": 35.29,
    "avg_duration": 125.5
  }
]
```

---

### Export Functions

#### `export_metrics_report([output_file])`

Export comprehensive metrics report to JSON file.

**Syntax:**
```bash
report=$(export_metrics_report)
report=$(export_metrics_report "/path/to/report.json")
```

**Parameters:**
| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| output_file | path | auto-generated | Output file path |

**Returns:** Path to exported report file

**Report Contents:**
- Timestamp and metadata
- Overall statistics
- Success rates
- Top 20 slowest operations
- Performance by capability
- Performance by operation type
- 7-day failure trends

**Example:**
```bash
report=$(export_metrics_report)
log_info "Report exported to: $report"

# Access report data
jq '.statistics' "$report"
jq '.slowest_operations' "$report"
```

---

#### `export_metrics_csv([output_file])`

Export operation metrics to CSV format.

**Syntax:**
```bash
csv=$(export_metrics_csv)
csv=$(export_metrics_csv "/path/to/metrics.csv")
```

**Returns:** Path to exported CSV file

**CSV Columns:**
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
log_info "CSV exported to: $csv"

# Import into analysis tool
head -n 5 "$csv"  # Preview first 5 rows
```

---

### Reporting Functions

#### `print_metrics_summary()`

Print formatted metrics summary to console.

**Syntax:**
```bash
print_metrics_summary
```

**Output Format:**
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

---

#### `print_capability_performance()`

Print performance metrics grouped by capability.

**Syntax:**
```bash
print_capability_performance
```

**Output Format:**
```
========================================================================
  Performance by Capability
========================================================================

Capability                    Avg(s)  Min(s)  Max(s)  Ops  Success%
------------------------------------------------------------------------
compute                       125.5   45      450     120  98.33%
networking                    95.2    20      320     85   99.00%
storage                       67.8    10      200     95   96.84%
identity                      110.0   60      300     40   97.50%
avd                           150.0   80      500     50   96.00%
management                    45.0    10      150     30   100.00%
```

---

## Workflow Integration

### In Operation Handlers

```bash
#!/bin/bash
source core/metrics.sh

operation_id="my-operation-001"
capability="compute"
operation_type="vm-create"

start_time=$(date +%s)

# Execute operation
execute_operation

exit_code=$?
end_time=$(date +%s)
duration=$((end_time - start_time))

# Record performance
record_operation_performance "$operation_id" "$capability" "$operation_type" \
    "$duration" "$exit_code" 0

exit $exit_code
```

### In Deployment Workflows

```bash
#!/bin/bash
source core/metrics.sh

# Initialize
init_metrics_tables

# Run operations...
for op in operation1 operation2 operation3; do
    # Execute and record...
done

# Export and report
export_metrics_report
print_metrics_summary
```

### In CI/CD Pipelines

```bash
#!/bin/bash
source core/metrics.sh

# Track deployment
record_operation_performance "deployment-001" "management" "deployment" \
    "300" "0" "0"

# Export for analysis
json_report=$(export_metrics_report)
csv_export=$(export_metrics_csv)

# Upload reports
upload_to_artifact_storage "$json_report" "$csv_export"
```

---

## Database Schema Details

### metrics Table

```sql
CREATE TABLE metrics (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    operation_id TEXT NOT NULL,
    metric_name TEXT NOT NULL,
    metric_value REAL NOT NULL,
    unit TEXT,
    recorded_at INTEGER NOT NULL,
    FOREIGN KEY (operation_id) REFERENCES operations(operation_id),
    UNIQUE(operation_id, metric_name, recorded_at)
);

CREATE INDEX idx_metrics_operation ON metrics(operation_id);
CREATE INDEX idx_metrics_name ON metrics(metric_name);
CREATE INDEX idx_metrics_recorded ON metrics(recorded_at);
```

### operation_performance Table

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
    FOREIGN KEY (operation_id) REFERENCES operations(operation_id)
);

CREATE INDEX idx_operation_perf_capability ON operation_performance(capability);
CREATE INDEX idx_operation_perf_duration ON operation_performance(duration_seconds);
CREATE INDEX idx_operation_perf_exit_code ON operation_performance(exit_code);
```

### metrics_aggregated Table

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

CREATE INDEX idx_metrics_agg_period ON metrics_aggregated(period);
CREATE INDEX idx_metrics_agg_capability ON metrics_aggregated(capability);
```

---

## Best Practices

1. **Initialize on startup**: Call `init_metrics_tables()` once during application initialization
2. **Record immediately**: Record metrics right after operation completion
3. **Use consistent IDs**: Ensure operation IDs are globally unique and descriptive
4. **Include context**: Record capability and operation_type for better analytics
5. **Track retries**: Record retry counts to understand operation stability
6. **Export regularly**: Schedule metrics exports for historical analysis
7. **Monitor trends**: Review failure_trends to catch emerging issues
8. **Analyze outliers**: Investigate outlier operations to identify systemic issues
9. **Clean up old data**: Archive or delete metrics older than retention period
10. **Use percentiles**: Compare against P95/P99 for SLA validation

---

## Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| "No metrics found" | Tables not initialized | Call `init_metrics_tables()` |
| Slow queries | Large dataset, missing indexes | Check database size, consider archiving |
| NULL values in results | Incomplete metric recording | Ensure all required fields are captured |
| Duplicate operation IDs | ID collision | Use UUIDs or more granular IDs |
| Large database file | Accumulated old metrics | Archive and delete old data |

---

## Performance Tuning

- Metrics queries use indexed columns for O(log n) lookups
- Aggregated metrics table enables efficient reporting
- Consider archiving metrics older than 6-12 months
- Use CSV export for large dataset analysis
- JSON reports best for programmatic access

---

## Version History

- **1.0** - Initial release with core metrics functions and SQLite persistence
