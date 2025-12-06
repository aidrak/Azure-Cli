#!/bin/bash
# ==============================================================================
# Discovery Engine - Example Usage
# ==============================================================================
#
# This script demonstrates how to use the discovery engine to scan Azure
# infrastructure and build dependency graphs.
#
# Usage:
#   ./examples/discovery-example.sh
#
# ==============================================================================

set -euo pipefail

# Get project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

# Source discovery engine
source core/discovery.sh

# ==============================================================================
# Example 1: Discover a Resource Group
# ==============================================================================
example_1_resource_group_discovery() {
    echo ""
    echo "========================================================================"
    echo "Example 1: Resource Group Discovery"
    echo "========================================================================"
    echo ""

    # Replace with your resource group name
    local resource_group="RG-Azure-VDI-01"

    echo "This will discover all resources in resource group: $resource_group"
    echo ""
    read -p "Press Enter to continue (or Ctrl+C to cancel)..."

    # Run discovery
    discover_resource_group "$resource_group"

    echo ""
    echo "Discovery complete! Check these files:"
    echo "  - discovered/inventory-summary.yaml"
    echo "  - discovered/inventory-full.json"
    echo "  - discovered/dependency-graph.dot"
    echo "  - state.db"
    echo ""
}

# ==============================================================================
# Example 2: Query Discovered Resources
# ==============================================================================
example_2_query_resources() {
    echo ""
    echo "========================================================================"
    echo "Example 2: Query Discovered Resources"
    echo "========================================================================"
    echo ""

    # Check if state.db exists
    if [[ ! -f "state.db" ]]; then
        echo "ERROR: state.db not found. Run discovery first (Example 1)."
        return 1
    fi

    echo "Querying resources from state database..."
    echo ""

    # Query 1: Resource counts by type
    echo "Resource Counts by Type:"
    echo "------------------------"
    sqlite3 state.db <<'EOF'
SELECT
    resource_type,
    COUNT(*) as count,
    SUM(CASE WHEN managed_by_toolkit = 1 THEN 1 ELSE 0 END) as managed
FROM resources
WHERE deleted_at IS NULL
GROUP BY resource_type
ORDER BY count DESC;
EOF

    echo ""

    # Query 2: Recent discoveries
    echo "Recent Discoveries:"
    echo "-------------------"
    sqlite3 state.db <<'EOF'
SELECT
    name,
    resource_type,
    datetime(discovered_at, 'unixepoch') as discovered
FROM resources
WHERE deleted_at IS NULL
ORDER BY discovered_at DESC
LIMIT 10;
EOF

    echo ""

    # Query 3: Dependency statistics
    echo "Dependency Statistics:"
    echo "----------------------"
    sqlite3 state.db <<'EOF'
SELECT
    'Total Dependencies' as metric,
    COUNT(*) as count
FROM dependencies

UNION ALL

SELECT
    'Required Dependencies',
    COUNT(*)
FROM dependencies
WHERE dependency_type = 'required'

UNION ALL

SELECT
    'Optional Dependencies',
    COUNT(*)
FROM dependencies
WHERE dependency_type = 'optional';
EOF

    echo ""
}

# ==============================================================================
# Example 3: View Inventory Summary
# ==============================================================================
example_3_view_summary() {
    echo ""
    echo "========================================================================"
    echo "Example 3: View Inventory Summary"
    echo "========================================================================"
    echo ""

    if [[ ! -f "discovered/inventory-summary.yaml" ]]; then
        echo "ERROR: inventory-summary.yaml not found. Run discovery first."
        return 1
    fi

    echo "Inventory Summary:"
    echo "------------------"
    cat discovered/inventory-summary.yaml
    echo ""
}

# ==============================================================================
# Example 4: Visualize Dependency Graph
# ==============================================================================
example_4_visualize_graph() {
    echo ""
    echo "========================================================================"
    echo "Example 4: Visualize Dependency Graph"
    echo "========================================================================"
    echo ""

    if [[ ! -f "discovered/dependency-graph.dot" ]]; then
        echo "ERROR: dependency-graph.dot not found. Run discovery first."
        return 1
    fi

    echo "Dependency graph available at: discovered/dependency-graph.dot"
    echo ""

    # Check if graphviz is installed
    if command -v dot &>/dev/null; then
        echo "Graphviz detected! Converting to PNG..."
        dot -Tpng discovered/dependency-graph.dot -o discovered/dependency-graph.png
        echo "Graph exported to: discovered/dependency-graph.png"
    else
        echo "Install Graphviz to convert DOT to PNG:"
        echo "  Ubuntu: sudo apt-get install graphviz"
        echo "  macOS:  brew install graphviz"
        echo ""
        echo "Then run: dot -Tpng discovered/dependency-graph.dot -o dependency-graph.png"
    fi

    echo ""
}

