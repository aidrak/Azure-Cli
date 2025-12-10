# Metrics Module - Quick Reference Card

## One-Minute Quickstart

```bash
# Source and initialize
source core/metrics.sh
init_metrics_tables

# Record operation performance
record_operation_performance "op-id" "compute" "vm-create" 120 0 0

# Get metrics
get_success_rate                    # Success rate %
get_slowest_operations              # Top 10 slowest
get_duration_by_capability          # Performance by capability

# Export reports
export_metrics_report               # → JSON file
export_metrics_csv                  # → CSV file

# Print to console
print_metrics_summary               # Text summary
```

## 10 Essential Functions

| Function | Purpose | Example |
|----------|---------|---------|
| `record_operation_performance()` | Record operation metrics | `record_operation_performance "op1" "compute" "vm-create" 120 0 0` |
| `record_metric()` | Record custom metric | `record_metric "op1" "memory-used" "512" "MB"` |
| `get_success_rate()` | Success rate % | `get_success_rate "compute"` |
| `get_slowest_operations()` | Slowest N operations | `get_slowest_operations 10` |
| `get_duration_by_capability()` | Performance stats by capability | `get_duration_by_capability` |
| `get_failure_trends()` | Failure trends over days | `get_failure_trends 7` |
| `get_operation_statistics()` | Overall statistics | `get_operation_statistics` |
| `export_metrics_report()` | Export to JSON | `export_metrics_report` |
| `export_metrics_csv()` | Export to CSV | `export_metrics_csv` |
| `print_metrics_summary()` | Console summary | `print_metrics_summary` |

## Function Quick Lookup

### Recording Functions
```bash
record_metric "op-id" "metric-name" "value" ["unit"]
record_operation_performance "op-id" "capability" "type" duration exit_code [retries]
```

### Query Functions
```bash
get_operation_duration "op-id"              # → duration in seconds
get_metric "op-id" "metric-name"            # → metric value
get_operation_metrics "op-id"               # → JSON array
```

### Analytics Functions
```bash
get_success_rate [capability]               # → JSON with rates
get_slowest_operations [limit]              # → JSON array (default: 10)
get_fastest_operations [limit]              # → JSON array
get_duration_by_capability                  # → JSON array
get_duration_by_operation_type              # → JSON array
get_failure_trends [days]                   # → JSON array (default: 7)
get_operation_statistics                    # → JSON object
get_duration_percentile percentile          # → duration (0-100)
get_outlier_operations [std_dev_threshold]  # → JSON array (default: 2)
get_failing_operations [limit]              # → JSON array (default: 10)
```

### Export Functions
```bash
export_metrics_report [output_file]         # → JSON file path
export_metrics_csv [output_file]            # → CSV file path
```

### Console Functions
```bash
print_metrics_summary                       # Print to console
print_capability_performance                # Print table
```

## Common Patterns

### Check Success Rate
```bash
rate=$(get_success_rate)
echo "Success: $(echo "$rate" | jq '.[0].success_rate')%"
```

### Find Slow Operations
```bash
slow=$(get_slowest_operations 5)
echo "$slow" | jq '.[] | "\(.operation_id): \(.duration_seconds)s"'
```

### Export All Data
```bash
json=$(export_metrics_report)
csv=$(export_metrics_csv)
echo "JSON: $json"
echo "CSV: $csv"
```

### Performance by Capability
```bash
perf=$(get_duration_by_capability)
echo "$perf" | jq '.[] | "\(.capability): avg=\(.avg_duration)s"'
```

### Check Failure Trends
```bash
trends=$(get_failure_trends 7)
echo "$trends" | jq '.[] | "\(.date): \(.failure_rate)% failures"'
```

## Output Examples

### Success Rate
```json
[{
  "success_rate": 97.50,
  "total_operations": 200,
  "successful": 195,
  "failed": 5
}]
```

### Slowest Operations
```json
[{
  "operation_id": "vm-create-001",
  "capability": "compute",
  "operation_type": "vm-create",
  "duration_seconds": 450,
  "exit_code": 0
}]
```

