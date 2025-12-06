#!/bin/bash
set -euo pipefail

echo "[START] Application Group Permissions Assignment: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"

# Configuration from config.yaml
RESOURCE_GROUP="RG-Azure-VDI-01"
APP_GROUP_NAME="Desktop-Prod"
STD_GROUP_NAME="AVD-Users-Standard"
ADMIN_GROUP_NAME="AVD-Users-Admins"

# Step 1: Validate Azure authentication
echo "[PROGRESS] Step 1/5: Validating Azure authentication..."
if ! az account show &>/dev/null; then
  echo "[ERROR] Not authenticated to Azure"
  exit 1
fi

# Step 2: Get application group
echo "[PROGRESS] Step 2/5: Finding application group..."

# Initialize APP_GROUP_ID
APP_GROUP_ID=""

# Try to find by configured name first
if [[ -n "$APP_GROUP_NAME" && "$APP_GROUP_NAME" != "Desktop-Prod" ]]; then
  APP_GROUP_ID=$(az desktopvirtualization applicationgroup show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$APP_GROUP_NAME" \
    --query id -o tsv 2>/dev/null || true)
fi

# If not found, find first available application group
if [[ -z "$APP_GROUP_ID" || "$APP_GROUP_ID" == "null" ]]; then
  echo "[PROGRESS] Searching for application group in resource group..."
  APP_GROUP_ID=$(az desktopvirtualization applicationgroup list \
    --resource-group "$RESOURCE_GROUP" \
    --query "[0].id" -o tsv)

  if [[ -z "$APP_GROUP_ID" || "$APP_GROUP_ID" == "null" ]]; then
    echo "[ERROR] No application group found in resource group: $RESOURCE_GROUP"
    echo "[ERROR] Please ensure application group was created (Module 04)"
    exit 1
  fi

  # Get the name from the ID
  APP_GROUP_NAME=$(az desktopvirtualization applicationgroup list \
    --resource-group "$RESOURCE_GROUP" \
    --query "[0].name" -o tsv)
fi

echo "[VALIDATE] Found application group: $APP_GROUP_NAME"
echo "[VALIDATE] Application group ID: $APP_GROUP_ID"

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

# Step 4: Assign application group permissions to standard users
echo "[PROGRESS] Step 4/5: Assigning application group access to standard users..."
echo "[PROGRESS] Role: Desktop Virtualization User"
echo "[PROGRESS] Group: $STD_GROUP_NAME"
echo "[PROGRESS] Application Group: $APP_GROUP_NAME"

if az role assignment create \
  --assignee "$STD_GROUP_ID" \
  --role "Desktop Virtualization User" \
  --scope "$APP_GROUP_ID" \
  --output none 2>/dev/null; then
  echo "[SUCCESS] Application group access assigned to standard users"
else
  # Check if already exists
  if az role assignment list \
    --assignee "$STD_GROUP_ID" \
    --scope "$APP_GROUP_ID" \
    --query "[?roleDefinitionName=='Desktop Virtualization User']" -o tsv | grep -q "Desktop"; then
    echo "[SUCCESS] Application group access already assigned to standard users"
  else
    echo "[ERROR] Failed to assign application group access to standard users"
    exit 1
  fi
fi

# Step 5: Assign application group permissions to admin users
echo "[PROGRESS] Step 5/5: Assigning application group access to admin users..."
echo "[PROGRESS] Role: Desktop Virtualization User"
echo "[PROGRESS] Group: $ADMIN_GROUP_NAME"
echo "[PROGRESS] Application Group: $APP_GROUP_NAME"

if az role assignment create \
  --assignee "$ADMIN_GROUP_ID" \
  --role "Desktop Virtualization User" \
  --scope "$APP_GROUP_ID" \
  --output none 2>/dev/null; then
  echo "[SUCCESS] Application group access assigned to admin users"
else
  # Check if already exists
  if az role assignment list \
    --assignee "$ADMIN_GROUP_ID" \
    --scope "$APP_GROUP_ID" \
    --query "[?roleDefinitionName=='Desktop Virtualization User']" -o tsv | grep -q "Desktop"; then
    echo "[SUCCESS] Application group access already assigned to admin users"
  else
    echo "[ERROR] Failed to assign application group access to admin users"
    exit 1
  fi
fi

# Verify assignments
echo "[VALIDATE] Verifying application group role assignments..."

STD_ASSIGNMENTS=$(az role assignment list \
  --assignee "$STD_GROUP_ID" \
  --scope "$APP_GROUP_ID" \
  --query "[].roleDefinitionName" -o tsv)

ADMIN_ASSIGNMENTS=$(az role assignment list \
  --assignee "$ADMIN_GROUP_ID" \
  --scope "$APP_GROUP_ID" \
  --query "[].roleDefinitionName" -o tsv)

echo "[VALIDATE] Standard users roles: $STD_ASSIGNMENTS"
echo "[VALIDATE] Admin users roles: $ADMIN_ASSIGNMENTS"

# Save assignment details
{
  echo "Application Group RBAC Assignment Details"
  echo "=========================================="
  echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
  echo ""
  echo "Application Group:"
  echo "  Name: $APP_GROUP_NAME"
  echo "  Resource Group: $RESOURCE_GROUP"
  echo "  ID: $APP_GROUP_ID"
  echo ""
  echo "Standard Users ($STD_GROUP_NAME):"
  echo "  Group ID: $STD_GROUP_ID"
  echo "  Role: Desktop Virtualization User"
  echo "  Scope: Application Group"
  echo "  Permissions: Access to AVD desktop/applications"
  echo ""
  echo "Admin Users ($ADMIN_GROUP_NAME):"
  echo "  Group ID: $ADMIN_GROUP_ID"
  echo "  Role: Desktop Virtualization User"
  echo "  Scope: Application Group"
  echo "  Permissions: Access to AVD desktop/applications"
  echo ""
  echo "Next Steps:"
  echo "  1. Verify all RBAC assignments (next operation)"
  echo "  2. Test user access to AVD desktops"
  echo "  3. Verify users can see desktops in AVD client"
  echo ""
  echo "User Access Verification:"
  echo "  - Standard users should see desktop in AVD web client"
  echo "  - Admin users should have both desktop access AND admin rights on VMs"
  echo "  - Both groups should have FSLogix profiles working"
  echo ""
} > "artifacts/outputs/rbac-app-group-permissions.txt"

echo "[SUCCESS] Application group permissions assignment completed"
exit 0
