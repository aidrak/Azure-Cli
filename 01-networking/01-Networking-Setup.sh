#!/bin/bash

# Automates Networking Setup for Azure Virtual Desktop (AVD)
#
# Purpose: Creates core networking infrastructure including VNet, subnets, Network Security Groups,
# and optional VNet peering for AVD deployment.
#
# Prerequisites:
# - Azure CLI installed and authenticated (az login)
# - Required permissions: Owner or Network Contributor role on the subscription
# - Resource group must exist or be created first
#
# Permissions Required:
# - Microsoft.Network/virtualNetworks/write
# - Microsoft.Network/networkSecurityGroups/write
# - Microsoft.Network/virtualNetworks/subnets/write
#
# Usage:
# chmod +x ./01-Networking-Setup.sh
# ./01-Networking-Setup.sh
#
# Example with custom parameters:
# RESOURCE_GROUP="RG-Azure-VDI-01" LOCATION="centralus" ./01-Networking-Setup.sh
#
# Environment Variables (with defaults):
# - RESOURCE_GROUP: Name of resource group (default: RG-Azure-VDI-01)
# - LOCATION: Azure region (default: centralus)
# - VNET_NAME: Virtual network name (default: vnet-avd-prod)
# - VNET_PREFIX: VNet CIDR prefix (default: 10.0.0.0/16)
# - SESSION_HOSTS_SUBNET: Session hosts subnet name (default: subnet-session-hosts)
# - SESSION_HOSTS_PREFIX: Subnet CIDR (default: 10.0.1.0/24)
# - PRIVATE_ENDPOINTS_SUBNET: Private endpoints subnet name (default: subnet-private-endpoints)
# - PRIVATE_ENDPOINTS_PREFIX: Subnet CIDR (default: 10.0.2.0/24)
# - FILE_SERVER_SUBNET: File server subnet name (default: subnet-file-server)
# - FILE_SERVER_PREFIX: Subnet CIDR (default: 10.0.3.0/24)
# - HUB_VNET_NAME: Hub VNet name for peering (optional)
# - HUB_VNET_RG: Hub VNet resource group (optional)
#
# Notes:
# - This script is idempotent - safe to run multiple times
# - Existing resources will be checked before creation
# - Expected runtime: 2-5 minutes
# - Peering is optional - skip if not needed

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration with defaults
RESOURCE_GROUP="${RESOURCE_GROUP:-RG-Azure-VDI-01}"
LOCATION="${LOCATION:-centralus}"
VNET_NAME="${VNET_NAME:-vnet-avd-prod}"
VNET_PREFIX="${VNET_PREFIX:-10.0.0.0/16}"

SESSION_HOSTS_SUBNET="${SESSION_HOSTS_SUBNET:-subnet-session-hosts}"
SESSION_HOSTS_PREFIX="${SESSION_HOSTS_PREFIX:-10.0.1.0/24}"

PRIVATE_ENDPOINTS_SUBNET="${PRIVATE_ENDPOINTS_SUBNET:-subnet-private-endpoints}"
PRIVATE_ENDPOINTS_PREFIX="${PRIVATE_ENDPOINTS_PREFIX:-10.0.2.0/24}"

FILE_SERVER_SUBNET="${FILE_SERVER_SUBNET:-subnet-file-server}"
FILE_SERVER_PREFIX="${FILE_SERVER_PREFIX:-10.0.3.0/24}"

HUB_VNET_NAME="${HUB_VNET_NAME:-}"
HUB_VNET_RG="${HUB_VNET_RG:-}"

# ============================================================================
# Helper Functions
# ============================================================================

log_section() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
}

log_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

