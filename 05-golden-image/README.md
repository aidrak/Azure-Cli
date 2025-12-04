# Golden Image Creation for Azure Virtual Desktop

This directory contains a modular, AI-friendly workflow for creating golden images for Azure Virtual Desktop deployments.

## Quick Start

```bash
# 1. Validate prerequisites
./config-validators/validate-prereqs.sh

# 2. Configure your environment (edit config.env)
export ADMIN_PASSWORD="YourSecurePassword123!"

# 3. Run the complete workflow
./tasks/01-create-vm.sh && \
./tasks/02-validate-vm.sh && \
./tasks/03-configure-vm.sh && \
./tasks/07-avd-registry-optimizations.sh && \
./tasks/08-final-cleanup-sysprep.sh && \
./tasks/04-sysprep-vm.sh && \
./tasks/05-capture-image.sh && \
./tasks/06-cleanup.sh
```

**Total time**: 90-150 minutes (1.5-2.5 hours)

## What This Directory Contains

### Core Task Scripts (`tasks/`)
Each task is a standalone, executable script that performs one specific operation:

- **`01-create-vm.sh`** - Create temporary Windows 11 VM (5-10 min)
- **`02-validate-vm.sh`** - Wait for VM to boot and be ready (5-15 min)
- **`03-configure-vm.sh`** - Install software and optimizations (30-60 min)
- **`07-avd-registry-optimizations.sh`** - Apply AVD-specific registry settings (2-5 min)
- **`08-final-cleanup-sysprep.sh`** - Final cleanup and sysprep preparation (5-10 min)
- **`04-sysprep-vm.sh`** - Prepare VM for image capture (5-10 min)
- **`05-capture-image.sh`** - Save VM as reusable image (15-30 min)
- **`06-cleanup.sh`** - Delete temporary resources (5-10 min)

### Configuration
- **`config.env`** - Golden image specific configuration (sourced by all tasks)
  - VM settings (size, image, credentials)
  - Network settings (VNet, subnet)
  - Image gallery settings
  - Software versions

### Command Reference (`commands/`)
Reusable Azure CLI commands for AI or manual execution:

- **`vm-operations.sh`** - VM lifecycle commands (create, start, stop, delete)
- **`image-operations.sh`** - Image gallery commands (create, capture, deploy)
- **`README.md`** - How to use command references

### Validators (`config-validators/`)
Pre-flight checks before starting workflow:

- **`validate-prereqs.sh`** - Check Azure CLI, auth, permissions, resources

### Documentation (`docs/`)
Comprehensive guides for understanding and executing the workflow:

- **`WORKFLOW.md`** - Step-by-step workflow guide with troubleshooting
- **`TASK-REFERENCE.md`** - Detailed reference for each task
- **`COMMANDS.md`** - (placeholder for command documentation)
- **`TROUBLESHOOTING.md`** - (placeholder for troubleshooting guide)
- **`ARCHITECTURE.md`** - (placeholder for design decisions)

### Runtime Artifacts
These directories are created during execution (gitignored):

- **`artifacts/`** - Task logs, output files, state tracking
- **`state/`** - Deployment state files

## Usage Scenarios

### Scenario 1: Full Automated Workflow
Run entire workflow with single command:

```bash
./tasks/01-create-vm.sh && \
./tasks/02-validate-vm.sh && \
./tasks/03-configure-vm.sh && \
./tasks/04-sysprep-vm.sh && \
./tasks/05-capture-image.sh && \
./tasks/06-cleanup.sh
```

### Scenario 2: Interactive Execution
Run tasks one-by-one, monitoring each:

```bash
./tasks/01-create-vm.sh      # Create VM
# Wait and monitor in Azure Portal
./tasks/02-validate-vm.sh     # Validate ready
# Optionally RDP into VM to verify
./tasks/03-configure-vm.sh    # Configure (30-60 min)
# Monitor configuration progress
./tasks/04-sysprep-vm.sh      # Sysprep
./tasks/05-capture-image.sh   # Capture to gallery
./tasks/06-cleanup.sh         # Cleanup
```

### Scenario 3: Custom Workflow (using commands)
Manually execute commands for more control:

```bash
source config.env
source commands/vm-operations.sh
source commands/image-operations.sh

# Create VM manually
az vm create --resource-group "$RESOURCE_GROUP_NAME" ...

# Wait for readiness (manual or using task)
./tasks/02-validate-vm.sh

# Custom configuration (your scripts)
# ...

# Capture to gallery
./tasks/05-capture-image.sh

# Cleanup
./tasks/06-cleanup.sh
```

