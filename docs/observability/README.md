# Observability & Metrics Module

Complete observability and performance analytics for the Azure VDI Deployment Engine.

## Quick Start

```bash
# Source the module
source core/metrics.sh

# Initialize database tables (once)
init_metrics_tables

# Record operation completion
record_operation_performance "vm-create-001" "compute" "vm-create" 120 0 0

# Query metrics
get_success_rate              # Overall success rate
get_slowest_operations 10     # Top 10 slowest operations
get_duration_by_capability    # Performance by capability

# Export reports
export_metrics_report         # JSON report
export_metrics_csv            # CSV export

# Print to console
print_metrics_summary
print_capability_performance
```

## Documentation

### User Guides

- **[METRICS.md](./METRICS.md)** - Complete user guide
  - Quick start examples
  - Function reference with examples
  - Database schema
  - Integration patterns
  - Best practices

- **[METRICS-REFERENCE.md](./METRICS-REFERENCE.md)** - Function reference
  - Detailed function syntax
  - Parameter descriptions
  - Return values and JSON schemas
  - Performance characteristics
  - Troubleshooting table

- **[IMPLEMENTATION-GUIDE.md](./IMPLEMENTATION-GUIDE.md)** - Integration guide
  - Architecture overview
  - Implementation checklist
  - Integration examples
  - Maintenance procedures
  - Future enhancements

## Core Module

**Location:** `core/metrics.sh` (25 KB)

### Public Functions (20+)

**Initialization:**
- `init_metrics_tables()` - Initialize SQLite tables

**Recording:**
- `record_metric()` - Record custom metric
- `record_operation_performance()` - Record operation completion

**Retrieval:**
- `get_operation_duration()` - Get operation duration
- `get_metric()` - Get specific metric value
- `get_operation_metrics()` - Get all metrics for operation

**Analytics:**
- `get_success_rate()` - Calculate success rate
- `get_slowest_operations()` - Get slowest operations
- `get_fastest_operations()` - Get fastest operations
- `get_duration_by_capability()` - Performance by capability
- `get_duration_by_operation_type()` - Performance by type
- `get_failure_trends()` - Analyze failure trends
- `get_operation_statistics()` - Comprehensive statistics
- `get_duration_percentile()` - Percentile analysis
- `get_outlier_operations()` - Anomaly detection
- `get_failing_operations()` - Most failing operations

**Export:**
- `export_metrics_report()` - Export to JSON
- `export_metrics_csv()` - Export to CSV

**Reporting:**
- `print_metrics_summary()` - Console summary
- `print_capability_performance()` - Capability performance table

## Database Schema

Three SQLite tables with comprehensive indexing:

### metrics
Individual metric measurements
- Fields: operation_id, metric_name, metric_value, unit, recorded_at
- Indexes: operation_id, metric_name, recorded_at

### operation_performance
Operation completion data
- Fields: operation_id, capability, operation_type, duration_seconds, exit_code, retry_count, started_at, completed_at
- Indexes: capability, duration_seconds, exit_code

### metrics_aggregated
Pre-calculated aggregates (performance optimization)
- Fields: period, capability, operation_type, metric_name, metric_value, sample_count

## Examples

### Example 1: Basic Usage

```bash
#!/bin/bash
source core/metrics.sh

# Initialize
init_metrics_tables

# Record operation
start=$(date +%s)
az vm create --resource-group RG --name vm-001
exit_code=$?
duration=$(($(date +%s) - start))

record_operation_performance "vm-001" "compute" "vm-create" "$duration" "$exit_code" 0

# Get metrics
rate=$(get_success_rate)
echo "Success rate: $(echo "$rate" | jq '.[0].success_rate')%"
```

### Example 2: Performance Analysis

```bash
#!/bin/bash
source core/metrics.sh

# Get slowest operations
slowest=$(get_slowest_operations 10)
echo "$slowest" | jq '.[] | "\(.operation_id): \(.duration_seconds)s"'

# Get percentiles
p95=$(get_duration_percentile 95)
p99=$(get_duration_percentile 99)
echo "P95: ${p95}s, P99: ${p99}s"

# Find outliers
outliers=$(get_outlier_operations 2)
echo "Outliers: $(echo "$outliers" | jq 'length')"
```

### Example 3: Workflow Integration

```bash
#!/bin/bash
source core/metrics.sh

# Initialize
init_metrics_tables

# Run operations and record metrics
for op in vm-create vnet-deploy storage-create; do
    ./core/engine.sh run "$op"
    # Metrics recorded by engine
done

# Generate reports
json=$(export_metrics_report)
csv=$(export_metrics_csv)

print_metrics_summary
print_capability_performance
```

## Running Examples

Complete working example script with 12 examples:

```bash
bash examples/metrics-integration-example.sh
```

This demonstrates:
1. Basic metrics recording
2. Retrieving and analyzing metrics
3. Success rate analysis
4. Performance analysis
5. Capability performance comparison
6. Operation type performance
7. Failure analysis
8. Comprehensive statistics
9. Console reports
10. Report export (JSON & CSV)
11. Percentile analysis
12. Outlier detection

## Integration with Engine

### Automatic Integration

