# Templates for New Deployment Steps

This directory contains templates and boilerplate for creating new deployment steps (01-12) or extending existing ones.

## Status

🔄 **In Planning** - Templates will be created in Phase 2B

## Planned Templates

### task-template.sh
**Purpose**: Template for creating new Bash task scripts

**Includes**:
- Header with description, usage, prerequisites
- Configuration loading pattern
- Error handling and logging
- Pre-flight validation
- Main task logic with comments
- Artifact/log generation
- Exit code handling

**When to Use**:
- Creating new deployment task in Bash
- Following established patterns
- Ensuring consistency across steps

**Example Usage**:
```bash
# Copy template
cp templates/task-template.sh 01-networking/tasks/01-create-vnet.sh

# Edit with task-specific logic
# Keep header documentation
# Keep error handling pattern
# Keep logging pattern
```

### task-template.ps1
**Purpose**: Template for creating new PowerShell task scripts

**Includes**:
- Comment header with documentation
- Parameter definition
- Color-coded logging functions
- Configuration loading
- Validation functions
- Main execution block
- Error handling with try/catch
- Artifact generation

**When to Use**:
- Creating PowerShell-based tasks
- Configuration scripts
- Windows-specific operations

### config-template.env
**Purpose**: Template for configuration files

**Structure**:
```bash
# Header comment explaining configuration
# Clear section headers for different resource types
# Documented variables with examples
# Comments explaining precedence
# Override patterns shown
```

**Sections**:
- Subscription and environment
- Resource group and location
- Network configuration
- Compute configuration
- Storage configuration
- Tags and naming
- Logging and artifacts

**When to Use**:
- Creating configuration for new deployment step
- Standardizing variable naming
- Documenting all configurable values

## Template Structure (When Implemented)

```
templates/
├── task-template.sh                    # Bash task template
├── task-template.ps1                   # PowerShell task template
├── config-template.env                 # Configuration file template
├── config-template.ps1                 # PowerShell config template
│
├── examples/                           # Example implementations
│   ├── 01-create-vnet.sh              # Example: networking task
│   ├── 02-create-storage.sh           # Example: storage task
│   └── 03-configure-vm.ps1            # Example: PowerShell config
│
└── README.md (this file)
```

## Template Characteristics

All templates follow Phase 1 (golden image) patterns:

1. **Modular**: Single responsibility per script
2. **Idempotent**: Safe to run multiple times where possible
3. **Well-Documented**: Clear comments and headers
4. **Logged**: All operations saved to artifacts/
5. **Configured**: External configuration, no hardcoding
6. **Error-Handled**: Proper error handling and exit codes
7. **AI-Friendly**: Clear structure for AI assistants

## Using Templates

### Creating a New Task Script

1. **Copy template**:
   ```bash
   cp common/templates/task-template.sh 02-storage/tasks/01-create-storage.sh
   ```

2. **Edit the script**:
   - Update header documentation
   - Replace `# TODO: Main logic` with actual task
   - Keep logging/error pattern
   - Keep configuration pattern

3. **Test the script**:
   - Run validation first
   - Test with dry-run if possible
   - Check logs and artifacts

4. **Commit with message**:
   ```
   Step 02: Add task to create storage account

   Uses common task template pattern:
   - Modular single-task design
   - Configuration-driven
   - Comprehensive logging
   ```

### Creating a New Configuration File

1. **Copy template**:
   ```bash
   cp common/templates/config-template.env 02-storage/config.env
   ```

2. **Edit the config**:
   - Update section comments
   - Fill in your values
   - Document any step-specific variables

3. **Document defaults**:
   ```bash
   # Default is X, override with Y
   export STORAGE_ACCOUNT_SKU="${STORAGE_SKU:-Standard_LRS}"
   ```

## Template Features

### Error Handling
All templates include:
- `set -e` (bash) or `$ErrorActionPreference = "Stop"` (PowerShell)
- Try/catch blocks where appropriate
- Clear error messages
- Exit codes (0=success, 1=error)

### Logging
- Color-coded output (green=success, red=error, yellow=warning)
- Timestamped logs
- Structured output files
- Artifact collection

### Configuration
- Source centralized config first
- Allow environment variable overrides
- Document all variables
- Clear precedence rules

### Validation
- Pre-flight checks before main logic
- Resource existence validation
- Permission validation
- Configuration validation

## Implementation Phase

**Phase 2B** (Coming Soon):
- [ ] Create task-template.sh with documented sections
- [ ] Create task-template.ps1 with functions
- [ ] Create config-template.env with sections
- [ ] Add examples for common tasks (VM, network, storage)
- [ ] Document template usage in main README

**Phase 3**:
- [ ] Apply to steps 01-04 (networking, storage, entra, host pool)

**Phase 4**:
- [ ] Apply to steps 06-12 (session hosts through cleanup)

**Phase 5+**:
- [ ] Add advanced templates (scaling, monitoring, backup)
- [ ] Add integration testing templates

## Benefits of Using Templates

1. **Consistency**: All scripts follow same patterns
2. **Speed**: Start new tasks faster
3. **Quality**: Built-in error handling and logging
4. **Maintainability**: Easy to understand and modify
5. **Discoverability**: AI assistants know patterns to follow

## Current Best Practices

The golden image (Phase 1) scripts serve as current best practice examples:
- See `05-golden-image/tasks/01-create-vm.sh` for Bash pattern
- See `05-golden-image/tasks/03-configure-vm.sh` for complex task
- See `05-golden-image/config.env` for configuration pattern

These will be distilled into reusable templates in Phase 2B.

---

**Status**: Planning Phase
**Next Step**: Phase 2B Implementation
**Reference**: See `05-golden-image/` for current best practices