### Scenario 4: Resume from Failure
If a task fails:

```bash
# Check logs to understand failure
tail -f artifacts/0X-task-name_*.log

# Fix the issue (varies by error)
# ...

# Re-run the failed task
./tasks/0X-task-name.sh

# Continue with remaining tasks
./tasks/0Y-next-task.sh
# ...
```

## Configuration

### Before Running

Edit `config.env` with your values:

```bash
# Azure Environment
export RESOURCE_GROUP_NAME="RG-Azure-VDI-01"
export LOCATION="centralus"

# VM Configuration
export TEMP_VM_NAME="gm-temp-vm"
export VM_SIZE="Standard_D4s_v6"
export WINDOWS_IMAGE_SKU="MicrosoftWindowsDesktop:windows-11:win11-25h2-avd:latest"

# Networking
export VNET_NAME="avd-vnet"
export SUBNET_NAME="avd-subnet"

# Credentials (set via environment variable, not hardcoded)
export ADMIN_USERNAME="localadmin"
export ADMIN_PASSWORD="YourSecurePassword123!"

# Image Gallery
export IMAGE_GALLERY_NAME="avd_gallery"
export IMAGE_DEFINITION_NAME="windows11-golden-image"
```

### Configuration Priority

Values are loaded in this order (highest priority first):
1. Environment variables (can override config.env)
2. Values in `config.env`
3. Centralized config (`../config/avd-config.sh`)
4. Script defaults

Example override:
```bash
# Override TEMP_VM_NAME for this run only
TEMP_VM_NAME="my-custom-vm" ./tasks/01-create-vm.sh
```

## Validation

Before starting, validate prerequisites:

```bash
./config-validators/validate-prereqs.sh
```

Checks:
- ✓ Azure CLI installed
- ✓ Azure authentication
- ✓ Resource group exists
- ✓ VNet and subnet exist
- ✓ Required Azure permissions
- ✓ Configuration file present

## Workflow Details

### Task Overview

| Task | Purpose | Duration | Interactive |
|------|---------|----------|-------------|
| 01 | Create VM | 5-10 min | No |
| 02 | Validate readiness | 5-15 min | No |
| 03 | Configure VM | 30-60 min | No |
| 07 | AVD Registry Optimizations | 2-5 min | No |
| 08 | Final Cleanup & Sysprep | 5-10 min | No |
| 04 | Sysprep | 5-10 min | No |
| 05 | Capture image | 15-30 min | No |
| 06 | Cleanup | 5-10 min | No |

### What Gets Installed

Task 03 installs:
- **FSLogix** - Profile management for pooled deployments
- **Google Chrome Enterprise** - Web browser
- **Adobe Reader DC** - PDF viewer
- **Microsoft Office 365** - Productivity suite
- **Windows Updates** - Latest patches
- **AVD Optimization Tool (VDOT)** - Performance tuning

Plus registry optimizations for:
- Windows permissions redirection
- Printer redirection
- Timezone redirection
- User profile optimization

### Image Output

After successful completion:
- Image stored in **Azure Compute Gallery**
- Available for immediate deployment
- Versioned with timestamp (YYYY.MMDD.HHMM)
- Reusable for multiple session host deployments

Use the image version ID in `06-session-host-deployment` step to deploy session hosts from this golden image.

## Logs and Troubleshooting

### View Logs

```bash
# Most recent logs
tail -f artifacts/*.log

# Specific task logs
ls -lt artifacts/ | head -10  # See most recent files

# Search for errors
grep -i error artifacts/*.log

# Search for warnings
grep -i warning artifacts/*.log
```

### Common Issues

See `docs/WORKFLOW.md` for:
- Detailed troubleshooting
- Recovery procedures
- Task-specific issues

See `docs/TASK-REFERENCE.md` for:
- Per-task troubleshooting
- Prerequisites for each task
- Common failure scenarios

### Support Resources

- **Workflow Guide**: `docs/WORKFLOW.md` - Complete step-by-step walkthrough
- **Task Reference**: `docs/TASK-REFERENCE.md` - Detailed task documentation
- **Command Reference**: `commands/README.md` - Azure CLI commands
- **Troubleshooting**: `docs/WORKFLOW.md#troubleshooting` - Common issues

## For AI Assistants (Gemini, Claude Code)

### Key Principles

