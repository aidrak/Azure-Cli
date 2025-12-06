#!/bin/bash
# ==============================================================================
# Azure Infrastructure Toolkit - Query Engine
# ==============================================================================
#
# Purpose: Intelligent query engine with cache-first approach for Azure resources
# Architecture: Uses state-manager.sh for caching, JQ filters for token efficiency
#
# Usage:
#   source core/query.sh
#   query_resources "compute"                      # Query all VMs (cache-first)
#   query_resource "vm" "avd-sh-01" "RG-Azure-VDI-01"  # Query specific VM
#   query_resources "networking" "" "full"         # Full details for networking
#
# ==============================================================================

set -euo pipefail

# ==============================================================================
# CONFIGURATION
# ==============================================================================

PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
QUERIES_DIR="${PROJECT_ROOT}/queries"

# Cache TTL values (in seconds)
CACHE_TTL_SINGLE_RESOURCE=300   # 5 minutes for single resource
CACHE_TTL_RESOURCE_LIST=120     # 2 minutes for resource lists

# Source dependencies
if [[ -f "${PROJECT_ROOT}/core/logger.sh" ]]; then
    source "${PROJECT_ROOT}/core/logger.sh"
else
    # Fallback logging if logger not available
    log_info() { echo "[INFO] $1"; }
    log_warn() { echo "[WARN] $1"; }
    log_error() { echo "[ERROR] $1" >&2; }
    log_success() { echo "[SUCCESS] $1"; }
    log_debug() { [[ "${DEBUG:-0}" == "1" ]] && echo "[DEBUG] $1" || true; }
fi

# ==============================================================================
# STATE MANAGER INTEGRATION (PLACEHOLDER/STUB)
# ==============================================================================
# These functions will integrate with state-manager.sh when it's implemented.
# For now, they provide graceful fallback to direct Azure queries.

_state_manager_available() {
    [[ -f "${PROJECT_ROOT}/core/state-manager.sh" ]] && return 0 || return 1
}

_get_cached_resource() {
    local resource_type="$1"
    local resource_name="$2"
    local resource_group="$3"

    if _state_manager_available; then
        source "${PROJECT_ROOT}/core/state-manager.sh"
        get_resource "$resource_type" "$resource_name" "$resource_group" 2>/dev/null || echo ""
    else
        log_debug "State manager not available, skipping cache check"
        echo ""
    fi
}

_store_cached_resource() {
    local resource_json="$1"

    if _state_manager_available; then
        source "${PROJECT_ROOT}/core/state-manager.sh"
        store_resource "$resource_json" 2>/dev/null || true
    else
        log_debug "State manager not available, skipping cache store"
    fi
}

_invalidate_resource_cache() {
    local pattern="${1:-*}"
    local reason="${2:-manual}"

    if _state_manager_available; then
        source "${PROJECT_ROOT}/core/state-manager.sh"
        invalidate_cache "$pattern" "$reason" 2>/dev/null || true
    else
        log_debug "State manager not available, skipping cache invalidation"
    fi
}

# ==============================================================================
# JQ FILTER MANAGEMENT
# ==============================================================================

apply_jq_filter() {
    local json_data="$1"
    local filter_file="$2"

    if [[ ! -f "$filter_file" ]]; then
        log_warn "JQ filter not found: $filter_file, using identity filter"
        echo "$json_data" | jq -c '.'
        return 0
    fi

    log_debug "Applying JQ filter: $filter_file"
    echo "$json_data" | jq -c -f "$filter_file" 2>/dev/null || {
        log_warn "JQ filter failed, returning raw data"
        echo "$json_data" | jq -c '.'
    }
}

ensure_jq_filter_exists() {
    local filter_type="$1"
    local filter_file="${QUERIES_DIR}/${filter_type}.jq"

    mkdir -p "$QUERIES_DIR"

    if [[ -f "$filter_file" ]]; then
        return 0
    fi

    log_debug "Creating default JQ filter: $filter_file"

    # Create default filters based on type
    case "$filter_type" in
        compute)
            cat > "$filter_file" <<'EOF'
# Compute (VM) resource filter for token efficiency
map({
    id: .id,
    name: .name,
    resourceGroup: .resourceGroup,
    location: .location,
    vmSize: .hardwareProfile.vmSize,
    osType: .storageProfile.osDisk.osType,
    provisioningState: .provisioningState,
    powerState: (.instanceView.statuses[] | select(.code | startswith("PowerState/")) | .displayStatus) // "Unknown",
    privateIp: .privateIps[0] // null,
    publicIp: .publicIps[0] // null,
    tags: .tags
})
EOF
            ;;
        networking)
            cat > "$filter_file" <<'EOF'
