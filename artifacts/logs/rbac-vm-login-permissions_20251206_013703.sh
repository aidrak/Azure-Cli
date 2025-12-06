#!/bin/bash
set -euo pipefail

echo "[START] VM Login Permissions Assignment: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"

# Configuration from config.yaml
RESOURCE_GROUP="RG-Azure-VDI-01"
SUBSCRIPTION_ID="6c7eb5e0-8e77-40dd-a06c-bdb06c2d5856"
STD_GROUP_NAME="AVD-Users-Standard"
ADMIN_GROUP_NAME="AVD-Users-Admins"

# Step 1: Validate Azure authentication
echo "[PROGRESS] Step 1/5: Validating Azure authentication..."
if ! az account show &>/dev/null; then
  echo "[ERROR] Not authenticated to Azure"
  exit 1
fi

# Step 2: Validate resource group exists
echo "[PROGRESS] Step 2/5: Validating resource group..."
if ! az group exists --name "$RESOURCE_GROUP" | grep -q "true"; then
  echo "[ERROR] Resource group not found: $RESOURCE_GROUP"
  exit 1
fi

# Get resource group ID
RG_ID=$(az group show --name "$RESOURCE_GROUP" --query id -o tsv)
echo "[VALIDATE] Resource group ID: $RG_ID"

# Step 3: Get user group IDs
echo "[PROGRESS] Step 3/5: Getting user group IDs..."

STD_GROUP_ID=$(az ad group list \
  --filter "displayName eq '${STD_GROUP_NAME}'" \
  --query "[0].id" -o tsv)

if [[ -z "$STD_GROUP_ID" || "$STD_GROUP_ID" == "null" ]]; then
  echo "[ERROR] Standard users group not found: $STD_GROUP_NAME"
  exit 1
fi

echo "[VALIDATE] Standard users group ID: $STD_GROUP_ID"

ADMIN_GROUP_ID=$(az ad group list \
  --filter "displayName eq '${ADMIN_GROUP_NAME}'" \
  --query "[0].id" -o tsv)

if [[ -z "$ADMIN_GROUP_ID" || "$ADMIN_GROUP_ID" == "null" ]]; then
  echo "[ERROR] Admin users group not found: $ADMIN_GROUP_NAME"
  exit 1
fi

echo "[VALIDATE] Admin users group ID: $ADMIN_GROUP_ID"

# Step 4: Assign VM login permissions to standard users
echo "[PROGRESS] Step 4/5: Assigning VM login permissions to standard users..."
echo "[PROGRESS] Role: Virtual Machine User Login"
echo "[PROGRESS] Group: $STD_GROUP_NAME"
echo "[PROGRESS] Scope: Resource Group ($RESOURCE_GROUP)"

if az role assignment create \
  --assignee "$STD_GROUP_ID" \
  --role "Virtual Machine User Login" \
  --scope "$RG_ID" \
  --output none 2>/dev/null; then
  echo "[SUCCESS] VM login permissions assigned to standard users"
else
  # Check if already exists
  if az role assignment list \
    --assignee "$STD_GROUP_ID" \
    --scope "$RG_ID" \
    --query "[?roleDefinitionName=='Virtual Machine User Login']" -o tsv | grep -q "Virtual"; then
    echo "[SUCCESS] VM login permissions already assigned to standard users"
  else
    echo "[ERROR] Failed to assign VM login permissions to standard users"
    exit 1
  fi
fi

# Step 5: Assign VM admin login permissions to admin users
echo "[PROGRESS] Step 5/5: Assigning VM admin login permissions to admin users..."
echo "[PROGRESS] Role: Virtual Machine Administrator Login"
echo "[PROGRESS] Group: $ADMIN_GROUP_NAME"
echo "[PROGRESS] Scope: Resource Group ($RESOURCE_GROUP)"

if az role assignment create \
  --assignee "$ADMIN_GROUP_ID" \
  --role "Virtual Machine Administrator Login" \
  --scope "$RG_ID" \
  --output none 2>/dev/null; then
  echo "[SUCCESS] VM admin login permissions assigned to admin users"
else
  # Check if already exists
  if az role assignment list \
    --assignee "$ADMIN_GROUP_ID" \
    --scope "$RG_ID" \
    --query "[?roleDefinitionName=='Virtual Machine Administrator Login']" -o tsv | grep -q "Virtual"; then
    echo "[SUCCESS] VM admin login permissions already assigned to admin users"
  else
    echo "[ERROR] Failed to assign VM admin login permissions to admin users"
    exit 1
  fi
fi

# Optional: Assign power management permissions to admin users
echo "[PROGRESS] (Optional) Assigning power management permissions to admin users..."
echo "[PROGRESS] Role: Desktop Virtualization Power On Off Contributor"

if az role assignment create \
  --assignee "$ADMIN_GROUP_ID" \
  --role "Desktop Virtualization Power On Off Contributor" \
  --scope "$RG_ID" \
  --output none 2>/dev/null; then
  echo "[SUCCESS] Power management permissions assigned to admin users"
else
  if az role assignment list \
    --assignee "$ADMIN_GROUP_ID" \
    --scope "$RG_ID" \
    --query "[?roleDefinitionName=='Desktop Virtualization Power On Off Contributor']" -o tsv | grep -q "Desktop"; then
    echo "[SUCCESS] Power management permissions already assigned to admin users"
  else
    echo "[WARNING] Failed to assign power management permissions (optional)"
  fi
fi

# Verify assignments
echo "[VALIDATE] Verifying VM login role assignments..."

STD_ASSIGNMENTS=$(az role assignment list \
  --assignee "$STD_GROUP_ID" \
  --scope "$RG_ID" \
  --query "[].roleDefinitionName" -o tsv | grep -E "Virtual Machine")

ADMIN_ASSIGNMENTS=$(az role assignment list \
  --assignee "$ADMIN_GROUP_ID" \
  --scope "$RG_ID" \
  --query "[].roleDefinitionName" -o tsv | grep -E "Virtual Machine|Desktop Virtualization")

echo "[VALIDATE] Standard users roles:"
echo "$STD_ASSIGNMENTS" | sed 's/^/  - /'

echo "[VALIDATE] Admin users roles:"
echo "$ADMIN_ASSIGNMENTS" | sed 's/^/  - /'

# Save assignment details
{
  echo "VM Login RBAC Assignment Details"
  echo "================================="
  echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
  echo ""
  echo "Resource Group:"
  echo "  Name: $RESOURCE_GROUP"
  echo "  ID: $RG_ID"
  echo ""
  echo "Standard Users ($STD_GROUP_NAME):"
  echo "  Group ID: $STD_GROUP_ID"
  echo "  Role: Virtual Machine User Login"
  echo "  Scope: Resource Group"
  echo "  Permissions: Standard user login to session hosts (no admin rights)"
  echo ""
  echo "Admin Users ($ADMIN_GROUP_NAME):"
  echo "  Group ID: $ADMIN_GROUP_ID"
  echo "  Roles:"
  echo "    - Virtual Machine Administrator Login"
  echo "    - Desktop Virtualization Power On Off Contributor (optional)"
  echo "  Scope: Resource Group"
  echo "  Permissions:"
  echo "    - Admin login to session hosts with local admin rights"
  echo "    - Manage session host power state"
  echo ""
  echo "Next Steps:"
  echo "  1. Assign application group permissions (next operation)"
  echo "  2. Test user login to session hosts"
  echo "  3. Verify admin users have elevated access"
  echo ""
} > "artifacts/outputs/rbac-vm-login-permissions.txt"

echo "[SUCCESS] VM login permissions assignment completed"
exit 0
