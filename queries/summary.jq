# ==============================================================================
# Summary Resource Filter - Ultra-Minimal for Overview Queries
# ==============================================================================
#
# Purpose: Provide absolute minimum information for quick overviews
# Input: Array of any Azure resource objects
# Output: Ultra-minimal resource objects (name, type, location, state only)
#

map({
    name: .name,
    type: (.type // .resourceType // "unknown"),
    location: .location,
    state: (.provisioningState // .properties.provisioningState? // "Unknown")
})
