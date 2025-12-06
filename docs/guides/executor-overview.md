# Operation Executor Guide

## Overview

The Operation Executor (`core/executor.sh`) is the Phase 3 execution engine that runs infrastructure operations defined in YAML files. It provides:

- **Declarative Operations**: Define infrastructure changes in simple YAML
- **Prerequisite Validation**: Automatic verification of required resources
- **State Tracking**: Full operation history in SQLite database
- **Automatic Rollback**: Rollback on failure with saved scripts
- **Dry-Run Mode**: Preview changes before execution
- **Variable Substitution**: Use config variables in commands

## Table of Contents

1. [Quick Start](#quick-start)
2. [Operation YAML Format](#operation-yaml-format)
3. [Execution Modes](#execution-modes)
4. [Prerequisite Validation](#prerequisite-validation)
5. [Rollback Mechanism](#rollback-mechanism)
6. [State Tracking](#state-tracking)
7. [Variable Substitution](#variable-substitution)
8. [Error Handling](#error-handling)
9. [Examples](#examples)
10. [API Reference](#api-reference)

---

## Quick Start

### 1. Create an Operation YAML

```yaml
operation:
  id: "create-storage-account"
  name: "Create Azure Storage Account"
  type: "create"
  resource_type: "Microsoft.Storage/storageAccounts"
  resource_name: "${STORAGE_ACCOUNT_NAME}"

prerequisites:
  - resource_type: "Microsoft.Network/virtualNetworks"
    name_from_config: "NETWORKING_VNET_NAME"

steps:
  - name: "Create storage account"
    command: "az storage account create --name ${STORAGE_ACCOUNT_NAME} --resource-group ${AZURE_RESOURCE_GROUP} --location ${AZURE_LOCATION} --sku ${STORAGE_SKU}"

rollback:
  - name: "Delete storage account"
    command: "az storage account delete --name ${STORAGE_ACCOUNT_NAME} --resource-group ${AZURE_RESOURCE_GROUP} --yes"
```

### 2. Preview with Dry-Run

```bash
./core/executor.sh dry-run operations/create-storage.yaml
```

### 3. Execute the Operation

```bash
./core/executor.sh execute operations/create-storage.yaml
```

---

## Operation YAML Format

### Complete Structure

```yaml
operation:
  id: "unique-operation-id"              # Required: Unique identifier
  name: "Human Readable Name"            # Required: Display name
  type: "create"                         # Required: create|update|delete|configure
  resource_type: "Microsoft.*/type"      # Optional: Azure resource type
  resource_name: "${VAR_NAME}"           # Optional: Resource name for state tracking

prerequisites:                           # Optional: List of required resources
  - resource_type: "Microsoft.Network/virtualNetworks"
    name_from_config: "NETWORKING_VNET_NAME"  # Resolve from environment
    resource_group: "custom-rg"          # Optional: Override resource group

  - resource_type: "Microsoft.Storage/storageAccounts"
    name: "hardcoded-name"               # Or use hardcoded name
    resource_group: "${AZURE_RESOURCE_GROUP}"

steps:                                   # Required: Execution steps
  - name: "Step 1: Create resource"
    command: "az resource create ..."
    continue_on_error: false             # Optional: Continue if step fails

  - name: "Step 2: Configure resource"
    command: "az resource update ..."
    continue_on_error: true              # Example: continue on error

rollback:                                # Optional: Rollback steps (executed in reverse)
  - name: "Delete resource"
    command: "az resource delete ..."

  - name: "Clean up tags"
    command: "az tag delete ..."
```

### Field Reference

#### `operation` Section

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | Yes | Unique identifier for the operation type |
| `name` | string | Yes | Human-readable name shown in logs |
| `type` | string | Yes | Operation type: `create`, `update`, `delete`, `configure` |
| `resource_type` | string | No | Azure resource type (for state tracking) |
| `resource_name` | string | No | Resource name to track (supports variable substitution) |

#### `prerequisites` Section

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `resource_type` | string | Yes | Azure resource type to check |
| `name_from_config` | string | Conditional | Environment variable name to resolve |
| `name` | string | Conditional | Hardcoded resource name |
| `resource_group` | string | No | Resource group (defaults to `AZURE_RESOURCE_GROUP`) |

**Note**: Either `name_from_config` OR `name` must be specified.

#### `steps` Section

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | Yes | Step description |
| `command` | string | Yes | Shell command to execute (supports variable substitution) |
| `continue_on_error` | boolean | No | If `true`, continue even if step fails (default: `false`) |

#### `rollback` Section

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | Yes | Rollback step description |
| `command` | string | Yes | Command to undo changes (supports variable substitution) |

**Note**: Rollback steps are executed in **reverse order** (LIFO).

---

## Execution Modes

### Normal Execution

Execute operation with full validation and rollback:

```bash
./core/executor.sh execute operations/my-operation.yaml
```

**Behavior**:
- Validates prerequisites before execution
- Creates operation record in state database
- Executes steps sequentially
- Stores resource state after completion
- Automatic rollback on failure

### Dry-Run Mode

Preview what will be executed without making changes:

```bash
./core/executor.sh dry-run operations/my-operation.yaml
```

**Output**:
```
===================================================================
DRY RUN MODE - No changes will be made
===================================================================

Operation Details:
  ID: create-storage-account
  Name: Create Azure Storage Account
  Type: create

Prerequisites:
  1. Microsoft.Network/virtualNetworks: test-vnet

Execution Steps:
  1. Create storage account
     Command: az storage account create --name teststorage --resource-group test-rg ...

Rollback Steps:
  1. Delete storage account
     Command: az storage account delete --name teststorage --resource-group test-rg --yes

===================================================================
Dry run completed - ready for execution
===================================================================
```

### Force Mode

Execute without prerequisite validation:

```bash
./core/executor.sh force operations/my-operation.yaml
```

**Use Cases**:
- Testing/development
- Overriding validation when you know resources exist
- Emergency operations

**Warning**: Use with caution - may fail mid-execution if prerequisites are actually missing.

---

## Prerequisite Validation

### How It Works

1. **Parse Prerequisites**: Extract from YAML
2. **Resolve Names**: Substitute variables from environment
3. **Query Resources**: Check existence via state-manager (cache-first)
4. **Report Results**: Log validation status for each prerequisite

### Example Prerequisites

```yaml
prerequisites:
  # Method 1: Resolve from environment variable
  - resource_type: "Microsoft.Network/virtualNetworks"
    name_from_config: "NETWORKING_VNET_NAME"

  # Method 2: Hardcoded name
  - resource_type: "Microsoft.Network/networkInterfaces"
    name: "vm-nic-01"

  # Method 3: Custom resource group
  - resource_type: "Microsoft.Storage/storageAccounts"
    name_from_config: "STORAGE_ACCOUNT_NAME"
    resource_group: "different-rg"
```

### Validation Process

```
[*] Validating prerequisites...
[*] Found 3 prerequisites to validate
[*] Validating prerequisite 1/3: test-vnet (Microsoft.Network/virtualNetworks)
[*] Cache HIT: test-vnet
[v] Prerequisite validated: test-vnet
[*] Validating prerequisite 2/3: vm-nic-01 (Microsoft.Network/networkInterfaces)
[*] Cache MISS: vm-nic-01, querying Azure...
[v] Prerequisite validated: vm-nic-01
[*] Validating prerequisite 3/3: teststorage (Microsoft.Storage/storageAccounts)
[x] ERROR: Prerequisite not found: teststorage
[x] ERROR: Prerequisite validation failed: 1 of 3 prerequisites not found
```

---

## Rollback Mechanism

### Automatic Rollback on Failure

When any step fails (and `continue_on_error` is not set), the executor:

1. **Stops Execution**: No further steps are executed
2. **Executes Rollback**: Runs rollback steps in **reverse order**
3. **Logs Errors**: Captures all error details
