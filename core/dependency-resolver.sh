#!/bin/bash
# ==============================================================================
# dependency-resolver.sh - Resource Dependency Graph Builder
# ==============================================================================
# Build and analyze Directed Acyclic Graphs (DAG) of Azure resource dependencies
#
# Features:
# - Detect dependencies from Azure resource JSON
# - Build complete dependency graphs
# - Validate dependencies exist in Azure
# - Detect circular dependency cycles
# - Query dependency trees and paths
# - Export to GraphViz DOT format
#
# Usage:
#   source core/dependency-resolver.sh
#   detect_vm_dependencies "$vm_json"
#   build_dependency_graph
#   validate_dependencies "$resource_id"
# ==============================================================================

set -uo pipefail

# Source required modules
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Dependency resolver will need state-manager when it exists
# For now, we'll implement core functionality with fallback

# ==============================================================================
# UTILITY FUNCTIONS
# ==============================================================================

# Extract resource type from resource ID
# Args: resource_id
extract_resource_type() {
    local resource_id="$1"

    if [[ ! "$resource_id" =~ /providers/([^/]+/[^/]+)/ ]]; then
        echo "UNKNOWN"
        return 1
    fi

    echo "${BASH_REMATCH[1]}"
}

# Extract resource name from resource ID
# Args: resource_id
extract_resource_name() {
    local resource_id="$1"

    # Resource ID format: /subscriptions/{sub}/resourceGroups/{rg}/providers/{type}/{name}
    # Get the last segment
    echo "${resource_id##*/}"
}

# Extract resource group from resource ID
# Args: resource_id
extract_resource_group() {
    local resource_id="$1"

    if [[ ! "$resource_id" =~ /resourceGroups/([^/]+)/ ]]; then
        echo ""
        return 1
    fi

    echo "${BASH_REMATCH[1]}"
}

# Validate resource ID format
# Args: resource_id
validate_resource_id() {
    local resource_id="$1"

    if [[ ! "$resource_id" =~ ^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/[^/]+/ ]]; then
        return 1
    fi

    return 0
}

# Log dependency detection
# Args: from_resource_id, to_resource_id, relationship_type, relationship
log_dependency() {
    local from_id="$1"
    local to_id="$2"
    local dep_type="$3"
    local relationship="$4"

    local from_name=$(extract_resource_name "$from_id")
    local to_name=$(extract_resource_name "$to_id")

    if command -v log_info &>/dev/null; then
        log_info "Dependency: $from_name → $to_name [$dep_type/$relationship]" "dependency-resolver"
    else
        # Log to stderr so it doesn't interfere with function return values
        echo "[DEPENDENCY] $from_name → $to_name [$dep_type/$relationship]" >&2
    fi
}

# Add dependency to state database
# Args: from_resource_id, to_resource_id, dependency_type, relationship
add_dependency() {
    local from_id="$1"
    local to_id="$2"
    local dep_type="${3:-required}"
    local relationship="${4:-uses}"

    # Validate both resource IDs
    if ! validate_resource_id "$from_id"; then
        echo "ERROR: Invalid source resource ID: $from_id" >&2
        return 1
    fi

    if ! validate_resource_id "$to_id"; then
        echo "ERROR: Invalid target resource ID: $to_id" >&2
        return 1
    fi

    # Log the dependency
    log_dependency "$from_id" "$to_id" "$dep_type" "$relationship"

    # If state-manager is available, use it
    if command -v add_dependency &>/dev/null && [[ -n "${STATE_DB:-}" ]]; then
        # Call state-manager's add_dependency (different signature)
        # state-manager: add_dependency resource_id depends_on_id dependency_type relationship
        command add_dependency "$from_id" "$to_id" "$dep_type" "$relationship"
    else
        # Fallback: store in temporary file for testing
        local dep_file="${PROJECT_ROOT}/discovered/dependencies.jsonl"
        mkdir -p "${PROJECT_ROOT}/discovered"

        local now=$(date +%s)
        local dep_json=$(cat <<EOF
{
  "from": "$from_id",
  "to": "$to_id",
  "dependency_type": "$dep_type",
  "relationship": "$relationship",
  "discovered_at": $now
}
EOF
)
        echo "$dep_json" >> "$dep_file"
    fi
}

# ==============================================================================
# VM DEPENDENCY DETECTION
# ==============================================================================

