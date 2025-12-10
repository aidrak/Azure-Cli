#!/bin/bash
# ==============================================================================
# Metrics Module Integration Example
# ==============================================================================
#
# This script demonstrates how to integrate the Metrics Module with
# Azure VDI Deployment Engine operations.
#
# Usage:
#   ./examples/metrics-integration-example.sh
#
# ==============================================================================

set -euo pipefail

# Project root
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Source required modules
source "${PROJECT_ROOT}/core/logger.sh"
source "${PROJECT_ROOT}/core/state-manager.sh"
source "${PROJECT_ROOT}/core/metrics.sh"

# ==============================================================================
# EXAMPLE 1: Initialize and Record Basic Metrics
# ==============================================================================
example_basic_metrics() {
    log_info "Example 1: Basic Metrics Recording" "metrics-example"
    echo ""

    # Initialize metrics tables
    init_metrics_tables || return 1

    # Record some operation performance data
    log_info "Recording sample operations..." "metrics-example"

    # Successful fast operations
    record_operation_performance "vnet-create-001" "networking" "vnet-create" 45 0 0
    record_operation_performance "vnet-create-002" "networking" "vnet-create" 52 0 0
    record_operation_performance "vnet-create-003" "networking" "vnet-create" 38 0 0

    # Successful compute operations (slower)
    record_operation_performance "vm-create-001" "compute" "vm-create" 280 0 0
    record_operation_performance "vm-create-002" "compute" "vm-create" 310 0 0
    record_operation_performance "vm-create-003" "compute" "vm-create" 290 0 0

    # Some failed operations
    record_operation_performance "storage-deploy-001" "storage" "storage-deploy" 60 1 1
    record_operation_performance "storage-deploy-002" "storage" "storage-deploy" 75 0 0

    # Operation with high retry count
    record_operation_performance "identity-setup-001" "identity" "identity-setup" 120 0 3

    log_success "Sample operations recorded" "metrics-example"
    echo ""
}

# ==============================================================================
# EXAMPLE 2: Retrieve and Analyze Metrics
# ==============================================================================
example_retrieve_metrics() {
    log_info "Example 2: Retrieving and Analyzing Metrics" "metrics-example"
    echo ""

    # Get duration of specific operation
    duration=$(get_operation_duration "vm-create-001")
    log_info "Operation vm-create-001 duration: ${duration}s" "metrics-example"

    # Get all metrics for operation
    log_info "All metrics for vm-create-001:" "metrics-example"
    metrics=$(get_operation_metrics "vm-create-001")
    echo "$metrics" | jq '.' || true

    echo ""
}

# ==============================================================================
# EXAMPLE 3: Success Rate Analysis
# ==============================================================================
example_success_rate() {
    log_info "Example 3: Success Rate Analysis" "metrics-example"
    echo ""

    # Overall success rate
    log_info "Overall success rate:" "metrics-example"
    overall=$(get_success_rate)
    echo "$overall" | jq '.[] | "Success Rate: \(.success_rate)% (\(.successful)/\(.total_operations))"' || true

    echo ""

    # Success rate by capability
    log_info "Success rate by capability:" "metrics-example"

    for capability in "networking" "compute" "storage" "identity"; do
        result=$(get_success_rate "$capability" 2>/dev/null || echo "[]")
        if [[ "$result" != "[]" ]]; then
            echo "$result" | jq -r '.[] | "  \(.capability): \(.success_rate)% (\(.successful)/\(.total_operations))"' || true
        fi
    done

    echo ""
}