# Networking (VNet) resource filter for token efficiency
map({
    id: .id,
    name: .name,
    resourceGroup: .resourceGroup,
    location: .location,
    addressSpace: .addressSpace.addressPrefixes,
    subnets: (.subnets | map({name: .name, addressPrefix: .addressPrefix})),
    provisioningState: .provisioningState,
    tags: .tags
})
EOF
            ;;
        storage)
            cat > "$filter_file" <<'EOF'
# Storage account filter for token efficiency
map({
    id: .id,
    name: .name,
    resourceGroup: .resourceGroup,
    location: .location,
    kind: .kind,
    sku: .sku.name,
    provisioningState: .provisioningState,
    primaryEndpoints: .primaryEndpoints,
    tags: .tags
})
EOF
            ;;
        identity)
            cat > "$filter_file" <<'EOF'
# Identity (Entra groups) filter for token efficiency
map({
    id: .id,
    displayName: .displayName,
    mailNickname: .mailNickname,
    description: .description,
    securityEnabled: .securityEnabled,
    mailEnabled: .mailEnabled
})
EOF
            ;;
        avd)
            cat > "$filter_file" <<'EOF'
# AVD host pool filter for token efficiency
map({
    id: .id,
    name: .name,
    resourceGroup: .resourceGroup,
    location: .location,
    hostPoolType: .properties.hostPoolType,
    loadBalancerType: .properties.loadBalancerType,
    maxSessionLimit: .properties.maxSessionLimit,
    registrationInfo: .properties.registrationInfo,
    tags: .tags
})
EOF
            ;;
        summary)
            cat > "$filter_file" <<'EOF'
# Summary filter - ultra-minimal for overview queries
map({
    name: .name,
    type: .type,
    location: .location,
    state: .provisioningState // .properties.provisioningState // "Unknown"
})
EOF
            ;;
        *)
            # Generic identity filter
            cat > "$filter_file" <<'EOF'
# Generic identity filter (no transformation)
.
EOF
            ;;
    esac

    log_debug "Created JQ filter: $filter_file"
}

# ==============================================================================
# AZURE QUERY HELPERS
# ==============================================================================

query_azure_raw() {
    local resource_type="$1"
    local resource_group="${2:-}"
    local additional_args="${3:-}"

    log_debug "Querying Azure: type=$resource_type, rg=$resource_group"

    local result=""
    local exit_code=0

    case "$resource_type" in
        vm|compute)
            if [[ -n "$resource_group" ]]; then
                result=$(az vm list --resource-group "$resource_group" --show-details -o json 2>/dev/null) || exit_code=$?
            else
                result=$(az vm list --show-details -o json 2>/dev/null) || exit_code=$?
            fi
            ;;
        vnet|networking)
            if [[ -n "$resource_group" ]]; then
                result=$(az network vnet list --resource-group "$resource_group" -o json 2>/dev/null) || exit_code=$?
            else
                result=$(az network vnet list -o json 2>/dev/null) || exit_code=$?
            fi
            ;;
        storage)
            if [[ -n "$resource_group" ]]; then
                result=$(az storage account list --resource-group "$resource_group" -o json 2>/dev/null) || exit_code=$?
            else
                result=$(az storage account list -o json 2>/dev/null) || exit_code=$?
            fi
            ;;
        identity|group|ad-group)
            # Entra groups don't filter by resource group
            result=$(az ad group list -o json 2>/dev/null) || exit_code=$?
            ;;
        avd|hostpool)
            if [[ -n "$resource_group" ]]; then
                result=$(az desktopvirtualization hostpool list --resource-group "$resource_group" -o json 2>/dev/null) || exit_code=$?
            else
                result=$(az desktopvirtualization hostpool list -o json 2>/dev/null) || exit_code=$?
            fi
            ;;
        all|resources)
            if [[ -n "$resource_group" ]]; then
                result=$(az resource list --resource-group "$resource_group" -o json 2>/dev/null) || exit_code=$?
            else
                result=$(az resource list -o json 2>/dev/null) || exit_code=$?
            fi
            ;;
        *)
            log_error "Unknown resource type: $resource_type"
            return 1
            ;;
    esac

    if [[ $exit_code -ne 0 ]]; then
        log_error "Azure CLI query failed: exit code $exit_code"
        return 1
    fi

    # Return empty array if null
    if [[ -z "$result" ]] || [[ "$result" == "null" ]]; then
        echo "[]"
    else
        echo "$result"
    fi
}