# Detect all dependencies for a Virtual Machine
# Args: vm_json, vm_resource_id
# Returns: count of dependencies (to stdout, logs to stderr)
detect_vm_dependencies() {
    local vm_json="$1"
    local vm_id="${2:-$(echo "$vm_json" | jq -r '.id')}"

    if ! validate_resource_id "$vm_id"; then
        echo "ERROR: Invalid VM resource ID" >&2
        return 1
    fi

    local dep_count=0

    # 1. Network Interfaces (REQUIRED)
    local nic_ids=$(echo "$vm_json" | jq -r '.properties.networkProfile.networkInterfaces[]?.id // empty')
    while IFS= read -r nic_id; do
        [[ -z "$nic_id" || "$nic_id" == "null" ]] && continue
        add_dependency "$vm_id" "$nic_id" "required" "uses"
        ((dep_count++))
    done <<< "$nic_ids"

    # 2. OS Disk (REQUIRED)
    local os_disk_id=$(echo "$vm_json" | jq -r '.properties.storageProfile.osDisk.managedDisk.id // empty')
    if [[ -n "$os_disk_id" && "$os_disk_id" != "null" ]]; then
        add_dependency "$vm_id" "$os_disk_id" "required" "uses"
        ((dep_count++))
    fi

    # 3. Data Disks (REQUIRED)
    local data_disk_ids=$(echo "$vm_json" | jq -r '.properties.storageProfile.dataDisks[]?.managedDisk.id // empty')
    while IFS= read -r disk_id; do
        [[ -z "$disk_id" || "$disk_id" == "null" ]] && continue
        add_dependency "$vm_id" "$disk_id" "required" "uses"
        ((dep_count++))
    done <<< "$data_disk_ids"

    # 4. Availability Set (OPTIONAL)
    local avset_id=$(echo "$vm_json" | jq -r '.properties.availabilitySet.id // empty')
    if [[ -n "$avset_id" && "$avset_id" != "null" ]]; then
        add_dependency "$vm_id" "$avset_id" "optional" "references"
        ((dep_count++))
    fi

    # 5. Image Reference (REFERENCE)
    local image_id=$(echo "$vm_json" | jq -r '.properties.storageProfile.imageReference.id // empty')
    if [[ -n "$image_id" && "$image_id" != "null" ]]; then
        add_dependency "$vm_id" "$image_id" "reference" "uses"
        ((dep_count++))
    fi

    # 6. Diagnostics Storage Account (OPTIONAL)
    local diag_storage=$(echo "$vm_json" | jq -r '.properties.diagnosticsProfile.bootDiagnostics.storageUri // empty')
    if [[ -n "$diag_storage" && "$diag_storage" != "null" ]]; then
        # Extract storage account name from URI
        if [[ "$diag_storage" =~ https://([^.]+)\.blob\.core\.windows\.net ]]; then
            local storage_name="${BASH_REMATCH[1]}"
            local rg=$(extract_resource_group "$vm_id")
            local sub_id=$(echo "$vm_id" | grep -oP '(?<=subscriptions/)[^/]+')
            local storage_id="/subscriptions/${sub_id}/resourceGroups/${rg}/providers/Microsoft.Storage/storageAccounts/${storage_name}"
            add_dependency "$vm_id" "$storage_id" "optional" "uses"
            ((dep_count++))
        fi
    fi

    # 7. VM Extensions (CONTAINS)
    local ext_ids=$(echo "$vm_json" | jq -r '.resources[]? | select(.type == "Microsoft.Compute/virtualMachines/extensions") | .id // empty')
    while IFS= read -r ext_id; do
        [[ -z "$ext_id" || "$ext_id" == "null" ]] && continue
        add_dependency "$vm_id" "$ext_id" "optional" "contains"
        ((dep_count++))
    done <<< "$ext_ids"

    echo "$dep_count"
}

# ==============================================================================
# NETWORK INTERFACE DEPENDENCY DETECTION
# ==============================================================================

# Detect all dependencies for a Network Interface
# Args: nic_json, nic_resource_id
detect_nic_dependencies() {
    local nic_json="$1"
    local nic_id="${2:-$(echo "$nic_json" | jq -r '.id')}"

    if ! validate_resource_id "$nic_id"; then
        echo "ERROR: Invalid NIC resource ID" >&2
        return 1
    fi

    local dep_count=0

    # 1. Subnet (REQUIRED)
    local subnet_id=$(echo "$nic_json" | jq -r '.properties.ipConfigurations[0].properties.subnet.id // empty')
    if [[ -n "$subnet_id" && "$subnet_id" != "null" ]]; then
        add_dependency "$nic_id" "$subnet_id" "required" "uses"
        ((dep_count++))

        # Extract VNet from subnet ID
        local vnet_id="${subnet_id%/subnets/*}"
        if validate_resource_id "$vnet_id"; then
            add_dependency "$nic_id" "$vnet_id" "required" "uses"
            ((dep_count++))
        fi
    fi

    # 2. Network Security Group (OPTIONAL)
    local nsg_id=$(echo "$nic_json" | jq -r '.properties.networkSecurityGroup.id // empty')
    if [[ -n "$nsg_id" && "$nsg_id" != "null" ]]; then
        add_dependency "$nic_id" "$nsg_id" "optional" "references"
        ((dep_count++))
    fi

    # 3. Public IP Address (OPTIONAL)
    local pip_id=$(echo "$nic_json" | jq -r '.properties.ipConfigurations[0].properties.publicIPAddress.id // empty')
    if [[ -n "$pip_id" && "$pip_id" != "null" ]]; then
        add_dependency "$nic_id" "$pip_id" "optional" "uses"
        ((dep_count++))
    fi

    # 4. Load Balancer Backend Pools (OPTIONAL)
    local lb_pool_ids=$(echo "$nic_json" | jq -r '.properties.ipConfigurations[].properties.loadBalancerBackendAddressPools[]?.id // empty')
    while IFS= read -r pool_id; do
        [[ -z "$pool_id" || "$pool_id" == "null" ]] && continue
        # Extract load balancer ID from pool ID
        local lb_id="${pool_id%/backendAddressPools/*}"
        if validate_resource_id "$lb_id"; then
            add_dependency "$nic_id" "$lb_id" "optional" "references"
            ((dep_count++))
        fi
    done <<< "$lb_pool_ids"

    # 5. Application Security Groups (OPTIONAL)
    local asg_ids=$(echo "$nic_json" | jq -r '.properties.ipConfigurations[].properties.applicationSecurityGroups[]?.id // empty')
    while IFS= read -r asg_id; do
        [[ -z "$asg_id" || "$asg_id" == "null" ]] && continue
        add_dependency "$nic_id" "$asg_id" "optional" "references"
        ((dep_count++))
    done <<< "$asg_ids"

    echo "$dep_count"
}

# ==============================================================================
# VNET DEPENDENCY DETECTION
# ==============================================================================

# Detect all dependencies for a Virtual Network
# Args: vnet_json, vnet_resource_id
detect_vnet_dependencies() {
    local vnet_json="$1"
    local vnet_id="${2:-$(echo "$vnet_json" | jq -r '.id')}"

    if ! validate_resource_id "$vnet_id"; then
        echo "ERROR: Invalid VNet resource ID" >&2
        return 1
    fi

    local dep_count=0

    # 1. Subnets (CONTAINS)
    local subnet_ids=$(echo "$vnet_json" | jq -r '.properties.subnets[]?.id // empty')
    while IFS= read -r subnet_id; do
        [[ -z "$subnet_id" || "$subnet_id" == "null" ]] && continue
        add_dependency "$vnet_id" "$subnet_id" "required" "contains"
        ((dep_count++))

        # 2. NSG attached to subnet (REFERENCE)
        local subnet_json=$(echo "$vnet_json" | jq --arg sid "$subnet_id" '.properties.subnets[] | select(.id == $sid)')
        local nsg_id=$(echo "$subnet_json" | jq -r '.properties.networkSecurityGroup.id // empty')
        if [[ -n "$nsg_id" && "$nsg_id" != "null" ]]; then
            add_dependency "$subnet_id" "$nsg_id" "optional" "references"
            ((dep_count++))
        fi

        # 3. Route table attached to subnet (REFERENCE)
        local rt_id=$(echo "$subnet_json" | jq -r '.properties.routeTable.id // empty')
        if [[ -n "$rt_id" && "$rt_id" != "null" ]]; then
            add_dependency "$subnet_id" "$rt_id" "optional" "references"
            ((dep_count++))
        fi
    done <<< "$subnet_ids"

    # 4. VNet Peerings (REFERENCE)
    local peering_ids=$(echo "$vnet_json" | jq -r '.properties.virtualNetworkPeerings[]?.remoteVirtualNetwork.id // empty')
    while IFS= read -r peer_vnet_id; do
        [[ -z "$peer_vnet_id" || "$peer_vnet_id" == "null" ]] && continue
        add_dependency "$vnet_id" "$peer_vnet_id" "reference" "peers-with"
        ((dep_count++))
    done <<< "$peering_ids"

    # 5. DDoS Protection Plan (OPTIONAL)
    local ddos_id=$(echo "$vnet_json" | jq -r '.properties.ddosProtectionPlan.id // empty')
    if [[ -n "$ddos_id" && "$ddos_id" != "null" ]]; then
        add_dependency "$vnet_id" "$ddos_id" "optional" "references"
        ((dep_count++))
    fi

    echo "$dep_count"
}

# ==============================================================================
# STORAGE DEPENDENCY DETECTION
# ==============================================================================

# Detect all dependencies for a Storage Account
# Args: storage_json, storage_resource_id
detect_storage_dependencies() {
    local storage_json="$1"
    local storage_id="${2:-$(echo "$storage_json" | jq -r '.id')}"

    if ! validate_resource_id "$storage_id"; then
        echo "ERROR: Invalid Storage Account resource ID" >&2
        return 1
    fi

    local dep_count=0

    # 1. Private Endpoints (REFERENCE)
    local pe_ids=$(echo "$storage_json" | jq -r '.properties.privateEndpointConnections[]?.privateEndpoint.id // empty')
    while IFS= read -r pe_id; do
        [[ -z "$pe_id" || "$pe_id" == "null" ]] && continue
        add_dependency "$storage_id" "$pe_id" "optional" "references"
        ((dep_count++))
    done <<< "$pe_ids"

    # 2. VNet Rules (REFERENCE)
    local vnet_ids=$(echo "$storage_json" | jq -r '.properties.networkAcls.virtualNetworkRules[]?.id // empty')
    while IFS= read -r vnet_rule_id; do
        [[ -z "$vnet_rule_id" || "$vnet_rule_id" == "null" ]] && continue
        # VNet rule ID is actually subnet ID
        local subnet_id="$vnet_rule_id"
        add_dependency "$storage_id" "$subnet_id" "optional" "references"
        ((dep_count++))

        # Also add VNet
        local vnet_id="${subnet_id%/subnets/*}"
        if validate_resource_id "$vnet_id"; then
            add_dependency "$storage_id" "$vnet_id" "optional" "references"
            ((dep_count++))
        fi
    done <<< "$vnet_ids"

    # 3. Encryption Key Vault (OPTIONAL)
    local kv_uri=$(echo "$storage_json" | jq -r '.properties.encryption.keyVaultProperties.keyVaultUri // empty')
    if [[ -n "$kv_uri" && "$kv_uri" != "null" ]]; then
        # Extract Key Vault name from URI
        if [[ "$kv_uri" =~ https://([^.]+)\.vault\.azure\.net ]]; then
            local kv_name="${BASH_REMATCH[1]}"
            local rg=$(extract_resource_group "$storage_id")
            local sub_id=$(echo "$storage_id" | grep -oP '(?<=subscriptions/)[^/]+')
            local kv_id="/subscriptions/${sub_id}/resourceGroups/${rg}/providers/Microsoft.KeyVault/vaults/${kv_name}"
            add_dependency "$storage_id" "$kv_id" "optional" "uses"
            ((dep_count++))
        fi
    fi

    echo "$dep_count"
}

# ==============================================================================
# AVD DEPENDENCY DETECTION
# ==============================================================================

# Detect all dependencies for an AVD Host Pool
# Args: hostpool_json, hostpool_resource_id
detect_hostpool_dependencies() {
    local hp_json="$1"
    local hp_id="${2:-$(echo "$hp_json" | jq -r '.id')}"

    if ! validate_resource_id "$hp_id"; then
        echo "ERROR: Invalid Host Pool resource ID" >&2
        return 1
    fi

    local dep_count=0

    # 1. Application Groups (REFERENCE)
    # Note: Application groups reference host pools, so this is reverse dependency
    # We'll handle this when processing application groups

    # 2. Session Hosts (VMs) - These are separate resources
    # Format: hostpool-name/session-host-name
    # These are detected via VM naming convention or tags

    # 3. VNet for session hosts (REFERENCE)
    # This is indirect - session hosts are in subnets

    echo "$dep_count"
}

# Detect all dependencies for an AVD Application Group
# Args: appgroup_json, appgroup_resource_id
detect_appgroup_dependencies() {
    local ag_json="$1"
    local ag_id="${2:-$(echo "$ag_json" | jq -r '.id')}"

    if ! validate_resource_id "$ag_id"; then
        echo "ERROR: Invalid Application Group resource ID" >&2
        return 1
    fi

    local dep_count=0

    # 1. Host Pool (REQUIRED)
    local hp_id=$(echo "$ag_json" | jq -r '.properties.hostPoolArmPath // empty')
    if [[ -n "$hp_id" && "$hp_id" != "null" ]]; then
        add_dependency "$ag_id" "$hp_id" "required" "references"
        ((dep_count++))
    fi

    echo "$dep_count"
}

# Detect all dependencies for an AVD Workspace
# Args: workspace_json, workspace_resource_id
detect_workspace_dependencies() {
    local ws_json="$1"
    local ws_id="${2:-$(echo "$ws_json" | jq -r '.id')}"

    if ! validate_resource_id "$ws_id"; then
        echo "ERROR: Invalid Workspace resource ID" >&2
        return 1
    fi

    local dep_count=0

    # 1. Application Groups (REFERENCE)
    local ag_ids=$(echo "$ws_json" | jq -r '.properties.applicationGroupReferences[]? // empty')
    while IFS= read -r ag_id; do
        [[ -z "$ag_id" || "$ag_id" == "null" ]] && continue
        add_dependency "$ws_id" "$ag_id" "reference" "references"
        ((dep_count++))
    done <<< "$ag_ids"

    echo "$dep_count"
}

# ==============================================================================
# GENERIC RESOURCE DEPENDENCY DETECTION
# ==============================================================================

# Detect dependencies for any resource type
# Args: resource_json
detect_resource_dependencies() {
    local resource_json="$1"

    local resource_id=$(echo "$resource_json" | jq -r '.id')
    local resource_type=$(echo "$resource_json" | jq -r '.type')

    if ! validate_resource_id "$resource_id"; then
        echo "ERROR: Invalid resource ID" >&2
        return 1
    fi

    local dep_count=0

    # Route to specific detector based on type
    case "$resource_type" in
        Microsoft.Compute/virtualMachines)
            dep_count=$(detect_vm_dependencies "$resource_json" "$resource_id")
            ;;
        Microsoft.Network/networkInterfaces)
            dep_count=$(detect_nic_dependencies "$resource_json" "$resource_id")
            ;;
        Microsoft.Network/virtualNetworks)
            dep_count=$(detect_vnet_dependencies "$resource_json" "$resource_id")
            ;;
        Microsoft.Storage/storageAccounts)
            dep_count=$(detect_storage_dependencies "$resource_json" "$resource_id")
            ;;
        Microsoft.DesktopVirtualization/hostpools)
            dep_count=$(detect_hostpool_dependencies "$resource_json" "$resource_id")
            ;;
        Microsoft.DesktopVirtualization/applicationgroups)
            dep_count=$(detect_appgroup_dependencies "$resource_json" "$resource_id")
            ;;
        Microsoft.DesktopVirtualization/workspaces)
            dep_count=$(detect_workspace_dependencies "$resource_json" "$resource_id")
            ;;
        *)
            # Generic dependency detection
            # Look for common patterns in properties
            dep_count=$(detect_generic_dependencies "$resource_json" "$resource_id")
            ;;
    esac

    echo "$dep_count"
}

