#!/bin/bash
# ==============================================================================
# Validate All Entra ID Security Groups
# ==============================================================================

set -euo pipefail

echo "[START] Validating all Entra ID security groups: $(date '+%Y-%m-%d %H:%M:%S')"

# Define expected groups from config
declare -A EXPECTED_GROUPS=(
  ["Users"]="AVD-Users-Standard"
  ["Admins"]="AVD-Users-Admins"
  ["SSO Devices"]="AVD-Devices-Pooled-SSO"
  ["FSLogix Devices"]="AVD-Devices-Pooled-FSLogix"
  ["Network Devices"]="AVD-Devices-Pooled-Network"
  ["Security Devices"]="AVD-Devices-Pooled-Security"
)

VALIDATION_PASSED=true
TOTAL_GROUPS=0
FOUND_GROUPS=0
MISSING_GROUPS=()

echo "[PROGRESS] Checking all security groups..."
echo ""

# Validate each group
for GROUP_TYPE in "${!EXPECTED_GROUPS[@]}"; do
  GROUP_NAME="${EXPECTED_GROUPS[$GROUP_TYPE]}"
  TOTAL_GROUPS=$((TOTAL_GROUPS + 1))

  echo "[VALIDATE] Checking: $GROUP_TYPE ($GROUP_NAME)"

  GROUP_ID=$(az ad group list \
    --filter "displayName eq '$GROUP_NAME'" \
    --query "[0].id" -o tsv 2>/dev/null || echo "")

  if [[ -n "$GROUP_ID" && "$GROUP_ID" != "None" ]]; then
    FOUND_GROUPS=$((FOUND_GROUPS + 1))

    # Get group details
    SECURITY_ENABLED=$(az ad group show --group "$GROUP_ID" \
      --query "securityEnabled" -o tsv)
    MEMBER_COUNT=$(az ad group member list --group "$GROUP_ID" \
      --query "length(@)" -o tsv)

    echo "  ✓ Found: $GROUP_NAME"
    echo "    ID: $GROUP_ID"
    echo "    Security Enabled: $SECURITY_ENABLED"
    echo "    Members: $MEMBER_COUNT"
  else
    echo "  ✗ MISSING: $GROUP_NAME"
    MISSING_GROUPS+=("$GROUP_NAME")
    VALIDATION_PASSED=false
  fi
  echo ""
done

# Generate summary
echo "[VALIDATE] =========================================="
echo "[VALIDATE] Validation Summary"
echo "[VALIDATE] =========================================="
echo "[VALIDATE] Total groups expected: $TOTAL_GROUPS"
echo "[VALIDATE] Groups found: $FOUND_GROUPS"
echo "[VALIDATE] Groups missing: ${#MISSING_GROUPS[@]}"
echo ""

if [[ "$VALIDATION_PASSED" == true ]]; then
  echo "[SUCCESS] All security groups validated successfully"
  echo ""
  echo "[INFO] Next steps:"
  echo "[INFO]   1. Add user members to groups:"
  echo "[INFO]      az ad group member add --group <group-id> --member-id <user-object-id>"
  echo "[INFO]   2. Proceed to Module 04: Host Pool & Workspace creation"
  echo "[INFO]   3. Use groups for application group assignments"
  echo "[INFO]   4. Configure RBAC role assignments (Module 08)"
  echo "[INFO]   5. Apply Intune/Conditional Access policies to device groups"

  # Save validation results
  {
    echo "{"
    echo "  \"timestamp\": \"$(date -u '+%Y-%m-%dT%H:%M:%SZ')\","
    echo "  \"validation_passed\": true,"
    echo "  \"total_groups\": $TOTAL_GROUPS,"
    echo "  \"found_groups\": $FOUND_GROUPS,"
    echo "  \"groups\": {"
    for GROUP_TYPE in "${!EXPECTED_GROUPS[@]}"; do
      GROUP_NAME="${EXPECTED_GROUPS[$GROUP_TYPE]}"
      GROUP_ID=$(az ad group list \
        --filter "displayName eq '$GROUP_NAME'" \
        --query "[0].id" -o tsv)
      echo "    \"$GROUP_TYPE\": {"
      echo "      \"name\": \"$GROUP_NAME\","
      echo "      \"id\": \"$GROUP_ID\""
      echo "    },"
    done | sed '$ s/,$//'
    echo "  }"
    echo "}"
  } > artifacts/outputs/entra-validate-groups.json

  exit 0
else
  echo "[ERROR] Validation failed - missing groups:"
  for MISSING_GROUP in "${MISSING_GROUPS[@]}"; do
    echo "[ERROR]   - $MISSING_GROUP"
  done
  echo ""
  echo "[ERROR] Please re-run the failed operations or check logs"

  exit 1
fi