log_error() {
    echo -e "${RED}✗ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

log_info() {
    echo -e "${YELLOW}ℹ $1${NC}"
}

# ============================================================================
# Validation Functions
# ============================================================================

validate_prerequisites() {
    log_section "Validating Prerequisites"

    if ! command -v az &> /dev/null; then
        log_error "Azure CLI is not installed"
        exit 1
    fi
    log_success "Azure CLI installed"

    # Check if logged in
    if ! az account show &> /dev/null; then
        log_error "Not logged into Azure. Run 'az login' first"
        exit 1
    fi
    log_success "Logged into Azure"

    # Check if resource group exists
    if ! az group exists -n "$RESOURCE_GROUP" | grep -q true; then
        log_error "Resource group '$RESOURCE_GROUP' does not exist"
        log_info "Create it with: az group create -n $RESOURCE_GROUP -l $LOCATION"
        exit 1
    fi
    log_success "Resource group '$RESOURCE_GROUP' exists"
}

# ============================================================================
# VNet and Subnet Creation
# ============================================================================

create_vnet_and_subnets() {
    log_section "Creating Virtual Network and Subnets"

    # Check if VNet already exists
    if az network vnet show -g "$RESOURCE_GROUP" -n "$VNET_NAME" &> /dev/null; then
        log_warning "VNet '$VNET_NAME' already exists"
        return 0
    fi

    log_info "Creating VNet '$VNET_NAME' with CIDR $VNET_PREFIX"
    az network vnet create \
        --resource-group "$RESOURCE_GROUP" \
        --name "$VNET_NAME" \
        --address-prefix "$VNET_PREFIX" \
        --location "$LOCATION" \
        --subnet-name "$SESSION_HOSTS_SUBNET" \
        --subnet-prefix "$SESSION_HOSTS_PREFIX" \
        --output none

    log_success "VNet '$VNET_NAME' created"

    # Create additional subnets
    log_info "Creating subnet '$PRIVATE_ENDPOINTS_SUBNET'"
    az network vnet subnet create \
        --resource-group "$RESOURCE_GROUP" \
        --vnet-name "$VNET_NAME" \
        --name "$PRIVATE_ENDPOINTS_SUBNET" \
        --address-prefix "$PRIVATE_ENDPOINTS_PREFIX" \
        --output none

    log_success "Subnet '$PRIVATE_ENDPOINTS_SUBNET' created"

    log_info "Creating subnet '$FILE_SERVER_SUBNET'"
    az network vnet subnet create \
        --resource-group "$RESOURCE_GROUP" \
        --vnet-name "$VNET_NAME" \
        --name "$FILE_SERVER_SUBNET" \
        --address-prefix "$FILE_SERVER_PREFIX" \
        --output none

    log_success "Subnet '$FILE_SERVER_SUBNET' created"
}

# ============================================================================
# Network Security Groups
# ============================================================================

create_nsg_session_hosts() {
    log_section "Creating NSG for Session Hosts"

    NSG_NAME="nsg-session-hosts"

    if az network nsg show -g "$RESOURCE_GROUP" -n "$NSG_NAME" &> /dev/null; then
        log_warning "NSG '$NSG_NAME' already exists"
        return 0
    fi

    log_info "Creating NSG '$NSG_NAME'"
    az network nsg create \
        --resource-group "$RESOURCE_GROUP" \
        --name "$NSG_NAME" \
        --location "$LOCATION" \
        --output none

    # Allow RDP (for initial setup only - consider restricting to specific IPs)
    log_info "Adding RDP inbound rule"
    az network nsg rule create \
        --resource-group "$RESOURCE_GROUP" \
        --nsg-name "$NSG_NAME" \
        --name "Allow-RDP" \
        --priority 100 \
        --direction Inbound \
        --access Allow \
        --protocol Tcp \
        --source-address-prefixes "*" \
        --destination-address-prefixes "$SESSION_HOSTS_PREFIX" \
        --destination-port-ranges 3389 \
        --output none

    log_success "NSG '$NSG_NAME' created with RDP rule"
}

create_nsg_private_endpoints() {
    log_section "Creating NSG for Private Endpoints"

    NSG_NAME="nsg-private-endpoints"

    if az network nsg show -g "$RESOURCE_GROUP" -n "$NSG_NAME" &> /dev/null; then
        log_warning "NSG '$NSG_NAME' already exists"
        return 0
    fi

    log_info "Creating NSG '$NSG_NAME'"
    az network nsg create \
        --resource-group "$RESOURCE_GROUP" \
        --name "$NSG_NAME" \
        --location "$LOCATION" \
        --output none

    # Allow traffic from VNet
    log_info "Adding inbound rule for VNet traffic"
    az network nsg rule create \
        --resource-group "$RESOURCE_GROUP" \
        --nsg-name "$NSG_NAME" \
        --name "Allow-VNet-Inbound" \
        --priority 100 \
        --direction Inbound \
        --access Allow \
        --protocol "*" \
        --source-address-prefixes "VirtualNetwork" \
        --destination-address-prefixes "VirtualNetwork" \
        --output none

    log_success "NSG '$NSG_NAME' created"
}

create_nsg_file_server() {
    log_section "Creating NSG for File Server"

    NSG_NAME="nsg-file-server"

    if az network nsg show -g "$RESOURCE_GROUP" -n "$NSG_NAME" &> /dev/null; then
        log_warning "NSG '$NSG_NAME' already exists"
        return 0
    fi

    log_info "Creating NSG '$NSG_NAME'"
    az network nsg create \
        --resource-group "$RESOURCE_GROUP" \
        --name "$NSG_NAME" \
        --location "$LOCATION" \
        --output none

    # Allow SMB from session hosts
    log_info "Adding SMB inbound rule"
    az network nsg rule create \
        --resource-group "$RESOURCE_GROUP" \
        --nsg-name "$NSG_NAME" \
        --name "Allow-SMB-From-SessionHosts" \
        --priority 100 \
        --direction Inbound \
        --access Allow \
        --protocol Tcp \
        --source-address-prefixes "$SESSION_HOSTS_PREFIX" \
        --destination-address-prefixes "$FILE_SERVER_PREFIX" \
        --destination-port-ranges 445 \
        --output none

    log_success "NSG '$NSG_NAME' created with SMB rule"
}

# ============================================================================
# Attach NSGs to Subnets
# ============================================================================

attach_nsgs_to_subnets() {
    log_section "Attaching NSGs to Subnets"

    # Attach to session hosts subnet
    log_info "Attaching nsg-session-hosts to $SESSION_HOSTS_SUBNET"
    az network vnet subnet update \
        --resource-group "$RESOURCE_GROUP" \
        --vnet-name "$VNET_NAME" \
        --name "$SESSION_HOSTS_SUBNET" \
        --network-security-group "nsg-session-hosts" \
        --output none

    log_success "NSG attached to session hosts subnet"

    # Attach to private endpoints subnet
    log_info "Attaching nsg-private-endpoints to $PRIVATE_ENDPOINTS_SUBNET"
    az network vnet subnet update \
        --resource-group "$RESOURCE_GROUP" \
        --vnet-name "$VNET_NAME" \
        --name "$PRIVATE_ENDPOINTS_SUBNET" \
        --network-security-group "nsg-private-endpoints" \
        --output none

    log_success "NSG attached to private endpoints subnet"

    # Attach to file server subnet
    log_info "Attaching nsg-file-server to $FILE_SERVER_SUBNET"
    az network vnet subnet update \
        --resource-group "$RESOURCE_GROUP" \
        --vnet-name "$VNET_NAME" \
        --name "$FILE_SERVER_SUBNET" \
        --network-security-group "nsg-file-server" \
        --output none

    log_success "NSG attached to file server subnet"
}

# ============================================================================
# Optional VNet Peering
# ============================================================================

create_vnet_peering() {
    if [[ -z "$HUB_VNET_NAME" ]] || [[ -z "$HUB_VNET_RG" ]]; then
        log_warning "Hub VNet not specified - skipping peering"
        return 0
    fi

    log_section "Creating VNet Peering to Hub"

    PEERING_NAME="${VNET_NAME}-to-${HUB_VNET_NAME}"

    # Check if peering already exists
    if az network vnet peering show -g "$RESOURCE_GROUP" -n "$PEERING_NAME" --vnet-name "$VNET_NAME" &> /dev/null; then
        log_warning "Peering '$PEERING_NAME' already exists"
        return 0
    fi

    log_info "Creating peering from '$VNET_NAME' to '$HUB_VNET_NAME'"
    az network vnet peering create \
        --resource-group "$RESOURCE_GROUP" \
        --vnet-name "$VNET_NAME" \
        --name "$PEERING_NAME" \
        --remote-vnet "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/${HUB_VNET_RG}/providers/Microsoft.Network/virtualNetworks/${HUB_VNET_NAME}" \
        --allow-vnet-access \
        --allow-forwarded-traffic \
        --output none

    log_success "Peering created"
}

# ============================================================================
# Verification
# ============================================================================

verify_networking() {
    log_section "Verifying Network Configuration"

    # Verify VNet
    if az network vnet show -g "$RESOURCE_GROUP" -n "$VNET_NAME" &> /dev/null; then
        log_success "VNet '$VNET_NAME' verified"
    else
        log_error "VNet '$VNET_NAME' not found"
        return 1
    fi

    # Verify subnets
    for subnet in "$SESSION_HOSTS_SUBNET" "$PRIVATE_ENDPOINTS_SUBNET" "$FILE_SERVER_SUBNET"; do
        if az network vnet subnet show -g "$RESOURCE_GROUP" --vnet-name "$VNET_NAME" -n "$subnet" &> /dev/null; then
            log_success "Subnet '$subnet' verified"
        else
            log_error "Subnet '$subnet' not found"
            return 1
        fi
    done

    # Verify NSGs
    for nsg in "nsg-session-hosts" "nsg-private-endpoints" "nsg-file-server"; do
        if az network nsg show -g "$RESOURCE_GROUP" -n "$nsg" &> /dev/null; then
            log_success "NSG '$nsg' verified"
        else
            log_error "NSG '$nsg' not found"
            return 1
        fi
    done

    log_success "All networking components verified"
}

# ============================================================================
# Main Execution
# ============================================================================

main() {
    log_section "AVD Networking Setup"

    validate_prerequisites
    create_vnet_and_subnets
    create_nsg_session_hosts
    create_nsg_private_endpoints
    create_nsg_file_server
    attach_nsgs_to_subnets
    create_vnet_peering
    verify_networking

    echo ""
    log_success "Networking Setup Complete!"
    echo ""
    log_info "Summary:"
    echo "  Resource Group: $RESOURCE_GROUP"
    echo "  VNet Name: $VNET_NAME"
    echo "  VNet CIDR: $VNET_PREFIX"
    echo "  Session Hosts Subnet: $SESSION_HOSTS_SUBNET ($SESSION_HOSTS_PREFIX)"
    echo "  Private Endpoints Subnet: $PRIVATE_ENDPOINTS_SUBNET ($PRIVATE_ENDPOINTS_PREFIX)"
    echo "  File Server Subnet: $FILE_SERVER_SUBNET ($FILE_SERVER_PREFIX)"
    echo ""
}

main "$@"