### Capability Performance
```json
[{
  "capability": "compute",
  "avg_duration": 125.5,
  "min_duration": 45,
  "max_duration": 450,
  "operation_count": 120,
  "success_rate": 98.33
}]
```

## Database

### Tables
- `metrics` - Individual metric measurements
- `operation_performance` - Operation completion data
- `metrics_aggregated` - Performance cache

### Direct Queries
```bash
# List all operations
sqlite3 state.db "SELECT operation_id, duration_seconds, exit_code FROM operation_performance;"

# Find failures
sqlite3 state.db "SELECT operation_id, capability FROM operation_performance WHERE exit_code != 0;"

# Performance stats
sqlite3 state.db "SELECT capability, AVG(duration_seconds), COUNT(*) FROM operation_performance GROUP BY capability;"
```

## Configuration

### Environment Variables
```bash
export STATE_DB="/path/to/state.db"
export METRICS_EXPORT_DIR="/path/to/export"
export PROJECT_ROOT="/project/root"
```

### Default Paths
- Database: `./state.db`
- Exports: `./artifacts/metrics/`
- Reports: `./artifacts/metrics/metrics_report_*.json`

## Parameter Reference

### Capabilities
Common values: `compute`, `networking`, `storage`, `identity`, `avd`, `management`

### Operation Types
Common values: `vm-create`, `vm-delete`, `vnet-create`, `vnet-deploy`, `storage-create`, etc.

### Exit Codes
- `0` = Success
- Non-zero = Failure (specific error code)

### Metrics Units
Common: `seconds`, `minutes`, `MB`, `GB`, `%`, `count`

## Performance Tips

1. **Initialize once:** `init_metrics_tables()` at startup
2. **Record immediately:** After each operation completes
3. **Query efficiently:** Use indexed columns (operation_id, duration_seconds, exit_code)
4. **Export regularly:** Schedule daily/weekly exports
5. **Archive old data:** Delete metrics > 6 months old
6. **Use CSV for Excel:** Faster than JSON for large datasets
7. **Use JSON for APIs:** Better for programmatic access

## Troubleshooting

| Issue | Fix |
|-------|-----|
| "No data found" | Call `init_metrics_tables()` and record operations first |
| Slow queries | Check database size with `sqlite3 state.db ".tables"` |
| NULL results | Not all metrics recorded; check operation completion |
| Export fails | Ensure `artifacts/metrics/` directory exists and is writable |

## File Locations

```
core/metrics.sh                              # Main module
docs/observability/METRICS.md                # Full user guide
docs/observability/METRICS-REFERENCE.md      # Complete function reference
docs/observability/IMPLEMENTATION-GUIDE.md   # Integration guide
examples/metrics-integration-example.sh      # 12 working examples
```

## Links

- **User Guide:** [METRICS.md](./METRICS.md)
- **Reference:** [METRICS-REFERENCE.md](./METRICS-REFERENCE.md)
- **Integration:** [IMPLEMENTATION-GUIDE.md](./IMPLEMENTATION-GUIDE.md)
- **Examples:** `bash examples/metrics-integration-example.sh`

## Key Commands

```bash
# Initialize
source core/metrics.sh
init_metrics_tables

# Record
record_operation_performance "op1" "compute" "vm-create" 120 0 0

# Query
get_success_rate
get_slowest_operations 10
get_operation_statistics

# Export
export_metrics_report
export_metrics_csv

# Report
print_metrics_summary
print_capability_performance
```

## Notes

- All timestamps are Unix epoch (seconds since 1970)
- Operations are unique by operation_id
- Success = exit_code of 0
- Failure = any non-zero exit_code
- Duration in seconds
- Percentiles: 0-100 (50 = median, 95 = 95th percentile)
- Standard deviations: number of std dev from mean
- Capabilities: compute, networking, storage, identity, avd, management

---

**For more information:**
- Quick start: [METRICS.md](./METRICS.md)
- Details: [METRICS-REFERENCE.md](./METRICS-REFERENCE.md)
- Integration: [IMPLEMENTATION-GUIDE.md](./IMPLEMENTATION-GUIDE.md)
