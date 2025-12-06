#!/bin/bash
# ==============================================================================
# Discovery Engine - Azure Infrastructure Toolkit
# ==============================================================================
#
# Purpose: Comprehensive resource discovery with intelligent caching and
#          dependency graph construction
#
# Features:
#   - Subscription-wide or resource-group-scoped discovery
#   - Token-efficient batch queries with JQ filtering
#   - Automatic dependency detection
#   - State database integration
#   - Progress tracking and logging
#   - Multiple output formats (summary YAML, full JSON, GraphViz DOT)
#   - Automatic tagging of discovered resources
#
# Usage:
#   source core/discovery.sh
#   discover "subscription" "subscription-id"
#   discover "resource-group" "RG-Azure-VDI-01"
#
# Output:
#   - discovered/inventory-summary.yaml  - Token-efficient summary
#   - discovered/inventory-full.json     - Complete resource details
#   - discovered/dependency-graph.dot    - GraphViz visualization
#   - state.db                           - All resources stored in SQLite
#
# ==============================================================================

set -euo pipefail

# ==============================================================================
# CONFIGURATION
# ==============================================================================

PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
DISCOVERED_DIR="${PROJECT_ROOT}/discovered"
QUERIES_DIR="${PROJECT_ROOT}/queries"

# Ensure directories exist
mkdir -p "$DISCOVERED_DIR"
mkdir -p "$QUERIES_DIR"

# Discovery configuration
DISCOVERY_BATCH_SIZE=100
DISCOVERY_TIMEOUT=600  # 10 minutes
TAG_DISCOVERED_RESOURCES=true

# Source dependencies
source "${PROJECT_ROOT}/core/logger.sh" || {
    echo "[ERROR] Failed to load logger.sh"
    exit 1
}

source "${PROJECT_ROOT}/core/state-manager.sh" || {
    echo "[ERROR] Failed to load state-manager.sh"
    exit 1
}

source "${PROJECT_ROOT}/core/query.sh" || {
    echo "[ERROR] Failed to load query.sh"
    exit 1
}

source "${PROJECT_ROOT}/core/dependency-resolver.sh" || {
    echo "[ERROR] Failed to load dependency-resolver.sh"
    exit 1
}

# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

# Get current timestamp
get_discovery_timestamp() {
    date -u +%Y-%m-%dT%H:%M:%SZ
}

# Calculate duration in seconds
calculate_duration() {
    local start_time="$1"
    local end_time="$2"
    echo $((end_time - start_time))
}

# Extract subscription ID from Azure context
get_current_subscription() {
    az account show --query id -o tsv 2>/dev/null || echo ""
}

# Validate scope and target
validate_discovery_scope() {
    local scope="$1"
    local target="$2"

    case "$scope" in
        subscription)
            if [[ -z "$target" ]]; then
                log_error "Subscription ID required for subscription-scoped discovery"
                return 1
            fi
            # Validate subscription exists
            if ! az account show --subscription "$target" &>/dev/null; then
                log_error "Subscription not found or not accessible: $target"
                return 1
            fi
            ;;
        resource-group)
            if [[ -z "$target" ]]; then
                log_error "Resource group name required for resource-group-scoped discovery"
                return 1
            fi
            # Validate resource group exists
            if ! az group show --name "$target" &>/dev/null; then
                log_error "Resource group not found: $target"
                return 1
            fi
            ;;
        *)
            log_error "Invalid scope: $scope (must be 'subscription' or 'resource-group')"
            return 1
            ;;
    esac

    return 0
}

# ==============================================================================
# RESOURCE TYPE DISCOVERY FUNCTIONS
# ==============================================================================

