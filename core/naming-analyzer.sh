#!/bin/bash
# ==============================================================================
# Naming Analyzer - Pattern Discovery and Name Generation
# ==============================================================================
#
# Purpose: Analyze existing Azure resources to discover naming conventions
#          and propose names for new resources following those patterns.
#
# Usage:
#   source core/naming-analyzer.sh
#   analyze_naming_patterns "Microsoft.Network/virtualNetworks" "RG-Azure-VDI-01"
#   propose_name "vnet" '{"purpose": "avd", "env": "prod"}'
#
# ==============================================================================

set -euo pipefail

# Project paths
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
STANDARDS_FILE="${PROJECT_ROOT}/standards.yaml"
STATE_DB="${PROJECT_ROOT}/state.db"

# Source dependencies
source "${PROJECT_ROOT}/core/logger.sh" 2>/dev/null || true

# ==============================================================================
# PATTERN EXTRACTION
# ==============================================================================

# Extract naming pattern components from a list of resource names
# Usage: extract_pattern_components "name1 name2 name3"
# Returns: JSON with prefix, separator, suffix_type, confidence
extract_pattern_components() {
    local names_input="$1"
    local names
    IFS=' ' read -ra names <<< "$names_input"

    local count=${#names[@]}
    if [[ $count -lt 2 ]]; then
        echo '{"prefix":"","separator":"-","suffix_type":"numeric","confidence":0.0}'
        return 0
    fi

    # Detect common prefix
    local prefix=""
    local first_name="${names[0]}"
    local min_len=${#first_name}

    for name in "${names[@]}"; do
        [[ ${#name} -lt $min_len ]] && min_len=${#name}
    done

    for ((i=0; i<min_len; i++)); do
        local char="${first_name:$i:1}"
        local all_match=true

        for name in "${names[@]}"; do
            if [[ "${name:$i:1}" != "$char" ]]; then
                all_match=false
                break
            fi
        done

        if $all_match; then
            prefix+="$char"
        else
            break
        fi
    done

    # Trim trailing separators from prefix
    prefix="${prefix%-}"
    prefix="${prefix%_}"

    # Detect separator (most common: -, _, none)
    local dash_count=0
    local underscore_count=0

    for name in "${names[@]}"; do
        [[ "$name" == *-* ]] && ((dash_count++)) || true
        [[ "$name" == *_* ]] && ((underscore_count++)) || true
    done

    local separator="-"
    if [[ $underscore_count -gt $dash_count ]]; then
        separator="_"
    elif [[ $dash_count -eq 0 && $underscore_count -eq 0 ]]; then
        separator=""
    fi

    # Detect suffix type (numeric, random, none)
    local numeric_suffix_count=0
    local random_suffix_count=0

    for name in "${names[@]}"; do
        # Check for numeric suffix (e.g., -01, -001, 1, 01)
        if [[ "$name" =~ [0-9]+$ ]]; then
            ((numeric_suffix_count++))
        # Check for random alphanumeric suffix (5+ chars)
        elif [[ "$name" =~ [a-z0-9]{5,}$ ]]; then
            ((random_suffix_count++))
        fi
    done

    local suffix_type="none"
    if [[ $numeric_suffix_count -gt $((count / 2)) ]]; then
        suffix_type="numeric"
    elif [[ $random_suffix_count -gt $((count / 2)) ]]; then
        suffix_type="random"
    fi

    # Calculate confidence based on pattern consistency (using awk instead of bc)
    local confidence
    if [[ -n "$prefix" && ${#prefix} -gt 2 ]]; then
        confidence=$(awk "BEGIN {c = 0.5 + ($count / 20); if (c > 1.0) c = 1.0; printf \"%.2f\", c}")
    else
        confidence=$(awk "BEGIN {c = 0.3 + ($count / 30); if (c > 0.7) c = 0.7; printf \"%.2f\", c}")
    fi

    # Output JSON
    cat <<EOF
{"prefix":"$prefix","separator":"$separator","suffix_type":"$suffix_type","confidence":$confidence,"sample_count":$count}
EOF
}

# ==============================================================================
# AZURE DISCOVERY
# ==============================================================================

# Query Azure for resources of a specific type and analyze naming patterns
# Usage: analyze_naming_patterns "Microsoft.Network/virtualNetworks" "RG-Name"
analyze_naming_patterns() {
    local resource_type="$1"
    local resource_group="${2:-}"

    echo "[*] Analyzing naming patterns for: $resource_type" >&2

    # Build Azure CLI query
    local az_cmd="az resource list --resource-type \"$resource_type\" --query \"[].name\" -o tsv"
    if [[ -n "$resource_group" ]]; then
        az_cmd="az resource list --resource-type \"$resource_type\" --resource-group \"$resource_group\" --query \"[].name\" -o tsv"
    fi

    # Execute query
    local names
    names=$(eval "$az_cmd" 2>/dev/null) || {
        echo "[!] Failed to query Azure for $resource_type" >&2
        echo '{"prefix":"","separator":"-","suffix_type":"numeric","confidence":0.0}'
        return 1
    }

    if [[ -z "$names" ]]; then
        echo "[i] No existing resources found for $resource_type" >&2
        echo '{"prefix":"","separator":"-","suffix_type":"numeric","confidence":0.0}'
        return 0
    fi

    # Convert newlines to spaces
    names=$(echo "$names" | tr '\n' ' ')

    # Extract pattern
    local pattern
    pattern=$(extract_pattern_components "$names")

    echo "[v] Discovered pattern: $pattern" >&2

    # Cache pattern in state.db if available
    if [[ -f "$STATE_DB" ]]; then
        cache_naming_pattern "$resource_type" "$resource_group" "$pattern"
    fi

    echo "$pattern"
}

# ==============================================================================
# PATTERN CACHING
# ==============================================================================

# Cache discovered naming pattern in state.db
cache_naming_pattern() {
    local resource_type="$1"
    local resource_group="${2:-}"
    local pattern_json="$3"

    [[ ! -f "$STATE_DB" ]] && return 0

    local prefix separator suffix_type confidence sample_count
    prefix=$(echo "$pattern_json" | jq -r '.prefix // ""')
    separator=$(echo "$pattern_json" | jq -r '.separator // "-"')
    suffix_type=$(echo "$pattern_json" | jq -r '.suffix_type // "numeric"')
    confidence=$(echo "$pattern_json" | jq -r '.confidence // 0.0')
    sample_count=$(echo "$pattern_json" | jq -r '.sample_count // 0')

    # Construct the pattern template
    local pattern_template
    if [[ -n "$prefix" ]]; then
        pattern_template="${prefix}${separator}{purpose}${separator}{number}"
    else
        pattern_template="{type}${separator}{purpose}${separator}{number}"
    fi

    local now
    now=$(date +%s)

    sqlite3 "$STATE_DB" <<EOF
INSERT OR REPLACE INTO naming_patterns
    (resource_type, resource_group, pattern, prefix, separator, suffix_type, sample_count, confidence, discovered_at)
VALUES
    ('$resource_type', '$resource_group', '$pattern_template', '$prefix', '$separator', '$suffix_type', $sample_count, $confidence, $now);
EOF

    echo "[v] Cached naming pattern for $resource_type" >&2
}

# Get cached naming pattern from state.db
# Usage: get_cached_pattern "Microsoft.Network/virtualNetworks" "RG-Name"
get_cached_pattern() {
    local resource_type="$1"
    local resource_group="${2:-}"

    [[ ! -f "$STATE_DB" ]] && return 1

    # Check if table exists
    local table_exists
    table_exists=$(sqlite3 "$STATE_DB" "SELECT name FROM sqlite_master WHERE type='table' AND name='naming_patterns';" 2>/dev/null)
    [[ -z "$table_exists" ]] && return 1

    local cache_ttl=1800  # 30 minutes
    local now
    now=$(date +%s)
    local min_time=$((now - cache_ttl))

    local result
    if [[ -n "$resource_group" ]]; then
        result=$(sqlite3 -json "$STATE_DB" \
            "SELECT * FROM naming_patterns
             WHERE resource_type = '$resource_type'
             AND resource_group = '$resource_group'
             AND discovered_at > $min_time
             LIMIT 1;" 2>/dev/null) || result=""
    else
        result=$(sqlite3 -json "$STATE_DB" \
            "SELECT * FROM naming_patterns
             WHERE resource_type = '$resource_type'
             AND (resource_group IS NULL OR resource_group = '')
             AND discovered_at > $min_time
             LIMIT 1;" 2>/dev/null) || result=""
    fi

    if [[ -n "$result" && "$result" != "[]" ]] && echo "$result" | jq -e '.[0]' >/dev/null 2>&1; then
        echo "$result" | jq '.[0]'
        return 0
    fi

    return 1
}

# ==============================================================================
# NAME GENERATION
# ==============================================================================

# Get the next available number for a resource name pattern
# Usage: get_next_number "avd-sh" "Microsoft.Compute/virtualMachines" "RG-Name"
get_next_number() {
    local prefix="$1"
    local resource_type="$2"
    local resource_group="${3:-}"

    # Query Azure for existing resources with this prefix
    local az_cmd="az resource list --resource-type \"$resource_type\" --query \"[?starts_with(name, '$prefix')].name\" -o tsv"
    if [[ -n "$resource_group" ]]; then
        az_cmd="az resource list --resource-type \"$resource_type\" --resource-group \"$resource_group\" --query \"[?starts_with(name, '$prefix')].name\" -o tsv"
    fi

    local names
    names=$(eval "$az_cmd" 2>/dev/null) || names=""

    if [[ -z "$names" ]]; then
        echo "01"
        return 0
    fi

    # Extract numbers and find highest
    local max_num=0
    while IFS= read -r name; do
        # Extract trailing numbers
        if [[ "$name" =~ ([0-9]+)$ ]]; then
            local num="${BASH_REMATCH[1]}"
            # Remove leading zeros for comparison
            num=$((10#$num))
            [[ $num -gt $max_num ]] && max_num=$num
        fi
    done <<< "$names"

    # Return next number with zero-padding
    printf "%02d" $((max_num + 1))
}

# Generate a random suffix (for storage accounts, etc.)
generate_random_suffix() {
    local length="${1:-5}"
    head /dev/urandom | tr -dc 'a-z0-9' | head -c "$length"
}

# Propose a name for a new resource
# Usage: propose_name "vnet" '{"purpose":"avd","env":"prod"}' "RG-Name"
propose_name() {
    local resource_type_friendly="$1"
    local context_json="${2:-"{}"}"
    local resource_group="${3:-${AZURE_RESOURCE_GROUP:-}}"

    # Map friendly name to Azure resource type
    local azure_resource_type
    azure_resource_type=$(get_azure_resource_type "$resource_type_friendly")

    # Try to get cached pattern first
    local pattern
    pattern=$(get_cached_pattern "$azure_resource_type" "$resource_group" 2>/dev/null) || pattern=""

    # If no cached pattern, analyze from Azure
    if [[ -z "$pattern" || "$pattern" == "null" ]]; then
        pattern=$(analyze_naming_patterns "$azure_resource_type" "$resource_group" 2>/dev/null) || pattern=""
    fi

    # Extract pattern components (with fallback for invalid/empty JSON)
    local prefix="" separator="-" suffix_type="numeric" confidence="0.0"
    if [[ -n "$pattern" ]] && echo "$pattern" | jq -e . >/dev/null 2>&1; then
        prefix=$(echo "$pattern" | jq -r '.prefix // ""')
        separator=$(echo "$pattern" | jq -r '.separator // "-"')
        suffix_type=$(echo "$pattern" | jq -r '.suffix_type // "numeric"')
        confidence=$(echo "$pattern" | jq -r '.confidence // 0.0')
    fi

    # Extract context values
    local purpose env project
    purpose=$(echo "$context_json" | jq -r '.purpose // "default"')
    env=$(echo "$context_json" | jq -r '.env // "prod"')
    project=$(echo "$context_json" | jq -r '.project // "avd"')

    # If low confidence or no pattern, use standards.yaml default
    # Use awk for float comparison (bc may not be installed)
    if [[ -z "$confidence" || "$confidence" == "null" ]] || awk "BEGIN {exit !($confidence < 0.5)}"; then
        prefix=$(get_standard_prefix "$resource_type_friendly")
        separator="-"
    fi

    # Build the name
    local proposed_name=""

    case "$resource_type_friendly" in
        storage_account|storage)
            # Storage accounts have special naming: 3-24 chars, lowercase alphanumeric only
            local storage_prefix
            storage_prefix=$(get_standard_prefix "storage_account")
            proposed_name="${storage_prefix}$(generate_random_suffix 5)"
            proposed_name=$(echo "$proposed_name" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9')
            ;;
        vm|session_host)
            if [[ -n "$prefix" ]]; then
                local next_num
                next_num=$(get_next_number "$prefix" "$azure_resource_type" "$resource_group")
                proposed_name="${prefix}${separator}${next_num}"
            else
                local vm_prefix
                vm_prefix=$(get_standard_prefix "session_host")
                local next_num
                next_num=$(get_next_number "$vm_prefix" "$azure_resource_type" "$resource_group")
                proposed_name="${vm_prefix}${separator}${next_num}"
            fi
            ;;
        *)
            if [[ -n "$prefix" ]]; then
                proposed_name="${prefix}${separator}${purpose}"
            else
                local type_prefix
                type_prefix=$(get_standard_prefix "$resource_type_friendly")
                if [[ -n "$type_prefix" ]]; then
                    proposed_name="${type_prefix}${separator}${purpose}${separator}${env}"
                else
                    proposed_name="${resource_type_friendly}${separator}${purpose}${separator}${env}"
                fi
            fi
            ;;
    esac

    echo "$proposed_name"
}

# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

# Map friendly resource type to Azure resource type
get_azure_resource_type() {
    local friendly_name="$1"

    case "$friendly_name" in
        vnet|virtual_network)
            echo "Microsoft.Network/virtualNetworks"
            ;;
        subnet)
            echo "Microsoft.Network/virtualNetworks/subnets"
            ;;
        nsg|network_security_group)
            echo "Microsoft.Network/networkSecurityGroups"
            ;;
        storage_account|storage)
            echo "Microsoft.Storage/storageAccounts"
            ;;
        vm|virtual_machine|session_host)
            echo "Microsoft.Compute/virtualMachines"
            ;;
        nic|network_interface)
            echo "Microsoft.Network/networkInterfaces"
            ;;
        disk)
            echo "Microsoft.Compute/disks"
            ;;
        public_ip|pip)
            echo "Microsoft.Network/publicIPAddresses"
            ;;
        host_pool)
            echo "Microsoft.DesktopVirtualization/hostPools"
            ;;
        workspace)
            echo "Microsoft.DesktopVirtualization/workspaces"
            ;;
        app_group|application_group)
            echo "Microsoft.DesktopVirtualization/applicationGroups"
            ;;
        gallery|compute_gallery)
            echo "Microsoft.Compute/galleries"
            ;;
        image_definition)
            echo "Microsoft.Compute/galleries/images"
            ;;
        resource_group|rg)
            echo "Microsoft.Resources/resourceGroups"
            ;;
        *)
            echo "$friendly_name"
            ;;
    esac
}

