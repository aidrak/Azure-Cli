# JQ Query Filters for Token Efficiency

This directory contains JQ filters designed to minimize token usage when querying Azure resources.

## Purpose

Azure CLI returns verbose JSON with many fields that may not be needed for typical operations. These JQ filters extract only the essential information, reducing:
- Token usage in caching
- Network transfer sizes
- Processing time
- Storage requirements

## Available Filters

### compute.jq
Filters VM objects to extract:
- Basic identification (id, name, resource group, location)
- Hardware profile (VM size)
- OS information (type, disk details)
- Network configuration (private/public IPs)
- Power state and provisioning state
- Image reference
- Tags

### networking.jq
Filters VNet objects to extract:
- Basic identification
- Address space and subnets
- Subnet configurations (NSGs, service endpoints)
- DNS settings
- DDoS and VM protection status
- Tags

### storage.jq
Filters storage account objects to extract:
- Basic identification
- SKU and kind
- Primary endpoints
- Encryption settings
- Access tier
- Network rules
- Security settings (HTTPS, TLS, public access)
- Tags

### identity.jq
Filters Entra ID group objects to extract:
- Basic identification (id, displayName)
- Group type and security settings
- Membership information
- Sync status
- Tags

### avd.jq
Filters AVD host pool objects to extract:
- Basic identification
- Host pool configuration (type, load balancer)
- Session limits
- Registration info
- VM template
- SSO context
- Tags

### summary.jq
Ultra-minimal filter for quick overviews:
- Name
- Type
- Location
- State

## Usage

These filters are automatically used by `core/query.sh`:

```bash
# Use summary filter (default)
query_resources "compute"

# Use full filter
query_resources "compute" "" "full"
```

## Token Reduction

Example savings for a typical VM query:
- Raw Azure CLI output: ~2000 tokens
- Filtered output: ~200 tokens
- **90% reduction**

## Adding Custom Filters

To add a new filter:

1. Create `<resource-type>.jq` in this directory
2. Follow the structure of existing filters
3. Use the `map()` function to process arrays
4. Select only essential fields
5. Use optional operators (`?`) to handle missing fields
6. Provide default values with `//` operator

Example:
```jq
map({
    id: .id,
    name: .name,
    location: .location,
    state: .provisioningState // "Unknown"
})
```

## Testing Filters

Test a filter manually:
```bash
az vm list -o json | jq -f queries/compute.jq
```
