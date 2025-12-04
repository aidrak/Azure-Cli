#!/bin/bash

################################################################################
# Task: Cleanup Orphaned Resources
#
# Purpose: Clean up temporary resources and orphaned objects from deployment
#
# Inputs (from config.env):
#   - RESOURCE_GROUP_NAME
#   - CLEANUP_TEMP_VMS
#   - CLEANUP_TEMP_IMAGES
#   - DRY_RUN
#
# Outputs:
#   - Resources cleaned up
#   - Cleanup report saved to artifacts/
#
# Duration: 5-10 minutes
# Idempotent: Yes
#
# WARNING: This task can delete resources. Use DRY_RUN=true to preview changes.
################################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCRIPT_NAME="01-cleanup-resources"

CONFIG_FILE="${PROJECT_ROOT}/12-cleanup-migration/config.env"
[[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE" || { echo "ERROR: Config not found"; exit 1; }

ENABLE_LOGGING=1
LOG_DIR="${ARTIFACTS_DIR}"
mkdir -p "$LOG_DIR"

# Load logging functions
LOGGING_FUNCS="${PROJECT_ROOT}/common/functions/logging-functions.sh"
[[ -f "$LOGGING_FUNCS" ]] && source "$LOGGING_FUNCS" || {
    log_info() { echo "ℹ $*"; }
    log_success() { echo "✓ $*"; }
    log_error() { echo "✗ $*" >&2; }
    log_warning() { echo "⚠ $*"; }
}

log_section() { echo ""; echo "=== $1 ==="; echo ""; }

log_section "Cleaning Up Resources"

# Validate
if ! az account show &>/dev/null; then
    log_error "Not authenticated to Azure"
    exit 1
fi

if ! az group exists --name "$RESOURCE_GROUP_NAME" | grep -q "true"; then
    log_error "Resource group not found: $RESOURCE_GROUP_NAME"
    exit 1
fi

# Dry run mode
local DRY_RUN="${DRY_RUN:-false}"
if [[ "$DRY_RUN" == "true" ]]; then
    log_warning "DRY RUN MODE - No changes will be made"
fi

local resources_deleted=0
local resources_failed=0

# Find temporary VMs (those with 'temp' in name or specific patterns)
if [[ "${CLEANUP_TEMP_VMS:-false}" == "true" ]]; then
    log_info "Finding temporary VMs..."

    local temp_vms
    temp_vms=$(az vm list \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --query "[?contains(name, 'temp') || contains(name, '-tmp')].name" \
        -o tsv)

    if [[ -n "$temp_vms" ]]; then
        log_info "Found temporary VMs: $temp_vms"

        for vm in $temp_vms; do
            log_info "Preparing to delete: $vm"

            if [[ "$DRY_RUN" != "true" ]]; then
                if az vm delete \
                    --resource-group "$RESOURCE_GROUP_NAME" \
                    --name "$vm" \
                    --yes \
                    --no-wait \
                    --output none; then

                    log_success "Deleted VM: $vm"
                    ((resources_deleted++))
                else
                    log_error "Failed to delete VM: $vm"
                    ((resources_failed++))
                fi
            else
                log_info "[DRY RUN] Would delete: $vm"
                ((resources_deleted++))
            fi
        done
    else
        log_info "No temporary VMs found"
    fi
fi

# Find temporary images
if [[ "${CLEANUP_TEMP_IMAGES:-false}" == "true" ]]; then
    log_info "Finding temporary images..."

    local temp_images
    temp_images=$(az image list \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --query "[?contains(name, 'temp') || contains(name, '-tmp')].name" \
        -o tsv 2>/dev/null || echo "")

    if [[ -n "$temp_images" ]]; then
        log_info "Found temporary images: $temp_images"

        for image in $temp_images; do
            log_info "Preparing to delete: $image"

            if [[ "$DRY_RUN" != "true" ]]; then
                if az image delete \
                    --resource-group "$RESOURCE_GROUP_NAME" \
                    --name "$image" \
                    --yes \
                    --output none; then

                    log_success "Deleted image: $image"
                    ((resources_deleted++))
                else
                    log_error "Failed to delete image: $image"
                    ((resources_failed++))
                fi
            else
                log_info "[DRY RUN] Would delete: $image"
                ((resources_deleted++))
            fi
        done
    else
        log_info "No temporary images found"
    fi
fi

# Find unattached disks
log_info "Finding unattached disks..."

local unattached_disks
unattached_disks=$(az disk list \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --query "[?managedBy == null].name" \
    -o tsv 2>/dev/null || echo "")

local orphaned_disk_count=0

if [[ -n "$unattached_disks" ]]; then
    log_info "Found unattached disks"

    for disk in $unattached_disks; do
        # Skip OS disks and boot disks
        if [[ ! "$disk" =~ "-OsDisk" ]]; then
            log_info "Unattached disk: $disk"
            ((orphaned_disk_count++))
        fi
    done
fi

# Save cleanup report
{
    echo "Cleanup Report"
    echo "=============="
    echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
    echo ""
    echo "Execution Mode: $([ "$DRY_RUN" = "true" ] && echo "DRY RUN" || echo "LIVE")"
    echo ""
    echo "Cleanup Summary:"
    echo "  Resources processed: $resources_deleted"
    echo "  Resources failed: $resources_failed"
    echo "  Orphaned disks found: $orphaned_disk_count"
    echo ""
    echo "Cleanup Options:"
    echo "  Clean temp VMs: ${CLEANUP_TEMP_VMS:-false}"
    echo "  Clean temp images: ${CLEANUP_TEMP_IMAGES:-false}"
    echo ""
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "DRY RUN NOTE: Run with DRY_RUN=false to actually delete resources"
    fi
    echo ""
    echo "Next Steps:"
    echo "  1. Verify all resources are properly cleaned"
    echo "  2. Check for orphaned disks in Azure Portal"
    echo "  3. Monitor costs after cleanup"
    echo "  4. Verify users can still access AVD resources"
    echo ""
    echo "Cost Optimization:"
    echo "  - Deleted temporary resources"
    echo "  - Removed unattached disks"
    echo "  - Consider review of resource group for unused items"
    echo ""
} > "${LOG_DIR}/${SCRIPT_NAME}-report.txt"

if [[ $resources_failed -gt 0 ]]; then
    log_error "Cleanup encountered errors: $resources_failed failed"
    exit 1
fi

log_success "Cleanup completed successfully"
exit 0
