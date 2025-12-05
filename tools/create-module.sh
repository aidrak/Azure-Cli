#!/bin/bash
# ==============================================================================
# Module Template Generator
# ==============================================================================
#
# Usage: ./tools/create-module.sh [MODULE_ID] "[MODULE_NAME]"
#
# Example: ./tools/create-module.sh 06 "Session Host Deployment"
#
# ==============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Usage function
usage() {
    echo "Usage: $0 [MODULE_ID] \"[MODULE_NAME]\""
    echo ""
    echo "Arguments:"
    echo "  MODULE_ID     Two-digit module ID (e.g., 06)"
    echo "  MODULE_NAME   Human-readable module name (e.g., \"Session Host Deployment\")"
    echo ""
    echo "Example:"
    echo "  $0 06 \"Session Host Deployment\""
    echo ""
    echo "Creates:"
    echo "  modules/[ID]-[slug]/"
    echo "  ├── module.yaml"
    echo "  └── operations/"
    echo "      └── 01-example-operation.yaml"
    exit 1
}

# Check arguments
if [ $# -ne 2 ]; then
    usage
fi

MODULE_ID="$1"
MODULE_NAME="$2"

# Validate module ID format
if ! [[ "$MODULE_ID" =~ ^[0-9]{2}$ ]]; then
    echo -e "${RED}Error: MODULE_ID must be a two-digit number (e.g., 06)${NC}"
    exit 1
fi

# Generate module slug (lowercase, hyphenated)
MODULE_SLUG=$(echo "$MODULE_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
MODULE_DIR="modules/${MODULE_ID}-${MODULE_SLUG}"

# Check if module already exists
if [ -d "$MODULE_DIR" ]; then
    echo -e "${RED}Error: Module directory already exists: $MODULE_DIR${NC}"
    exit 1
fi

echo -e "${BLUE}Creating new module: ${MODULE_ID}-${MODULE_SLUG}${NC}"

# Create module directory structure
mkdir -p "$MODULE_DIR/operations"

# Create module.yaml
cat > "$MODULE_DIR/module.yaml" <<EOF
# ==============================================================================
# Module ${MODULE_ID}: ${MODULE_NAME}
# ==============================================================================

module:
  id: "${MODULE_ID}-${MODULE_SLUG}"
  name: "${MODULE_NAME}"
  description: "Description of ${MODULE_NAME}"

  operations:
    - id: "${MODULE_SLUG}-example-operation"
      name: "Example Operation"
      duration: 120
      type: "NORMAL"

  validation:
    enabled: true
    checks:
      - type: "resource_exists"
        resource: "example"
        name: "{{EXAMPLE_RESOURCE_NAME}}"

  dependencies:
    # List module IDs that must be completed before this module
    - "01-networking"
    - "02-storage"

  rollback:
    enabled: false
    # Define rollback steps if needed
EOF

# Create example operation template
cat > "$MODULE_DIR/operations/01-example-operation.yaml" <<'EOF'
# ==============================================================================
# Example Operation Template
# ==============================================================================

operation:
  id: "MODULE_SLUG-example-operation"
  name: "Example Operation"

  duration:
    expected: 120       # Expected duration in seconds
    timeout: 240        # Timeout threshold (2x expected)
    type: "NORMAL"      # FAST, NORMAL, SLOW

  template:
    type: "az-vm-run-command"
    command: |
      az vm run-command invoke \
        --resource-group "{{AZURE_RESOURCE_GROUP}}" \
        --name "{{EXAMPLE_VM_NAME}}" \
        --command-id RunPowerShellScript \
        --scripts "@modules/MODULE_ID-MODULE_SLUG/operations/01-example-operation.ps1"

  powershell:
    content: |
      # ==============================================================================
      # Example PowerShell Script
      # ==============================================================================

      Write-Host "[START] Example operation: $(Get-Date -Format 'HH:mm:ss')"

      try {
          # Step 1: Example task
          Write-Host "[PROGRESS] Step 1/3: Performing example task..."
          # Add your PowerShell code here

          # Step 2: Example validation
          Write-Host "[PROGRESS] Step 2/3: Validating..."
          # Add validation code here

          # Step 3: Completion
          Write-Host "[PROGRESS] Step 3/3: Finalizing..."
          # Add finalization code here

          Write-Host "[VALIDATE] Checking results..."
          # Add validation checks here

          Write-Host "[SUCCESS] Example operation completed successfully"
          exit 0

      } catch {
          Write-Host "[ERROR] Failed: $_"
          exit 1
      }

  validation:
    enabled: true
    checks:
      - type: "file_exists"
        path: "C:\\Example\\file.txt"
      - type: "registry_key_exists"
        path: "HKLM:\\SOFTWARE\\Example"

  fixes:
    # Auto-populated by error handler on failures
    # Example fix entry:
    # - issue: "Connection timeout"
    #   detected: "2025-12-04"
    #   fix: "Increased timeout value to 120 seconds"
    #   applied_to_template: true
EOF

# Replace placeholders in operation template
sed -i "s/MODULE_SLUG/${MODULE_SLUG}/g" "$MODULE_DIR/operations/01-example-operation.yaml"
sed -i "s/MODULE_ID/${MODULE_ID}/g" "$MODULE_DIR/operations/01-example-operation.yaml"

echo -e "${GREEN}✓ Created module directory: $MODULE_DIR${NC}"
echo -e "${GREEN}✓ Created module definition: $MODULE_DIR/module.yaml${NC}"
echo -e "${GREEN}✓ Created example operation: $MODULE_DIR/operations/01-example-operation.yaml${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo ""
echo "1. Edit module.yaml:"
echo "   - Update description"
echo "   - Define operations"
echo "   - Configure validation checks"
echo "   - Set dependencies"
echo ""
echo "2. Create operation templates in operations/"
echo "   - Copy 01-example-operation.yaml as template"
echo "   - Update IDs, names, and PowerShell code"
echo ""
echo "3. Add configuration to config.yaml:"
echo "   ${MODULE_SLUG}:"
echo "     # Add module-specific configuration here"
echo ""
echo "4. Execute module:"
echo "   source core/config-manager.sh && load_config"
echo "   ./core/engine.sh run ${MODULE_ID}-${MODULE_SLUG}"
echo ""
echo -e "${BLUE}Module created successfully!${NC}"