# ==============================================================================
# EXAMPLE 4: Performance Analysis
# ==============================================================================
example_performance_analysis() {
    log_info "Example 4: Performance Analysis" "metrics-example"
    echo ""

    # Slowest operations
    log_info "Top 5 slowest operations:" "metrics-example"
    slowest=$(get_slowest_operations 5)
    echo "$slowest" | jq -r '.[] | "  \(.operation_id): \(.duration_seconds)s (\(.capability)/\(.operation_type))"' || true

    echo ""

    # Fastest operations
    log_info "Top 5 fastest operations:" "metrics-example"
    fastest=$(get_fastest_operations 5)
    echo "$fastest" | jq -r '.[] | "  \(.operation_id): \(.duration_seconds)s (\(.capability)/\(.operation_type))"' || true

    echo ""
}

# ==============================================================================
# EXAMPLE 5: Capability Performance Comparison
# ==============================================================================
example_capability_performance() {
    log_info "Example 5: Capability Performance Comparison" "metrics-example"
    echo ""

    by_capability=$(get_duration_by_capability)

    echo "Capability Performance:"
    echo "-------------------------------------"
    echo "$by_capability" | jq -r '.[] |
        printf("%-20s Avg: %6.1fs Min: %5.0fs Max: %5.0fs Ops: %3d Success: %5.1f%%\n",
            .capability,
            .avg_duration,
            .min_duration,
            .max_duration,
            .operation_count,
            .success_rate)' || true

    echo ""
}

# ==============================================================================
# EXAMPLE 6: Operation Type Performance
# ==============================================================================
example_operation_type_performance() {
    log_info "Example 6: Operation Type Performance" "metrics-example"
    echo ""

    by_type=$(get_duration_by_operation_type)

    echo "Operation Type Performance:"
    echo "-------------------------------------"
    echo "$by_type" | jq -r '.[] |
        printf("%-20s Avg: %6.1fs Min: %5.0fs Max: %5.0fs Ops: %3d Success: %5.1f%%\n",
            .operation_type,
            .avg_duration,
            .min_duration,
            .max_duration,
            .operation_count,
            .success_rate)' || true

    echo ""
}

# ==============================================================================
# EXAMPLE 7: Failure Analysis
# ==============================================================================
example_failure_analysis() {
    log_info "Example 7: Failure Analysis" "metrics-example"
    echo ""

    # Get failing operations
    failing=$(get_failing_operations 10 2>/dev/null || echo "[]")

    if [[ "$failing" != "[]" ]]; then
        log_info "Most frequently failing operation types:" "metrics-example"
        echo "$failing" | jq -r '.[] |
            printf("  %-25s Failures: %3d (%.1f%%) Avg Duration: %.1fs\n",
                .operation_type,
                .failure_count,
                .percentage,
                .avg_duration)' || true
    else
        log_info "No failures recorded" "metrics-example"
    fi

    echo ""

    # Get failure trends
    log_info "Failure trends (last 7 days):" "metrics-example"
    trends=$(get_failure_trends 7 2>/dev/null || echo "[]")

    if [[ "$trends" != "[]" ]]; then
        echo "$trends" | jq -r '.[] |
            printf("  %s: %3d failures out of %3d operations (%.1f%% failure rate)\n",
                .date,
                .failed_operations,
                .total_operations,
                .failure_rate)' || true
    fi

    echo ""
}

# ==============================================================================
# EXAMPLE 8: Comprehensive Statistics
# ==============================================================================
example_comprehensive_stats() {
    log_info "Example 8: Comprehensive Statistics" "metrics-example"
    echo ""

    stats=$(get_operation_statistics)

    if [[ -n "$stats" ]] && [[ "$stats" != "[]" ]]; then
        echo "$stats" | jq -r '.[] |
            "Total Operations:        \(.total_operations)\n" +
            "Successful:              \(.successful_operations)\n" +
            "Failed:                  \(.failed_operations)\n" +
            "Success Rate:            \(.overall_success_rate)%\n" +
            "Average Duration:        \(.avg_duration)s\n" +
            "Min Duration:            \(.min_duration)s\n" +
            "Max Duration:            \(.max_duration)s\n" +
            "Unique Capabilities:     \(.unique_capabilities)\n" +
            "Total Retries:           \(.total_retries)"' || true
    fi

    echo ""
}

