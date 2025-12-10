#!/bin/bash
set -euo pipefail

# Create AVD SSO Dynamic Group using Azure CLI
# This creates a dynamic group containing all AVD session hosts

echo "[START] Creating AVD SSO Dynamic Group"

GROUP_NAME="AVD-SessionHosts-SSO"
GROUP_DESCRIPTION="Dynamic group for all AVD session hosts - used for SSO configuration"
MEMBERSHIP_RULE='(device.displayName -startsWith "avd-")'

# Check if group already exists
echo "[*] Checking if group already exists..."
EXISTING_GROUP=$(az ad group list --filter "displayName eq '$GROUP_NAME'" --query '[0].id' -o tsv 2>/dev/null || echo "")

if [ -n "$EXISTING_GROUP" ]; then
    echo "[v] Group already exists: $GROUP_NAME"
    echo "[i] Group ID: $EXISTING_GROUP"
    GROUP_ID="$EXISTING_GROUP"
else
    echo "[*] Creating dynamic group: $GROUP_NAME"

    # Create the dynamic group using Microsoft Graph REST API
    # Write JSON to temp file to avoid variable expansion issues
    cat > /tmp/group-payload.json <<'EOF'
{
  "displayName": "AVD-SessionHosts-SSO",
  "description": "Dynamic group for all AVD session hosts - used for SSO configuration",
  "mailEnabled": false,
  "mailNickname": "AVDSessionHostsSSO",
  "securityEnabled": true,
  "groupTypes": ["DynamicMembership"],
  "membershipRule": "(device.displayName -startsWith \"avd-\")",
  "membershipRuleProcessingState": "On"
}
EOF

    GROUP_ID=$(az rest --method POST \
        --uri "https://graph.microsoft.com/v1.0/groups" \
        --headers "Content-Type=application/json" \
        --body @/tmp/group-payload.json \
        --query 'id' -o tsv)

    echo "[v] Dynamic group created successfully"
    echo "[i] Group ID: $GROUP_ID"
    echo "[i] Membership Rule: $MEMBERSHIP_RULE"
    echo "[!] Note: Dynamic group membership will update within 5-10 minutes"
fi

# Save the group ID for the next step
echo "$GROUP_ID" > artifacts/outputs/sso-group-id.txt
echo "[i] Group ID saved to: artifacts/outputs/sso-group-id.txt"

echo "[SUCCESS] Dynamic group configuration completed"
exit 0
