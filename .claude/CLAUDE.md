# Azure VDI Deployment Engine

Production-ready YAML-based deployment engine for Azure Virtual Desktop (AVD). Declarative, idempotent, self-healing operations.

## Quick Start

```bash
source core/config-manager.sh && load_config   # Load configuration
./core/engine.sh run <operation-id>            # Run operation
./core/engine.sh resume                        # Resume after failure
```

**Full guide:** [QUICKSTART.md](../QUICKSTART.md) | **Architecture:** [ARCHITECTURE.md](../ARCHITECTURE.md)

---

## Authentication (Pre-Configured)

This environment has automated authentication configured. You can use these tools directly:

| Tool | Status | Usage |
|------|--------|-------|
| **Azure CLI** | Authenticated via service principal | `az` commands work directly |
| **Microsoft Graph** | Certificate-based auth configured | `pwsh` with `Connect-MgGraph` |
| **PowerShell Core** | Installed | `pwsh -Command '...'` or `pwsh -File script.ps1` |

### Authenticate Before Operations

```bash
source core/config-manager.sh && load_config   # Loads credentials to env vars
./core/engine.sh run identity/az-login-service-principal    # Azure CLI
./core/engine.sh run identity/mggraph-connect-certificate   # MS Graph
```

### Available Environment Variables (after load_config)

- `AZURE_CLIENT_ID` - Service principal app ID
- `AZURE_CLIENT_SECRET` - Client secret for Azure CLI
- `AZURE_TENANT_ID` - Entra ID tenant
- `AZURE_SUBSCRIPTION_ID` - Target subscription
- `AZURE_CERTIFICATE_PATH` - Path to PFX for MS Graph
- `AZURE_CERTIFICATE_THUMBPRINT` - Certificate thumbprint

### When to Use Each

- **Azure CLI (`az`)**: Resource management, deployments, queries
- **MS Graph (`Connect-MgGraph`)**: Entra ID operations (groups, app registrations, RBAC)
- **PowerShell (`pwsh`)**: Complex logic, MS Graph SDK, Windows-style scripting

---

## Dynamic Configuration (NEW)

Values are resolved at runtime, not pre-configured. Priority pipeline:

1. **Environment Variable** - User-specified override
2. **Azure Discovery** - Query existing resources for patterns
3. **Standards Defaults** - From `standards.yaml`
4. **Config Fallback** - From `config.yaml` (legacy)
5. **Interactive Prompt** - Ask user if needed

### Configuration Files

| File | Purpose |
|------|---------|
| `secrets.yaml` | **Required:** Credentials only (subscription_id, tenant_id, passwords) |
| `standards.yaml` | Defaults, naming patterns, best practices |
| `config.yaml` | Legacy support (optional) |

### AI Workflow for Creating Resources

```bash
# 1. Discover existing patterns
source core/naming-analyzer.sh
proposed=$(propose_name "storage_account" '{"purpose":"fslogix"}')

# 2. Propose name to user
echo "[?] Create storage account named '$proposed'? [Y/n]"

# 3. Resolve other values dynamically
source core/value-resolver.sh
sku=$(resolve_value "STORAGE_SKU" "storage")  # Returns from pipeline
```

**Full guide:** `.claude/skills/azure-operations/context/dynamic-config.md`

---

## Core Components

**Core Scripts:** `config-manager.sh`, `template-engine.sh`, `engine.sh`, `value-resolver.sh`, `naming-analyzer.sh`

**79 Operations across 7 Capabilities:**
- `networking/` - VNets, NSGs, VPN, DNS
- `storage/` - Storage accounts, file shares
- `identity/` - Entra ID, RBAC
- `compute/` - VMs, images
- `avd/` - Host pools, workspaces
- `management/` - Resource groups

---

## Development Standards

### Anti-Patterns (NEVER)

1. **NO standalone scripts** - Use YAML operations
2. **NO hardcoded values** - Use `{{VARIABLES}}` with dynamic resolution
3. **NO PowerShell remoting** - Use `az vm run-command invoke`

### Required Patterns (ALWAYS)

1. **Load config first:** `source core/config-manager.sh && load_config`
2. **YAML operations only** - All logic in `capabilities/*/operations/*.yaml`
3. **ASCII markers in PowerShell** - `[*] [v] [x] [!] [i]` (NO emoji)

### Naming Conventions

