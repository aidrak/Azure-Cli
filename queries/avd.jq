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
    hostPoolType: .properties.hostPoolType,
    loadBalancerType: .properties.loadBalancerType,
    maxSessionLimit: .properties.maxSessionLimit,
    preferredAppGroupType: .properties.preferredAppGroupType,
    validationEnvironment: .properties.validationEnvironment,
    registrationInfo: {
        expirationTime: .properties.registrationInfo?.expirationTime?,
        registrationTokenOperation: .properties.registrationInfo?.registrationTokenOperation?
    },
    vmTemplate: .properties.vmTemplate?,
    ssoContext: .properties.ssoContext?,
    friendlyName: .properties.friendlyName?,
    description: .properties.description?,
    tags: .tags
})
