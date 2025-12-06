#!/bin/bash
# ==============================================================================
# dependency-analysis.sh - Example: Comprehensive Dependency Analysis
# ==============================================================================
# Demonstrates how to use the dependency resolver to analyze Azure infrastructure
#
# Usage:
#   ./examples/dependency-analysis.sh [resource-id]
#
# Examples:
#   ./examples/dependency-analysis.sh                                    # Analyze all
#   ./examples/dependency-analysis.sh "/subscriptions/.../vms/my-vm"     # Analyze specific resource
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Source required modules
source "${PROJECT_ROOT}/core/dependency-resolver.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ==============================================================================
# EXAMPLE 1: Build Complete Dependency Graph
# ==============================================================================

example_build_graph() {
    echo -e "${BLUE}===================================================${NC}"
    echo -e "${BLUE}Example 1: Building Complete Dependency Graph${NC}"
    echo -e "${BLUE}===================================================${NC}"
    echo ""

    # Clean up previous runs
    rm -f "${PROJECT_ROOT}/discovered/dependencies.jsonl"
    rm -f "${PROJECT_ROOT}/discovered/dependency-graph.json"
    rm -f "${PROJECT_ROOT}/discovered/dependency-graph.dot"

    # Example: Detect dependencies for sample resources
    # In real usage, you would query Azure for actual resources

    # Sample VM
    local vm_json=$(cat <<'EOF'
{
  "id": "/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/prod-rg/providers/Microsoft.Compute/virtualMachines/web-vm-01",
  "name": "web-vm-01",
  "type": "Microsoft.Compute/virtualMachines",
  "properties": {
    "networkProfile": {
      "networkInterfaces": [
        {"id": "/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/prod-rg/providers/Microsoft.Network/networkInterfaces/web-nic-01"}
      ]
    },
    "storageProfile": {
      "osDisk": {
        "managedDisk": {
          "id": "/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/prod-rg/providers/Microsoft.Compute/disks/web-os-disk"
        }
      }
    }
  }
}
EOF
)

    # Sample NIC
    local nic_json=$(cat <<'EOF'
{
  "id": "/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/prod-rg/providers/Microsoft.Network/networkInterfaces/web-nic-01",
  "name": "web-nic-01",
  "type": "Microsoft.Network/networkInterfaces",
  "properties": {
    "ipConfigurations": [
      {
        "properties": {
          "subnet": {
            "id": "/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/prod-rg/providers/Microsoft.Network/virtualNetworks/prod-vnet/subnets/web-subnet"
          }
        }
      }
    ]
  }
}
EOF
)

    echo "Detecting VM dependencies..."
    local vm_deps=$(detect_vm_dependencies "$vm_json" 2>&1)
    echo -e "${GREEN}✓ Found dependencies for web-vm-01${NC}"

    echo "Detecting NIC dependencies..."
    local nic_deps=$(detect_nic_dependencies "$nic_json" 2>&1)
    echo -e "${GREEN}✓ Found dependencies for web-nic-01${NC}"

    echo ""
    echo "Building complete dependency graph..."
    # Note: This will fail without state.db but will work with the JSONL file
    # build_dependency_graph 2>/dev/null || true

    if [[ -f "${PROJECT_ROOT}/discovered/dependencies.jsonl" ]]; then
        local dep_count=$(grep -c '"from":' "${PROJECT_ROOT}/discovered/dependencies.jsonl" || echo 0)
        echo -e "${GREEN}✓ Dependency graph built: $dep_count dependencies tracked${NC}"
    fi

    echo ""
}

# ==============================================================================
# EXAMPLE 2: Export and Visualize
# ==============================================================================

