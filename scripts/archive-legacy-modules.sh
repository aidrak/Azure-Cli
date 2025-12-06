#!/bin/bash
# ==============================================================================
# Archive Legacy Modules
# ==============================================================================
# Moves legacy modules to the archive location
# ==============================================================================

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODULES_DIR="${PROJECT_ROOT}/modules"
LEGACY_DIR="${PROJECT_ROOT}/legacy/modules"

mkdir -p "$LEGACY_DIR"

echo "Archiving legacy modules..."

if [[ -d "$MODULES_DIR" ]]; then
    # Move all contents of modules/ to legacy/modules/
    mv "${MODULES_DIR}"/* "${LEGACY_DIR}/" 2>/dev/null || true
    
    # Remove empty modules dir
    rmdir "$MODULES_DIR" 2>/dev/null || true
    
    echo "Moved modules to $LEGACY_DIR"
else
    echo "Modules directory not found (already archived?)"
fi

# Create README in legacy dir
cat > "${PROJECT_ROOT}/legacy/README.md" <<EOF
# Legacy Modules Archive

This directory contains the deprecated module-based operation system.
The project has migrated to the Capability System (see `capabilities/`).

## Migration Status
- Migration Date: $(date +%Y-%m-%d)
- All operations have been ported to `capabilities/`
- See `MIGRATION-INDEX.md` for mapping
EOF

echo "Archive complete."