# Get standard prefix from standards.yaml
get_standard_prefix() {
    local resource_type="$1"

    if [[ -f "$STANDARDS_FILE" ]]; then
        local prefix
        prefix=$(yq e ".naming.prefixes.$resource_type // \"\"" "$STANDARDS_FILE" 2>/dev/null)
        if [[ -n "$prefix" && "$prefix" != "null" ]]; then
            echo "$prefix"
            return 0
        fi
    fi

    # Fallback defaults
    case "$resource_type" in
        storage_account|storage) echo "fslogix" ;;
        session_host|vm) echo "avd-sh" ;;
        golden_image) echo "gm" ;;
        vnet|virtual_network) echo "vnet" ;;
        subnet) echo "snet" ;;
        nsg) echo "nsg" ;;
        host_pool) echo "hp" ;;
        workspace) echo "ws" ;;
        app_group) echo "dag" ;;
        *) echo "" ;;
    esac
}

# Get standard pattern from standards.yaml
get_standard_pattern() {
    local resource_type="$1"

    if [[ -f "$STANDARDS_FILE" ]]; then
        local pattern
        pattern=$(yq e ".naming.patterns.$resource_type // \"\"" "$STANDARDS_FILE" 2>/dev/null)
        if [[ -n "$pattern" && "$pattern" != "null" ]]; then
            echo "$pattern"
            return 0
        fi
    fi

    # Fallback default pattern
    echo "{type}-{purpose}-{env}"
}