query_azure_resource_by_name() {
    local resource_type="$1"
    local resource_name="$2"
    local resource_group="$3"

    log_debug "Querying specific Azure resource: $resource_name"

    local result=""
    local exit_code=0

    case "$resource_type" in
        vm|compute)
            result=$(az vm show --name "$resource_name" --resource-group "$resource_group" --show-details -o json 2>/dev/null) || exit_code=$?
            ;;
        vnet|networking)
            result=$(az network vnet show --name "$resource_name" --resource-group "$resource_group" -o json 2>/dev/null) || exit_code=$?
            ;;
        storage)
            result=$(az storage account show --name "$resource_name" --resource-group "$resource_group" -o json 2>/dev/null) || exit_code=$?
            ;;
        identity|group|ad-group)
            result=$(az ad group show --group "$resource_name" -o json 2>/dev/null) || exit_code=$?
            ;;
        avd|hostpool)
            result=$(az desktopvirtualization hostpool show --name "$resource_name" --resource-group "$resource_group" -o json 2>/dev/null) || exit_code=$?
            ;;
        *)
            log_error "Unknown resource type: $resource_type"
            return 1
            ;;
    esac

    if [[ $exit_code -ne 0 ]]; then
        log_error "Azure CLI query failed for resource: $resource_name"
        return 1
    fi

    echo "$result"
}

# ==============================================================================
# RESOURCE-SPECIFIC QUERY FUNCTIONS
# ==============================================================================

query_compute_resources() {
    local resource_group="${1:-}"
    local output_format="${2:-summary}"

    log_info "Querying compute resources (VMs)${resource_group:+ in $resource_group}"

    # Query Azure
    local raw_result
    raw_result=$(query_azure_raw "vm" "$resource_group") || {
        log_error "Failed to query compute resources"
        return 1
    }

    # Check if empty
    local count
    count=$(echo "$raw_result" | jq 'length')
    log_debug "Found $count VMs"

    if [[ "$count" -eq 0 ]]; then
        log_warn "No VMs found${resource_group:+ in resource group $resource_group}"
        echo "[]"
        return 0
    fi

    # Apply JQ filter for token efficiency
    local filter_type
    if [[ "$output_format" == "full" ]]; then
        filter_type="compute"
    else
        filter_type="summary"
    fi

    ensure_jq_filter_exists "$filter_type"
    local filtered_result
    filtered_result=$(apply_jq_filter "$raw_result" "${QUERIES_DIR}/${filter_type}.jq")

    # Store each resource in cache
    echo "$raw_result" | jq -c '.[]' | while read -r resource; do
        _store_cached_resource "$resource"
    done

    echo "$filtered_result"
}

query_networking_resources() {
    local resource_group="${1:-}"
    local output_format="${2:-summary}"

    log_info "Querying networking resources (VNets)${resource_group:+ in $resource_group}"

    # Query Azure
    local raw_result
    raw_result=$(query_azure_raw "vnet" "$resource_group") || {
        log_error "Failed to query networking resources"
        return 1
    }

    local count
    count=$(echo "$raw_result" | jq 'length')
    log_debug "Found $count VNets"

    if [[ "$count" -eq 0 ]]; then
        log_warn "No VNets found${resource_group:+ in resource group $resource_group}"
        echo "[]"
        return 0
    fi

    # Apply JQ filter
    local filter_type
    if [[ "$output_format" == "full" ]]; then
        filter_type="networking"
    else
        filter_type="summary"
    fi

    ensure_jq_filter_exists "$filter_type"
    local filtered_result
    filtered_result=$(apply_jq_filter "$raw_result" "${QUERIES_DIR}/${filter_type}.jq")

    # Store in cache
    echo "$raw_result" | jq -c '.[]' | while read -r resource; do
        _store_cached_resource "$resource"
    done

    echo "$filtered_result"
}