# Discover compute resources (VMs, disks, availability sets)
discover_compute_resources() {
    local scope="$1"
    local target="$2"

    log_info "Discovering compute resources..." "discovery"

    local resource_count=0
    local rg_param=""

    if [[ "$scope" == "resource-group" ]]; then
        rg_param="--resource-group $target"
    fi

    # 1. Virtual Machines
    log_info "  - Querying virtual machines..." "discovery"
    local vms
    vms=$(az vm list $rg_param --show-details -o json 2>/dev/null || echo "[]")

    local vm_count=$(echo "$vms" | jq 'length')
    log_info "    Found $vm_count VMs" "discovery"

    # Apply JQ filter and store
    if [[ $vm_count -gt 0 ]]; then
        echo "$vms" | jq -c '.[]' | while IFS= read -r vm; do
            store_resource "$vm"
            ((resource_count++)) || true
        done
    fi

    # 2. Managed Disks
    log_info "  - Querying managed disks..." "discovery"
    local disks
    disks=$(az disk list $rg_param -o json 2>/dev/null || echo "[]")

    local disk_count=$(echo "$disks" | jq 'length')
    log_info "    Found $disk_count disks" "discovery"

    if [[ $disk_count -gt 0 ]]; then
        echo "$disks" | jq -c '.[]' | while IFS= read -r disk; do
            store_resource "$disk"
            ((resource_count++)) || true
        done
    fi

    # 3. Availability Sets
    log_info "  - Querying availability sets..." "discovery"
    local avsets
    avsets=$(az vm availability-set list $rg_param -o json 2>/dev/null || echo "[]")

    local avset_count=$(echo "$avsets" | jq 'length')
    log_info "    Found $avset_count availability sets" "discovery"

    if [[ $avset_count -gt 0 ]]; then
        echo "$avsets" | jq -c '.[]' | while IFS= read -r avset; do
            store_resource "$avset"
            ((resource_count++)) || true
        done
    fi

    # Total compute resources
    local total=$((vm_count + disk_count + avset_count))
    log_success "Discovered $total compute resources" "discovery"

    echo "$total"
}

# Discover networking resources (VNets, subnets, NSGs, NICs, public IPs)
discover_networking_resources() {
    local scope="$1"
    local target="$2"

    log_info "Discovering networking resources..." "discovery"

    local resource_count=0
    local rg_param=""

    if [[ "$scope" == "resource-group" ]]; then
        rg_param="--resource-group $target"
    fi

    # 1. Virtual Networks
    log_info "  - Querying virtual networks..." "discovery"
    local vnets
    vnets=$(az network vnet list $rg_param -o json 2>/dev/null || echo "[]")

    local vnet_count=$(echo "$vnets" | jq 'length')
    log_info "    Found $vnet_count VNets" "discovery"

    if [[ $vnet_count -gt 0 ]]; then
        echo "$vnets" | jq -c '.[]' | while IFS= read -r vnet; do
            store_resource "$vnet"
            ((resource_count++)) || true
        done
    fi

    # 2. Subnets (extracted from VNets)
    local subnet_count=0
    if [[ $vnet_count -gt 0 ]]; then
        subnet_count=$(echo "$vnets" | jq '[.[].subnets[]?] | length')
        log_info "    Found $subnet_count subnets" "discovery"
    fi

    # 3. Network Security Groups
    log_info "  - Querying network security groups..." "discovery"
    local nsgs
    nsgs=$(az network nsg list $rg_param -o json 2>/dev/null || echo "[]")

    local nsg_count=$(echo "$nsgs" | jq 'length')
    log_info "    Found $nsg_count NSGs" "discovery"

    if [[ $nsg_count -gt 0 ]]; then
        echo "$nsgs" | jq -c '.[]' | while IFS= read -r nsg; do
            store_resource "$nsg"
            ((resource_count++)) || true
        done
    fi

    # 4. Network Interfaces
    log_info "  - Querying network interfaces..." "discovery"
    local nics
    nics=$(az network nic list $rg_param -o json 2>/dev/null || echo "[]")

    local nic_count=$(echo "$nics" | jq 'length')
    log_info "    Found $nic_count NICs" "discovery"

    if [[ $nic_count -gt 0 ]]; then
        echo "$nics" | jq -c '.[]' | while IFS= read -r nic; do
            store_resource "$nic"
            ((resource_count++)) || true
        done
    fi

    # 5. Public IP Addresses
    log_info "  - Querying public IP addresses..." "discovery"
    local pips
    pips=$(az network public-ip list $rg_param -o json 2>/dev/null || echo "[]")

    local pip_count=$(echo "$pips" | jq 'length')
    log_info "    Found $pip_count public IPs" "discovery"

    if [[ $pip_count -gt 0 ]]; then
        echo "$pips" | jq -c '.[]' | while IFS= read -r pip; do
            store_resource "$pip"
            ((resource_count++)) || true
        done
    fi

    # Total networking resources
    local total=$((vnet_count + subnet_count + nsg_count + nic_count + pip_count))
    log_success "Discovered $total networking resources" "discovery"

    echo "$total"
}