# Generic dependency detection for unknown resource types
# Args: resource_json, resource_id
detect_generic_dependencies() {
    local resource_json="$1"
    local resource_id="$2"

    local dep_count=0

    # Look for common property patterns that indicate dependencies
    # 1. Properties ending with "Id" or "id"
    local dep_ids=$(echo "$resource_json" | jq -r '.. | select(type == "string" and startswith("/subscriptions/"))')

    while IFS= read -r dep_id; do
        [[ -z "$dep_id" || "$dep_id" == "null" || "$dep_id" == "$resource_id" ]] && continue

        if validate_resource_id "$dep_id"; then
            add_dependency "$resource_id" "$dep_id" "reference" "references"
            ((dep_count++))
        fi
    done <<< "$dep_ids"

    echo "$dep_count"
}

# ==============================================================================
# DEPENDENCY GRAPH BUILDER
# ==============================================================================

# Build complete dependency graph from all resources
# Returns: JSON graph structure
build_dependency_graph() {
    local output_file="${1:-${PROJECT_ROOT}/discovered/dependency-graph.json}"

    if command -v log_info &>/dev/null; then
        log_info "Building dependency graph..." "dependency-resolver"
    fi

    # Get all resources from state database
    local resources_json
    if [[ -n "${STATE_DB:-}" ]] && [[ -f "$STATE_DB" ]]; then
        resources_json=$(sqlite3 "$STATE_DB" -json <<'EOF'
SELECT resource_id, name, resource_type, properties_json
FROM resources
WHERE deleted_at IS NULL;
EOF
)
    else
        # Fallback: read from discovery output
        if [[ -f "${PROJECT_ROOT}/discovered/inventory-full.json" ]]; then
            resources_json=$(cat "${PROJECT_ROOT}/discovered/inventory-full.json")
        else
            echo "ERROR: No resources found. Run discovery first." >&2
            return 1
        fi
    fi

    # Process each resource
    local total_deps=0
    local resource_count=0

    while IFS= read -r resource; do
        [[ -z "$resource" ]] && continue

        local resource_id=$(echo "$resource" | jq -r '.resource_id // .id')
        local resource_json=$(echo "$resource" | jq -r '.properties_json // .')

        if [[ "$resource_json" == "null" || -z "$resource_json" ]]; then
            resource_json="$resource"
        fi

        # Detect dependencies
        local dep_count=$(detect_resource_dependencies "$resource_json" 2>/dev/null || echo "0")
        total_deps=$((total_deps + dep_count))
        resource_count=$((resource_count + 1))

    done <<< "$(echo "$resources_json" | jq -c '.[]?')"

    # Build graph JSON from dependencies
    local nodes_json="[]"
    local edges_json="[]"

    if [[ -f "${PROJECT_ROOT}/discovered/dependencies.jsonl" ]]; then
        # Build nodes (unique resource IDs)
        local unique_resources=$(cat "${PROJECT_ROOT}/discovered/dependencies.jsonl" | \
            jq -r '.from, .to' | sort -u)

        nodes_json="["
        local first=true
        while IFS= read -r res_id; do
            [[ -z "$res_id" ]] && continue

            local res_name=$(extract_resource_name "$res_id")
            local res_type=$(extract_resource_type "$res_id")

            if [[ "$first" == "true" ]]; then
                first=false
            else
                nodes_json+=","
            fi

            nodes_json+=$(cat <<EOF
{"id":"$res_id","name":"$res_name","type":"$res_type"}
EOF
)
        done <<< "$unique_resources"
        nodes_json+="]"

        # Build edges
        edges_json=$(cat "${PROJECT_ROOT}/discovered/dependencies.jsonl" | \
            jq -s 'map({from: .from, to: .to, type: .dependency_type, relationship: .relationship})')
    fi

    # Create final graph structure
    local graph_json=$(cat <<EOF
{
  "metadata": {
    "generated_at": "$(date -Iseconds)",
    "total_resources": $resource_count,
    "total_dependencies": $total_deps
  },
  "nodes": $nodes_json,
  "edges": $edges_json
}
EOF
)

    # Write to file
    mkdir -p "$(dirname "$output_file")"
    echo "$graph_json" | jq '.' > "$output_file"

    if command -v log_success &>/dev/null; then
        log_success "Dependency graph built: $output_file ($total_deps dependencies)" "dependency-resolver"
    fi

    echo "$graph_json"
}