query_storage_resources() {
    local resource_group="${1:-}"
    local output_format="${2:-summary}"

    log_info "Querying storage resources${resource_group:+ in $resource_group}"

    # Query Azure
    local raw_result
    raw_result=$(query_azure_raw "storage" "$resource_group") || {
        log_error "Failed to query storage resources"
        return 1
    }

    local count
    count=$(echo "$raw_result" | jq 'length')
    log_debug "Found $count storage accounts"

    if [[ "$count" -eq 0 ]]; then
        log_warn "No storage accounts found${resource_group:+ in resource group $resource_group}"
        echo "[]"
        return 0
    fi

    # Apply JQ filter
    local filter_type
    if [[ "$output_format" == "full" ]]; then
        filter_type="storage"
    else
        filter_type="summary"
    fi

    ensure_jq_filter_exists "$filter_type"
    local filtered_result
    filtered_result=$(apply_jq_filter "$raw_result" "${QUERIES_DIR}/${filter_type}.jq")

    # Store in cache
    echo "$raw_result" | jq -c '.[]' | while read -r resource; do
        _store_cached_resource "$resource"
    done

    echo "$filtered_result"
}

query_identity_resources() {
    local resource_group="${1:-}"
    local output_format="${2:-summary}"

    log_info "Querying identity resources (Entra groups)"

    # Query Azure
    local raw_result
    raw_result=$(query_azure_raw "identity" "") || {
        log_error "Failed to query identity resources"
        return 1
    }

    # Filter by resource group if specified (using tags or description)
    if [[ -n "$resource_group" ]]; then
        log_debug "Filtering groups by resource group: $resource_group"
        raw_result=$(echo "$raw_result" | jq -c "[.[] | select(.description // \"\" | contains(\"$resource_group\"))]")
    fi

    local count
    count=$(echo "$raw_result" | jq 'length')
    log_debug "Found $count Entra groups"

    if [[ "$count" -eq 0 ]]; then
        log_warn "No Entra groups found"
        echo "[]"
        return 0
    fi

    # Apply JQ filter
    local filter_type
    if [[ "$output_format" == "full" ]]; then
        filter_type="identity"
    else
        filter_type="summary"
    fi

    ensure_jq_filter_exists "$filter_type"
    local filtered_result
    filtered_result=$(apply_jq_filter "$raw_result" "${QUERIES_DIR}/${filter_type}.jq")

    echo "$filtered_result"
}

query_avd_resources() {
    local resource_group="${1:-}"
    local output_format="${2:-summary}"

    log_info "Querying AVD resources (host pools)${resource_group:+ in $resource_group}"

    # Query Azure
    local raw_result
    raw_result=$(query_azure_raw "avd" "$resource_group") || {
        log_error "Failed to query AVD resources"
        return 1
    }

    local count
    count=$(echo "$raw_result" | jq 'length')
    log_debug "Found $count AVD host pools"

    if [[ "$count" -eq 0 ]]; then
        log_warn "No AVD host pools found${resource_group:+ in resource group $resource_group}"
        echo "[]"
        return 0
    fi

    # Apply JQ filter
    local filter_type
    if [[ "$output_format" == "full" ]]; then
        filter_type="avd"
    else
        filter_type="summary"
    fi

    ensure_jq_filter_exists "$filter_type"
    local filtered_result
    filtered_result=$(apply_jq_filter "$raw_result" "${QUERIES_DIR}/${filter_type}.jq")

    # Store in cache
    echo "$raw_result" | jq -c '.[]' | while read -r resource; do
        _store_cached_resource "$resource"
    done

    echo "$filtered_result"
}

query_all_resources() {
    local resource_group="${1:-}"
    local output_format="${2:-summary}"

    log_info "Querying all resources${resource_group:+ in $resource_group}"

    # Query Azure
    local raw_result
    raw_result=$(query_azure_raw "all" "$resource_group") || {
        log_error "Failed to query all resources"
        return 1
    }

    local count
    count=$(echo "$raw_result" | jq 'length')
    log_info "Found $count total resources"

    if [[ "$count" -eq 0 ]]; then
        log_warn "No resources found${resource_group:+ in resource group $resource_group}"
        echo "[]"
        return 0
    fi

    # Group by type
    if [[ "$output_format" == "full" ]]; then
        echo "$raw_result"
    else
        ensure_jq_filter_exists "summary"
        apply_jq_filter "$raw_result" "${QUERIES_DIR}/summary.jq"
    fi
}

# ==============================================================================
# MAIN QUERY INTERFACE FUNCTIONS
# ==============================================================================

