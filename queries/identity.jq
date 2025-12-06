# ==============================================================================
# Identity (Entra Groups) Resource Filter - Token Efficiency Optimized
# ==============================================================================
#
# Purpose: Extract essential Entra group information while minimizing token usage
# Input: Array of Azure AD Group objects (from 'az ad group list')
# Output: Minimal group objects with key properties
#

map({
    id: .id,
    objectId: (.objectId? // .id),
    displayName: .displayName,
    mailNickname: .mailNickname,
    description: .description,
    securityEnabled: .securityEnabled,
    mailEnabled: .mailEnabled,
    groupTypes: (.groupTypes? // []),
    onPremisesSyncEnabled: .onPremisesSyncEnabled?,
    membershipRule: .membershipRule?
})