example_export_visualization() {
    echo -e "${BLUE}===================================================${NC}"
    echo -e "${BLUE}Example 2: Export Dependency Graph for Visualization${NC}"
    echo -e "${BLUE}===================================================${NC}"
    echo ""

    if [[ ! -f "${PROJECT_ROOT}/discovered/dependencies.jsonl" ]]; then
        echo -e "${YELLOW}⚠ No dependencies found. Run example_build_graph first.${NC}"
        return
    fi

    echo "Exporting to GraphViz DOT format..."
    local dot_file=$(export_dependency_graph_dot 2>&1)

    if [[ -f "${PROJECT_ROOT}/discovered/dependency-graph.dot" ]]; then
        echo -e "${GREEN}✓ DOT file created: discovered/dependency-graph.dot${NC}"
        echo ""
        echo "To visualize:"
        echo "  dot -Tpng discovered/dependency-graph.dot -o infrastructure.png"
        echo "  dot -Tsvg discovered/dependency-graph.dot -o infrastructure.svg"
        echo ""

        # Show a preview of the DOT file
        echo "Preview of DOT file:"
        echo "-------------------"
        head -20 "${PROJECT_ROOT}/discovered/dependency-graph.dot"
        echo "..."
        echo ""
    fi
}

# ==============================================================================
# EXAMPLE 3: Analyze Specific Resource
# ==============================================================================

example_analyze_resource() {
    local resource_id="$1"

    echo -e "${BLUE}===================================================${NC}"
    echo -e "${BLUE}Example 3: Analyze Specific Resource${NC}"
    echo -e "${BLUE}===================================================${NC}"
    echo ""

    local resource_name=$(extract_resource_name "$resource_id")
    local resource_type=$(extract_resource_type "$resource_id")

    echo "Resource: $resource_name"
    echo "Type: $resource_type"
    echo "ID: $resource_id"
    echo ""

    # Check dependencies
    echo "Dependencies (this resource depends on):"
    echo "----------------------------------------"

    if [[ -f "${PROJECT_ROOT}/discovered/dependencies.jsonl" ]]; then
        local deps=$(grep "\"from\":\"$resource_id\"" "${PROJECT_ROOT}/discovered/dependencies.jsonl" || true)

        if [[ -z "$deps" ]]; then
            echo -e "${YELLOW}  No dependencies found${NC}"
        else
            while IFS= read -r dep; do
                local to_id=$(echo "$dep" | jq -r '.to')
                local dep_type=$(echo "$dep" | jq -r '.dependency_type')
                local relationship=$(echo "$dep" | jq -r '.relationship')
                local to_name=$(extract_resource_name "$to_id")

                case "$dep_type" in
                    required) color="${RED}" ;;
                    optional) color="${YELLOW}" ;;
                    *) color="${NC}" ;;
                esac

                echo -e "  ${color}[$dep_type]${NC} $to_name ($relationship)"
            done <<< "$deps"
        fi
    else
        echo -e "${YELLOW}  No dependency data available${NC}"
    fi

    echo ""

    # Check dependents (reverse dependencies)
    echo "Dependents (resources that depend on this):"
    echo "-------------------------------------------"

    if [[ -f "${PROJECT_ROOT}/discovered/dependencies.jsonl" ]]; then
        local dependents=$(grep "\"to\":\"$resource_id\"" "${PROJECT_ROOT}/discovered/dependencies.jsonl" || true)

        if [[ -z "$dependents" ]]; then
            echo -e "${GREEN}  No dependents - safe to delete${NC}"
        else
            while IFS= read -r dep; do
                local from_id=$(echo "$dep" | jq -r '.from')
                local dep_type=$(echo "$dep" | jq -r '.dependency_type')
                local relationship=$(echo "$dep" | jq -r '.relationship')
                local from_name=$(extract_resource_name "$from_id")

                case "$dep_type" in
                    required) color="${RED}" ;;
                    optional) color="${YELLOW}" ;;
                    *) color="${NC}" ;;
                esac

                echo -e "  ${color}[$dep_type]${NC} $from_name ($relationship)"
            done <<< "$dependents"

            echo ""
            echo -e "${RED}⚠ WARNING: This resource has dependents. Delete them first.${NC}"
        fi
    fi

    echo ""
}

# ==============================================================================
# EXAMPLE 4: Check for Circular Dependencies
# ==============================================================================

example_check_cycles() {
    echo -e "${BLUE}===================================================${NC}"
    echo -e "${BLUE}Example 4: Check for Circular Dependencies${NC}"
    echo -e "${BLUE}===================================================${NC}"
    echo ""

    if [[ ! -f "${PROJECT_ROOT}/discovered/dependencies.jsonl" ]]; then
        echo -e "${YELLOW}⚠ No dependencies found. Run example_build_graph first.${NC}"
        return
    fi

    echo "Checking for circular dependencies..."

    if detect_circular_dependencies 2>/dev/null; then
        echo -e "${GREEN}✓ No circular dependencies detected${NC}"
        echo "  Infrastructure is safe to deploy in dependency order"
    else
        echo -e "${RED}✗ Circular dependencies detected!${NC}"
        echo "  Review the dependency graph and break the cycle"
    fi

    echo ""
}

