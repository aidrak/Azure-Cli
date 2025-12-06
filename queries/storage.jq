# ==============================================================================
# Storage Account Resource Filter - Token Efficiency Optimized
# ==============================================================================
#
# Purpose: Extract essential storage account information while minimizing token usage
# Input: Array of Azure Storage Account objects (from 'az storage account list')
# Output: Minimal storage account objects with key properties
#

map({
    id: .id,
    name: .name,
    resourceGroup: .resourceGroup,
    location: .location,
    kind: .kind,
    sku: {
        name: .sku.name,
        tier: .sku.tier
    },
    provisioningState: .provisioningState,
    primaryEndpoints: {
        blob: .primaryEndpoints.blob?,
        file: .primaryEndpoints.file?,
        queue: .primaryEndpoints.queue?,
        table: .primaryEndpoints.table?,
        dfs: .primaryEndpoints.dfs?
    },
    encryption: {
        services: {
            blob: .encryption.services.blob?.enabled?,
            file: .encryption.services.file?.enabled?
        },
        keySource: .encryption.keySource?
    },
    accessTier: .accessTier?,
    allowBlobPublicAccess: .allowBlobPublicAccess,
    minimumTlsVersion: .minimumTlsVersion?,
    enableHttpsTrafficOnly: .enableHttpsTrafficOnly,
    networkRuleSet: {
        defaultAction: .networkRuleSet?.defaultAction?,
        bypass: .networkRuleSet?.bypass?
    },
    tags: .tags
})
