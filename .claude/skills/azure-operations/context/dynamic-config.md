# Dynamic Configuration System

The Azure VDI Deployment Engine uses a dynamic configuration system that resolves values at runtime rather than requiring all values to be pre-configured.

## Value Resolution Pipeline

When a value is needed, the system checks these sources in order:

1. **User-Specified** - Environment variables or runtime parameters
2. **Azure Discovery** - Query existing resources and extract patterns
3. **Standards Defaults** - From `standards.yaml` defaults
4. **Config Fallback** - From `config.yaml` (legacy support)
5. **Interactive Prompt** - Ask user if in interactive mode

## Key Files

| File | Purpose |
|------|---------|
| `standards.yaml` | Defaults, naming patterns, best practices |
| `secrets.yaml` | Credentials only (subscription_id, passwords) |
| `core/value-resolver.sh` | Value resolution pipeline |
| `core/naming-analyzer.sh` | Pattern discovery and name generation |
| `state.db` | Cached patterns and resolved values |

## Workflow for Creating Resources

### Step 1: Discover Existing Resources

Before creating resources, discover what already exists:

```bash
source core/discovery.sh
discover "resource-group" "$AZURE_RESOURCE_GROUP"
```

### Step 2: Analyze Naming Patterns

Extract naming conventions from existing resources:

```bash
source core/naming-analyzer.sh
pattern=$(analyze_naming_patterns "Microsoft.Network/virtualNetworks" "$RG")
```

### Step 3: Propose Names

Generate names following discovered patterns:

```bash
proposed=$(propose_name "vnet" '{"purpose":"avd","env":"prod"}' "$RG")
echo "Proposed name: $proposed"
```

### Step 4: Resolve All Values

Use the resolver for any configuration value:

```bash
source core/value-resolver.sh
vm_size=$(resolve_value "SESSION_HOST_VM_SIZE" "compute")
storage_sku=$(resolve_value "STORAGE_SKU" "storage")
```

## For AI Assistants

When creating Azure resources:

1. **Always discover first** - Check what resources already exist
2. **Follow existing patterns** - Match the naming conventions in use
3. **Propose names to user** - Show the proposed name and ask for approval
4. **Use resolve_value** - Let the pipeline determine values dynamically
5. **Only ask when necessary** - The pipeline handles most values automatically

### Example AI Workflow

User: "Create a storage account for FSLogix"

```bash
# 1. Discover existing storage accounts
source core/naming-analyzer.sh
pattern=$(analyze_naming_patterns "Microsoft.Storage/storageAccounts" "$AZURE_RESOURCE_GROUP")

# 2. Propose a name following the pattern
proposed=$(propose_name "storage_account" '{"purpose":"fslogix"}')
echo "[i] Proposed storage account name: $proposed"
echo "[?] Accept this name? [Y/n/custom]"

# 3. Resolve other values dynamically
source core/value-resolver.sh
sku=$(resolve_value "STORAGE_SKU" "storage")      # Returns "Premium_LRS" from standards
kind=$(resolve_value "STORAGE_KIND" "storage")    # Returns "FileStorage" from standards

# 4. Execute operation with resolved values
./core/engine.sh run storage-account-create
```

## Configuration Files

### standards.yaml

Contains defaults and naming patterns:

```yaml
naming:
  patterns:
    storage_account: "{prefix}{random5}"
  prefixes:
    storage_account: "fslogix"

defaults:
  storage:
    sku: "Premium_LRS"
    kind: "FileStorage"
```

### secrets.yaml

Contains only credentials:

```yaml
azure:
  subscription_id: "xxx"
  tenant_id: "xxx"

credentials:
  golden_image:
    admin_password: "xxx"
```

## Key Principles

1. **No mandatory pre-configuration** - Values are resolved at runtime
2. **Environment-aware naming** - Follow patterns from existing resources
3. **Sensible defaults** - Standards provide good defaults
4. **User control** - Always allow overrides and custom values
5. **Caching** - Discovered patterns cached in state.db
