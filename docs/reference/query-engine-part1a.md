# Query Engine Documentation

## Overview

The Query Engine (`core/query.sh`) is the primary interface for querying Azure resources with intelligent caching and token efficiency optimization.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      QUERY ENGINE                            │
│                   (core/query.sh)                            │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Cache-First Strategy:                                      │
│  1. Check state-manager cache (if available)                │
│  2. On cache miss, query Azure CLI                          │
│  3. Apply JQ filter for token efficiency                    │
│  4. Store result in cache                                   │
│  5. Return filtered result                                  │
│                                                              │
└─────────────────────────────────────────────────────────────┘
         ↓                                    ↓
    ┌────────────┐                      ┌──────────────┐
    │  State     │                      │  JQ Filters  │
    │  Manager   │                      │  (queries/)  │
    └────────────┘                      └──────────────┘
```

## Core Functions

### Main Query Interface

#### `query_resources(resource_type, resource_group, output_format)`

Query resources by type with cache-first approach.

**Parameters:**
- `resource_type`: Type of resource to query
  - `compute|vms|vm` - Virtual Machines
  - `networking|vnets|vnet` - Virtual Networks
  - `storage` - Storage Accounts
  - `identity|groups|ad-group` - Entra ID Groups
  - `avd|hostpools|hostpool` - AVD Host Pools
  - `all|resources` - All resources
- `resource_group`: (Optional) Resource group name to filter by
- `output_format`: (Optional, default: "summary")
  - `summary` - Minimal information using summary.jq filter
  - `full` - Detailed information using resource-specific filter

**Returns:** JSON array of resources

**Examples:**
```bash
# Query all VMs with summary info
query_resources "compute"

# Query VMs in specific resource group with full details
query_resources "compute" "RG-Azure-VDI-01" "full"

# Query all networking resources
query_resources "networking"

# Query all resources (any type)
query_resources "all" "RG-Azure-VDI-01"
```

**Cache Behavior:**
- TTL: 120 seconds (2 minutes) for resource lists
- Cache invalidation: Automatic on resource modification
- Cache key: `{resource_type}:{resource_group}`

---

#### `query_resource(resource_type, resource_name, resource_group)`

Query a specific resource by name with cache-first approach.

**Parameters:**
- `resource_type`: Type of resource (same as `query_resources`)
- `resource_name`: Exact name of the resource
- `resource_group`: (Optional) Resource group name

**Returns:** JSON object of the resource

**Examples:**
```bash
# Query specific VM
query_resource "vm" "avd-sh-01" "RG-Azure-VDI-01"

# Query specific VNet
query_resource "vnet" "VNet-Azure-VDI" "RG-Azure-VDI-01"

# Query specific storage account
query_resource "storage" "stavdprofiles001" "RG-Azure-VDI-01"

# Query specific Entra group
query_resource "identity" "AVD-Users"
```

**Cache Behavior:**
- TTL: 300 seconds (5 minutes) for single resources
- Cache invalidation: Automatic on resource modification
- Cache key: `{resource_type}:{resource_group}:{resource_name}`

---

### Resource-Specific Query Functions

These functions are called internally by `query_resources()` but can be used directly:

#### `query_compute_resources(resource_group, output_format)`
Query all Virtual Machines.

#### `query_networking_resources(resource_group, output_format)`
Query all Virtual Networks.

#### `query_storage_resources(resource_group, output_format)`
Query all Storage Accounts.

#### `query_identity_resources(resource_group, output_format)`
Query all Entra ID Groups.

#### `query_avd_resources(resource_group, output_format)`
Query all AVD Host Pools.

#### `query_all_resources(resource_group, output_format)`
Query all resources (any type).

---

### Azure Query Helpers

#### `query_azure_raw(resource_type, resource_group)`

Execute raw Azure CLI query without filtering.

**Parameters:**
- `resource_type`: Resource type to query
- `resource_group`: (Optional) Resource group filter

**Returns:** Raw JSON from Azure CLI

**Example:**
```bash
# Get raw VM data
raw_data=$(query_azure_raw "vm" "RG-Azure-VDI-01")
```

**Use Cases:**
- Debugging Azure CLI responses
- Custom processing workflows
- Extracting fields not in standard filters

---

#### `query_azure_resource_by_name(resource_type, resource_name, resource_group)`

Query a specific resource by name from Azure (bypass cache).

---

#### `apply_jq_filter(json_data, filter_file)`

Apply JQ filter to JSON data for token efficiency.