- **Operations:** `{action}-{resource}.yaml` (e.g., `vnet-create.yaml`)
- **Variables:** `CATEGORY_SUBCATEGORY_NAME` (e.g., `STORAGE_ACCOUNT_NAME`)

---

## Common Workflows

```bash
./core/engine.sh list              # List all operations
./core/engine.sh run <op-id>       # Run operation
./core/engine.sh resume            # Resume from failure
./core/engine.sh status            # Check state
```

### Handling Failures

```bash
./core/engine.sh resume                              # Resume
tail -f artifacts/logs/deployment_*.jsonl            # View logs
sqlite3 state.db "SELECT * FROM operations"          # Query state
```

---

## YAML Operation Template

```yaml
operation:
  id: "action-resource"
  name: "Human Readable Name"
  duration: { expected: 180, timeout: 300, type: "NORMAL" }

  template:
    type: "az-vm-run-command"
    command: |
      az vm run-command invoke \
        --resource-group "{{AZURE_RESOURCE_GROUP}}" \
        --name "{{VM_NAME}}" \
        --scripts "@capabilities/compute/operations/script.ps1"

  powershell:
    content: |
      Write-Host "[START] Operation"
      # Your code here
      Write-Host "[SUCCESS] Complete"
      exit 0
```

---

## Code Style

**Bash:** `set -euo pipefail`, UPPER_SNAKE_CASE for env vars, lower_snake_case for locals
**PowerShell:** ASCII markers `[*] [v] [x] [!] [i]`, try/catch with exit codes

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "Config not loaded" | `source core/config-manager.sh && load_config` |
| "Variable not found" | Check standards.yaml, then config.yaml |
| "Operation not found" | `./core/engine.sh list` |
| "Permission denied" | `./core/engine.sh run identity/az-login-service-principal` |
| "Not connected to Graph" | `./core/engine.sh run identity/mggraph-connect-certificate` |

---

## Self-Healing Protocol

When an Azure operation fails, the `PostToolUse` hook will block with context. Follow this protocol:

### Automatic Self-Healing Flow

1. **Parse error context** from the hook's `additionalContext` JSON
2. **Read `error-patterns.yaml`** to find a matching pattern by regex
3. **Check `auto_fix` field**:
   - **If `auto_fix: true`**: Follow `fix_action` instructions, edit YAML, retry
   - **If `auto_fix: false`**: Inform user what manual action is needed

### Self-Healing Rules

- **NEVER create new scripts** - Always fix the existing YAML operation
- **NEVER start over** - Fix incrementally, preserve completed work
- **ALWAYS retry after fix** - Run `./core/engine.sh run <operation-id>` again
- **For transient errors** (vm-run-command-busy): Just wait and retry, don't modify YAML

### Example Self-Healing

```
Hook blocks with: "Azure operation failed. Apply self-healing..."
Error output: "unrecognized arguments: --yes"

1. Read error-patterns.yaml
2. Match pattern: "az-cli-arg-unknown" (regex: "unrecognized arguments: --yes")
3. auto_fix: true
4. fix_action: Remove --yes flag from the az command in the YAML
5. Edit the YAML operation file
6. Retry: ./core/engine.sh run <operation-id>
```

---

## AI Assistant Rules

### Skills (Auto-Detected)

1. **azure-state-query** - "What VMs exist?", "List resources"
2. **azure-operations** - "Create VNet", "Deploy storage"
3. **azure-troubleshooting** - "Operation failed", "Debug"

### Critical Rules

1. **Read this file first** before making changes
2. **NEVER create standalone scripts** - use YAML operations
3. **NEVER hardcode values** - use `{{VARIABLES}}` with dynamic resolution
4. **ALWAYS use `az vm run-command invoke`** for remote PowerShell
5. **NEVER use RDP, WinRM, or PowerShell remoting**
6. **Legacy modules (01-12) are archived** - DO NOT use

### Dynamic Config Workflow

When creating Azure resources:

1. **Discover first** - Query Azure for existing resources
2. **Follow patterns** - Match existing naming conventions
3. **Propose names** - Show AI-generated name, ask user to approve
4. **Use resolve_value** - Let the pipeline determine values dynamically
5. **Only ask when necessary** - Pipeline handles most values automatically

---

## Documentation

**All docs <300 lines. Navigate via [docs/README.md](../docs/README.md)**

- Guides: `docs/guides/`
- Reference: `docs/reference/`
- Capability system: `docs/capability-system/`
