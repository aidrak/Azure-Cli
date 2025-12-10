# ==============================================================================
# AVD (Host Pool) Resource Filter - Token Efficiency Optimized
# ==============================================================================
#
# Purpose: Extract essential AVD host pool information while minimizing token usage
# Input: Array of AVD Host Pool objects (from 'az desktopvirtualization hostpool list')
# Output: Minimal host pool objects with key properties
#

map({
    id: .id,
    name: .name,
    resourceGroup: .resourceGroup,
    location: .location,
    hostPoolType: .hostPoolType,
    loadBalancerType: .loadBalancerType,
    maxSessionLimit: .maxSessionLimit,
    preferredAppGroupType: .preferredAppGroupType,
    validationEnvironment: .validationEnvironment,
    customRdpProperty: .customRdpProperty,
    registrationInfo: .registrationInfo,
    vmTemplate: .vmTemplate,
    ssoContext: .ssoContext,
    friendlyName: .friendlyName,
    description: .description,
    identity: .identity,
    tags: .tags
})
