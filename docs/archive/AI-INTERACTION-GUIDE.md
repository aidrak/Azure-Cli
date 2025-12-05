# AI Interaction Guide for Azure VDI Deployment

Complete guide for AI assistants (Gemini, Claude Code, etc.) to effectively use and extend the Azure Virtual Desktop deployment template.

## Table of Contents

1. [Introduction](#introduction)
2. [Template Architecture](#template-architecture)
3. [Key Principles](#key-principles)
4. [How to Use the Template](#how-to-use-the-template)
5. [Common AI Tasks](#common-ai-tasks)
6. [Troubleshooting](#troubleshooting)
7. [Extension Guide](#extension-guide)

---

## Introduction

This Azure Virtual Desktop (AVD) deployment template is designed to be AI-friendly. Rather than creating new scripts, AI assistants should leverage the existing modular task structure, function libraries, and command references.

### Design Philosophy

**Task-Centric Architecture**: Each deployment step breaks into modular tasks
- Each task does ONE thing well
- Tasks are chainable for full automation
- Tasks are individually testable
- Tasks are resumable on failure

**No Script Proliferation**: Tools exist, don't create new ones
- Use task templates for new tasks
- Reference command libraries for Azure operations
- Use function libraries for reusable logic
- Follow established patterns

**Configuration as Code**: All values in config files, not hardcoded
- `config.env` per step for configuration
- `config/avd-config.sh` for centralized defaults
- Environment variables for overrides
- Clear precedence rules

---

## Template Architecture

### Directory Structure

```
azure-cli/
├── config/                          # Centralized configuration
│   └── avd-config.sh               # Global AVD settings
│
├── common/                          # Shared utilities
│   ├── functions/                  # Reusable function libraries
│   │   ├── logging-functions.sh
│   │   ├── config-functions.sh
│   │   ├── azure-functions.sh
│   │   └── string-functions.sh
│   ├── scripts/                    # Utility scripts
│   ├── templates/                  # Task templates
│   └── docs/                       # Reference documentation
│
├── 01-networking/                  # Each step (01-12) has:
│   ├── config.env                 #   Configuration file
│   ├── tasks/                     #   Executable task scripts
│   ├── commands/                  #   Azure CLI references
│   ├── docs/                      #   Step documentation
│   └── artifacts/                 #   Generated logs
│
├── orchestrate.sh                  # Master orchestration script
├── AI-INTERACTION-GUIDE.md        # This file
└── README.md                       # Project overview
```

### Step Breakdown

**12-Step Deployment Pipeline**:
1. Networking - VNets, subnets, NSGs
2. Storage - FSLogix storage account
3. Entra ID - Security groups, service principals
4. Host Pool - Host pool, app groups, workspaces
5. Golden Image - Windows VM image creation
6. Session Hosts - VM deployment from image
7. Intune - Device management
8. RBAC - Role-based access control
9. SSO - Single sign-on
10. Autoscaling - Scaling policies
11. Testing - Validation
12. Cleanup - Decommissioning

---

## Key Principles

### Principle 1: Use Tasks, Not New Scripts

**❌ DON'T**: Create new bash/PowerShell scripts
```bash
# DON'T do this:
cat > my-new-networking-script.sh <<'EOF'
#!/bin/bash
# ... networking logic ...
EOF
```

**✅ DO**: Use existing task templates and modify as needed
```bash
# DO this:
cp common/templates/task-template.sh 01-networking/tasks/03-create-firewall-rules.sh
# Then edit 03-create-firewall-rules.sh with specific logic
```

### Principle 2: Configuration First

**❌ DON'T**: Hardcode values in scripts
```bash
RESOURCE_GROUP="RG-Azure-VDI-01"      # Hardcoded!
VM_SIZE="Standard_D4s_v5"             # Hardcoded!
```

**✅ DO**: Use config.env for all values
```bash
# In config.env:
export RESOURCE_GROUP_NAME="${RESOURCE_GROUP_NAME:-RG-Azure-VDI-01}"
export VM_SIZE="${VM_SIZE:-Standard_D4s_v5}"

# In script:
source config.env
# Use $RESOURCE_GROUP_NAME and $VM_SIZE
```

### Principle 3: Use Function Libraries

**❌ DON'T**: Rewrite logging, validation, or Azure operations
```bash
# DON'T create new functions
function my_log_success() {
    echo "✓ $1"
}
```

**✅ DO**: Source and use existing libraries
```bash
source ../common/functions/logging-functions.sh
log_success "Operation completed"
```

### Principle 4: Follow Task Patterns

**Every task should**:
1. Load configuration (`source config.env`)
2. Load function libraries
3. Validate prerequisites
4. Execute main logic
5. Save artifacts (logs, details)
6. Return proper exit codes

See `common/templates/task-template.sh` for pattern.

### Principle 5: Respect Command References

**❌ DON'T**: Create custom Azure CLI commands inline
```bash
# DON'T scatter Azure commands through scripts
az vm create --resource-group "$RG" --name "$VM" ...
```

**✅ DO**: Reference command library for complex operations
```bash
# Commands in: commands/vm-operations.sh
# Script uses function wrappers: common/functions/azure-functions.sh
azure_vm_create "$RG" "$VM" "$image" "$size"
```

---

## How to Use the Template

### Starting a Deployment

```bash
# 1. Clone/download the template
cd azure-cli

# 2. Configure centralized settings
vi config/avd-config.sh
# Set: SUBSCRIPTION_ID, TENANT_ID, RESOURCE_GROUP_NAME, LOCATION, etc.

# 3. Run full automated deployment
./orchestrate.sh --automated

# OR run interactively
./orchestrate.sh
```

### Running Individual Steps

```bash
# Navigate to step
cd 01-networking

# Configure step-specific settings
vi config.env

# Run tasks in order
./tasks/01-create-vnet.sh
./tasks/02-create-nsgs.sh
```

### Checking Logs and Artifacts

```bash
# Each task saves logs and details
tail -f 01-networking/artifacts/01-create-vnet_*.log

# View task details
cat 01-networking/artifacts/01-create-vnet-details.txt

# Check entire step
ls -lh 01-networking/artifacts/
```

### Resuming from Failure

```bash
# After fixing the issue that caused failure
./orchestrate.sh --resume

# Or re-run specific step
cd 01-networking
./tasks/01-create-vnet.sh  # Idempotent, safe to re-run
```

---

## Common AI Tasks

### Task: Add a New Feature to a Step

**Example**: Add firewall rules task to networking step

```bash
# 1. Use template
cp common/templates/task-template.sh 01-networking/tasks/03-create-firewall-rules.sh

# 2. Edit template with specific logic
vi 01-networking/tasks/03-create-firewall-rules.sh
# - Update header documentation
# - Update CONFIGURATION section with relevant vars
# - Implement validate_prerequisites() for this task
# - Implement main logic (create_firewall_rules function)
# - Update save_artifacts() with relevant outputs

# 3. Test the task
cd 01-networking
./tasks/03-create-firewall-rules.sh

# 4. Verify logs
cat artifacts/03-create-firewall-rules-details.txt
```

### Task: Modify Configuration Values

**Example**: Change VM size for golden image

```bash
# 1. Find the configuration
cd 05-golden-image
grep -n "VM_SIZE" config.env

# 2. Update in config.env
vi config.env
# Change: export VM_SIZE="${VM_SIZE:-Standard_D4s_v5}"
# To: export VM_SIZE="${VM_SIZE:-Standard_D8s_v5}"

# 3. Run affected task
./tasks/01-create-vm.sh
```

### Task: Add New Function Library

**Example**: Add database connection utilities

```bash
# 1. Use function template
# Create: common/functions/database-functions.sh

# 2. Follow pattern from existing functions:
#    - Start with header comments
#    - Define related functions
#    - Use log_* functions for messaging
#    - Export functions at end of file

# 3. In your task, source the library:
source ../common/functions/database-functions.sh

# 4. Use the functions:
database_connect "$connection_string"
```

### Task: Debug a Failed Deployment

```bash
# 1. Check logs for the failed step
tail -100 [step]/artifacts/[task]_*.log

# 2. Check detailed output
cat [step]/artifacts/[task]-details.txt

# 3. Check JSON output (if available)
jq . [step]/artifacts/[task]*.json

# 4. Verify configuration
cat [step]/config.env | grep -E "^export"

# 5. Test Azure authentication
az account show

# 6. Fix the issue (varies)
# - Wrong configuration? Update config.env
# - Missing prerequisites? Install/configure them
# - Script bug? Check logs and fix logic

# 7. Re-run the failing task (idempotent)
[step]/tasks/[task].sh

# 8. Continue with remaining tasks
# Or use orchestrator resume:
./orchestrate.sh --resume
```

### Task: Configure VM Remotely via `az vm run-command`

**When to Use**: Golden image creation and any VM configuration that doesn't require RDP/GUI interaction.

**Key Point**: The repository's task scripts (03-06 in golden image workflow) use `az vm run-command` to execute PowerShell scripts remotely **without needing RDP**. This enables fully automated configuration.

```bash
# Basic pattern - send local script to Azure VM for execution
az vm run-command invoke \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --name "$VM_NAME" \
  --command-id RunPowerShellScript \
  --scripts "$(cat /path/to/script.ps1)" \
  --output json > output.json

# For golden image configuration (example):
cd 05-golden-image
source config.env

# Execute comprehensive configuration (30-60 min)
az vm run-command invoke \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --name "$TEMP_VM_NAME" \
  --command-id RunPowerShellScript \
  --scripts "$(cat config_vm.ps1)" \
  --output json > artifacts/config_output.json

# Extract results from JSON output
STDOUT=$(cat artifacts/config_output.json | jq -r '.value[0].message')
echo "$STDOUT"
```

**Why This Matters**:
- No RDP connection required for VM configuration
- Fully scriptable automation workflow
- Enables CI/CD pipeline integration
- Allows configuration of VMs without public IP addresses

**Important Characteristics**:
1. **Synchronous by default**: Command waits for PowerShell to complete
2. **Script loading**: `$(cat script.ps1)` reads entire script into bash string
3. **Output format**: JSON response with stdout/stderr/exitCode
4. **Error handling**: Use `|| true` to prevent bash exit on PowerShell errors

**Related Documentation**: See [AZURE-VM-REMOTE-EXECUTION.md](./AZURE-VM-REMOTE-EXECUTION.md) for comprehensive pattern documentation, examples, and troubleshooting.

---

## Troubleshooting

### Issue: "Configuration file not found"

**Cause**: Task looking for config in wrong location

**Solution**:
```bash
# Check your working directory
pwd

# Config should be in current directory
ls config.env

# If in a task subdirectory, use relative path
# Correct in task-template.sh:
CONFIG_FILE="${PROJECT_ROOT}/01-networking/config.env"
```

### Issue: "Function not found"

**Cause**: Function library not sourced before use

**Solution**:
```bash
# Add source statement to task:
source ../common/functions/logging-functions.sh
source ../common/functions/azure-functions.sh

# Then use functions:
log_info "This works now"
azure_vm_create "RG" "vm" "image" "size"
```

### Issue: "Azure authentication failed"

**Cause**: Not logged into Azure

**Solution**:
```bash
# Authenticate
az login

# Or for service principal
az login --service-principal -u $APP_ID -p $SECRET --tenant $TENANT_ID

# Verify
az account show
```

### Issue: Task runs but produces wrong results

**Cause**: Usually incorrect configuration

**Solution**:
```bash
# 1. Check configuration values
cat config.env

# 2. Check what's in environment
echo $VARIABLE_NAME

# 3. Test with overrides
VARIABLE_NAME="test-value" ./tasks/[task].sh

# 4. Check logs for what values were actually used
grep "VARIABLE_NAME=" artifacts/[task]*.log
```

---

## Extension Guide

### Adding a New Deployment Step

**Example**: Add step 13 for "Disaster Recovery"

```bash
# 1. Create directory structure
mkdir -p 13-disaster-recovery/{tasks,commands,docs,artifacts,state}

# 2. Create config.env
cp common/templates/config-template.env 13-disaster-recovery/config.env
# Edit with DR-specific variables

# 3. Create task template
cp common/templates/task-template.sh 13-disaster-recovery/tasks/01-create-backup-vault.sh
# Edit with specific logic

# 4. Create README
cat > 13-disaster-recovery/README.md <<'EOF'
# Step 13: Disaster Recovery

Setup backup and recovery procedures for AVD deployment.

## Tasks
- 01-create-backup-vault.sh: Create Azure Backup vault
- 02-configure-backups.sh: Configure backup policies
- etc.
EOF

# 5. Add to orchestrator
# Edit orchestrate.sh, add to STEPS array:
# "13-disaster-recovery"

# 6. Test
./orchestrate.sh --step 13-disaster-recovery
```

### Creating a Custom Function Library

**Pattern**:
```bash
# File: common/functions/my-custom-functions.sh

#!/bin/bash

# Header documenting the library
# Purpose, usage examples, available functions

# Load dependencies
source ../common/functions/logging-functions.sh

# Define functions
my_function() {
    local param="$1"
    log_info "Doing something with: $param"
    # ... implementation ...
    return 0
}

# Export all functions
export -f my_function
# ... export others ...
```

### Extending Command References

**Pattern**:
```bash
# File: commands/my-operations.sh

# Header with description and usage

# Section: Create Operation
# Usage:
#   az my-resource create \
#     --resource-group "RG" \
#     --name "resource-name" \
#     ...

az my-resource create \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --name "$RESOURCE_NAME" \
  ...

# Section: Delete Operation
# Usage:
#   az my-resource delete \
#     --resource-group "RG" \
#     --name "resource-name" \
#     ...

az my-resource delete \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --name "$RESOURCE_NAME" \
  ...
```

---

## Best Practices for AI

### DO

✅ **Follow existing patterns** - Copy structure from similar tasks
✅ **Use templates** - Start from templates, don't write from scratch
✅ **Read error messages** - Logs contain clues about failures
✅ **Use function libraries** - Reuse, don't recreate
✅ **Test incrementally** - Run one task at a time during development
✅ **Document changes** - Update comments and README files
✅ **Validate configuration** - Check config before running tasks
✅ **Save artifacts** - Always log operations for debugging

### DON'T

❌ **Create new scripts** - Use task templates instead
❌ **Hardcode values** - Use config.env and environment variables
❌ **Ignore errors** - Check exit codes and log files
❌ **Skip validation** - Always validate prerequisites
❌ **Forget to source configs** - Load configuration first
❌ **Mix concerns** - Keep one task = one responsibility
❌ **Ignore idempotency** - Make tasks safe to re-run
❌ **Skip documentation** - Update headers and READMEs

---

## Example: Complete Workflow for AI

```bash
# 1. Understand the deployment
# Read: README.md, AI-INTERACTION-GUIDE.md, 05-golden-image/README.md

# 2. Check current state
./orchestrate.sh --help
./common/scripts/verify_prerequisites.ps1

# 3. Configure
vi config/avd-config.sh
vi 05-golden-image/config.env

# 4. Run golden image
./orchestrate.sh --step 05-golden-image
# Or:
cd 05-golden-image
./tasks/01-create-vm.sh
./tasks/02-validate-vm.sh
./tasks/03-configure-vm.sh
./tasks/04-sysprep-vm.sh
./tasks/05-capture-image.sh
./tasks/06-cleanup.sh

# 5. Check results
tail -f artifacts/*details.txt

# 6. Debug if needed
tail -100 artifacts/*create-vm*.log
grep -i error artifacts/*.log

# 7. Continue with next step
./orchestrate.sh --step 06-session-host-deployment
```

---

## Getting Help

1. **Check documentation**:
   - Main README.md
   - Step-specific README.md files
   - docs/ directories in each step

2. **Review logs**:
   - artifacts/[task]_*.log - Detailed execution log
   - artifacts/[task]-details.txt - Summary of outputs

3. **Test commands manually**:
   - See commands/ directory for Azure CLI examples
   - Reference common/docs/azure-cli-reference.md

4. **Read error messages carefully**:
   - Azure CLI errors indicate what's wrong
   - Most failures are configuration or permission issues

---

## Contact & Support

For issues:
1. Check logs in artifacts/
2. Verify configuration in config.env
3. Review task documentation
4. Check Azure Portal for resource status
5. Re-run task with DEBUG=1 for verbose output

---

**Last Updated**: Phase 6 (AI Interaction Guide)
**Status**: Complete and Ready for AI Assistants
