# Repository Setup for New Azure Instances

This guide explains how to clone and set up this repository for deployment to a new Azure instance.

## Quick Start

```bash
# 1. Clone the repository
git clone <repository-url> azure-vdi-deployment
cd azure-vdi-deployment

# 2. Run the setup script
./setup.sh

# 3. Configure your Azure instance
vi config.yaml  # Add your subscription ID, resource group, etc.
vi secrets.yaml  # Add passwords and secrets (if needed)

# 4. Login to Azure
az login

# 5. Load configuration and start deploying
source core/config-manager.sh && load_config
./core/engine.sh list
```

## What Gets Cloned vs. What's Instance-Specific

### ✅ Cloned (Committed to Git)

These files are part of the codebase and will be cloned:

- **Core engine scripts** (`core/`)
- **Operation definitions** (`capabilities/`)
- **Documentation** (`docs/`)
- **Query templates** (`queries/`)
- **Example/template files**:
  - `config.yaml.example`
  - `secrets.yaml.example`
  - `state.json.example`
- **Directory structure** (via `.gitkeep` files)

### ❌ NOT Cloned (Instance-Specific)

These files contain your deployment state and configuration. They are **gitignored** and must be created for each new instance:

- **Configuration files**:
  - `config.yaml` - Your Azure subscription details
  - `secrets.yaml` - Passwords and secrets
- **State files**:
  - `state.json` - Deployment state tracking
  - `state.db` - SQLite database with operation history
- **Runtime artifacts**:
  - `artifacts/logs/` - Deployment logs
  - `artifacts/outputs/` - Operation outputs
  - `artifacts/temp/` - Temporary files
- **Legacy folder**:
  - `legacy/` - Archived modules (not part of current system)

## Detailed Setup Process

### 1. Prerequisites

Before cloning, ensure you have:

- **Azure CLI** installed ([Installation Guide](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli))
- **jq** for JSON processing (optional): `sudo apt-get install jq`
- **sqlite3** for state database: `sudo apt-get install sqlite3`
- **Git** for cloning the repository

### 2. Clone the Repository

```bash
git clone <repository-url> azure-vdi-deployment
cd azure-vdi-deployment
```

### 3. Run Setup Script

The `setup.sh` script will:
- Initialize `state.json` and `state.db` from templates
- Copy `config.yaml.example` to `config.yaml`
- Copy `secrets.yaml.example` to `secrets.yaml`
- Verify prerequisites (Azure CLI, jq, sqlite3)
- Check Azure authentication status

```bash
./setup.sh
```

**Expected output:**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Azure VDI Deployment Engine - Initial Setup
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ Repository structure verified
...
✓ Setup Complete!
```

### 4. Configure for Your Azure Instance

#### Edit `config.yaml`

Update with your Azure subscription details:

```yaml
azure:
  subscription_id: "YOUR-SUBSCRIPTION-ID"
  tenant_id: "YOUR-TENANT-ID"
  location: "centralus"  # Your preferred region
  resource_group: "RG-Azure-VDI-YourInstance"

networking:
  vnet:
    name: "vnet-avd-yourinstance"
    address_space: "10.0.0.0/16"
  # ... other settings
```

**Find your subscription ID:**
```bash
az login
az account show --query id -o tsv
```

#### Edit `secrets.yaml` (if needed)

Add passwords and sensitive data:

```yaml
secrets:
  vm_admin_password: "YourSecurePassword123!"
  domain_join_password: "YourDomainPassword456!"
```

**Security note:** `secrets.yaml` is gitignored and will NEVER be committed.

### 5. Verify Azure Authentication

```bash
az login
az account show
```

Set the correct subscription if you have multiple:

```bash
az account set --subscription "YOUR-SUBSCRIPTION-ID"
```

### 6. Load Configuration

```bash
source core/config-manager.sh && load_config
```

This exports 50+ environment variables from `config.yaml`.

**Verify:**
```bash
echo $AZURE_RESOURCE_GROUP
echo $NETWORKING_VNET_NAME
```

### 7. Start Deployment

List available operations:

```bash
./core/engine.sh list
```

Run an operation:

```bash
./core/engine.sh run networking-vnet-create
```

## Understanding the .gitignore Strategy

### Why State Files Are Gitignored

**Problem:** Each Azure instance has different deployment state:
- Instance A might have VNet created, storage pending
- Instance B might be fully deployed
- Instance C might be starting fresh

**Solution:** State files (`state.json`, `state.db`) track **instance-specific** deployment progress and must NOT be shared across instances.

### Why Config Files Are Gitignored

**Problem:** Each Azure instance has different configuration:
- Different subscription IDs
- Different resource names
- Different regions
- Different passwords

**Solution:** Use **template files** (`.example` suffix) that ARE committed, and generate instance-specific configs during setup.

### Directory Structure Preservation

The `.gitkeep` files ensure that the directory structure is preserved in git, even though the contents are gitignored:

```
artifacts/
├── .gitkeep          # Committed
├── logs/
│   └── .gitkeep      # Committed
├── outputs/
│   └── .gitkeep      # Committed
└── temp/
    └── .gitkeep      # Committed
