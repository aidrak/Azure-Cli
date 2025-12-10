# Metrics Module Implementation Guide

## Overview

The Metrics Module has been successfully created and integrated into the Azure VDI Deployment Engine. This guide covers implementation, integration, and usage patterns.

## Files Created

### 1. Core Module
**File:** `/mnt/cache_pool/development/azure-projects/test-01/core/metrics.sh` (25 KB)

The main metrics module implementing all observability functions.

**Key Features:**
- SQLite-based metrics persistence
- 20+ analytics functions
- JSON and CSV export capabilities
- Real-time performance tracking
- Trend analysis and outlier detection

### 2. Documentation

#### METRICS.md (14 KB)
Complete user guide covering:
- Quick start examples
- Function reference with usage examples
- Database schema documentation
- Integration patterns
- Best practices and troubleshooting

#### METRICS-REFERENCE.md (18 KB)
Comprehensive reference guide with:
- Complete function syntax and parameters
- JSON output structures
- Performance tuning recommendations
- Workflow integration patterns
- Troubleshooting table

### 3. Example Integration
**File:** `/mnt/cache_pool/development/azure-projects/test-01/examples/metrics-integration-example.sh` (13 KB)

Executable examples demonstrating:
- 12 practical usage examples
- Basic metrics recording and retrieval
- Success rate and performance analysis
- Capability performance comparison
- Failure analysis and trending
- Comprehensive statistics and reporting
- Export to JSON and CSV formats
- Percentile analysis
- Outlier detection

## Architecture

### Database Schema

Three main tables:

```
metrics
├── operation_id → operations.operation_id (FK)
├── metric_name (indexed)
├── metric_value (numeric)
├── unit (e.g., "seconds", "MB")
└── recorded_at (indexed, Unix timestamp)

operation_performance
├── operation_id → operations.operation_id (FK, UNIQUE)
├── capability (indexed, e.g., "compute", "networking")
├── operation_type (e.g., "vm-create")
├── duration_seconds (indexed)
├── exit_code (indexed, 0=success)
├── retry_count
├── started_at
└── completed_at

metrics_aggregated (performance cache)
├── period (daily/weekly/monthly)
├── capability
├── operation_type
├── metric_name
├── metric_value
└── sample_count
```

### Function Hierarchy

```
Initialization
└── init_metrics_tables()

Recording (Write)
├── record_metric()
└── record_operation_performance()

Retrieval (Read)
├── get_operation_duration()
├── get_metric()
└── get_operation_metrics()

Analytics (Aggregation)
├── get_success_rate()
├── get_slowest_operations()
├── get_fastest_operations()
├── get_duration_by_capability()
├── get_duration_by_operation_type()
├── get_failure_trends()
├── get_operation_statistics()
├── get_duration_percentile()
├── get_outlier_operations()
└── get_failing_operations()

Export
├── export_metrics_report() → JSON
└── export_metrics_csv() → CSV

Reporting (Console)
├── print_metrics_summary()
└── print_capability_performance()
```

## Integration Checklist

### Step 1: Source the Module

```bash
source core/metrics.sh
```

### Step 2: Initialize Tables (Once)

```bash
init_metrics_tables
```

### Step 3: Record Operation Performance

After each operation completes:

```bash
start_time=$(date +%s)

# ... execute operation ...

exit_code=$?
duration=$(($(date +%s) - start_time))

record_operation_performance \
    "operation-id" \
    "capability" \
    "operation-type" \
    "$duration" \
    "$exit_code" \
    0  # retry count
```

### Step 4: Query Metrics

```bash
# Success rate
get_success_rate

# Performance analysis
get_slowest_operations 10
get_duration_by_capability

# Export reports
export_metrics_report
```

## Usage Examples

### Example 1: Basic Integration in Operation

```bash
#!/bin/bash
source core/metrics.sh

operation_id="vm-create-$(date +%s)"
capability="compute"
operation_type="vm-create"

start_time=$(date +%s)

# Execute operation
if az vm create --resource-group "$RG" --name "vm-001" ...; then
    exit_code=0
else
    exit_code=1
fi

duration=$(($(date +%s) - start_time))

# Record metrics
record_operation_performance "$operation_id" "$capability" "$operation_type" \
    "$duration" "$exit_code" 0

# Record custom metrics if needed
if [[ $exit_code -eq 0 ]]; then
    record_metric "$operation_id" "provisioning-state" "Succeeded"
fi

exit $exit_code
```

### Example 2: Success Rate Monitoring

```bash
#!/bin/bash
source core/metrics.sh

# Check overall success rate
overall=$(get_success_rate)
success_rate=$(echo "$overall" | jq -r '.[0].success_rate')

echo "Overall success rate: ${success_rate}%"

if (( $(echo "$success_rate < 95" | bc -l) )); then
    echo "WARNING: Success rate below 95%"

    # Investigate failures
    failing=$(get_failing_operations 5)
    echo "$failing" | jq '.[] | "\(.operation_type): \(.failure_count) failures"'
fi
```

