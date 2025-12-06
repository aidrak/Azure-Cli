#!/bin/bash
set -euo pipefail

echo "[START] Storage Permissions Assignment: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"

# Configuration from config.yaml
RESOURCE_GROUP="RG-Azure-VDI-01"
SUBSCRIPTION_ID="6c7eb5e0-8e77-40dd-a06c-bdb06c2d5856"
FILE_SHARE_NAME="fslogix-profiles"
STD_GROUP_NAME="AVD-Users-Standard"
ADMIN_GROUP_NAME="AVD-Users-Admins"

# Step 1: Validate Azure authentication
echo "[PROGRESS] Step 1/6: Validating Azure authentication..."
if ! az account show &>/dev/null; then
  echo "[ERROR] Not authenticated to Azure"
  exit 1
fi

# Step 2: Find storage account (auto-generated name starts with 'fslogix' or explicit name)
echo "[PROGRESS] Step 2/6: Finding FSLogix storage account..."
STORAGE_ACCOUNT=$(az storage account list \
  --resource-group "$RESOURCE_GROUP" \
  --query "[?starts_with(name, 'fslogix')] | [0].name" -o tsv)

if [[ -z "$STORAGE_ACCOUNT" || "$STORAGE_ACCOUNT" == "null" ]]; then
  echo "[ERROR] FSLogix storage account not found in resource group: $RESOURCE_GROUP"
  echo "[ERROR] Please ensure storage account was created (Module 02)"
  exit 1
fi

echo "[VALIDATE] Found storage account: $STORAGE_ACCOUNT"

# Get storage account resource ID
STORAGE_ID=$(az storage account show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$STORAGE_ACCOUNT" \
  --query id -o tsv)

# Construct file share resource ID
FILE_SHARE_ID="${STORAGE_ID}/fileServices/default/fileshares/${FILE_SHARE_NAME}"

echo "[VALIDATE] File share resource ID: $FILE_SHARE_ID"

# Step 3: Get user group IDs
echo "[PROGRESS] Step 3/6: Getting user group IDs..."

STD_GROUP_ID=$(az ad group list \
  --filter "displayName eq '${STD_GROUP_NAME}'" \
  --query "[0].id" -o tsv)

if [[ -z "$STD_GROUP_ID" || "$STD_GROUP_ID" == "null" ]]; then
  echo "[ERROR] Standard users group not found: $STD_GROUP_NAME"
  echo "[ERROR] Please ensure Entra ID groups were created (Module 03)"
  exit 1
fi

echo "[VALIDATE] Standard users group ID: $STD_GROUP_ID"

ADMIN_GROUP_ID=$(az ad group list \
  --filter "displayName eq '${ADMIN_GROUP_NAME}'" \
  --query "[0].id" -o tsv)

if [[ -z "$ADMIN_GROUP_ID" || "$ADMIN_GROUP_ID" == "null" ]]; then
  echo "[ERROR] Admin users group not found: $ADMIN_GROUP_NAME"
  echo "[ERROR] Please ensure Entra ID groups were created (Module 03)"
  exit 1
fi

echo "[VALIDATE] Admin users group ID: $ADMIN_GROUP_ID"

# Step 4: Assign storage permissions to standard users
echo "[PROGRESS] Step 4/6: Assigning storage permissions to standard users..."
echo "[PROGRESS] Role: Storage File Data SMB Share Contributor"
echo "[PROGRESS] Group: $STD_GROUP_NAME"

if az role assignment create \
  --assignee "$STD_GROUP_ID" \
  --role "Storage File Data SMB Share Contributor" \
  --scope "$FILE_SHARE_ID" \
  --output none 2>/dev/null; then
  echo "[SUCCESS] Storage permissions assigned to standard users"
else
  # Check if already exists
  if az role assignment list \
    --assignee "$STD_GROUP_ID" \
    --scope "$FILE_SHARE_ID" \
    --query "[?roleDefinitionName=='Storage File Data SMB Share Contributor']" -o tsv | grep -q "Storage"; then
    echo "[SUCCESS] Storage permissions already assigned to standard users"
  else
    echo "[ERROR] Failed to assign storage permissions to standard users"
    exit 1
  fi
fi

# Step 5: Assign elevated storage permissions to admin users
echo "[PROGRESS] Step 5/6: Assigning elevated storage permissions to admin users..."
echo "[PROGRESS] Role: Storage File Data SMB Share Elevated Contributor"
echo "[PROGRESS] Group: $ADMIN_GROUP_NAME"

if az role assignment create \
  --assignee "$ADMIN_GROUP_ID" \
  --role "Storage File Data SMB Share Elevated Contributor" \
  --scope "$FILE_SHARE_ID" \
  --output none 2>/dev/null; then
  echo "[SUCCESS] Elevated storage permissions assigned to admin users"
else
  # Check if already exists
  if az role assignment list \
    --assignee "$ADMIN_GROUP_ID" \
    --scope "$FILE_SHARE_ID" \
    --query "[?roleDefinitionName=='Storage File Data SMB Share Elevated Contributor']" -o tsv | grep -q "Storage"; then
    echo "[SUCCESS] Elevated storage permissions already assigned to admin users"
  else
    echo "[ERROR] Failed to assign elevated storage permissions to admin users"
    exit 1
  fi
fi

# Step 6: Verify assignments
echo "[PROGRESS] Step 6/6: Verifying role assignments..."

STD_ASSIGNMENTS=$(az role assignment list \
  --assignee "$STD_GROUP_ID" \
  --scope "$FILE_SHARE_ID" \
  --query "[].roleDefinitionName" -o tsv)

ADMIN_ASSIGNMENTS=$(az role assignment list \
  --assignee "$ADMIN_GROUP_ID" \
  --scope "$FILE_SHARE_ID" \
  --query "[].roleDefinitionName" -o tsv)

echo "[VALIDATE] Standard users roles: $STD_ASSIGNMENTS"
echo "[VALIDATE] Admin users roles: $ADMIN_ASSIGNMENTS"

# Save assignment details
{
  echo "Storage RBAC Assignment Details"
  echo "================================"
  echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
  echo ""
  echo "Storage Account:"
  echo "  Name: $STORAGE_ACCOUNT"
  echo "  Resource Group: $RESOURCE_GROUP"
  echo "  File Share: $FILE_SHARE_NAME"
  echo ""
  echo "Standard Users ($STD_GROUP_NAME):"
  echo "  Group ID: $STD_GROUP_ID"
  echo "  Role: Storage File Data SMB Share Contributor"
  echo "  Scope: File Share ($FILE_SHARE_NAME)"
  echo "  Permissions: Read/Write own FSLogix profile"
  echo ""
  echo "Admin Users ($ADMIN_GROUP_NAME):"
  echo "  Group ID: $ADMIN_GROUP_ID"
  echo "  Role: Storage File Data SMB Share Elevated Contributor"
  echo "  Scope: File Share ($FILE_SHARE_NAME)"
  echo "  Permissions: Manage all FSLogix profiles (elevated)"
  echo ""
  echo "Next Steps:"
  echo "  1. Assign VM login permissions (next operation)"
  echo "  2. Assign application group permissions"
  echo "  3. Test user access to FSLogix profiles"
  echo ""
} > "artifacts/outputs/rbac-storage-permissions.txt"

echo "[SUCCESS] Storage permissions assignment completed"
exit 0
