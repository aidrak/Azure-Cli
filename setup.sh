#!/bin/bash
# ============================================================================
# Azure VDI Deployment Engine - Initial Setup Script
# ============================================================================
# This script initializes a fresh clone of the repository for a new Azure
# instance. Run this once after cloning the repo.
#
# Usage:
#   ./setup.sh
# ============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
print_header() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# ============================================================================
# Main Setup
# ============================================================================

print_header "Azure VDI Deployment Engine - Initial Setup"

# Check if we're in the right directory
if [[ ! -f "core/engine.sh" ]]; then
    print_error "Error: Must be run from the azure-cli repository root"
    exit 1
fi

print_success "Repository structure verified"

# ============================================================================
# Step 1: Initialize State Files
# ============================================================================

print_header "Step 1: Initializing State Files"

if [[ -f "state.json" ]]; then
    print_warning "state.json already exists, backing up to state.json.backup"
    cp state.json "state.json.backup.$(date +%Y%m%d_%H%M%S)"
fi

cp state.json.example state.json
print_success "Created state.json from template"

if [[ -f "state.db" ]]; then
    print_warning "state.db already exists, backing up to state.db.backup"
    cp state.db "state.db.backup.$(date +%Y%m%d_%H%M%S)"
    rm state.db
fi

# Initialize SQLite database
sqlite3 state.db <<'EOF'
CREATE TABLE IF NOT EXISTS operations (
    id TEXT PRIMARY KEY,
    status TEXT NOT NULL,
    started_at TEXT,
    completed_at TEXT,
    duration INTEGER,
    exit_code INTEGER,
    error_message TEXT,
    retry_count INTEGER DEFAULT 0
);
CREATE INDEX IF NOT EXISTS idx_status ON operations(status);
CREATE INDEX IF NOT EXISTS idx_started_at ON operations(started_at);
EOF

print_success "Initialized state.db SQLite database"

# ============================================================================
# Step 2: Configuration Files
# ============================================================================

print_header "Step 2: Configuration Files"

if [[ ! -f "config.yaml" ]]; then
    cp config.yaml.example config.yaml
    print_success "Created config.yaml from template"
    print_warning "IMPORTANT: Edit config.yaml with your Azure subscription details"
else
    print_info "config.yaml already exists, skipping"
fi

if [[ ! -f "secrets.yaml" ]]; then
    cp secrets.yaml.example secrets.yaml
    print_success "Created secrets.yaml from template"
    print_warning "IMPORTANT: Edit secrets.yaml with your passwords and secrets"
else
    print_info "secrets.yaml already exists, skipping"
fi

# ============================================================================
# Step 3: Verify Azure CLI
# ============================================================================

print_header "Step 3: Verifying Prerequisites"

if ! command -v az &> /dev/null; then
    print_error "Azure CLI not found"
    print_info "Install from: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
fi

AZURE_CLI_VERSION=$(az version --query '"azure-cli"' -o tsv)
print_success "Azure CLI installed (version: ${AZURE_CLI_VERSION})"

if ! command -v jq &> /dev/null; then
    print_warning "jq not found (optional but recommended for query operations)"
    print_info "Install with: sudo apt-get install jq (Ubuntu/Debian)"
else
    print_success "jq installed"
fi

if ! command -v sqlite3 &> /dev/null; then
    print_warning "sqlite3 not found (required for state database)"
    print_error "Install with: sudo apt-get install sqlite3 (Ubuntu/Debian)"
    exit 1
fi

print_success "sqlite3 installed"

# ============================================================================
# Step 4: Azure Login Check
# ============================================================================

print_header "Step 4: Azure Authentication"

if az account show &> /dev/null; then
    SUBSCRIPTION_NAME=$(az account show --query name -o tsv)
    SUBSCRIPTION_ID=$(az account show --query id -o tsv)
    print_success "Already logged in to Azure"
    print_info "Subscription: ${SUBSCRIPTION_NAME} (${SUBSCRIPTION_ID})"
else
    print_warning "Not logged in to Azure"
    print_info "Run 'az login' to authenticate"
fi

# ============================================================================
# Step 5: Directory Structure
# ============================================================================

print_header "Step 5: Setting Up Directory Structure"

# Directories that must exist (from git)
REQUIRED_DIRS=(
    "core"
    "capabilities"
    "docs"
    "queries"
)

for dir in "${REQUIRED_DIRS[@]}"; do
    if [[ -d "$dir" ]]; then
        print_success "Directory exists: $dir"
    else
        print_error "Missing directory: $dir (git repository may be incomplete)"
        exit 1
    fi
done

# Create runtime directories (gitignored)
RUNTIME_DIRS=(
    "artifacts"
    "artifacts/logs"
    "artifacts/temp"
    "artifacts/workflow-logs"
    "artifacts/workflow-state"
)

for dir in "${RUNTIME_DIRS[@]}"; do
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
        print_success "Created runtime directory: $dir"
    else
        print_info "Runtime directory exists: $dir"
    fi
done

# ============================================================================
# Setup Complete
# ============================================================================

print_header "Setup Complete!"

echo ""
print_success "Repository initialized and ready for deployment"
echo ""
print_info "Next steps:"
echo "  1. Edit config.yaml with your Azure subscription details"
echo "  2. Edit secrets.yaml with your passwords (if needed)"
echo "  3. Login to Azure: az login"
echo "  4. Load configuration: source core/config-manager.sh && load_config"
echo "  5. List operations: ./core/engine.sh list"
echo "  6. Run operation: ./core/engine.sh run <operation-id>"
echo ""
print_info "Documentation: docs/README.md"
print_info "Quick start: QUICKSTART.md"
echo ""