# ==============================================================================
# INTERACTIVE FUNCTIONS
# ==============================================================================

# Propose name and ask user for confirmation
# Usage: propose_and_confirm "vnet" '{"purpose":"avd"}' "RG-Name"
propose_and_confirm() {
    local resource_type="$1"
    local context_json="${2:-"{}"}"
    local resource_group="${3:-}"

    local proposed
    proposed=$(propose_name "$resource_type" "$context_json" "$resource_group")

    echo "" >&2
    echo "[i] Proposed name for $resource_type: $proposed" >&2
    echo "" >&2

    if [[ "${INTERACTIVE_MODE:-true}" == "true" ]]; then
        read -r -p "Accept this name? [Y/n/custom]: " response
        case "$response" in
            [nN]*)
                read -r -p "Enter custom name: " custom_name
                echo "$custom_name"
                ;;
            "")
                echo "$proposed"
                ;;
            [yY]*)
                echo "$proposed"
                ;;
            *)
                # User entered a custom name directly
                echo "$response"
                ;;
        esac
    else
        echo "$proposed"
    fi
}

# ==============================================================================
# Export functions
# ==============================================================================
export -f extract_pattern_components
export -f analyze_naming_patterns
export -f cache_naming_pattern
export -f get_cached_pattern
export -f get_next_number
export -f generate_random_suffix
export -f propose_name
export -f get_azure_resource_type
export -f get_standard_prefix
export -f get_standard_pattern
export -f propose_and_confirm