# Discover storage resources (storage accounts, file shares)
discover_storage_resources() {
    local scope="$1"
    local target="$2"

    log_info "Discovering storage resources..." "discovery"

    local resource_count=0
    local rg_param=""

    if [[ "$scope" == "resource-group" ]]; then
        rg_param="--resource-group $target"
    fi

    # 1. Storage Accounts
    log_info "  - Querying storage accounts..." "discovery"
    local storage_accounts
    storage_accounts=$(az storage account list $rg_param -o json 2>/dev/null || echo "[]")

    local sa_count=$(echo "$storage_accounts" | jq 'length')
    log_info "    Found $sa_count storage accounts" "discovery"

    if [[ $sa_count -gt 0 ]]; then
        echo "$storage_accounts" | jq -c '.[]' | while IFS= read -r sa; do
            store_resource "$sa"
            ((resource_count++)) || true

            # Query file shares for each storage account
            local sa_name=$(echo "$sa" | jq -r '.name')
            local sa_rg=$(echo "$sa" | jq -r '.resourceGroup')

            log_info "    Querying file shares in $sa_name..." "discovery"
            local shares
            shares=$(az storage share list --account-name "$sa_name" -o json 2>/dev/null || echo "[]")

            local share_count=$(echo "$shares" | jq 'length')
            if [[ $share_count -gt 0 ]]; then
                log_info "      Found $share_count file shares" "discovery"
                # Note: File shares don't have full resource IDs like ARM resources
                # They're contained within storage accounts
            fi
        done
    fi

    log_success "Discovered $sa_count storage resources" "discovery"

    echo "$sa_count"
}

# Discover identity resources (Entra groups)
discover_identity_resources() {
    local scope="$1"
    local target="$2"

    log_info "Discovering identity resources (Entra groups)..." "discovery"

    local resource_count=0

    # Query Entra ID groups
    log_info "  - Querying Entra ID groups..." "discovery"
    local groups
    groups=$(az ad group list -o json 2>/dev/null || echo "[]")

    local group_count=$(echo "$groups" | jq 'length')
    log_info "    Found $group_count Entra groups" "discovery"

    # Filter by resource group if specified (based on naming convention or tags)
    if [[ "$scope" == "resource-group" ]]; then
        log_info "    Filtering groups for resource group: $target" "discovery"
        # Filter groups that contain the resource group name in description or displayName
        groups=$(echo "$groups" | jq --arg rg "$target" '[.[] | select(.displayName | contains($rg) or (.description // "") | contains($rg))]')
        group_count=$(echo "$groups" | jq 'length')
        log_info "    Filtered to $group_count groups" "discovery"
    fi

    # Note: Entra groups don't store in resources table (different structure)
    # But we track them for AVD dependencies

    log_success "Discovered $group_count identity resources" "discovery"

    echo "$group_count"
}

# Discover AVD resources (host pools, workspaces, app groups)
discover_avd_resources() {
    local scope="$1"
    local target="$2"

    log_info "Discovering AVD resources..." "discovery"

    local resource_count=0
    local rg_param=""

    if [[ "$scope" == "resource-group" ]]; then
        rg_param="--resource-group $target"
    fi

    # 1. Host Pools
    log_info "  - Querying AVD host pools..." "discovery"
    local hostpools
    hostpools=$(az desktopvirtualization hostpool list $rg_param -o json 2>/dev/null || echo "[]")

    local hp_count=$(echo "$hostpools" | jq 'length')
    log_info "    Found $hp_count host pools" "discovery"

    if [[ $hp_count -gt 0 ]]; then
        echo "$hostpools" | jq -c '.[]' | while IFS= read -r hp; do
            store_resource "$hp"
            ((resource_count++)) || true
        done
    fi

    # 2. Application Groups
    log_info "  - Querying AVD application groups..." "discovery"
    local appgroups
    appgroups=$(az desktopvirtualization applicationgroup list $rg_param -o json 2>/dev/null || echo "[]")

    local ag_count=$(echo "$appgroups" | jq 'length')
    log_info "    Found $ag_count application groups" "discovery"

    if [[ $ag_count -gt 0 ]]; then
        echo "$appgroups" | jq -c '.[]' | while IFS= read -r ag; do
            store_resource "$ag"
            ((resource_count++)) || true
        done
    fi

    # 3. Workspaces
    log_info "  - Querying AVD workspaces..." "discovery"
    local workspaces
    workspaces=$(az desktopvirtualization workspace list $rg_param -o json 2>/dev/null || echo "[]")

    local ws_count=$(echo "$workspaces" | jq 'length')
    log_info "    Found $ws_count workspaces" "discovery"

    if [[ $ws_count -gt 0 ]]; then
        echo "$workspaces" | jq -c '.[]' | while IFS= read -r ws; do
            store_resource "$ws"
            ((resource_count++)) || true
        done
    fi

    # Total AVD resources
    local total=$((hp_count + ag_count + ws_count))
    log_success "Discovered $total AVD resources" "discovery"

    echo "$total"
}