# ==============================================================================
# DEPENDENCY GRAPH EXPORT
# ==============================================================================

# Export dependency graph to GraphViz DOT format
# Args: output_file
export_dependency_graph_dot() {
    local output_file="${1:-${PROJECT_ROOT}/discovered/dependency-graph.dot}"

    if [[ ! -f "${PROJECT_ROOT}/discovered/dependencies.jsonl" ]]; then
        echo "ERROR: No dependencies found. Run build_dependency_graph first." >&2
        return 1
    fi

    # Create DOT file
    cat > "$output_file" <<'EOF'
digraph AzureDependencies {
    // Graph settings
    rankdir=TB;
    node [shape=box, style=filled, fontname="Arial"];
    edge [fontname="Arial", fontsize=10];

    // Define color scheme by resource type
    node [fillcolor=lightblue];

EOF

    # Add nodes with styling
    local unique_resources=$(cat "${PROJECT_ROOT}/discovered/dependencies.jsonl" | \
        jq -r '.from, .to' | sort -u)

    while IFS= read -r res_id; do
        [[ -z "$res_id" ]] && continue

        local res_name=$(extract_resource_name "$res_id")
        local res_type=$(extract_resource_type "$res_id")
        local node_id=$(echo "$res_id" | md5sum | cut -d' ' -f1)

        # Color by type
        local color="lightblue"
        case "$res_type" in
            Microsoft.Compute/virtualMachines) color="lightcoral" ;;
            Microsoft.Network/*) color="lightgreen" ;;
            Microsoft.Storage/*) color="lightyellow" ;;
            Microsoft.DesktopVirtualization/*) color="lightpink" ;;
        esac

        echo "    \"$node_id\" [label=\"$res_name\\n($res_type)\", fillcolor=$color];" >> "$output_file"
    done <<< "$unique_resources"

    echo "" >> "$output_file"

    # Add edges
    while IFS= read -r dep; do
        [[ -z "$dep" ]] && continue

        local from_id=$(echo "$dep" | jq -r '.from')
        local to_id=$(echo "$dep" | jq -r '.to')
        local dep_type=$(echo "$dep" | jq -r '.dependency_type')
        local relationship=$(echo "$dep" | jq -r '.relationship')

        local from_node=$(echo "$from_id" | md5sum | cut -d' ' -f1)
        local to_node=$(echo "$to_id" | md5sum | cut -d' ' -f1)

        # Style edge by type
        local style="solid"
        local color="black"
        case "$dep_type" in
            required) style="solid"; color="red" ;;
            optional) style="dashed"; color="blue" ;;
            reference) style="dotted"; color="gray" ;;
        esac

        echo "    \"$from_node\" -> \"$to_node\" [label=\"$relationship\", style=$style, color=$color];" >> "$output_file"
    done <<< "$(cat "${PROJECT_ROOT}/discovered/dependencies.jsonl")"

    echo "}" >> "$output_file"

    if command -v log_success &>/dev/null; then
        log_success "Exported dependency graph to DOT: $output_file" "dependency-resolver"
    fi

    echo "$output_file"
}

# ==============================================================================
# DEPENDENCY VALIDATION
# ==============================================================================

# Validate that all dependencies for a resource exist in Azure
# Args: resource_id
validate_dependencies() {
    local resource_id="$1"

    if ! validate_resource_id "$resource_id"; then
        echo "ERROR: Invalid resource ID" >&2
        return 1
    fi

    # Get dependencies from database or file
    local dependencies
    if [[ -n "${STATE_DB:-}" ]] && [[ -f "$STATE_DB" ]]; then
        dependencies=$(sqlite3 "$STATE_DB" -json <<EOF
SELECT depends_on_resource_id, dependency_type, relationship
FROM dependencies
WHERE resource_id = '$resource_id';
EOF
)
    else
        # Fallback: read from dependencies file
        if [[ -f "${PROJECT_ROOT}/discovered/dependencies.jsonl" ]]; then
            dependencies=$(grep "\"from\":\"$resource_id\"" "${PROJECT_ROOT}/discovered/dependencies.jsonl" | \
                jq -s 'map({depends_on_resource_id: .to, dependency_type: .dependency_type, relationship: .relationship})')
        else
            echo "ERROR: No dependencies found" >&2
            return 1
        fi
    fi

    local missing_count=0
    local total_count=0

    while IFS= read -r dep; do
        [[ -z "$dep" ]] && continue

        local dep_id=$(echo "$dep" | jq -r '.depends_on_resource_id')
        local dep_type=$(echo "$dep" | jq -r '.dependency_type')

        total_count=$((total_count + 1))

        # Check if dependency exists in Azure
        if command -v az &>/dev/null; then
            if ! az resource show --ids "$dep_id" &>/dev/null; then
                echo "MISSING: $dep_id ($dep_type)"
                missing_count=$((missing_count + 1))
            fi
        else
            # Can't validate without az CLI
            echo "WARNING: Cannot validate without Azure CLI"
        fi
    done <<< "$(echo "$dependencies" | jq -c '.[]?')"

    if [[ $missing_count -eq 0 ]]; then
        if command -v log_success &>/dev/null; then
            log_success "All $total_count dependencies validated" "dependency-resolver"
        fi
        return 0
    else
        if command -v log_warn &>/dev/null; then
            log_warn "$missing_count of $total_count dependencies missing" "dependency-resolver"
        fi
        return 1
    fi
}

# ==============================================================================
# CIRCULAR DEPENDENCY DETECTION
# ==============================================================================

# Detect circular dependencies using DFS
# Returns: 0 if no cycles, 1 if cycles found
detect_circular_dependencies() {
    if [[ ! -f "${PROJECT_ROOT}/discovered/dependencies.jsonl" ]]; then
        echo "ERROR: No dependencies found. Run build_dependency_graph first." >&2
        return 1
    fi

    # Build adjacency list
    declare -A graph
    declare -A visited
    declare -A rec_stack

    # Parse dependencies into adjacency list
    while IFS= read -r dep; do
        [[ -z "$dep" ]] && continue

        local from_id=$(echo "$dep" | jq -r '.from')
        local to_id=$(echo "$dep" | jq -r '.to')

        if [[ -z "${graph[$from_id]}" ]]; then
            graph[$from_id]="$to_id"
        else
            graph[$from_id]+=" $to_id"
        fi
    done <<< "$(cat "${PROJECT_ROOT}/discovered/dependencies.jsonl")"

    # DFS to detect cycles
    local has_cycle=false

    detect_cycle_dfs() {
        local node="$1"

        visited[$node]=1
        rec_stack[$node]=1

        # Visit all neighbors
        if [[ -n "${graph[$node]}" ]]; then
            for neighbor in ${graph[$node]}; do
                if [[ -z "${visited[$neighbor]}" ]]; then
                    if detect_cycle_dfs "$neighbor"; then
                        return 0
                    fi
                elif [[ "${rec_stack[$neighbor]}" == "1" ]]; then
                    # Found a cycle
                    echo "CYCLE DETECTED: $node -> $neighbor"
                    return 0
                fi
            done
        fi

        rec_stack[$node]=0
        return 1
    }

    # Check all nodes
    for node in "${!graph[@]}"; do
        if [[ -z "${visited[$node]}" ]]; then
            if detect_cycle_dfs "$node"; then
                has_cycle=true
            fi
        fi
    done

    if [[ "$has_cycle" == "true" ]]; then
        if command -v log_warn &>/dev/null; then
            log_warn "Circular dependencies detected!" "dependency-resolver"
        fi
        return 1
    else
        if command -v log_success &>/dev/null; then
            log_success "No circular dependencies found" "dependency-resolver"
        fi
        return 0
    fi
}

# ==============================================================================
# DEPENDENCY QUERIES
# ==============================================================================

# Get full dependency tree for a resource (recursive)
# Args: resource_id, max_depth
get_dependency_tree() {
    local resource_id="$1"
    local max_depth="${2:-10}"

    if ! validate_resource_id "$resource_id"; then
        echo "ERROR: Invalid resource ID" >&2
        return 1
    fi

    # Use recursive CTE if database is available
    if [[ -n "${STATE_DB:-}" ]] && [[ -f "$STATE_DB" ]]; then
        sqlite3 "$STATE_DB" -json <<EOF
WITH RECURSIVE dep_tree AS (
    -- Base case
    SELECT
        d.resource_id,
        d.depends_on_resource_id,
        d.dependency_type,
        d.relationship,
        r.name as depends_on_name,
        r.resource_type as depends_on_type,
        1 as depth
    FROM dependencies d
    JOIN resources r ON d.depends_on_resource_id = r.resource_id
    WHERE d.resource_id = '$resource_id'

    UNION ALL

    -- Recursive case
    SELECT
        d.resource_id,
        d.depends_on_resource_id,
        d.dependency_type,
        d.relationship,
        r.name,
        r.resource_type,
        dt.depth + 1
    FROM dependencies d
    JOIN resources r ON d.depends_on_resource_id = r.resource_id
    JOIN dep_tree dt ON d.resource_id = dt.depends_on_resource_id
    WHERE dt.depth < $max_depth
)
SELECT * FROM dep_tree ORDER BY depth;
EOF
    else
        # Fallback: manual recursive search
        echo "ERROR: Requires state database" >&2
        return 1
    fi
}

# Find shortest path between two resources
# Args: from_resource_id, to_resource_id
get_dependency_path() {
    local from_id="$1"
    local to_id="$2"

    if ! validate_resource_id "$from_id" || ! validate_resource_id "$to_id"; then
        echo "ERROR: Invalid resource ID" >&2
        return 1
    fi

    # Use BFS to find shortest path
    # This is complex in bash/SQL, simplified implementation
    if [[ -n "${STATE_DB:-}" ]] && [[ -f "$STATE_DB" ]]; then
        # Try to find path using recursive CTE
        sqlite3 "$STATE_DB" -json <<EOF
WITH RECURSIVE path AS (
    SELECT
        resource_id,
        depends_on_resource_id,
        resource_id || ' -> ' || depends_on_resource_id as path_str,
        1 as depth
    FROM dependencies
    WHERE resource_id = '$from_id'

    UNION ALL

    SELECT
        d.resource_id,
        d.depends_on_resource_id,
        p.path_str || ' -> ' || d.depends_on_resource_id,
        p.depth + 1
    FROM dependencies d
    JOIN path p ON d.resource_id = p.depends_on_resource_id
    WHERE p.depth < 20
    AND d.depends_on_resource_id = '$to_id'
)
SELECT * FROM path WHERE depends_on_resource_id = '$to_id' ORDER BY depth LIMIT 1;
EOF
    else
        echo "ERROR: Requires state database" >&2
        return 1
    fi
}

# Get root resources (no dependencies)
get_root_resources() {
    if [[ -n "${STATE_DB:-}" ]] && [[ -f "$STATE_DB" ]]; then
        sqlite3 "$STATE_DB" -json <<'EOF'
SELECT
    r.resource_id,
    r.name,
    r.resource_type
FROM resources r
LEFT JOIN dependencies d ON r.resource_id = d.resource_id
WHERE d.resource_id IS NULL
AND r.deleted_at IS NULL
ORDER BY r.resource_type, r.name;
EOF
    else
        echo "ERROR: Requires state database" >&2
        return 1
    fi
}

# Get leaf resources (nothing depends on them)
get_leaf_resources() {
    if [[ -n "${STATE_DB:-}" ]] && [[ -f "$STATE_DB" ]]; then
        sqlite3 "$STATE_DB" -json <<'EOF'
SELECT
    r.resource_id,
    r.name,
    r.resource_type
FROM resources r
LEFT JOIN dependencies d ON r.resource_id = d.depends_on_resource_id
WHERE d.depends_on_resource_id IS NULL
AND r.deleted_at IS NULL
ORDER BY r.resource_type, r.name;
EOF
    else
        echo "ERROR: Requires state database" >&2
        return 1
    fi
}

# ==============================================================================
# MAIN EXECUTION (if run directly)
# ==============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Dependency Resolver - Azure Infrastructure Toolkit"
    echo "=================================================="
    echo ""
    echo "This module provides dependency detection and graph building."
    echo "Usage: source this file from other scripts"
    echo ""
    echo "Available functions:"
    echo "  - detect_vm_dependencies <vm_json>"
    echo "  - detect_nic_dependencies <nic_json>"
    echo "  - detect_vnet_dependencies <vnet_json>"
    echo "  - detect_storage_dependencies <storage_json>"
    echo "  - detect_hostpool_dependencies <hostpool_json>"
    echo "  - build_dependency_graph [output_file]"
    echo "  - export_dependency_graph_dot [output_file]"
    echo "  - validate_dependencies <resource_id>"
    echo "  - detect_circular_dependencies"
    echo "  - get_dependency_tree <resource_id> [max_depth]"
    echo "  - get_dependency_path <from_id> <to_id>"
    echo "  - get_root_resources"
    echo ""
fi
