# Azure Virtual Desktop (AVD) Deployment Guide

## Overview

This repository contains a collection of scripts and step-by-step guides to deploy a complete Azure Virtual Desktop (AVD) environment. The process covers everything from initial network and storage setup to session host deployment, Intune configuration, and final testing.

## Prerequisites

Before you begin, ensure you have the following:

- An active Azure Subscription.
- A user account with 'Owner' or 'Contributor' and 'User Access Administrator' roles on the subscription.
- Azure CLI installed and configured.
- PowerShell with the Az module installed.
- You are logged into your Azure account via `az login`.

## Configuration

### Quick Start

1. **Copy the example configuration file:**
   ```bash
   # For Bash scripts (01-Networking-Setup.sh)
   cp config/avd-config.example.sh config/avd-config.sh

   # For PowerShell scripts (02-12)
   cp config/avd-config.example.ps1 config/avd-config.ps1
   ```

2. **Edit configuration with your values:**
   ```bash
   # Edit with your favorite editor
   nano config/avd-config.sh
   # or
   code config/avd-config.ps1
   ```

3. **Required configuration values to update:**
   - `AVD_SUBSCRIPTION_ID` / `SubscriptionId` - Your Azure subscription ID
   - `AVD_TENANT_ID` / `TenantId` - Your Entra ID tenant ID
   - `AVD_RESOURCE_GROUP` / `ResourceGroup` - Resource group name (default: RG-Azure-VDI-01)
   - `AVD_LOCATION` / `Location` - Azure region (default: centralus)

4. **Validate your configuration:**
   ```powershell
   # PowerShell validation
   .\common\validate-config.ps1 -ConfigFile ".\config\avd-config.ps1"
   ```

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

## Deployment Approach

This repository supports **two deployment methods**:

### 1. Automated Deployment (Recommended)

Each step includes PowerShell or Bash automation scripts that:
- Follow infrastructure-as-code best practices
- Include error handling and idempotency checks
- Provide detailed console output with progress indicators
- Verify operations completed successfully

**When to use:** Production deployments, repeatable processes, consistent results across environments.

### 2. Manual Deployment

Each step also includes detailed manual instructions for Azure Portal, Azure CLI, and PowerShell.

**When to use:** Learning the platform, troubleshooting, customizing individual resources.

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