1. **Use tasks, not scripts**: Run tasks from `tasks/` directory, not individual Azure CLI scripts
2. **Respect config.env**: All configuration in one place, no hardcoding
3. **Check logs first**: When issues occur, review task logs
4. **Use command references**: Before creating new scripts, check `commands/` directory
5. **Resume gracefully**: If task fails, review error and re-run

### How to Interact

```bash
# Validate environment first
./config-validators/validate-prereqs.sh

# Load configuration
source config.env

# Run individual tasks
./tasks/01-create-vm.sh
./tasks/02-validate-vm.sh
# etc.

# Or chain for full automation
./tasks/01-create-vm.sh && ./tasks/02-validate-vm.sh && ...

# Use command reference for custom operations
source commands/vm-operations.sh
source commands/image-operations.sh

# Create logs as needed
./tasks/0X-task.sh >> logs/custom-run.log 2>&1
```

### Task Outputs

Each task saves output to `artifacts/`:
- **Logs**: `task-name_TIMESTAMP.log` - Human readable log
- **Details**: `task-name_details.txt` - Structured output (IDs, IPs, etc.)
- **JSON**: `task-name_*.json` - Raw command output for parsing

Use details files to:
- Extract VM IDs for next tasks
- Get image IDs for deployment
- Track resources created

## Directory Structure

```
05-golden-image/
├── README.md                          # This file
├── config.env                         # Configuration (customize this)
│
├── tasks/                             # Executable task scripts
│   ├── 01-create-vm.sh               # Create temporary VM
│   ├── 02-validate-vm.sh             # Validate VM readiness
│   ├── 03-configure-vm.sh            # Install software
│   ├── 04-sysprep-vm.sh              # Prepare for capture
│   ├── 05-capture-image.sh           # Save as image
│   └── 06-cleanup.sh                 # Delete temp resources
│
├── commands/                          # Azure CLI command reference
│   ├── vm-operations.sh              # VM commands
│   ├── image-operations.sh           # Image gallery commands
│   └── README.md                     # How to use commands
│
├── config-validators/                # Pre-flight validation
│   └── validate-prereqs.sh           # Check prerequisites
│
├── docs/                             # Documentation
│   ├── WORKFLOW.md                   # Step-by-step guide
│   ├── TASK-REFERENCE.md             # Task details
│   ├── COMMANDS.md                   # Command documentation
│   ├── TROUBLESHOOTING.md            # Problem solving
│   └── ARCHITECTURE.md               # Design decisions
│
├── state/                            # Runtime state (gitignored)
│   └── .gitignore
│
└── artifacts/                        # Logs and output (gitignored)
    └── .gitignore
```

## Next Steps

After creating golden image:

1. **Verify image in gallery**:
   ```bash
   source config.env
   az sig image-version list \
       -g "$RESOURCE_GROUP_NAME" \
       -r "$IMAGE_GALLERY_NAME" \
       -i "$IMAGE_DEFINITION_NAME" \
       --output table
   ```

2. **Deploy session hosts** using `06-session-host-deployment` step with image version ID

3. **Optional**: Delete old image versions to manage costs
   - See `commands/image-operations.sh` for cleanup commands

4. **Optional**: Replicate image to other regions
   - See `commands/image-operations.sh` for replication commands

## Frequently Asked Questions

**Q: How long does the full workflow take?**
A: 90-150 minutes (1.5-2.5 hours) depending on Windows Updates and Azure infrastructure

**Q: Can I skip task 02 (validate VM)?**
A: Yes, if you monitor VM status manually in Azure Portal and proceed when ready

**Q: What if a task fails partway through?**
A: Fix the issue and re-run the failed task (most are idempotent). See troubleshooting docs.

**Q: Can I customize the software installed?**
A: Yes, edit `config_vm.ps1` to add/remove software. It's run in task 03.

**Q: How do I deploy session hosts from this image?**
A: Use the image version ID in `06-session-host-deployment` step

**Q: How do I delete the golden image when no longer needed?**
A: Use Azure Portal or Azure CLI to delete the image version/definition in the gallery

**Q: Can I replicate the image to other regions?**
A: Yes, see `commands/image-operations.sh` for replication commands

## Support

For issues:
1. Check `docs/WORKFLOW.md` - comprehensive troubleshooting guide
2. Check task logs in `artifacts/` directory
3. Review `docs/TASK-REFERENCE.md` for task-specific help
4. Consult `commands/README.md` for command usage

## License

This automation is part of the Azure Virtual Desktop deployment toolkit.