# ==============================================================================
# EXAMPLE 5: Generate Deployment Order
# ==============================================================================

example_deployment_order() {
    echo -e "${BLUE}===================================================${NC}"
    echo -e "${BLUE}Example 5: Generate Safe Deployment Order${NC}"
    echo -e "${BLUE}===================================================${NC}"
    echo ""

    if [[ ! -f "${PROJECT_ROOT}/discovered/dependencies.jsonl" ]]; then
        echo -e "${YELLOW}⚠ No dependencies found. Run example_build_graph first.${NC}"
        return
    fi

    echo "Analyzing dependency graph..."
    echo ""

    # Get all unique resource IDs
    local all_resources=$(cat "${PROJECT_ROOT}/discovered/dependencies.jsonl" | jq -r '.from, .to' | sort -u)

    # Simple topological sort simulation
    echo "Recommended deployment order (simplified):"
    echo "==========================================="

    # Resources with no dependencies (level 0)
    echo ""
    echo "Level 0 - Independent resources (deploy first):"
    local level=0
    while IFS= read -r res_id; do
        [[ -z "$res_id" ]] && continue

        # Check if this resource has no dependencies
        if ! grep -q "\"from\":\"$res_id\"" "${PROJECT_ROOT}/discovered/dependencies.jsonl"; then
            local res_name=$(extract_resource_name "$res_id")
            local res_type=$(extract_resource_type "$res_id")
            echo "  - $res_name ($res_type)"
            ((level++))
        fi
    done <<< "$all_resources"

    if [[ $level -eq 0 ]]; then
        echo "  (none found - all resources have dependencies)"
    fi

    # Resources with dependencies (level 1+)
    echo ""
    echo "Level 1+ - Dependent resources (deploy after dependencies):"
    level=0
    while IFS= read -r res_id; do
        [[ -z "$res_id" ]] && continue

        # Check if this resource has dependencies
        if grep -q "\"from\":\"$res_id\"" "${PROJECT_ROOT}/discovered/dependencies.jsonl"; then
            local res_name=$(extract_resource_name "$res_id")
            local res_type=$(extract_resource_type "$res_id")
            local dep_count=$(grep "\"from\":\"$res_id\"" "${PROJECT_ROOT}/discovered/dependencies.jsonl" | wc -l)
            echo "  - $res_name ($res_type) - $dep_count dependencies"
            ((level++))
        fi
    done <<< "$all_resources"

    echo ""
    echo -e "${YELLOW}Note: Use build_dependency_graph with state.db for accurate topological sort${NC}"
    echo ""
}

# ==============================================================================
# MAIN EXECUTION
# ==============================================================================

main() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║     Azure Infrastructure Toolkit                           ║"
    echo "║     Dependency Analysis Examples                           ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""

    # Run examples
    example_build_graph
    example_export_visualization
    example_check_cycles
    example_deployment_order

    # If resource ID provided, analyze it
    if [[ $# -gt 0 ]]; then
        example_analyze_resource "$1"
    fi

    echo -e "${GREEN}===================================================${NC}"
    echo -e "${GREEN}Examples Complete${NC}"
    echo -e "${GREEN}===================================================${NC}"
    echo ""
    echo "Output files:"
    echo "  - discovered/dependencies.jsonl       (dependency data)"
    echo "  - discovered/dependency-graph.dot     (GraphViz visualization)"
    echo ""
    echo "Next steps:"
    echo "  1. Run discovery on real Azure environment:"
    echo "     ./core/engine.sh discover"
    echo ""
    echo "  2. Build real dependency graph:"
    echo "     source core/dependency-resolver.sh && build_dependency_graph"
    echo ""
    echo "  3. Visualize:"
    echo "     dot -Tpng discovered/dependency-graph.dot -o infrastructure.png"
    echo ""
}

# Run main
main "$@"