# ==============================================================================
# EXAMPLE 9: Console Reports
# ==============================================================================
example_console_reports() {
    log_info "Example 9: Console Reports" "metrics-example"
    echo ""

    # Print summary
    print_metrics_summary

    # Print capability performance
    print_capability_performance
}

# ==============================================================================
# EXAMPLE 10: Export Reports
# ==============================================================================
example_export_reports() {
    log_info "Example 10: Exporting Reports" "metrics-example"
    echo ""

    # Export JSON report
    log_info "Exporting JSON report..." "metrics-example"
    json_report=$(export_metrics_report)
    log_success "JSON report exported: $json_report" "metrics-example"

    # Show JSON report summary
    if [[ -f "$json_report" ]]; then
        log_info "Report contents:" "metrics-example"
        jq '.statistics, .success_rate' "$json_report" || true
    fi

    echo ""

    # Export CSV report
    log_info "Exporting CSV report..." "metrics-example"
    csv_report=$(export_metrics_csv)
    log_success "CSV report exported: $csv_report" "metrics-example"

    # Show first few lines of CSV
    if [[ -f "$csv_report" ]]; then
        log_info "CSV preview (first 3 rows):" "metrics-example"
        head -3 "$csv_report"
    fi

    echo ""
}

# ==============================================================================
# ADVANCED EXAMPLE: Percentile Analysis
# ==============================================================================
example_percentile_analysis() {
    log_info "Example 11: Percentile Analysis" "metrics-example"
    echo ""

    log_info "Operation duration percentiles:" "metrics-example"

    for percentile in 50 75 90 95 99; do
        result=$(get_duration_percentile "$percentile" 2>/dev/null)
        if [[ -n "$result" ]]; then
            echo "  P${percentile}: ${result}s"
        fi
    done

    echo ""
}

# ==============================================================================
# ADVANCED EXAMPLE: Outlier Detection
# ==============================================================================
example_outlier_detection() {
    log_info "Example 12: Outlier Detection" "metrics-example"
    echo ""

    log_info "Detecting operations with anomalous durations (>2 std dev):" "metrics-example"

    outliers=$(get_outlier_operations 2 2>/dev/null || echo "[]")

    if [[ "$outliers" != "[]" ]]; then
        echo "$outliers" | jq -r '.[] |
            printf("  %s: %.1fs (%.2f std dev from mean) - Status: %s\n",
                .operation_id,
                .duration_seconds,
                .std_dev_count,
                if .exit_code == 0 then "SUCCESS" else "FAILED" end)' || true
    else
        log_info "No outliers detected" "metrics-example"
    fi

    echo ""
}

# ==============================================================================
# MAIN EXECUTION
# ==============================================================================
main() {
    log_info "Starting Metrics Module Integration Examples" "metrics-example"
    echo "============================================================================"
    echo ""

    # Run all examples
    example_basic_metrics || log_warn "Example 1 failed" "metrics-example"
    example_retrieve_metrics || log_warn "Example 2 failed" "metrics-example"
    example_success_rate || log_warn "Example 3 failed" "metrics-example"
    example_performance_analysis || log_warn "Example 4 failed" "metrics-example"
    example_capability_performance || log_warn "Example 5 failed" "metrics-example"
    example_operation_type_performance || log_warn "Example 6 failed" "metrics-example"
    example_failure_analysis || log_warn "Example 7 failed" "metrics-example"
    example_comprehensive_stats || log_warn "Example 8 failed" "metrics-example"
    example_console_reports || log_warn "Example 9 failed" "metrics-example"
    example_export_reports || log_warn "Example 10 failed" "metrics-example"
    example_percentile_analysis || log_warn "Example 11 failed" "metrics-example"
    example_outlier_detection || log_warn "Example 12 failed" "metrics-example"

    echo "============================================================================"
    log_success "All examples completed" "metrics-example"
}

main "$@"