The engine can be extended to automatically record metrics:

```bash
# In operation handler YAML
record_operation_performance "$operation_id" "$capability" "$operation_type" \
    "$duration" "$exit_code" "$retry_count"
```

### Manual Integration

Record metrics explicitly after operations:

```bash
#!/bin/bash
source core/metrics.sh

start=$(date +%s)
# ... execute operation ...
exit_code=$?
duration=$(($(date +%s) - start))

record_operation_performance "op-id" "capability" "type" "$duration" "$exit_code" 0
```

## Output Formats

### JSON Export

```json
{
  "timestamp": "2024-12-10T14:30:45Z",
  "export_date": 1733838645,
  "statistics": [
    {
      "total_operations": 500,
      "successful_operations": 485,
      "failed_operations": 15,
      "overall_success_rate": 97.0,
      "avg_duration": 120.5
    }
  ],
  "slowest_operations": [...],
  "duration_by_capability": [...],
  "failure_trends_7days": [...]
}
```

### CSV Export

```csv
operation_id,capability,operation_type,duration_seconds,exit_code,retry_count,completed_at
vm-create-001,compute,vm-create,120,0,0,2024-12-10 14:30:00
vm-create-002,compute,vm-create,135,0,1,2024-12-10 14:35:00
vnet-deploy-001,networking,vnet-deploy,45,0,0,2024-12-10 14:40:00
```

### Console Output

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

========================================================================
```

## Performance Characteristics

- **Query Speed:** O(log n) with indexing
- **Storage:** ~1-2 KB per operation
- **10K operations:** ~10-20 MB
- **100K operations:** ~100-200 MB
- **Export JSON:** 100-200ms for 1000 operations
- **Export CSV:** 50-100ms for 1000 operations

## Key Features

✓ **Production-Ready**
- Comprehensive error handling
- SQL injection protection
- Atomic transactions
- Data integrity checks

✓ **Performant**
- SQLite indexing on hot paths
- Aggregated metrics caching
- Efficient JSON output
- Fast CSV export

✓ **Flexible**
- Record custom metrics
- Filter by capability/type
- Multiple export formats
- Configurable analysis periods

✓ **Insightful**
- Success rate tracking
- Performance trending
- Outlier detection
- Failure analysis

## Directory Structure

```
docs/observability/
├── README.md                 # This file
├── METRICS.md               # User guide (14 KB)
├── METRICS-REFERENCE.md     # Function reference (18 KB)
└── IMPLEMENTATION-GUIDE.md  # Integration guide (15 KB)

core/
└── metrics.sh               # Main module (25 KB)

examples/
└── metrics-integration-example.sh  # 12 working examples (13 KB)

artifacts/
└── metrics/                 # Export destination
    ├── metrics_report_*.json
    └── metrics_report_*.csv
```

## Best Practices

1. **Initialize on startup** - Call `init_metrics_tables()` once
2. **Record immediately** - Capture metrics right after operation
3. **Use consistent IDs** - Globally unique operation identifiers
4. **Include context** - Always record capability and operation_type
5. **Track retries** - Record retry counts for stability insights
6. **Export regularly** - Schedule metrics exports for analysis
7. **Monitor trends** - Review failure trends weekly
8. **Analyze outliers** - Investigate anomalous durations
9. **Clean up old data** - Archive metrics > 6 months old
10. **Export reports** - Use JSON for integration, CSV for Excel

## Common Queries

```bash
# Overall success rate
get_success_rate

# Success by capability
get_success_rate "compute"

# Slowest 20 operations
get_slowest_operations 20

# Performance by capability
get_duration_by_capability

# Failure trends (last 7 days)
get_failure_trends 7

# Identify problematic operations
get_failing_operations 10

# Find outliers
get_outlier_operations 2

# Full statistics
get_operation_statistics

# Export all data
export_metrics_report
export_metrics_csv

# Console summary
print_metrics_summary
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "Tables already exist" | Normal - CREATE IF NOT EXISTS handles this |
| No metrics found | Call `init_metrics_tables()` first |
| Slow queries | Check database size, archive old data |
| Database locked | Wait and retry, or use WAL mode |
| Export fails | Check artifacts/metrics/ directory writable |

## Requirements

- Bash 4.0+
- sqlite3
- jq (for JSON processing)
- Standard Unix utilities (date, etc.)

## Version

- **Version:** 1.0
- **Created:** December 10, 2024
- **Status:** Production-Ready

## License

Same as Azure VDI Deployment Engine

## Support

1. Check [METRICS.md](./METRICS.md) for usage examples
2. See [METRICS-REFERENCE.md](./METRICS-REFERENCE.md) for complete API
3. Run examples with `bash examples/metrics-integration-example.sh`
4. Review logs in `artifacts/logs/`
5. Query database directly with `sqlite3 state.db`

---

**Next Steps:**
1. Read [METRICS.md](./METRICS.md) for quick start
2. Review [IMPLEMENTATION-GUIDE.md](./IMPLEMENTATION-GUIDE.md) for integration
3. Run examples: `bash examples/metrics-integration-example.sh`
4. Integrate into your operations
5. Export and analyze metrics regularly