# Discover all resources using batch query (most efficient)
discover_all_resources() {
    local scope="$1"
    local target="$2"

    log_info "Discovering all resources (batch query)..." "discovery"

    local rg_param=""
    if [[ "$scope" == "resource-group" ]]; then
        rg_param="--resource-group $target"
    fi

    # Use az resource list for efficient batch query
    log_info "  - Executing batch resource query..." "discovery"
    local all_resources
    all_resources=$(az resource list $rg_param -o json 2>/dev/null || echo "[]")

    local resource_count=$(echo "$all_resources" | jq 'length')
    log_info "    Found $resource_count total resources" "discovery"

    # Apply summary filter for token efficiency
    ensure_jq_filter_exists "summary"
    local filtered_resources
    filtered_resources=$(echo "$all_resources" | jq -f "${QUERIES_DIR}/summary.jq")

    # Store each resource (with full details)
    if [[ $resource_count -gt 0 ]]; then
        local stored=0
        echo "$all_resources" | jq -c '.[]' | while IFS= read -r resource; do
            store_resource "$resource"
            ((stored++))

            # Progress indicator every 10 resources
            if [[ $((stored % 10)) -eq 0 ]]; then
                log_info "    Stored $stored/$resource_count resources..." "discovery"
            fi
        done
    fi

    log_success "Discovered and stored $resource_count resources" "discovery"

    echo "$resource_count"
}

# ==============================================================================
# DEPENDENCY GRAPH CONSTRUCTION
# ==============================================================================

# Build complete dependency graph from discovered resources
build_discovery_graph() {
    log_info "Building dependency graph..." "discovery"

    local graph_file="${DISCOVERED_DIR}/dependency-graph.json"

    # Use dependency-resolver to build graph
    build_dependency_graph "$graph_file" 2>&1 | while IFS= read -r line; do
        [[ -n "$line" ]] && log_info "  $line" "discovery"
    done

    # Also export to DOT format
    local dot_file="${DISCOVERED_DIR}/dependency-graph.dot"
    export_dependency_graph_dot "$dot_file" 2>&1 | while IFS= read -r line; do
        [[ -n "$line" ]] && log_info "  $line" "discovery"
    done

    log_success "Dependency graph built: $graph_file, $dot_file" "discovery"
}

# ==============================================================================
# AZURE TAGGING
# ==============================================================================

# Tag all discovered resources in Azure
tag_discovered_resources() {
    log_info "Tagging discovered resources in Azure..." "discovery"

    if [[ "$TAG_DISCOVERED_RESOURCES" != "true" ]]; then
        log_info "  Resource tagging disabled (TAG_DISCOVERED_RESOURCES=false)" "discovery"
        return 0
    fi

    # Get all discovered resources from state DB
    local resources
    resources=$(sqlite3 "$STATE_DB" -json <<'EOF'
SELECT resource_id, name
FROM resources
WHERE deleted_at IS NULL
AND resource_id LIKE '/subscriptions/%';
EOF
)

    local resource_count=$(echo "$resources" | jq 'length')
    if [[ $resource_count -eq 0 ]]; then
        log_warn "No resources to tag" "discovery"
        return 0
    fi

    log_info "  Tagging $resource_count resources..." "discovery"

    local tagged=0
    local failed=0
    local discovery_timestamp=$(get_discovery_timestamp)

    echo "$resources" | jq -c '.[]' | while IFS= read -r resource; do
        local resource_id=$(echo "$resource" | jq -r '.resource_id')
        local resource_name=$(echo "$resource" | jq -r '.name')

        # Tag in Azure
        if az tag update \
            --resource-id "$resource_id" \
            --operation merge \
            --tags "discovered-by-toolkit=true" "discovery-timestamp=$discovery_timestamp" \
            &>/dev/null; then
            ((tagged++))
            log_info "    Tagged: $resource_name" "discovery"
        else
            ((failed++))
            log_warn "    Failed to tag: $resource_name" "discovery"
        fi
    done

    log_success "Tagged $tagged resources ($failed failed)" "discovery"
}

