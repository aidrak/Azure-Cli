# Common Documentation

Reference documentation shared across all AVD deployment steps.

## Documentation Files

### azure-cli-reference.md
Comprehensive reference of Azure CLI commands for AVD deployments

**Includes**:
- Authentication and account management
- Resource group operations
- Networking (VNets, subnets, NSGs)
- Virtual machines
- Storage accounts and file shares
- Azure Virtual Desktop services (host pools, app groups, workspaces)
- Image galleries
- And more...

**How to Use**:
- Search for specific operations (e.g., "create virtual network")
- Copy commands and adapt for your environment
- Reference as needed during script development

**Example**:
```bash
# From azure-cli-reference.md
az network vnet create \
  --resource-group <rg-name> \
  --name <vnet-name> \
  --address-prefixes <cidr>
```

## Additional Documentation (Planned)

### TROUBLESHOOTING.md
Common issues and solutions across all deployment steps

**Will Include**:
- Networking issues and solutions
- Storage access problems
- VM creation failures
- Authentication/permission issues
- Performance problems
- Scaling issues
- And more...

**Pattern**:
- Problem statement
- Root cause
- Step-by-step resolution
- Prevention tips
- Related links

### ARCHITECTURE.md
Design decisions and architectural patterns for AVD deployments

**Will Include**:
- Overall architecture overview
- Component relationships
- Security considerations
- Network topology decisions
- Storage strategy
- Scalability approach
- Disaster recovery planning
- Cost optimization strategies

### FUNCTIONS.md
Reference documentation for function libraries

**Will Include**:
- Function signatures
- Parameters and return values
- Usage examples
- Common patterns
- Best practices

## Documentation Standards

All documentation follows these standards:

1. **Clear Headers**: Use markdown headers (# ## ###)
2. **Code Examples**: Include practical examples
3. **Links**: Cross-reference related documentation
4. **Search-Friendly**: Use keywords for discoverability
5. **Maintainable**: Update with code changes

## Creating New Documentation

When adding documentation:

1. **File naming**: Use clear, descriptive names (e.g., `TOPIC-AREA.md`)
2. **Header**: Start with purpose and audience
3. **Structure**: Use consistent sections
4. **Examples**: Include practical examples
5. **Updates**: Keep in sync with code changes

## Using Documentation in Scripts

Reference documentation from scripts:

```bash
# In task script
echo "For more information, see ../common/docs/TROUBLESHOOTING.md"
echo "For Azure CLI commands, see ../common/docs/azure-cli-reference.md"
```

## Documentation Organization

```
docs/
├── README.md (this file)
├── azure-cli-reference.md (current)
├── TROUBLESHOOTING.md (planned)
├── ARCHITECTURE.md (planned)
└── FUNCTIONS.md (planned)
```

## Status

**Current**: 1 file (Azure CLI reference)
**Planned**: 3 additional files
**Timeline**: Phase 2B onwards

---

**Last Updated**: Phase 2A (Reorganization)
**Next**: Phase 2B - Complete function and template implementations
