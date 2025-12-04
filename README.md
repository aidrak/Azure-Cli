# Azure Virtual Desktop (AVD) Deployment Template

## Overview

This repository contains a complete, AI-friendly task-centric template for deploying a production-ready Azure Virtual Desktop (AVD) environment. The template supports both full automation and individual task execution across 12 deployment steps.

**Key Features:**
- **Task-Centric Architecture**: Modular, reusable tasks that can be run individually or chained
- **AI-Optimized**: Designed to prevent script proliferation and guide AI assistants effectively
- **Configuration-Driven**: Single source of truth for all deployment values
- **Multiple Execution Modes**: Interactive, automated, resume-from-failure, or single-step
- **Complete Automation**: From networking and storage through session hosts, Intune, and testing
- **Comprehensive Documentation**: For both AI assistants and human operators

## Quick Start

### Automated Full Deployment
```bash
# Run entire 12-step pipeline in automated mode
./orchestrate.sh --automated
```

### Interactive Deployment (Prompt per step)
```bash
# Run with prompts before each step
./orchestrate.sh
```

### Resume from Failure
```bash
# Continue from where the last failure occurred
./orchestrate.sh --resume
```

### Run Single Step
```bash
# Run only step 05 (golden image)
./orchestrate.sh --step 05-golden-image

# Or run individual task
cd 05-golden-image
./tasks/01-create-vm.sh
```

## Prerequisites

Before you begin, ensure you have the following:

- An active Azure Subscription
- A user account with 'Owner' or 'Contributor' and 'User Access Administrator' roles on the subscription
- Azure CLI installed and configured (version 2.30+)
- PowerShell Core or Windows PowerShell 5.1+
- You are logged into your Azure account via `az login`
- Sufficient quota in your Azure subscription for VMs, storage, and networking resources

## Configuration

### Setup Configuration

1. **Configure centralized settings:**
   ```bash
   # Copy and edit the global configuration
   cp config/avd-config.example.sh config/avd-config.sh
   vi config/avd-config.sh
   ```

   Update these required values:
   - `SUBSCRIPTION_ID` - Your Azure subscription ID
   - `TENANT_ID` - Your Entra ID tenant ID
   - `RESOURCE_GROUP_NAME` - Resource group name (e.g., RG-Azure-VDI-01)
   - `LOCATION` - Azure region (e.g., centralus)

2. **Configure individual steps (optional overrides):**
   ```bash
   # Each step can have its own config.env for step-specific settings
   vi 05-golden-image/config.env
   ```

   Step-specific configurations override centralized settings for that step only.

3. **Validate configuration:**
   ```bash
   # The orchestrator will validate prerequisites automatically
   ./orchestrate.sh --help
   ```

### Configuration Hierarchy

Configuration values are loaded in this order (first match wins):

1. Environment variables (highest priority)
2. Step-specific `config.env` (e.g., `05-golden-image/config.env`)
3. Centralized `config/avd-config.sh` (global defaults)
4. Script-level defaults (lowest priority)

### Configuration File Structure

The configuration files organize settings by deployment step:

- **Global Settings** - Subscription, tenant, location, resource group, environment (prod/dev/test)
- **Networking** (Step 01) - VNet name, subnets, IP ranges, NSG names
- **Storage** (Step 02) - Storage account, file share name and quota
- **Entra Groups** (Step 03) - User and device group names
- **Host Pool** (Step 04) - Workspace, host pool, app group names
- **Golden Image** (Step 05) - Image gallery, VM size
- **Session Hosts** (Step 06) - VM prefix, size, count
- **Autoscaling** (Step 10) - Scaling plan name, timezone, schedules

### Using Configuration Files

**Option 1: Automatic loading (recommended)**
Scripts check for `./config/avd-config.sh` (Bash) or `../config/avd-config.ps1` (PowerShell) by default:
```bash
./01-Networking-Setup.sh
```

