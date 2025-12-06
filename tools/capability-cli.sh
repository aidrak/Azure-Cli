#!/bin/bash
# ==============================================================================
# Capability CLI Tool
# ==============================================================================
# Helper tool for managing capabilities and operations
# ==============================================================================

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENGINE_SCRIPT="${PROJECT_ROOT}/core/engine.sh"

show_help() {
    echo "Capability CLI"
    echo ""
    echo "Usage:"
    echo "  $0 list                     List all capabilities and operations"
    echo "  $0 show <operation-id>      Show details of an operation"
    echo "  $0 validate <operation-id>  Validate operation schema"
    echo "  $0 create <capability>      Create a new capability"
    echo ""
}

list_capabilities() {
    "$ENGINE_SCRIPT" list
}

show_operation() {
    local op_id="$1"
    local found=0
    
    # Search all capability dirs
    for d in "${PROJECT_ROOT}/capabilities"/*; do
        if [[ -d "$d" ]]; then
            for f in "$d"/operations/*.yaml; do
                if [[ -f "$f" ]]; then
                    local id=$(yq e '.operation.id' "$f" 2>/dev/null)
                    if [[ "$id" == "$op_id" ]]; then
                        echo "File: $f"
                        echo "----------------------------------------"
                        cat "$f"
                        echo "----------------------------------------"
                        found=1
                        break 2
                    fi
                fi
            done
        fi
    done

    if [[ $found -eq 0 ]]; then
        echo "Operation not found: $op_id"
        exit 1
    fi
}

validate_operation() {
    local op_id="$1"
    # Reuse the validation script
    "${PROJECT_ROOT}/scripts/validate-operations.sh" | grep "$op_id"
}

create_capability() {
    local cap_name="$1"
    local cap_dir="${PROJECT_ROOT}/capabilities/$cap_name"
    
    if [[ -d "$cap_dir" ]]; then
        echo "Capability already exists: $cap_name"
        exit 1
    fi
    
    mkdir -p "$cap_dir/operations"
    
    # Create capability.yaml
    cat > "$cap_dir/capability.yaml" <<EOF
capability:
  id: "$cap_name"
  name: "$(tr '[:lower:]' '[:upper:]' <<< ${cap_name:0:1})${cap_name:1}"
  description: "Operations for $cap_name"
  version: "1.0.0"
EOF
    
    echo "Created capability: $cap_name at $cap_dir"
}

case "${1:-}" in
    list)
        list_capabilities
        ;;
    show)
        [[ -z "${2:-}" ]] && show_help && exit 1
        show_operation "$2"
        ;;
    validate)
        [[ -z "${2:-}" ]] && show_help && exit 1
        validate_operation "$2"
        ;;
    create)
        [[ -z "${2:-}" ]] && show_help && exit 1
        create_capability "$2"
        ;;
    *)
        show_help
        exit 1
        ;;
esac
