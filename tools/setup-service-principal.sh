#!/bin/bash
# ==============================================================================
# Service Principal Setup for Claude Code Automation
# ==============================================================================
#
# Purpose: Creates and configures a service principal with certificate
#          authentication for automated Azure and MS Graph operations
#
# Usage: ./tools/setup-service-principal.sh
#
# Prerequisites:
#   - Azure CLI (az) installed and logged in
#   - OpenSSL installed
#   - PowerShell Core (pwsh) installed
#
# ==============================================================================

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CERTS_DIR="${PROJECT_ROOT}/artifacts/certs"
SECRETS_FILE="${PROJECT_ROOT}/secrets.yaml"
SP_NAME="claude-code-automation"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ==============================================================================
# Helper Functions
# ==============================================================================

log_info() {
    echo -e "${BLUE}[*]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[v]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

log_error() {
    echo -e "${RED}[x]${NC} $1"
}

confirm() {
    local prompt="$1"
    local default="${2:-n}"

    if [[ "$default" == "y" ]]; then
        read -rp "$prompt [Y/n]: " response
        [[ -z "$response" || "$response" =~ ^[Yy] ]]
    else
        read -rp "$prompt [y/N]: " response
        [[ "$response" =~ ^[Yy] ]]
    fi
}

# ==============================================================================
# Prerequisites Check
# ==============================================================================

check_prerequisites() {
    echo "========================================================================"
    echo "  Service Principal Setup for Claude Code"
    echo "========================================================================"
    echo ""

    log_info "Checking prerequisites..."

    local missing=()

    # Check Azure CLI
    if ! command -v az &>/dev/null; then
        missing+=("Azure CLI (az)")
    else
        log_success "Azure CLI installed"
    fi

    # Check if logged in
    if ! az account show &>/dev/null; then
        log_error "Not logged into Azure CLI"
        echo ""
        echo "Please run: az login"
        exit 1
    fi
    log_success "Azure CLI authenticated"

    # Check OpenSSL
    if ! command -v openssl &>/dev/null; then
        missing+=("OpenSSL")
    else
        log_success "OpenSSL installed"
    fi

    # Check PowerShell Core
    if ! command -v pwsh &>/dev/null; then
        missing+=("PowerShell Core (pwsh)")
    else
        log_success "PowerShell Core installed"
    fi

    # Check yq for YAML manipulation
    if ! command -v yq &>/dev/null; then
        missing+=("yq (YAML processor)")
    else
        log_success "yq installed"
    fi

    if [[ ${#missing[@]} -gt 0 ]]; then
        echo ""
        log_error "Missing prerequisites:"
        for item in "${missing[@]}"; do
            echo "  - $item"
        done
        exit 1
    fi

    echo ""
}

# ==============================================================================
# Get Azure Context
# ==============================================================================

get_azure_context() {
    log_info "Getting Azure context..."

    SUBSCRIPTION_ID=$(az account show --query id -o tsv)
    SUBSCRIPTION_NAME=$(az account show --query name -o tsv)
    TENANT_ID=$(az account show --query tenantId -o tsv)

    echo ""
    echo "  Subscription: $SUBSCRIPTION_NAME"
    echo "  Subscription ID: $SUBSCRIPTION_ID"
    echo "  Tenant ID: $TENANT_ID"
    echo ""

    if ! confirm "Continue with this subscription?" "y"; then
        echo ""
        echo "To change subscription, run: az account set --subscription <name-or-id>"
        exit 0
    fi
}

# ==============================================================================
# Check for Existing Service Principal
# ==============================================================================

check_existing_sp() {
    log_info "Checking for existing service principal '$SP_NAME'..."

    EXISTING_APP_ID=$(az ad app list --display-name "$SP_NAME" --query "[0].appId" -o tsv 2>/dev/null || true)

    if [[ -n "$EXISTING_APP_ID" && "$EXISTING_APP_ID" != "null" ]]; then
        log_warning "Service principal '$SP_NAME' already exists (App ID: $EXISTING_APP_ID)"
        echo ""

        if confirm "Re-use existing service principal and add new certificate?"; then
            APP_ID="$EXISTING_APP_ID"
            REUSE_SP=true
            return 0
        elif confirm "Delete and recreate service principal?"; then
            log_info "Deleting existing service principal..."
            az ad app delete --id "$EXISTING_APP_ID"
            log_success "Deleted existing service principal"
            REUSE_SP=false
        else
            log_info "Exiting without changes"
            exit 0
        fi
    else
        log_success "No existing service principal found"
        REUSE_SP=false
    fi
}

# ==============================================================================
# Create Service Principal
# ==============================================================================

create_service_principal() {
    if [[ "${REUSE_SP:-false}" == "true" ]]; then
        log_info "Re-using existing service principal..."

        # Get existing SP object ID for role assignment check
        SP_OBJECT_ID=$(az ad sp list --filter "appId eq '$APP_ID'" --query "[0].id" -o tsv)

        # Generate client secret for Azure CLI auth
        log_info "Generating new client secret..."
        CLIENT_SECRET=$(az ad app credential reset --id "$APP_ID" --append --query password -o tsv)

    else
        echo ""
        log_info "Creating service principal '$SP_NAME'..."

        # Create with Contributor role scoped to subscription
        SP_OUTPUT=$(az ad sp create-for-rbac \
            --name "$SP_NAME" \
            --role Contributor \
            --scopes "/subscriptions/$SUBSCRIPTION_ID" \
            --query "{appId: appId, password: password, tenant: tenant}" \
            -o json)

        APP_ID=$(echo "$SP_OUTPUT" | jq -r '.appId')
        CLIENT_SECRET=$(echo "$SP_OUTPUT" | jq -r '.password')

        log_success "Service principal created"
        echo "  App ID: $APP_ID"
    fi
}

# ==============================================================================
# Generate Certificate
# ==============================================================================

generate_certificate() {
    echo ""
    log_info "Setting up certificate directory..."

    mkdir -p "$CERTS_DIR"

    CERT_KEY="${CERTS_DIR}/claude-code.key"
    CERT_CRT="${CERTS_DIR}/claude-code.crt"
    CERT_PFX="${CERTS_DIR}/claude-code.pfx"

    # Check for existing certificate
    if [[ -f "$CERT_PFX" ]]; then
        log_warning "Certificate already exists at $CERT_PFX"

        if confirm "Generate new certificate? (old one will be backed up)"; then
            BACKUP_SUFFIX=$(date +%Y%m%d_%H%M%S)
            mv "$CERT_KEY" "${CERT_KEY}.${BACKUP_SUFFIX}" 2>/dev/null || true
            mv "$CERT_CRT" "${CERT_CRT}.${BACKUP_SUFFIX}" 2>/dev/null || true
            mv "$CERT_PFX" "${CERT_PFX}.${BACKUP_SUFFIX}" 2>/dev/null || true
            log_info "Backed up existing certificates"
        else
            log_info "Using existing certificate"

            # Get thumbprint from existing cert
            THUMBPRINT=$(openssl x509 -in "$CERT_CRT" -noout -fingerprint -sha1 2>/dev/null | \
                         sed 's/.*=//g' | tr -d ':' | tr '[:upper:]' '[:lower:]')

            return 0
        fi
    fi

    log_info "Generating RSA 4096-bit certificate (valid for 365 days)..."

    # Generate private key and certificate
    openssl req -x509 -newkey rsa:4096 \
        -keyout "$CERT_KEY" \
        -out "$CERT_CRT" \
        -days 365 \
        -nodes \
        -subj "/CN=${SP_NAME}" \
        2>/dev/null

    log_success "Certificate generated"

    # Create PFX bundle (with empty password for import)
    log_info "Creating PFX bundle..."
    openssl pkcs12 -export \
        -out "$CERT_PFX" \
        -inkey "$CERT_KEY" \
        -in "$CERT_CRT" \
        -passout pass:

    log_success "PFX bundle created"

    # Get certificate thumbprint (strip any prefix like "sha1 Fingerprint=" and colons)
    THUMBPRINT=$(openssl x509 -in "$CERT_CRT" -noout -fingerprint -sha1 2>/dev/null | \
                 sed 's/.*=//g' | tr -d ':' | tr '[:upper:]' '[:lower:]')

    echo "  Certificate: $CERT_CRT"
    echo "  Private Key: $CERT_KEY"
    echo "  PFX Bundle: $CERT_PFX"
    echo "  Thumbprint: $THUMBPRINT"
}

# ==============================================================================
# Upload Certificate to Azure AD
# ==============================================================================

upload_certificate() {
    echo ""
    log_info "Uploading certificate to Azure AD app registration..."

    az ad app credential reset \
        --id "$APP_ID" \
        --cert "@${CERT_CRT}" \
        --append \
        --query "keyId" \
        -o tsv >/dev/null

    log_success "Certificate uploaded to Azure AD"
}

# ==============================================================================
# Install Certificate Locally
# ==============================================================================

install_certificate_local() {
    echo ""
    log_info "Configuring certificate for Microsoft Graph authentication..."

    # On Linux, we can't use the Windows certificate store
    # Instead, Connect-MgGraph can use -CertificateName with a PFX file path
    # But the preferred method is to use the certificate thumbprint with the cert in a known location

    # Create PowerShell script to handle certificate setup
    local PS_SCRIPT="${CERTS_DIR}/install-cert.ps1"

    cat > "$PS_SCRIPT" << 'PWSH_EOF'
param(
    [string]$PfxPath,
    [string]$Thumbprint
)

$ErrorActionPreference = "Stop"

# On Linux, the certificate store works differently
# We'll verify the PFX can be loaded and extract cert info

try {
    Write-Host "[*] Validating certificate file..."

    # Load the PFX to verify it's valid
    $pfxBytes = [System.IO.File]::ReadAllBytes($PfxPath)
    $cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new(
        $pfxBytes,
        "",
        [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::Exportable
    )

    Write-Host "[v] Certificate loaded successfully"
    Write-Host "    Subject: $($cert.Subject)"
    Write-Host "    Thumbprint: $($cert.Thumbprint)"
    Write-Host "    Expires: $($cert.NotAfter)"

    # Verify thumbprint matches
    if ($cert.Thumbprint.ToLower() -ne $Thumbprint.ToLower()) {
        Write-Host "[!] WARNING: Thumbprint mismatch!"
        Write-Host "    Expected: $Thumbprint"
        Write-Host "    Got: $($cert.Thumbprint)"
    }

    # On Linux, we need to use the PFX file directly with Connect-MgGraph
    # The -Certificate parameter accepts an X509Certificate2 object
    Write-Host ""
    Write-Host "[v] Certificate ready for MS Graph authentication"
    Write-Host "[i] On Linux, use -Certificate parameter with loaded cert object"
    Write-Host "[i] Or use Azure CLI for service principal auth (recommended)"

    exit 0
}
catch {
    Write-Host "[x] ERROR: Failed to load certificate: $_"
    exit 1
}
PWSH_EOF

    pwsh -File "$PS_SCRIPT" -PfxPath "$CERT_PFX" -Thumbprint "$THUMBPRINT"

    log_success "Certificate validated and ready"
}

# ==============================================================================
# Grant MS Graph Permissions
# ==============================================================================

grant_graph_permissions() {
    echo ""
    log_info "Configuring Microsoft Graph API permissions..."

    # MS Graph App ID
    GRAPH_APP_ID="00000003-0000-0000-c000-000000000000"

    # Permission IDs (Application permissions - Role type)
    # Group.ReadWrite.All - Manage all groups
    GROUP_RW_ALL="62a82d76-70ea-41e2-9197-370581804d09"
    # Application.ReadWrite.All - Manage app registrations
    APP_RW_ALL="1bfefb4e-e0b5-418b-a88f-73c46d2cc8e9"
    # Directory.ReadWrite.All - Read/write directory data
    DIR_RW_ALL="19dbc75e-c2e2-444c-a770-ec69d8559fc7"

    log_info "Adding Group.ReadWrite.All permission..."
    az ad app permission add \
        --id "$APP_ID" \
        --api "$GRAPH_APP_ID" \
        --api-permissions "${GROUP_RW_ALL}=Role" \
        2>/dev/null || true

    log_info "Adding Application.ReadWrite.All permission..."
    az ad app permission add \
        --id "$APP_ID" \
        --api "$GRAPH_APP_ID" \
        --api-permissions "${APP_RW_ALL}=Role" \
        2>/dev/null || true

    log_info "Adding Directory.ReadWrite.All permission..."
    az ad app permission add \
        --id "$APP_ID" \
        --api "$GRAPH_APP_ID" \
        --api-permissions "${DIR_RW_ALL}=Role" \
        2>/dev/null || true

    echo ""
    log_warning "Granting admin consent (requires Global Admin or Privileged Role Admin)..."

    if az ad app permission admin-consent --id "$APP_ID" 2>/dev/null; then
        log_success "Admin consent granted for MS Graph permissions"
    else
        log_warning "Could not grant admin consent automatically"
        echo ""
        echo "  A Global Administrator must grant consent manually:"
        echo "  1. Go to Azure Portal > Entra ID > App registrations"
        echo "  2. Find '$SP_NAME' (App ID: $APP_ID)"
        echo "  3. Go to API permissions > Grant admin consent"
        echo ""
    fi
}

# ==============================================================================
# Update secrets.yaml
# ==============================================================================

update_secrets_yaml() {
    echo ""
    log_info "Updating secrets.yaml..."

    # Check if secrets.yaml exists
    if [[ ! -f "$SECRETS_FILE" ]]; then
        log_info "Creating secrets.yaml from template..."
        cp "${PROJECT_ROOT}/secrets.yaml.example" "$SECRETS_FILE"
    fi

    # Check if service_principal section already exists
    if grep -q "^service_principal:" "$SECRETS_FILE" 2>/dev/null; then
        log_info "Updating existing service_principal section..."

        # Use yq to update values
        yq -i ".service_principal.client_id = \"$APP_ID\"" "$SECRETS_FILE"
        yq -i ".service_principal.client_secret = \"$CLIENT_SECRET\"" "$SECRETS_FILE"
        yq -i ".service_principal.certificate_thumbprint = \"$THUMBPRINT\"" "$SECRETS_FILE"
        yq -i ".service_principal.certificate_path = \"$CERT_PFX\"" "$SECRETS_FILE"
    else
        log_info "Adding service_principal section..."

        # Append to file
        cat >> "$SECRETS_FILE" << EOF

# ==============================================================================
# Claude Code Service Principal (Auto-generated $(date +%Y-%m-%d))
# ==============================================================================
service_principal:
  client_id: "$APP_ID"
  client_secret: "$CLIENT_SECRET"
  certificate_thumbprint: "$THUMBPRINT"
  certificate_path: "$CERT_PFX"
EOF
    fi

    # Also update azure section with tenant/subscription if not present
    if ! grep -q "^azure:" "$SECRETS_FILE" 2>/dev/null; then
        log_info "Adding azure section..."

        # Insert at the top after the header comments
        yq -i ". = {\"azure\": {\"subscription_id\": \"$SUBSCRIPTION_ID\", \"tenant_id\": \"$TENANT_ID\"}} + ." "$SECRETS_FILE" 2>/dev/null || {
            # Fallback: prepend manually
            TEMP_FILE=$(mktemp)
            cat > "$TEMP_FILE" << EOF
# ==============================================================================
# Azure Identity (Auto-generated $(date +%Y-%m-%d))
# ==============================================================================
azure:
  subscription_id: "$SUBSCRIPTION_ID"
  tenant_id: "$TENANT_ID"

EOF
            cat "$SECRETS_FILE" >> "$TEMP_FILE"
            mv "$TEMP_FILE" "$SECRETS_FILE"
        }
    else
        yq -i ".azure.subscription_id = \"$SUBSCRIPTION_ID\"" "$SECRETS_FILE" 2>/dev/null || true
        yq -i ".azure.tenant_id = \"$TENANT_ID\"" "$SECRETS_FILE" 2>/dev/null || true
    fi

    log_success "secrets.yaml updated"
}

# ==============================================================================
# Verify Setup
# ==============================================================================

verify_setup() {
    echo ""
    echo "========================================================================"
    echo "  Verification"
    echo "========================================================================"
    echo ""

    log_info "Loading configuration and testing authentication..."

    # Source config manager
    source "${PROJECT_ROOT}/core/config-manager.sh"
    load_config

    # Run auth status check
    if [[ -f "${PROJECT_ROOT}/core/engine.sh" ]]; then
        echo ""
        "${PROJECT_ROOT}/core/engine.sh" run identity/auth-status-check || true
    fi
}

# ==============================================================================
# Summary
# ==============================================================================

print_summary() {
    echo ""
    echo "========================================================================"
    echo "  Setup Complete"
    echo "========================================================================"
    echo ""
    echo "  Service Principal: $SP_NAME"
    echo "  App ID:            $APP_ID"
    echo "  Tenant ID:         $TENANT_ID"
    echo "  Subscription:      $SUBSCRIPTION_NAME"
    echo ""
    echo "  Certificate:"
    echo "    Thumbprint:      $THUMBPRINT"
    echo "    Location:        $CERT_PFX"
    echo "    Expires:         $(date -d '+365 days' +%Y-%m-%d)"
    echo ""
    echo "  Configuration updated: $SECRETS_FILE"
    echo ""
    echo "  Next steps:"
    echo "    1. Test Azure CLI auth:  ./core/engine.sh run identity/az-login-service-principal"
    echo "    2. Test MS Graph auth:   ./core/engine.sh run identity/mggraph-connect-certificate"
    echo ""
}

# ==============================================================================
# Main
# ==============================================================================

main() {
    check_prerequisites
    get_azure_context
    check_existing_sp
    create_service_principal
    generate_certificate
    upload_certificate
    install_certificate_local
    grant_graph_permissions
    update_secrets_yaml
    verify_setup
    print_summary
}

main "$@"
