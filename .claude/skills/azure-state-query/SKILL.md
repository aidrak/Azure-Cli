---
name: azure-state-query
description: Query live Azure environment state using JQ filters. Lists VMs, resource groups, storage accounts, identity resources, networking, and AVD resources. Use when asking about current Azure infrastructure, what resources exist, environment status, resource inventory, or checking if resources are deployed.
allowed-tools: Bash, Grep, Read
---

# Azure State Query

Query the live Azure environment to understand current infrastructure state using optimized JQ filters.

## When to use this Skill

- User asks "What VMs exist?" or "Show all resources"
- User asks "What's the current state of..." or "List Azure resources"
- User needs to check if a resource exists (VNet, VM, storage account, etc.)
- User needs to inventory Azure resources by type
- User asks for resource details, properties, or configuration
- User asks "Show me the current Azure environment"
- User wants to verify deployment status

## Key Patterns

All queries use the optimized JQ filters in `queries/` for token efficiency (90% reduction).

### Load Configuration First

```bash
# ALWAYS load config first - exports 50+ environment variables
source core/config-manager.sh && load_config

# Verify config loaded
echo $AZURE_RESOURCE_GROUP
```

### Query Azure Resources

```bash
# List VMs (filtered output)
az vm list -g "$AZURE_RESOURCE_GROUP" -o json | jq -f queries/compute.jq

# List all VNets (filtered output)
az network vnet list -g "$AZURE_RESOURCE_GROUP" -o json | jq -f queries/networking.jq

# List storage accounts (filtered output)
az storage account list -o json | jq -f queries/storage.jq

# List Entra ID groups (filtered output)
az ad group list --filter "startswith(displayName, 'AVD-')" -o json | jq -f queries/identity.jq

# List AVD host pools (filtered output)
az desktopvirtualization hostpool list -g "$AZURE_RESOURCE_GROUP" -o json | jq -f queries/avd.jq

# Ultra-minimal summary (name, type, location, state only)
az resource list -g "$AZURE_RESOURCE_GROUP" -o json | jq -f queries/summary.jq
```

### Query Specific Resource Details

```bash
# Get specific VM details
az vm show -g "$AZURE_RESOURCE_GROUP" -n "vm-golden-image" -o json | jq -f queries/compute.jq

# Get VNet details
az network vnet show -g "$AZURE_RESOURCE_GROUP" -n "vnet-avd-prod" -o json | jq -f queries/networking.jq

# Get storage account details
az storage account show -n "stavdprod01" -o json | jq -f queries/storage.jq
```

### Query Operation State (NOT Azure resources)

For operation status, use the state database:

```bash
# Check operation status
sqlite3 state.db "SELECT operation_id, status, timestamp FROM operations ORDER BY timestamp DESC LIMIT 20"

# Find failed operations
sqlite3 state.db "SELECT operation_id, status, error_message FROM operations WHERE status = 'FAILED'"

# Check specific operation
sqlite3 state.db "SELECT * FROM operations WHERE operation_id = 'compute-create-vm'"
```

## Available JQ Filters

Located in `queries/` directory:

- **compute.jq** - VMs (size, OS, network, power state)
- **networking.jq** - VNets (address space, subnets, NSGs, DNS)
- **storage.jq** - Storage accounts (SKU, endpoints, encryption, security)
- **identity.jq** - Entra ID groups (type, members, sync)
- **avd.jq** - AVD host pools (type, load balancer, sessions, SSO)
- **summary.jq** - Ultra-minimal (name, type, location, state)
- **common.jq** - Reusable functions for all filters

**Token reduction**: Raw Azure CLI output ~2000 tokens → Filtered ~200 tokens (90% reduction)

## Checklist

1. Load configuration: `source core/config-manager.sh && load_config`
2. Verify variable is set: `echo $AZURE_RESOURCE_GROUP`
3. Run appropriate `az` command for resource type
4. Pipe through JQ filter: `| jq -f queries/<type>.jq`
5. Report findings to user in clear format

## CRITICAL: Command Formatting Rules

**ALWAYS use hardcoded resource group name "RG-Azure-VDI-01" in az commands, NOT variables!**

