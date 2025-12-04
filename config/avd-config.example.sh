#!/bin/bash

# Azure Virtual Desktop Deployment Configuration
#
# Purpose: Central configuration file for all AVD deployment scripts
#
# Usage:
#   1. Copy this file to avd-config.sh
#   2. Edit avd-config.sh with your values
#   3. Scripts will automatically source this file when present
#   4. Command-line parameters override these values
#
# Security:
#   - avd-config.sh is in .gitignore and should NEVER be committed
#   - This file (avd-config.example.sh) is safe to commit
#   - Always use placeholder UUIDs in this example file
#
# Environment Variables (with defaults):
#   All variables use the AVD_ prefix and can be overridden by command-line parameters

# ============================================================================
# Global Settings
# ============================================================================
# These settings apply to all deployment steps

export AVD_SUBSCRIPTION_ID="00000000-0000-0000-0000-000000000000"
export AVD_TENANT_ID="00000000-0000-0000-0000-000000000000"
export AVD_LOCATION="centralus"
export AVD_RESOURCE_GROUP="RG-Azure-VDI-01"
export AVD_ENVIRONMENT="prod"  # Options: prod, dev, test

# ============================================================================
# Networking Configuration (Step 01)
# ============================================================================
# Configure virtual network, subnets, and network security groups

export AVD_VNET_NAME="vnet-avd-${AVD_ENVIRONMENT}"
export AVD_VNET_PREFIX="10.1.0.0/16"

# Session Hosts Subnet
export AVD_SUBNET_SESSION_HOSTS="subnet-session-hosts"
export AVD_SUBNET_SESSION_HOSTS_PREFIX="10.1.0.0/22"

# Private Endpoints Subnet (for storage, Key Vault, etc)
export AVD_SUBNET_PRIVATE_ENDPOINTS="subnet-private-endpoints"
export AVD_SUBNET_PRIVATE_ENDPOINTS_PREFIX="10.1.4.0/24"

# File Server Subnet
export AVD_SUBNET_FILE_SERVER="subnet-file-server"
export AVD_SUBNET_FILE_SERVER_PREFIX="10.1.5.0/24"

# Hub VNet Peering (optional - leave empty to skip)
export AVD_HUB_VNET_NAME=""
export AVD_HUB_VNET_RG=""

# ============================================================================
# Storage Configuration (Step 02)
# ============================================================================
# Configure Azure Files Premium storage for FSLogix profiles

# Storage account name (auto-generated if empty with format: fslogix<random5digits>)
export AVD_STORAGE_ACCOUNT_NAME=""

# File share settings
export AVD_STORAGE_FILE_SHARE_NAME="fslogix-profiles"
export AVD_STORAGE_FILE_SHARE_QUOTA_GB=1024

# ============================================================================
# Entra ID Groups Configuration (Step 03)
# ============================================================================
# Configure user and device groups for AVD access and targeting

# User groups
export AVD_GROUP_USERS_STANDARD="AVD-Users-Standard"
export AVD_GROUP_USERS_ADMINS="AVD-Users-Admins"

# Device groups (auto-populated by device naming pattern)
export AVD_GROUP_DEVICES_SSO="AVD-Devices-Pooled-SSO"
export AVD_GROUP_DEVICES_FSLOGIX="AVD-Devices-Pooled-FSLogix"
export AVD_GROUP_DEVICES_NETWORK="AVD-Devices-Pooled-Network"
export AVD_GROUP_DEVICES_SECURITY="AVD-Devices-Pooled-Security"

# ============================================================================
# Host Pool Configuration (Step 04)
# ============================================================================
# Configure AVD workspace, host pool, and application groups

export AVD_WORKSPACE_NAME="AVD-Workspace-${AVD_ENVIRONMENT^}"
export AVD_HOSTPOOL_NAME="Pool-Pooled-${AVD_ENVIRONMENT^}"
export AVD_HOSTPOOL_TYPE="Pooled"
export AVD_HOSTPOOL_MAX_SESSIONS=10
export AVD_HOSTPOOL_LOAD_BALANCER="BreadthFirst"  # BreadthFirst or DepthFirst
export AVD_APP_GROUP_NAME="Desktop-${AVD_ENVIRONMENT^}"

# ============================================================================
# Golden Image Configuration (Step 05)
# ============================================================================
# Configure image gallery for storing and deploying custom images

export AVD_IMAGE_GALLERY_NAME="gallery_avd_images"
export AVD_IMAGE_DEFINITION_NAME="Win11-AVD-Pooled"
export AVD_IMAGE_VM_NAME="avd-gold-${AVD_ENVIRONMENT}"
export AVD_IMAGE_VM_SIZE="Standard_D4s_v5"

# ============================================================================
# Session Host Configuration (Step 06)
# ============================================================================
# Configure session host virtual machines

export AVD_VM_PREFIX="avd-pool"
export AVD_VM_SIZE="Standard_D4s_v5"
export AVD_VM_COUNT=10
export AVD_VM_DISK_TYPE="Premium_LRS"

# ============================================================================
# Autoscaling Configuration (Step 10)
# ============================================================================
# Configure scaling plans for cost optimization

export AVD_SCALING_PLAN_NAME="ScalingPlan-${AVD_ENVIRONMENT^}"
export AVD_SCALING_TIMEZONE="Central Standard Time"

# Ramp-up schedule (weekdays 7:00 AM)
export AVD_SCALING_RAMPUP_START="07:00"
export AVD_SCALING_RAMPUP_MIN_PERCENT=20

# Peak schedule (weekdays 9:00 AM - 5:00 PM)
export AVD_SCALING_PEAK_START="09:00"
export AVD_SCALING_PEAK_MIN_PERCENT=100

# Ramp-down schedule (weekdays 5:00 PM)
export AVD_SCALING_RAMPDOWN_START="17:00"
export AVD_SCALING_RAMPDOWN_MIN_PERCENT=10

# Off-peak schedule (weekdays 7:00 PM, weekends)
export AVD_SCALING_OFFPEAK_START="19:00"
export AVD_SCALING_OFFPEAK_MIN_PERCENT=5

# ============================================================================
# Tags (Applied to all resources)
# ============================================================================
# Standard tags for resource organization and cost tracking

export AVD_TAG_ENVIRONMENT="${AVD_ENVIRONMENT}"
export AVD_TAG_PROJECT="AzureVirtualDesktop"
export AVD_TAG_MANAGED_BY="Automation"
