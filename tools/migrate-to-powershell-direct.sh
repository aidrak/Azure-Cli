#!/bin/bash
# ==============================================================================
# Migration Script: Convert powershell-local wrappers to powershell-direct
# ==============================================================================
#
# Purpose: Remove bash heredoc wrappers and use clean PowerShell-direct pattern
#
# Usage:
#   ./tools/migrate-to-powershell-direct.sh [file.yaml]
#   ./tools/migrate-to-powershell-direct.sh --all
#
# ==============================================================================

set -uo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ==============================================================================
# Migrate Single File
# ==============================================================================
migrate_file() {
    local yaml_file="$1"

    if [[ ! -f "$yaml_file" ]]; then
        echo "[x] File not found: $yaml_file"
        return 1
    fi

    # Check if this file uses powershell-local
    local template_type
    template_type=$(yq e '.operation.template.type' "$yaml_file")

    if [[ "$template_type" != "powershell-local" ]]; then
        echo "[i] Skipping $yaml_file (not powershell-local)"
        return 0
    fi

    echo "[*] Migrating: $yaml_file"

    # Create backup
    cp "$yaml_file" "${yaml_file}.bak"

    # Extract PowerShell content using awk
    # This extracts everything between the first line after << 'PSWRAPPER'
    # and the line before the closing PSWRAPPER
    # Then removes leading indentation (6 spaces from YAML)
    local ps_temp="/tmp/migrate-ps-$$.ps1"

    awk '
        /<<.*PSWRAPPER/ { in_ps=1; next }
        in_ps && /^[[:space:]]*PSWRAPPER$/ { in_ps=0; next }
        in_ps { sub(/^      /, ""); print }
    ' "$yaml_file" > "$ps_temp"

    # Check if we extracted anything
    if [[ ! -s "$ps_temp" ]]; then
        echo "[!] WARNING: Could not extract PowerShell content from $yaml_file"
        rm -f "$ps_temp" "${yaml_file}.bak"
        return 0
    fi

    # Update the YAML file
    # 1. Change type to powershell-direct
    yq e -i '.operation.template.type = "powershell-direct"' "$yaml_file"

    # 2. Remove the old command field
    yq e -i 'del(.operation.template.command)' "$yaml_file"

    # 3. Add powershell.content field (this will create the section if it doesn't exist)
    yq e -i ".operation.powershell.content = load_str(\"$ps_temp\")" "$yaml_file"

    # Cleanup
    rm -f "$ps_temp" "${yaml_file}.bak"

    echo "[v] Migrated: $yaml_file"
    return 0
}

# ==============================================================================
# Migrate All Files
# ==============================================================================
migrate_all() {
    echo "[*] Finding all powershell-local operations..."

    local count=0
    local migrated=0
    local failed=0
    local files=()

    # Find all files
    while IFS= read -r yaml_file; do
        files+=("$yaml_file")
    done < <(find "${PROJECT_ROOT}/capabilities" -name "*.yaml" -type f)

    echo "[*] Found ${#files[@]} YAML files to scan"

    for yaml_file in "${files[@]}"; do
        local template_type
        template_type=$(yq e '.operation.template.type' "$yaml_file" 2>/dev/null || echo "")

        if [[ "$template_type" == "powershell-local" ]]; then
            ((count++))

            if migrate_file "$yaml_file"; then
                ((migrated++))
            else
                ((failed++))
                echo "[x] Failed to migrate: $yaml_file"
            fi
        fi
    done

    echo ""
    echo "===================================================================="
    echo "  Migration Complete"
    echo "===================================================================="
    echo "Total files scanned: $count"
    echo "Successfully migrated: $migrated"
    echo "Failed: $failed"
    echo "===================================================================="
}

# ==============================================================================
# Main
# ==============================================================================
main() {
    if [[ $# -eq 0 ]]; then
        echo "Usage: $0 [file.yaml] | --all"
        echo ""
        echo "Examples:"
        echo "  $0 capabilities/storage/operations/account-create.yaml"
        echo "  $0 --all"
        exit 1
    fi

    if [[ "$1" == "--all" ]]; then
        migrate_all
    else
        migrate_file "$1"
    fi
}

main "$@"
