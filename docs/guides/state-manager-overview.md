# State Manager Guide

**Production-grade SQLite state management for Azure Infrastructure Toolkit**

---

## Overview

The State Manager (`core/state-manager.sh`) is the **CORE** of the Azure Infrastructure Toolkit, providing:

- **Intelligent caching** - Cache-first resource queries with 5-minute TTL
- **Dependency tracking** - Build and validate resource dependency graphs (DAG)
- **Operation history** - Complete audit trail with resume capability
- **Smart invalidation** - Automatic cache invalidation on resource changes
- **Analytics** - Performance metrics and operational insights

---

## Quick Start

```bash
# Load the state manager
source core/state-manager.sh

# Initialize database
init_state_db

# Store a resource
RESOURCE_JSON='{"id": "/subscriptions/.../resourceGroups/rg/providers/Microsoft.Compute/virtualMachines/vm1", ...}'
store_resource "$RESOURCE_JSON"

# Query with cache-first approach
get_resource "virtualMachines" "vm1" "rg-name"

# Track dependencies
add_dependency "$vm_id" "$vnet_id" "required" "uses"

# Create operation
create_operation "deploy-vm-001" "compute" "vm-create" "create"
update_operation_status "deploy-vm-001" "running"
update_operation_status "deploy-vm-001" "completed"
```

---

## Database Architecture

### Location
- **Database**: `/mnt/cache_pool/development/azure-cli/state.db`
- **Schema**: `/mnt/cache_pool/development/azure-cli/schemas/state.schema.sql`

### Tables

#### Core Tables
1. **resources** - Resource metadata and properties
2. **dependencies** - Resource dependency graph
3. **operations** - Operation history and tracking
4. **operation_logs** - Detailed operation logs
5. **cache_metadata** - Smart caching layer

#### Analytics Views
- **active_resources** - Non-deleted resources
- **managed_resources** - Resources managed by toolkit
- **failed_operations** - Failed operations eligible for retry
- **running_operations** - Currently running operations
- **operation_stats** - Aggregated operation statistics
- **resource_stats** - Resource counts and states

---

## API Reference

### Database Initialization

#### `init_state_db()`
Initialize SQLite database if not exists.

**Usage:**
```bash
init_state_db
```

**Returns:** 0 on success, 1 on failure

**Features:**
- Idempotent (safe to call multiple times)
- Creates schema from `schemas/state.schema.sql`
- Fallback inline schema if file not found
- Enables foreign keys and triggers

---

### Resource Management

#### `store_resource(resource_json)`
Store or update resource in database.

**Arguments:**
- `resource_json` - Full Azure resource JSON

**Usage:**
```bash
RESOURCE_JSON=$(az vm show --name vm1 --resource-group rg1)
store_resource "$RESOURCE_JSON"
```

**Features:**
- Upsert operation (INSERT or UPDATE)
- Automatic cache expiry (5 minutes)
- JSON validation
- SQL injection prevention

---

#### `get_resource(resource_type, resource_name, resource_group)`
Get resource from cache or query Azure.

**Arguments:**
- `resource_type` - Azure resource type (e.g., "virtualMachines")
- `resource_name` - Resource name
- `resource_group` - Resource group (optional, defaults to AZURE_RESOURCE_GROUP)

**Usage:**
```bash
# Cache-first query
vm_json=$(get_resource "virtualMachines" "vm1" "rg-name")
```

**Returns:** JSON resource data

**Features:**
- **Cache HIT**: Returns cached data if valid (< 5 min old)
- **Cache MISS**: Queries Azure CLI, stores result, returns data
- Automatic cache management
- Logging of cache hits/misses

---

#### `mark_as_managed(resource_id)`
Mark resource as managed by toolkit.

**Arguments:**
- `resource_id` - Full Azure resource ID

**Usage:**
```bash
mark_as_managed "/subscriptions/sub-id/resourceGroups/rg/providers/Microsoft.Compute/virtualMachines/vm1"
```

**Features:**
- Sets `managed_by_toolkit = 1`
- Records `adopted_at` timestamp
- Tags resource in Azure (best effort)

---

#### `mark_as_created(resource_id)`
Mark resource as created by toolkit.

**Arguments:**
- `resource_id` - Full Azure resource ID

**Usage:**
```bash
mark_as_created "/subscriptions/sub-id/resourceGroups/rg/providers/Microsoft.Compute/virtualMachines/vm1"
```

**Features:**
- Sets `managed_by_toolkit = 1`
- Records `created_at` timestamp
- Tags resource in Azure (best effort)

---

#### `soft_delete_resource(resource_id)`
Soft delete resource (mark as deleted without removing from DB).

**Arguments:**
- `resource_id` - Full Azure resource ID

**Usage:**
```bash
soft_delete_resource "$resource_id"
```

**Features:**
- Sets `deleted_at` timestamp
- Resource remains in database for audit
- Excluded from active queries

---

### Dependency Management

#### `add_dependency(resource_id, depends_on_id, dependency_type, relationship)`
Add dependency relationship between resources.

**Arguments:**
- `resource_id` - Dependent resource ID
- `depends_on_id` - Dependency target ID
- `dependency_type` - "required", "optional", or "reference" (default: "required")
- `relationship` - "uses", "contains", "references" (default: "uses")

**Usage:**
```bash
# VM depends on VNet
add_dependency "$vm_id" "$vnet_id" "required" "uses"

# Subnet contained by VNet
add_dependency "$subnet_id" "$vnet_id" "required" "contains"
```

**Features:**
- Upsert operation (prevents duplicates)
- Builds directed acyclic graph (DAG)
- Updates `validated_at` on conflict

---

#### `get_dependencies(resource_id)`
Get resources that this resource depends on.

**Arguments:**
- `resource_id` - Resource ID

**Returns:** JSON array of dependencies

**Usage:**
```bash
deps=$(get_dependencies "$vm_id")
