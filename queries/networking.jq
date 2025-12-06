# ==============================================================================
# Networking (VNet) Resource Filter - Token Efficiency Optimized
# ==============================================================================
#
# Purpose: Extract essential VNet information while minimizing token usage
# Input: Array of Azure VNet objects (from 'az network vnet list')
# Output: Minimal VNet objects with key properties
#

map({
    id: .id,
    name: .name,
    resourceGroup: .resourceGroup,
    location: .location,
    addressSpace: .addressSpace.addressPrefixes,
    subnets: (
        .subnets
        | map({
            name: .name,
            addressPrefix: .addressPrefix,
            nsgId: (.networkSecurityGroup.id? // null),
            serviceEndpoints: ([.serviceEndpoints[]?.service?] // [])
        })
    ),
    dnsServers: (.dhcpOptions?.dnsServers? // []),
    provisioningState: .provisioningState,
    enableDdosProtection: .enableDdosProtection,
    enableVmProtection: .enableVmProtection,
    tags: .tags
})