query_resource() {
    local resource_type="$1"
    local resource_name="$2"
    local resource_group="${3:-}"

    if [[ -z "$resource_type" ]] || [[ -z "$resource_name" ]]; then
        log_error "Usage: query_resource <resource_type> <resource_name> [resource_group]"
        return 1
    fi

    log_info "Querying specific resource: $resource_name (type: $resource_type)"

    # Normalize resource type
    case "$resource_type" in
        compute|vms) resource_type="vm" ;;
        networking|vnets) resource_type="vnet" ;;
        identity|groups) resource_type="identity" ;;
        avd|hostpools) resource_type="hostpool" ;;
    esac

    # Try cache first
    if [[ -n "$resource_group" ]]; then
        log_debug "Checking cache for: $resource_name"
        local cached_result
        cached_result=$(_get_cached_resource "$resource_type" "$resource_name" "$resource_group")

        if [[ -n "$cached_result" ]] && [[ "$cached_result" != "null" ]]; then
            log_success "Cache HIT: $resource_name"
            echo "$cached_result"
            return 0
        fi
    fi

    # Cache miss - query Azure
    log_info "Cache MISS: $resource_name - querying Azure"

    local result
    result=$(query_azure_resource_by_name "$resource_type" "$resource_name" "$resource_group") || {
        log_error "Failed to query resource: $resource_name"
        return 1
    }

    if [[ -z "$result" ]] || [[ "$result" == "null" ]]; then
        log_error "Resource not found: $resource_name"
        return 1
    fi

    # Store in cache
    _store_cached_resource "$result"

    echo "$result"
}

query_resources() {
    local resource_type="${1:-all}"
    local resource_group="${2:-}"
    local output_format="${3:-summary}"

    log_info "Querying resources: type=$resource_type${resource_group:+, rg=$resource_group}, format=$output_format"

    # Normalize resource type and dispatch to specific query function
    case "$resource_type" in
        compute|vms|vm)
            query_compute_resources "$resource_group" "$output_format"
            ;;
        networking|vnets|vnet)
            query_networking_resources "$resource_group" "$output_format"
            ;;
        storage)
            query_storage_resources "$resource_group" "$output_format"
            ;;
        identity|groups|ad-group)
            query_identity_resources "$resource_group" "$output_format"
            ;;
        avd|hostpools|hostpool)
            query_avd_resources "$resource_group" "$output_format"
            ;;
        all|resources)
            query_all_resources "$resource_group" "$output_format"
            ;;
        *)
            log_error "Unknown resource type: $resource_type"
            log_error "Valid types: compute|vms, networking|vnets, storage, identity|groups, avd|hostpools, all"
            return 1
            ;;
    esac
}

# ==============================================================================
# CACHE MANAGEMENT
# ==============================================================================

invalidate_cache() {
    local pattern="${1:-*}"
    local reason="${2:-manual invalidation}"

    log_info "Invalidating cache: pattern=$pattern, reason=$reason"
    _invalidate_resource_cache "$pattern" "$reason"
}

cache_query_result() {
    local cache_key="$1"
    local result_json="$2"
    local ttl="${3:-$CACHE_TTL_RESOURCE_LIST}"

    log_debug "Caching query result: key=$cache_key, ttl=${ttl}s"

    # This will be implemented when state-manager has cache_metadata table support
    if _state_manager_available; then
        # Store in cache_metadata table
        log_debug "Storing in cache_metadata (not yet implemented)"
    fi
}

# ==============================================================================
# UTILITY FUNCTIONS
# ==============================================================================

format_resource_summary() {
    local resource_json="$1"

    echo "$resource_json" | jq -r '.[] | "\(.name) (\(.type // .resourceType // "unknown")) - \(.location) - \(.state // .provisioningState // "unknown")"'
}

count_resources_by_type() {
    local resources_json="$1"

    echo "$resources_json" | jq -r '
        group_by(.type // .resourceType // "unknown") |
        map({type: .[0].type // .[0].resourceType // "unknown", count: length}) |
        .[] | "\(.type): \(.count)"
    '
}

# ==============================================================================
# EXPORT FUNCTIONS
# ==============================================================================

export -f query_resource
export -f query_resources
export -f query_compute_resources
export -f query_networking_resources
export -f query_storage_resources
export -f query_identity_resources
export -f query_avd_resources
export -f query_all_resources
export -f query_azure_raw
export -f query_azure_resource_by_name
export -f invalidate_cache
export -f cache_query_result
export -f apply_jq_filter
export -f ensure_jq_filter_exists
export -f format_resource_summary
export -f count_resources_by_type

log_debug "Query engine loaded successfully"