The issue: When using `source && load_config && az vm list -g "$AZURE_RESOURCE_GROUP"`, the variable doesn't persist in the same command chain, causing Azure API errors.

**WRONG - Variable gets lost:**
```bash
source core/config-manager.sh && load_config && az vm list -g "$AZURE_RESOURCE_GROUP" -o json
```

**RIGHT - Use hardcoded value:**
```bash
source core/config-manager.sh && load_config && az vm list -g "RG-Azure-VDI-01" -o json | jq -f queries/compute.jq
```

**Or separate the commands (but wastes tokens):**
```bash
# Load config first
source core/config-manager.sh && load_config

# Then run az command in separate Bash call
az vm list -g "$AZURE_RESOURCE_GROUP" -o json | jq -f queries/compute.jq
```

**Best practice: Use hardcoded "RG-Azure-VDI-01" for all az commands in this skill!**

## Common Queries

### What VMs exist?
```bash
source core/config-manager.sh && load_config && az vm list -g "RG-Azure-VDI-01" -o json | jq -f queries/compute.jq
```

### What's deployed in my resource group?
```bash
source core/config-manager.sh && load_config && az resource list -g "RG-Azure-VDI-01" -o json | jq -f queries/summary.jq
```

### Show all storage accounts
```bash
source core/config-manager.sh && load_config && az storage account list -g "RG-Azure-VDI-01" -o json | jq -f queries/storage.jq
```

### Show networking configuration
```bash
source core/config-manager.sh && load_config && az network vnet list -g "RG-Azure-VDI-01" -o json | jq -f queries/networking.jq
```

### Show AVD host pools
```bash
source core/config-manager.sh && load_config && az desktopvirtualization hostpool list -g "RG-Azure-VDI-01" -o json | jq -f queries/avd.jq
```

### Check Entra ID groups
```bash
source core/config-manager.sh && load_config && az ad group list --filter "startswith(displayName, 'AVD-')" -o json | jq -f queries/identity.jq
```

## Examples

### Example 1: User asks "What VMs exist?"
```bash
source core/config-manager.sh && load_config && az vm list -g "RG-Azure-VDI-01" -o json | jq -f queries/compute.jq
```

**Expected output**: Clean JSON with VM name, size, OS, power state, IPs

### Example 2: User asks "Show current Azure state"
```bash
source core/config-manager.sh && load_config && az resource list -g "RG-Azure-VDI-01" -o json | jq -f queries/summary.jq
```

```bash
source core/config-manager.sh && load_config && az resource list -g "RG-Azure-VDI-01" -o json | jq -r '.[].type' | sort | uniq -c
```

### Example 3: User asks "Is the golden image VM ready?"
```bash
source core/config-manager.sh && load_config && az vm show -g "RG-Azure-VDI-01" -n "vm-golden-img" -o json | jq -f queries/compute.jq
```

```bash
source core/config-manager.sh && load_config && az vm get-instance-view -g "RG-Azure-VDI-01" -n "vm-golden-img" -o json | jq -r '.statuses[] | select(.code | startswith("PowerState/")) | .displayStatus'
```

## Testing JQ Filters Manually

```bash
# Test a filter directly
az vm list -g "$AZURE_RESOURCE_GROUP" -o json | jq -f queries/compute.jq

# Test with pretty output
az vm list -g "$AZURE_RESOURCE_GROUP" -o json | jq -f queries/compute.jq | jq '.'

# Compare raw vs filtered token count
az vm list -o json > raw.json
az vm list -o json | jq -f queries/compute.jq > filtered.json
wc -c raw.json filtered.json  # See size difference
```

## Limitations

- **Read-only**: This skill only queries state, doesn't modify resources
- **Requires Azure authentication**: Must run `az login` first
- **Requires config.yaml loaded**: Must source core/config-manager.sh
- **Live data only**: Queries current Azure state, not historical
- **Not for operation status**: Use state.db for operation tracking

## Related Skills

- **azure-operations**: Deploy and modify infrastructure
- **azure-troubleshooting**: Debug failures and fix issues

## Documentation

- JQ filter reference: `queries/README.md`
- Azure CLI reference: `docs/reference/azure-cli-core.md`
- Query script documentation: `core/query.sh`