```

## Multiple Instance Workflows

### Scenario 1: Developer with Multiple Test Environments

```bash
# Clone for Instance A (dev environment)
git clone <repo> azure-vdi-dev
cd azure-vdi-dev
./setup.sh
vi config.yaml  # Configure for dev subscription
./core/engine.sh run networking-vnet-create

# Clone for Instance B (staging environment)
git clone <repo> azure-vdi-staging
cd azure-vdi-staging
./setup.sh
vi config.yaml  # Configure for staging subscription
./core/engine.sh run networking-vnet-create
```

**Result:** Each directory has independent state tracking. They don't interfere with each other.

### Scenario 2: Team Collaboration

**Developer A:**
```bash
# Create new operation
vi capabilities/networking/operations/new-feature.yaml
git add capabilities/networking/operations/new-feature.yaml
git commit -m "feat(networking): Add new-feature operation"
git push
```

**Developer B:**
```bash
# Pull latest operations
git pull

# Deploy to their instance
./core/engine.sh run networking-new-feature
```

**Result:** Team shares operation definitions (code), but each developer's deployment state remains independent.

### Scenario 3: Disaster Recovery

**Backup strategy:**
```bash
# Backup instance-specific files
tar -czf backup-$(date +%Y%m%d).tar.gz \
  config.yaml \
  secrets.yaml \
  state.json \
  state.db \
  artifacts/

# Store backup securely (encrypted, offsite)
```

**Recovery:**
```bash
# Clone repo
git clone <repo> azure-vdi-recovered
cd azure-vdi-recovered

# Restore instance-specific files
tar -xzf backup-20251206.tar.gz

# Continue deployment
./core/engine.sh resume
```

## Best Practices

### ✅ DO

1. **Run `setup.sh` immediately after cloning**
2. **Keep `config.yaml` and `secrets.yaml` backed up securely**
3. **Commit operation changes to git** (new capabilities, bug fixes)
4. **Use `config.yaml.example` to document required settings**
5. **Test operations on dev instance before production**

### ❌ DON'T

1. **DON'T commit `config.yaml` or `secrets.yaml`** (contains sensitive data)
2. **DON'T commit `state.json` or `state.db`** (instance-specific state)
3. **DON'T commit `artifacts/` contents** (runtime data)
4. **DON'T share state files between instances** (will cause conflicts)
5. **DON'T hardcode values in operations** (use `{{VARIABLES}}` instead)

## Troubleshooting

### "state.json not found"

**Solution:**
```bash
./setup.sh  # Re-run setup
# OR manually:
cp state.json.example state.json
```

### "Config variables not set"

**Solution:**
```bash
source core/config-manager.sh && load_config
```

### "Operation failed but state.json not updated"

**Solution:**
```bash
./core/engine.sh resume  # Auto-recovers state
```

### "Accidentally committed state files"

**Solution:**
```bash
# Remove from git history (if not pushed)
git rm --cached state.json state.db artifacts/logs/*.jsonl
git commit -m "fix: Remove instance-specific files from git"

# If already pushed, see: docs/troubleshooting/remove-sensitive-data.md
```

## Summary

This repository is designed for **portability across Azure instances**:

- ✅ **Code (operations, scripts, docs)** → Committed to git, shared across instances
- ❌ **State (deployment progress, configs, secrets)** → Instance-specific, gitignored
- 🔄 **Setup workflow:** Clone → `./setup.sh` → Configure → Deploy

Each clone is a **clean slate** ready to deploy to a new Azure instance, with no conflicts or shared state.

## Additional Resources

- **Quick Start:** [QUICKSTART.md](QUICKSTART.md)
- **Architecture:** [ARCHITECTURE.md](ARCHITECTURE.md)
- **Full Documentation:** [docs/README.md](docs/README.md)
- **Configuration Guide:** [docs/guides/state-manager-overview.md](docs/guides/state-manager-overview.md)