# ==============================================================================
# Example 5: Incremental Discovery (Rediscovery)
# ==============================================================================
example_5_rediscovery() {
    echo ""
    echo "========================================================================"
    echo "Example 5: Incremental Discovery (Rediscovery)"
    echo "========================================================================"
    echo ""

    local resource_group="RG-Azure-VDI-01"

    echo "This will invalidate cache and re-discover resources."
    echo "Resource Group: $resource_group"
    echo ""
    read -p "Press Enter to continue (or Ctrl+C to cancel)..."

    # Run rediscovery (invalidates cache first)
    rediscover "resource-group" "$resource_group"

    echo ""
    echo "Rediscovery complete!"
    echo ""
}

# ==============================================================================
# Example 6: Custom Discovery Workflow
# ==============================================================================
example_6_custom_workflow() {
    echo ""
    echo "========================================================================"
    echo "Example 6: Custom Discovery Workflow"
    echo "========================================================================"
    echo ""

    local resource_group="RG-Azure-VDI-01"

    echo "This demonstrates a custom discovery workflow:"
    echo "  1. Initialize state database"
    echo "  2. Discover specific resource types only"
    echo "  3. Build dependency graph"
    echo "  4. Generate custom output"
    echo ""
    read -p "Press Enter to continue (or Ctrl+C to cancel)..."

    # Step 1: Initialize
    echo ""
    echo "[1/4] Initializing state database..."
    init_state_db

    # Step 2: Discover specific types
    echo ""
    echo "[2/4] Discovering specific resource types..."
    local vm_count=$(discover_compute_resources "resource-group" "$resource_group")
    echo "  Discovered $vm_count compute resources"

    local net_count=$(discover_networking_resources "resource-group" "$resource_group")
    echo "  Discovered $net_count networking resources"

    # Step 3: Build dependency graph
    echo ""
    echo "[3/4] Building dependency graph..."
    build_discovery_graph

    # Step 4: Custom output
    echo ""
    echo "[4/4] Generating custom output..."
    sqlite3 state.db -json <<'EOF' > discovered/custom-vm-report.json
SELECT
    name,
    location,
    provisioning_state,
    datetime(discovered_at, 'unixepoch') as discovered_at
FROM resources
WHERE resource_type LIKE '%virtualMachines%'
AND deleted_at IS NULL
ORDER BY name;
EOF

    echo "Custom VM report saved to: discovered/custom-vm-report.json"
    echo ""
    echo "Custom workflow complete!"
    echo ""
}

# ==============================================================================
# Main Menu
# ==============================================================================
show_menu() {
    echo ""
    echo "========================================================================"
    echo "  Azure Infrastructure Toolkit - Discovery Engine Examples"
    echo "========================================================================"
    echo ""
    echo "Choose an example to run:"
    echo ""
    echo "  1. Resource Group Discovery"
    echo "  2. Query Discovered Resources"
    echo "  3. View Inventory Summary"
    echo "  4. Visualize Dependency Graph"
    echo "  5. Incremental Discovery (Rediscovery)"
    echo "  6. Custom Discovery Workflow"
    echo ""
    echo "  0. Exit"
    echo ""
    read -p "Enter your choice [0-6]: " choice

    case "$choice" in
        1) example_1_resource_group_discovery ;;
        2) example_2_query_resources ;;
        3) example_3_view_summary ;;
        4) example_4_visualize_graph ;;
        5) example_5_rediscovery ;;
        6) example_6_custom_workflow ;;
        0) echo "Exiting..."; exit 0 ;;
        *) echo "Invalid choice. Please try again." ;;
    esac

    # Show menu again
    show_menu
}

# ==============================================================================
# Entry Point
# ==============================================================================

# Check prerequisites
if ! command -v az &>/dev/null; then
    echo "ERROR: Azure CLI not found. Please install Azure CLI first."
    exit 1
fi

if ! command -v sqlite3 &>/dev/null; then
    echo "ERROR: sqlite3 not found. Please install sqlite3 first."
    exit 1
fi

if ! command -v jq &>/dev/null; then
    echo "ERROR: jq not found. Please install jq first."
    exit 1
fi

# Check Azure authentication
if ! az account show &>/dev/null; then
    echo "ERROR: Not logged in to Azure. Please run: az login"
    exit 1
fi

# Show menu
show_menu