**Option 2: Custom config file location**
```bash
CONFIG_FILE="/path/to/my-config.sh" ./01-Networking-Setup.sh
# OR PowerShell
$env:AVD_CONFIG_FILE = "C:\path\to\my-config.ps1"
.\02-Storage-Setup.ps1
```

**Option 3: Override with parameters**
Config file loads first, CLI parameters override values:
```bash
./01-Networking-Setup.sh --location "eastus"
# OR PowerShell
.\02-Storage-Setup.ps1 -Location "eastus"
```

### Configuration Best Practices

- **Never commit config files** - `avd-config.sh` and `avd-config.ps1` are in `.gitignore`
- **Use example files** - Copy and customize from `avd-config.example.sh` and `avd-config.example.ps1`
- **Validate before deployment** - Run `validate-config.ps1` to catch errors early
- **Environment-specific configs** - Create separate configs: `avd-config-dev.sh`, `avd-config-prod.sh`

## Directory Structure

```
azure-cli/
├── orchestrate.sh                    # Master orchestration script
├── config/
│   └── avd-config.sh                # Centralized configuration (create from example)
├── common/
│   ├── functions/                   # Reusable function libraries
│   ├── templates/                   # Task and config templates
│   └── docs/                        # Reference documentation
│
├── 01-networking/
│   ├── config.env                   # Networking configuration
│   ├── tasks/                       # Individual task scripts
│   ├── commands/                    # Azure CLI command references
│   └── README.md                    # Step documentation
│
├── 02-storage/
├── 03-entra-group/
├── 04-host-pool-workspace/
├── 05-golden-image/
├── 06-session-host-deployment/
├── 07-intune/
├── 08-rbac/
├── 09-sso/
├── 10-autoscaling/
├── 11-testing/
└── 12-cleanup-migration/
```