# ==============================================================================
# OUTPUT GENERATION
# ==============================================================================

# Generate token-efficient inventory summary (YAML)
generate_inventory_summary() {
    local scope="$1"
    local target="$2"
    local total_resources="$3"
    local duration="$4"

    log_info "Generating inventory summary..." "discovery"

    local output_file="${DISCOVERED_DIR}/inventory-summary.yaml"
    local timestamp=$(get_discovery_timestamp)

    # Get resource counts by type
    local resource_counts
    resource_counts=$(sqlite3 "$STATE_DB" -json <<'EOF'
SELECT
    resource_type,
    COUNT(*) as count,
    SUM(CASE WHEN managed_by_toolkit = 1 THEN 1 ELSE 0 END) as managed_count
FROM active_resources
GROUP BY resource_type
ORDER BY count DESC;
EOF
)

    # Get key resources (resources with most dependents)
    local key_resources
    key_resources=$(sqlite3 "$STATE_DB" -json <<'EOF'
SELECT
    r.resource_id,
    r.name,
    r.resource_type,
    COUNT(DISTINCT d.resource_id) as dependent_count
FROM resources r
LEFT JOIN dependencies d ON r.resource_id = d.depends_on_resource_id
WHERE r.deleted_at IS NULL
GROUP BY r.resource_id, r.name, r.resource_type
HAVING dependent_count > 0
ORDER BY dependent_count DESC
LIMIT 10;
EOF
)

    # Get managed vs external breakdown
    local managed_count
    managed_count=$(sqlite3 "$STATE_DB" "SELECT COUNT(*) FROM resources WHERE managed_by_toolkit = 1 AND deleted_at IS NULL;")

    local external_count=$((total_resources - managed_count))

    # Build YAML output
    cat > "$output_file" <<EOF
---
# Azure Infrastructure Discovery Summary
# Generated: $timestamp

discovery:
  timestamp: "$timestamp"
  scope: "$scope"
  target: "$target"
  duration_seconds: $duration
  total_resources: $total_resources

resource_counts:
  compute:
EOF

    # Add compute resources
    local vm_count=$(echo "$resource_counts" | jq -r '.[] | select(.resource_type | contains("virtualMachines")) | .count // 0' | head -n1)
    local disk_count=$(echo "$resource_counts" | jq -r '.[] | select(.resource_type | contains("disks")) | .count // 0' | head -n1)
    echo "    virtual_machines: ${vm_count:-0}" >> "$output_file"
    echo "    disks: ${disk_count:-0}" >> "$output_file"

    # Add networking resources
    cat >> "$output_file" <<EOF
  networking:
EOF
    local vnet_count=$(echo "$resource_counts" | jq -r '.[] | select(.resource_type | contains("virtualNetworks")) | .count // 0' | head -n1)
    local nsg_count=$(echo "$resource_counts" | jq -r '.[] | select(.resource_type | contains("networkSecurityGroups")) | .count // 0' | head -n1)
    local nic_count=$(echo "$resource_counts" | jq -r '.[] | select(.resource_type | contains("networkInterfaces")) | .count // 0' | head -n1)
    echo "    virtual_networks: ${vnet_count:-0}" >> "$output_file"
    echo "    network_security_groups: ${nsg_count:-0}" >> "$output_file"
    echo "    network_interfaces: ${nic_count:-0}" >> "$output_file"

    # Add storage resources
    cat >> "$output_file" <<EOF
  storage:
EOF
    local storage_count=$(echo "$resource_counts" | jq -r '.[] | select(.resource_type | contains("storageAccounts")) | .count // 0' | head -n1)
    echo "    storage_accounts: ${storage_count:-0}" >> "$output_file"

    # Add AVD resources
    cat >> "$output_file" <<EOF
  avd:
EOF
    local hp_count=$(echo "$resource_counts" | jq -r '.[] | select(.resource_type | contains("hostpools")) | .count // 0' | head -n1)
    local ag_count=$(echo "$resource_counts" | jq -r '.[] | select(.resource_type | contains("applicationgroups")) | .count // 0' | head -n1)
    local ws_count=$(echo "$resource_counts" | jq -r '.[] | select(.resource_type | contains("workspaces")) | .count // 0' | head -n1)
    echo "    host_pools: ${hp_count:-0}" >> "$output_file"
    echo "    application_groups: ${ag_count:-0}" >> "$output_file"
    echo "    workspaces: ${ws_count:-0}" >> "$output_file"

    # Add key resources
    cat >> "$output_file" <<EOF

key_resources:
EOF

    if [[ $(echo "$key_resources" | jq 'length') -gt 0 ]]; then
        echo "$key_resources" | jq -r '.[] | "  - name: \"" + .name + "\"\n    type: \"" + .resource_type + "\"\n    dependents: " + (.dependent_count | tostring)' >> "$output_file"
    else
        echo "  []" >> "$output_file"
    fi

    # Add management breakdown
    cat >> "$output_file" <<EOF

managed_by_toolkit: $managed_count
external_resources: $external_count
EOF

    log_success "Inventory summary written to: $output_file" "discovery"
    echo "$output_file"
}

