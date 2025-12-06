# Discovery Engine Documentation

## Overview

The Discovery Engine is a comprehensive resource discovery system for Azure Infrastructure Toolkit that provides:

- **Intelligent Discovery**: Subscription-wide or resource-group-scoped resource scanning
- **Token Efficiency**: JQ-filtered queries to minimize token usage by 90%+
- **Dependency Analysis**: Automatic dependency graph construction
- **State Management**: All resources stored in SQLite for intelligent caching
- **Multiple Outputs**: YAML summary, JSON full inventory, GraphViz DOT graph
- **Azure Tagging**: Optional automatic tagging of discovered resources

## Quick Start

```bash
# Discover a resource group
source core/discovery.sh
discover "resource-group" "RG-Azure-VDI-01"

# Discover entire subscription
discover "subscription" "your-subscription-id"

# Convenience functions
discover_resource_group "RG-Azure-VDI-01"
discover_subscription  # Uses current subscription
```

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    DISCOVERY ENGINE                          │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Phase 1: Resource Discovery                                │
│  ┌────────────────────────────────────────────────────┐    │
│  │ • Batch query all resources (az resource list)     │    │
│  │ • Type-specific queries (VMs, VNets, Storage, etc) │    │
│  │ • Apply JQ filters for token efficiency            │    │
│  │ • Store in SQLite state database                   │    │
│  └────────────────────────────────────────────────────┘    │
│                           ↓                                  │
│  Phase 2: Dependency Analysis                               │
│  ┌────────────────────────────────────────────────────┐    │
│  │ • Detect dependencies from resource properties      │    │
│  │ • Build dependency graph (DAG)                      │    │
│  │ • Store relationships in dependencies table         │    │
│  │ • Export to JSON and GraphViz DOT formats          │    │
│  └────────────────────────────────────────────────────┘    │
│                           ↓                                  │
│  Phase 3: Azure Tagging (Optional)                          │
│  ┌────────────────────────────────────────────────────┐    │
│  │ • Tag resources with "discovered-by-toolkit=true"  │    │
│  │ • Add discovery timestamp                           │    │
│  └────────────────────────────────────────────────────┘    │
│                           ↓                                  │
│  Phase 4: Output Generation                                 │
│  ┌────────────────────────────────────────────────────┐    │
│  │ • Generate YAML summary (token-efficient)          │    │
│  │ • Generate full JSON inventory                      │    │
│  │ • Export dependency graphs                          │    │
│  └────────────────────────────────────────────────────┘    │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## Functions Reference

### Main Discovery Functions

#### `discover <scope> <target>`
Main discovery entry point.

**Arguments:**
- `scope`: "subscription" or "resource-group"
- `target`: Subscription ID or resource group name

**Returns:**
- 0 on success
- 1 on failure

**Example:**
```bash
discover "resource-group" "RG-Azure-VDI-01"
discover "subscription" "12345678-1234-1234-1234-123456789012"
```

**Output Files:**
- `discovered/inventory-summary.yaml` - Token-efficient summary
- `discovered/inventory-full.json` - Complete resource details
- `discovered/dependency-graph.json` - Dependency graph (JSON)
- `discovered/dependency-graph.dot` - Dependency graph (GraphViz)
- `state.db` - SQLite state database

#### `discover_resource_group <resource-group-name>`
Convenience function for resource group discovery.

**Example:**
```bash
discover_resource_group "RG-Azure-VDI-01"
```

#### `discover_subscription [subscription-id]`
Convenience function for subscription discovery. Uses current subscription if not specified.

**Example:**
```bash
discover_subscription
discover_subscription "12345678-1234-1234-1234-123456789012"
```

#### `rediscover <scope> <target>`
Re-run discovery with cache invalidation (forces fresh Azure queries).

**Example:**
```bash
rediscover "resource-group" "RG-Azure-VDI-01"
```

### Resource Type Discovery Functions

#### `discover_compute_resources <scope> <target>`
Discover compute resources: VMs, disks, availability sets.

**Returns:** Count of discovered compute resources

**Example:**
```bash
compute_count=$(discover_compute_resources "resource-group" "RG-Azure-VDI-01")
echo "Found $compute_count compute resources"
```

#### `discover_networking_resources <scope> <target>`
Discover networking resources: VNets, subnets, NSGs, NICs, public IPs.

**Returns:** Count of discovered networking resources

#### `discover_storage_resources <scope> <target>`
Discover storage resources: Storage accounts, file shares.

**Returns:** Count of discovered storage resources

#### `discover_identity_resources <scope> <target>`
Discover identity resources: Entra ID groups.

**Returns:** Count of discovered identity resources

#### `discover_avd_resources <scope> <target>`
Discover AVD resources: Host pools, application groups, workspaces.

**Returns:** Count of discovered AVD resources

#### `discover_all_resources <scope> <target>`
Batch discovery using `az resource list` (most efficient).

**Returns:** Total count of discovered resources

### Dependency Graph Functions