Each step (01-12) follows the same structure:
- **tasks/** - Modular, individually executable task scripts
- **commands/** - Pre-built Azure CLI command references
- **config.env** - Step-specific configuration settings
- **README.md** - Quick start and documentation

## Deployment Approach

This repository supports **three deployment patterns**:

### 1. Full Automated Pipeline (Recommended)

```bash
./orchestrate.sh --automated
```

The orchestrator runs all 12 steps sequentially with:
- Automatic prerequisite validation
- Error detection and stop-on-failure
- State tracking for resume capability
- Detailed logging to artifacts/

**When to use:** Production deployments, repeatable processes, full automation.

### 2. Interactive Deployment (Prompt per step)

```bash
./orchestrate.sh
```

Execute with confirmation prompts before each step:
- Review configuration before each step
- Option to skip steps
- Resume capability on errors

**When to use:** Learning the system, testing individual steps, manual oversight.

### 3. Individual Task Execution

```bash
cd 05-golden-image
./tasks/01-create-vm.sh
./tasks/02-validate-vm.sh
```

Run specific tasks as needed:
- Completely independent execution
- Full control over order and parameters
- Use for troubleshooting or custom workflows

**When to use:** Debugging, custom deployments, integration with other tools.

## Script Conventions

**Naming Pattern:** `[step-number]-[step-name].[sh|ps1]`

**Script Types:**
- `.sh` - Bash scripts using Azure CLI (infrastructure provisioning)
- `.ps1` - PowerShell scripts using Az/Microsoft.Graph modules (configuration/management)
- `.Tests.ps1` - Verification scripts to validate deployment

**Script Features:**
- **Idempotent:** Safe to run multiple times
- **Parameterized:** Customize for your environment
- **Validated:** Check prerequisites before executing
- **Verbose:** Clear console output with color-coded status
- **Error Handling:** Fail-fast with meaningful error messages

**Color-Coded Output:**
- **Blue/Cyan** = Section headers and informational messages
- **Yellow** = Processing steps and warnings
- **Green** = Successful operations (✓)
- **Red** = Errors (✗)

## Workflow Steps

Follow the steps below in order. Each step corresponds to a directory containing detailed instructions and any necessary scripts.

1.  **Networking Setup**
    *   Provisions the core networking infrastructure (VNet, subnets, NSGs).
    *   **Automation:** `01-Networking-Setup.sh` (Bash/Azure CLI)
    *   [View Details](./01-networking/01-Networking-Setup.md)

2.  **Storage Setup**
    *   Creates Azure Files Premium with FSLogix profiles and private endpoint.
    *   **Automation:** `02-Storage-Setup.ps1` (PowerShell)
    *   [View Details](./02-storage/02-Storage-Setup.md)

3.  **Entra ID Group Setup**
    *   Creates user security groups and device dynamic groups for policy targeting.
    *   **Automation:** `03-Entra-Group-Setup.ps1` (PowerShell)
    *   [View Details](./03-entra-group/03-Entra-Group-Setup.md)

4.  **Host Pool & Workspace Setup**
    *   Creates AVD workspace, host pool, and application group with RDP configuration.
    *   **Automation:** `04-Host-Pool-Workspace-Setup.ps1` (PowerShell)
    *   [View Details](./04-host-pool-workspace/04-Host-Pool-Workspace-Setup.md)

5.  **Golden Image Creation**
    *   Creates and configures a golden image VM with all necessary applications (Office, Chrome, Adobe, FSLogix, VDOT optimizations).
    *   **Automation:** Three-script workflow:
      - `05-Golden-Image-VM-Create.sh` (Bash/Azure CLI) - Create temporary VM
      - `05-Golden-Image-VM-Configure.ps1` (PowerShell) - Configure inside VM via RDP
      - `05-Golden-Image-Capture.sh` (Bash/Azure CLI) - Sysprep and capture image
    *   [View Details](./05-golden-image-updated/05-Golden-Image-Creation.md)

6.  **Session Host Deployment**
    *   Deploys N session host VMs from golden image and registers to host pool.
    *   **Automation:** `06-Session-Host-Deployment.ps1` (PowerShell)
    *   [View Details](./06-session-host-deployment/06-Session-Host-Deployment.md)

7.  **Intune Configuration**
    *   Creates and assigns Intune configuration policies for FSLogix, RDP transport, and security baselines.
    *   **Automation:** `07-Intune-Configuration.ps1` (PowerShell)
    *   [View Details](./07-intune/07-Intune-Configuration.md)

8.  **RBAC Assignments**
    *   Assigns Role-Based Access Control (RBAC) to Entra ID groups for user access.
    *   **Automation:** `08-RBAC-Assignments.ps1` (PowerShell) + `08-RBAC-Assignments.Tests.ps1`
    *   [View Details](./08-rbac/08-RBAC-Assignments.md)

9.  **SSO Configuration**
    *   Configures Windows Cloud Login for Kerberos SSO and seamless authentication.
    *   **Automation:** `09-SSO-Configuration.ps1` (PowerShell)
    *   [View Details](./09-sso/09-SSO-Configuration.md)

10. **Autoscaling Setup**
    *   Creates scaling plans with time-based schedules to optimize costs by starting/stopping VMs.
    *   **Automation:** `10-Autoscaling-Setup.ps1` (PowerShell)
    *   [View Details](./10-autoscaling/10-Autoscaling-Setup.md)

11. **Testing & Validation**
    *   Comprehensive automated validation of entire AVD infrastructure and configuration.
    *   **Automation:** `11-Testing-Validation.ps1` (PowerShell)
    *   [View Details](./11-testing/11-Testing-Validation.md)

12. **VM Cleanup & Migration**
    *   Automated cleanup of temporary VMs and orphaned resources; migration guide for user transition.
    *   **Automation:** `12-VM-Cleanup.ps1` (PowerShell)
    *   [View Details](./12-cleanup-migration/12-VM-Cleanup-Migration.md)

## Function Libraries

The `common/functions/` directory contains reusable libraries for all task scripts:

- **logging-functions.sh** - Unified logging with color-coded output, file management, and operation tracking
- **config-functions.sh** - Configuration loading, validation, and environment variable handling
- **azure-functions.sh** - Azure CLI wrappers with retry logic and error handling
- **string-functions.sh** - String manipulation, JSON handling, security utilities

All task scripts automatically source these libraries. Reference: [Function Libraries Guide](./common/functions/FUNCTIONS-GUIDE.md)

## Shared Utilities

The `common/` directory contains reusable scripts and utilities for debugging, validation, and recovery:

**Prerequisites & Validation:**
- **`verify_prerequisites.ps1`** - Validates environment prerequisites before deployment
  - Checks PowerShell version, Azure modules, Microsoft Graph modules
  - Verifies Azure subscription access and permissions
  - Validates Entra ID licenses and resource provider registration
  - **Usage:** `.\verify_prerequisites.ps1` (run before starting deployment)

**Configuration & Documentation:**
- **`export_deployment_config.ps1`** - Exports all deployed resources and configuration as JSON
  - Exports: Resource group, VNets, storage accounts, host pools, app groups, workspaces, VMs
  - **Usage:** `.\export_deployment_config.ps1 -ResourceGroupName "RG-Azure-VDI-01" -OutputFile "avd-config.json"`

**Debugging & Recovery:**
- **`debug_apps.ps1`** - Diagnostic tool for troubleshooting application installations on golden image
  - Tests application installation status, registry keys, file permissions
  - **Usage:** Run on golden image VM to verify installations

- **`recover_vm.sh`** - Recovery script for troubleshooting or recovering sysprep issues
  - Helps with VM recovery after failed generalization
  - **Usage:** Use when VM recovery is needed after golden image capture failure

**Reference Documentation:**
- **`azure-cli-reference.md`** - Comprehensive Azure CLI command reference for AVD deployments
  - Complete list of relevant `az` commands organized by resource type
  - Includes networking, storage, VMs, AVD, RBAC, monitoring, and more
  - Provides command syntax, parameters, and usage examples
  - **Usage:** AI assistants and developers can reference this when building or modifying infrastructure

## Quick Start

### Option 1: Quick Validation Only
```bash
# Run prerequisites check
cd common
pwsh -ExecutionPolicy Bypass -File verify_prerequisites.ps1
```

### Option 2: Full Automated Deployment
```bash
# Step 1: Validate environment
cd common
pwsh -ExecutionPolicy Bypass -File verify_prerequisites.ps1

# Step 2: Run each deployment script in order
cd ../01-networking
bash 01-Networking-Setup.sh

cd ../02-storage
pwsh 02-Storage-Setup.ps1
# ... continue through all 12 steps

# Step 13: Validate complete deployment
cd ../11-testing
pwsh 11-Testing-Validation.ps1
```

### Option 3: Manual Deployment
Start with Step 1 and proceed sequentially. Navigate into each directory and follow the instructions within the markdown file. Each directory contains an `XX-*.md` file with detailed manual instructions.

## For AI Assistants (Gemini, Claude Code, etc.)

This template is specifically designed for AI assistant usage. If you're an AI assistant helping with AVD deployment:

1. **Start here:** Read [AI-INTERACTION-GUIDE.md](./AI-INTERACTION-GUIDE.md) for comprehensive guidance on using this template
2. **Key Principles:**
   - Use existing task templates; don't create new scripts
   - All configuration goes in `config.env` files, never hardcoded
   - Source and use function libraries instead of rewriting functionality
   - Follow established task patterns from `common/templates/task-template.sh`
3. **Function Libraries:** Before writing new code, check `common/functions/` for reusable functionality
4. **Command References:** Pre-built Azure CLI commands available in `commands/` subdirectories
5. **State Tracking:** The orchestrator maintains state in `artifacts/` for debugging and recovery

See [AI-INTERACTION-GUIDE.md](./AI-INTERACTION-GUIDE.md) for detailed best practices, common task examples, and troubleshooting.