# Generate full inventory with complete resource details (JSON)
generate_inventory_full() {
    local scope="$1"
    local target="$2"
    local total_resources="$3"
    local duration="$4"

    log_info "Generating full inventory..." "discovery"

    local output_file="${DISCOVERED_DIR}/inventory-full.json"
    local timestamp=$(get_discovery_timestamp)

    # Get all resources with full properties
    local resources
    resources=$(sqlite3 "$STATE_DB" -json <<'EOF'
SELECT
    resource_id as id,
    name,
    resource_type as type,
    resource_group as resourceGroup,
    location,
    provisioning_state as provisioningState,
    managed_by_toolkit as managedByToolkit,
    tags_json as tags,
    properties_json as properties
FROM resources
WHERE deleted_at IS NULL
ORDER BY resource_type, name;
EOF
)

    # Build JSON output
    local inventory_json=$(jq -n \
        --arg timestamp "$timestamp" \
        --arg scope "$scope" \
        --arg target "$target" \
        --argjson duration "$duration" \
        --argjson total "$total_resources" \
        --argjson resources "$resources" \
        '{
            discovery: {
                timestamp: $timestamp,
                scope: $scope,
                target: $target,
                duration_seconds: $duration,
                total_resources: $total
            },
            resources: $resources
        }')

    echo "$inventory_json" | jq '.' > "$output_file"

    log_success "Full inventory written to: $output_file" "discovery"
    echo "$output_file"
}

# ==============================================================================
# MAIN DISCOVERY FUNCTION
# ==============================================================================

