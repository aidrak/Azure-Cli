source core/dependency-resolver.sh

validate_all_dependencies() {
    local failed=0

    # Get all resources
    for resource_id in $(get_all_resource_ids); do
        if ! validate_dependencies "$resource_id"; then
            echo "ERROR: Missing dependencies for $resource_id"
            ((failed++))
        fi
    done

    return $failed
}

if validate_all_dependencies; then
    echo "Pre-flight check passed - ready to deploy"
    ./deploy.sh
else
    echo "Pre-flight check failed - fix dependencies first"
    exit 1
fi
```

### Deletion Order Planning

```bash
#!/bin/bash
# Plan safe deletion order (reverse dependency order)

source core/dependency-resolver.sh

plan_deletion() {
    local resource_id="$1"

    # Get all dependents (things that depend on this)
    dependents=$(get_dependents "$resource_id")

    if [[ -n "$dependents" ]]; then
        echo "WARNING: The following resources depend on this:"
        echo "$dependents" | jq -r '.[] | "  - \(.name) (\(.resource_type))"'
        echo ""
        echo "Delete these resources first, or use --force to break dependencies"
        return 1
    fi

    return 0
}

# Example: Check if safe to delete a VNet
if plan_deletion "/subscriptions/.../virtualNetworks/my-vnet"; then
    echo "Safe to delete VNet"
else
    echo "Cannot safely delete VNet"
fi
```

### Change Impact Analysis

```bash
#!/bin/bash
# Analyze what will be affected by changes to a resource

source core/dependency-resolver.sh

analyze_impact() {
    local resource_id="$1"

    echo "Impact Analysis for: $(extract_resource_name "$resource_id")"
    echo "========================================"

    # Direct dependencies
    echo "This resource depends on:"
    get_dependencies "$resource_id" | jq -r '.[] | "  - \(.name) (\(.dependency_type))"'

    echo ""

    # Dependents (reverse dependencies)
    echo "These resources depend on this:"
    get_dependents "$resource_id" | jq -r '.[] | "  - \(.name) (\(.dependency_type))"'

    echo ""

    # Full transitive tree
    echo "Full dependency tree (depth 3):"
    get_dependency_tree "$resource_id" 3 | jq -r '.[] | "  \(.depth)) \(.depends_on_name) (\(.dependency_type))"'
}

# Example: Analyze impact of changing a subnet
analyze_impact "/subscriptions/.../subnets/default"
```

## Best Practices

### 1. Run Discovery First

Always run full discovery before building dependency graphs:

```bash
./core/engine.sh discover
./core/engine.sh build-dependencies
```

### 2. Validate Periodically

Dependencies can become stale if resources change. Revalidate regularly:

```bash
# Validate all dependencies
for resource_id in $(get_all_resource_ids); do
    validate_dependencies "$resource_id"
done
```

### 3. Check for Cycles

Before deployment, always check for circular dependencies:

```bash
if ! detect_circular_dependencies; then
    echo "Fix circular dependencies before deploying"
    exit 1
fi
```

### 4. Use Relationship Types

When adding custom dependencies, choose the correct type and relationship:

```bash
# Required dependency - VM needs NIC
add_dependency "$vm_id" "$nic_id" "required" "uses"

# Optional dependency - VM can have availability set
add_dependency "$vm_id" "$avset_id" "optional" "references"

# Reference - Workspace references application groups
add_dependency "$workspace_id" "$appgroup_id" "reference" "references"
```

### 5. Visualize Complex Environments

For large environments, generate visual dependency graphs:

```bash
# Generate graph
export_dependency_graph_dot

# Render high-quality PNG
dot -Tpng -Gdpi=300 discovered/dependency-graph.dot -o infrastructure-hq.png

# Or generate interactive SVG
dot -Tsvg discovered/dependency-graph.dot -o infrastructure.svg
```

## Troubleshooting

### Dependencies Not Detected

**Problem:** Dependencies aren't being detected for a resource type.

**Solution:** Check if the resource type has a detector function. Add one in `dependency-resolver.sh`:

```bash
detect_myresource_dependencies() {
    local resource_json="$1"
    local resource_id="${2:-$(echo "$resource_json" | jq -r '.id')}"

    # Extract dependency IDs from JSON
    local dep_id=$(echo "$resource_json" | jq -r '.properties.dependencyId')

    # Add dependency
    add_dependency "$resource_id" "$dep_id" "required" "uses"

    echo "1"  # Return count
}
```

### Circular Dependencies Detected

**Problem:** Deployment fails due to circular dependencies.

**Solution:** Identify the cycle and break it:

```bash
# Find the cycle
detect_circular_dependencies

# Check the specific resources involved
# Usually this indicates a design issue - refactor to remove the cycle
```

### Missing Dependencies File

**Problem:** `discovered/dependencies.jsonl` doesn't exist.

**Solution:** Run dependency detection:

```bash
# Ensure discovery has run
./core/engine.sh discover

# Build dependencies
build_dependency_graph
```

## Performance Considerations

### Caching

Dependency resolution can be slow for large environments. Use caching:

```bash
# Cache dependency graph
if [[ ! -f discovered/dependency-graph.json ]] || [[ $(find discovered/dependency-graph.json -mmin +60) ]]; then
    echo "Rebuilding dependency graph (cache expired)..."
    build_dependency_graph
else
    echo "Using cached dependency graph"
fi
```

### Parallel Detection

For large environments, detect dependencies in parallel:

```bash
# Get all resources
resources=$(az resource list)

# Detect in parallel
echo "$resources" | jq -c '.[]' | parallel -j 8 'detect_resource_dependencies "{}"'
```

## API Reference

See the function documentation in `core/dependency-resolver.sh` for detailed API reference.

### Core Functions

| Function | Purpose |
|----------|---------|
| `detect_vm_dependencies` | Detect VM dependencies |
| `detect_nic_dependencies` | Detect NIC dependencies |
| `detect_vnet_dependencies` | Detect VNet dependencies |
| `detect_storage_dependencies` | Detect Storage Account dependencies |
| `detect_resource_dependencies` | Generic dependency detection |
| `build_dependency_graph` | Build complete graph |
| `export_dependency_graph_dot` | Export to GraphViz |
| `validate_dependencies` | Validate dependencies exist |
| `detect_circular_dependencies` | Find cycles |
| `get_dependency_tree` | Get recursive tree |
| `get_dependency_path` | Find shortest path |
| `get_root_resources` | Get entry points |
| `get_leaf_resources` | Get endpoints |

## Future Enhancements

- **Cost analysis** - Calculate cost impact of dependency changes
- **Security analysis** - Detect security boundaries in dependency graph
- **Compliance** - Validate compliance rules across dependency chains
- **Auto-fix** - Automatically resolve missing dependencies
- **Drift detection** - Detect when dependencies have drifted from expected state