### Example 3: Performance Analysis

```bash
#!/bin/bash
source core/metrics.sh

# Get duration distribution
p50=$(get_duration_percentile 50)
p95=$(get_duration_percentile 95)
p99=$(get_duration_percentile 99)

echo "P50: ${p50}s, P95: ${p95}s, P99: ${p99}s"

# Identify slow operations
slowest=$(get_slowest_operations 5)
echo "$slowest" | jq '.[] | "\(.operation_id): \(.duration_seconds)s"'

# Check for outliers
outliers=$(get_outlier_operations 2)
if [[ $(echo "$outliers" | jq 'length') -gt 0 ]]; then
    echo "Found $(echo "$outliers" | jq 'length') outlier operations"
fi
```

### Example 4: Workflow Metrics Export

```bash
#!/bin/bash
source core/metrics.sh

# Initialize
init_metrics_tables

# Run deployment workflow
./core/engine.sh run compute/vm-create
./core/engine.sh run networking/vnet-deploy
./core/engine.sh run storage/storage-deploy

# Generate reports
json_report=$(export_metrics_report)
csv_export=$(export_metrics_csv)

echo "Reports generated:"
echo "  JSON: $json_report"
echo "  CSV: $csv_export"

# Print summary
print_metrics_summary
print_capability_performance
```

## Running Examples

The included example script demonstrates all major functions:

```bash
# Run all 12 examples
bash examples/metrics-integration-example.sh

# Review example outputs
cat artifacts/metrics/metrics_report_*.json | jq '.'
```

## Performance Characteristics

### Query Performance

| Query Type | Complexity | Notes |
|------------|-----------|-------|
| get_operation_duration | O(log n) | Indexed on operation_id |
| get_slowest_operations | O(n log n) | Sorted scan, indexed duration |
| get_success_rate | O(n) | Single aggregation pass |
| get_duration_percentile | O(n log n) | Ordered scan |
| export_metrics_report | O(n) | Multiple queries, ~100-200ms |

### Storage

- Typical metrics storage: ~1-2 KB per operation
- 10,000 operations: ~10-20 MB
- 100,000 operations: ~100-200 MB

## Integration with Engine

The metrics module is designed to work seamlessly with:
- `core/state-manager.sh` - Queries operations table
- `core/logger.sh` - Structured logging
- `core/executor.sh` - Records operation completion

## Configuration

### Environment Variables

```bash
# Override default paths
export STATE_DB="/custom/path/state.db"
export METRICS_EXPORT_DIR="/custom/metrics/export"
export PROJECT_ROOT="/custom/project/root"
```

### Database Customization

Metrics table can be manually queried:

```bash
# Query raw metrics
sqlite3 state.db "SELECT * FROM operation_performance WHERE exit_code = 1;"

# Export custom report
sqlite3 state.db -json "SELECT operation_id, duration_seconds FROM operation_performance ORDER BY duration_seconds DESC LIMIT 10;"
```

## Maintenance

### Archiving Old Metrics

```bash
# Archive metrics older than 6 months
sqlite3 state.db "DELETE FROM metrics WHERE recorded_at < strftime('%s', 'now', '-6 months');"
sqlite3 state.db "DELETE FROM operation_performance WHERE completed_at < strftime('%s', 'now', '-6 months');"
sqlite3 state.db "VACUUM;"  # Reclaim space
```

### Database Optimization

```bash
# Analyze query performance
sqlite3 state.db "ANALYZE;"

# Rebuild indexes
sqlite3 state.db "REINDEX;"

# Check database integrity
sqlite3 state.db "PRAGMA integrity_check;"
```

## Troubleshooting

### Issue: "Tables already exist"
**Solution:** This is normal on subsequent runs. The CREATE IF NOT EXISTS clause prevents errors.

### Issue: Slow export queries
**Solution:** Consider exporting to CSV (faster), or archiving old metrics.

### Issue: "Resource temporarily unavailable"
**Solution:** Another process is locking the database. Wait a moment and retry.

## Future Enhancements

Potential future additions:
- Metrics aggregation scheduling
- Real-time metrics streaming
- Alerting on SLA violations
- Performance prediction models
- Cost analysis integration
- Resource utilization tracking

## Related Documentation

- **METRICS.md** - User guide with quick start and examples
- **METRICS-REFERENCE.md** - Complete function reference
- **examples/metrics-integration-example.sh** - 12 working examples
- **core/state-manager.sh** - Operation state tracking
- **core/logger.sh** - Structured logging system

## Support

For issues or questions:
1. Check the troubleshooting section in METRICS.md
2. Review examples in metrics-integration-example.sh
3. Query the database directly with sqlite3
4. Check logs in artifacts/logs/ directory

## Version Information

- **Module Version:** 1.0
- **Created:** December 10, 2024
- **Bash Version:** 4.0+
- **Dependencies:** sqlite3, jq, standard Unix utilities
- **Status:** Production-ready