# Main discovery entry point
# Args: scope (subscription|resource-group), target (subscription-id or rg-name)
discover() {
    local scope="${1:-}"
    local target="${2:-}"

    # Validate arguments
    if [[ -z "$scope" ]] || [[ -z "$target" ]]; then
        log_error "Usage: discover <scope> <target>"
        log_error "  scope: 'subscription' or 'resource-group'"
        log_error "  target: subscription-id or resource-group-name"
        return 1
    fi

    # Validate scope and target
    if ! validate_discovery_scope "$scope" "$target"; then
        return 1
    fi

    # Start discovery
    local start_time=$(date +%s)
    local operation_id="discovery-$(date +%Y%m%d-%H%M%S)"

    log_operation_start "$operation_id" "Resource Discovery: $scope=$target"
    log_info "Starting discovery: scope=$scope, target=$target" "discovery"
    log_info "" "discovery"

    # Initialize state database
    log_info "Initializing state database..." "discovery"
    init_state_db || {
        log_error "Failed to initialize state database"
        return 1
    }

    # Track resource counts
    local total_resources=0
    local compute_count=0
    local networking_count=0
    local storage_count=0
    local identity_count=0
    local avd_count=0

    # Phase 1: Resource Discovery
    log_info "=== Phase 1: Resource Discovery ===" "discovery"
    log_info "" "discovery"

    # Use batch discovery for efficiency
    total_resources=$(discover_all_resources "$scope" "$target")

    # Also run type-specific discovery for detailed queries
    log_info "" "discovery"
    log_info "Running detailed type-specific discovery..." "discovery"

    compute_count=$(discover_compute_resources "$scope" "$target")
    networking_count=$(discover_networking_resources "$scope" "$target")
    storage_count=$(discover_storage_resources "$scope" "$target")
    identity_count=$(discover_identity_resources "$scope" "$target")
    avd_count=$(discover_avd_resources "$scope" "$target")

    log_info "" "discovery"
    log_success "Phase 1 complete: Discovered $total_resources resources" "discovery"

    # Phase 2: Dependency Analysis
    log_info "" "discovery"
    log_info "=== Phase 2: Dependency Analysis ===" "discovery"
    log_info "" "discovery"

    build_discovery_graph

    log_info "" "discovery"
    log_success "Phase 2 complete: Dependency graph built" "discovery"

    # Phase 3: Azure Tagging (optional)
    if [[ "$TAG_DISCOVERED_RESOURCES" == "true" ]]; then
        log_info "" "discovery"
        log_info "=== Phase 3: Azure Resource Tagging ===" "discovery"
        log_info "" "discovery"

        tag_discovered_resources

        log_info "" "discovery"
        log_success "Phase 3 complete: Resources tagged" "discovery"
    fi

    # Phase 4: Output Generation
    log_info "" "discovery"
    log_info "=== Phase 4: Output Generation ===" "discovery"
    log_info "" "discovery"

    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    # Generate outputs
    local summary_file=$(generate_inventory_summary "$scope" "$target" "$total_resources" "$duration")
    local full_file=$(generate_inventory_full "$scope" "$target" "$total_resources" "$duration")

    log_info "" "discovery"
    log_success "Phase 4 complete: Outputs generated" "discovery"

    # Final summary
    log_info "" "discovery"
    log_info "=====================================================================" "discovery"
    log_info "  DISCOVERY COMPLETE" "discovery"
    log_info "=====================================================================" "discovery"
    log_info "" "discovery"
    log_info "  Scope:              $scope" "discovery"
    log_info "  Target:             $target" "discovery"
    log_info "  Duration:           ${duration}s" "discovery"
    log_info "  Total Resources:    $total_resources" "discovery"
    log_info "" "discovery"
    log_info "  Resource Breakdown:" "discovery"
    log_info "    - Compute:        $compute_count" "discovery"
    log_info "    - Networking:     $networking_count" "discovery"
    log_info "    - Storage:        $storage_count" "discovery"
    log_info "    - Identity:       $identity_count" "discovery"
    log_info "    - AVD:            $avd_count" "discovery"
    log_info "" "discovery"
    log_info "  Outputs:" "discovery"
    log_info "    - Summary:        $summary_file" "discovery"
    log_info "    - Full:           $full_file" "discovery"
    log_info "    - Graph (JSON):   ${DISCOVERED_DIR}/dependency-graph.json" "discovery"
    log_info "    - Graph (DOT):    ${DISCOVERED_DIR}/dependency-graph.dot" "discovery"
    log_info "    - State DB:       $STATE_DB" "discovery"
    log_info "" "discovery"
    log_info "=====================================================================" "discovery"

    log_operation_complete "$operation_id" "$duration" 0

    return 0
}

# ==============================================================================
# CONVENIENCE FUNCTIONS
# ==============================================================================

# Discover specific resource group
discover_resource_group() {
    local resource_group="$1"
    discover "resource-group" "$resource_group"
}

# Discover entire subscription
discover_subscription() {
    local subscription_id="${1:-$(get_current_subscription)}"

    if [[ -z "$subscription_id" ]]; then
        log_error "No subscription ID provided and could not determine current subscription"
        return 1
    fi

    discover "subscription" "$subscription_id"
}

# Re-discover (invalidate cache first)
rediscover() {
    local scope="$1"
    local target="$2"

    log_info "Invalidating cache before rediscovery..." "discovery"
    invalidate_cache "*" "rediscovery"

    discover "$scope" "$target"
}

# ==============================================================================
# EXPORT FUNCTIONS
# ==============================================================================

export -f discover
export -f discover_resource_group
export -f discover_subscription
export -f rediscover
export -f discover_compute_resources
export -f discover_networking_resources
export -f discover_storage_resources
export -f discover_identity_resources
export -f discover_avd_resources
export -f discover_all_resources
export -f build_discovery_graph
export -f tag_discovered_resources
export -f generate_inventory_summary
export -f generate_inventory_full
export -f validate_discovery_scope

log_info "Discovery engine loaded successfully" "discovery"
