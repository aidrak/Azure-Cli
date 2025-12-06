# ==============================================================================
# Compute (VM) Resource Filter - Token Efficiency Optimized
# ==============================================================================
#
# Purpose: Extract essential VM information while minimizing token usage
# Input: Array of Azure VM objects (from 'az vm list --show-details')
# Output: Minimal VM objects with key properties
#

map({
    id: .id,
    name: .name,
    resourceGroup: .resourceGroup,
    location: .location,
    vmSize: .hardwareProfile.vmSize,
    osType: .storageProfile.osDisk.osType,
    provisioningState: .provisioningState,
    powerState: ((.instanceView.statuses[]? | select(.code | startswith("PowerState/")) | .displayStatus) // "Unknown"),
    privateIp: (.privateIps[0]? // .networkProfile.networkInterfaces[0]?.privateIpAddress? // null),
    publicIp: (.publicIps[0]? // null),
    adminUsername: .osProfile.adminUsername,
    imageReference: {
        publisher: .storageProfile.imageReference.publisher,
        offer: .storageProfile.imageReference.offer,
        sku: .storageProfile.imageReference.sku
    },
    osDiskName: .storageProfile.osDisk.name,
    osDiskSize: .storageProfile.osDisk.diskSizeGB,
    nicIds: [.networkProfile.networkInterfaces[]?.id],
    tags: .tags
})
