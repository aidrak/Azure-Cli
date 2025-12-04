# Common Utility Scripts

This directory contains executable utility scripts used across all AVD deployment steps.

## Scripts Overview

| Script | Language | Purpose | Status |
|--------|----------|---------|--------|
| `verify_prerequisites.ps1` | PowerShell | Pre-flight requirement validation | ✅ Ready |
| `validate-config.ps1` | PowerShell | Configuration file validation | ✅ Ready |
| `debug_apps.ps1` | PowerShell | Debug installed applications | ✅ Ready |
| `recover_vm.sh` | Bash | VM recovery procedures | ✅ Ready |
| `export_deployment_config.ps1` | PowerShell | Export deployment to JSON | ✅ Ready |

## Individual Script Documentation

### verify_prerequisites.ps1

**Purpose**: Validates all prerequisites before starting AVD deployment

**Usage**:
```powershell
.\verify_prerequisites.ps1
```

**What It Checks**:
- PowerShell version (7.0+ recommended, 5.1+ minimum)
- Azure PowerShell modules:
  - Az.Accounts
  - Az.Compute
  - Az.DesktopVirtualization
  - Az.Network
  - Az.Storage
- Microsoft.Graph modules (optional)
- Azure authentication status
- Azure permissions

**Exit Codes**:
- 0: All prerequisites met
- 1: One or more prerequisites missing

**Output**:
- Color-coded results (green = pass, red = fail, yellow = warning)
- Summary statistics (passed/failed count)
- Helpful suggestions for missing items

**Example Output**:
```
=== AVD Deployment Prerequisites Check ===

=== Checking PowerShell Version ===
✓ PowerShell 7.3.4 (Recommended: PS 7+)

=== Checking Azure PowerShell Modules ===
✓ Az.Accounts (5.13.0)
✓ Az.Compute (6.2.0)
...
✓ Passed: 8
✗ Failed: 0

=== Summary ===
✓ All prerequisites verified! Ready to deploy AVD.
```

---

### validate-config.ps1

**Purpose**: Validates AVD configuration file before deployment

**Usage**:
```powershell
.\validate-config.ps1 -ConfigFile "path/to/config.ps1"
```

**Parameters**:
- `-ConfigFile` (Required): Path to configuration file to validate

**What It Validates**:
- Configuration file exists
- Configuration hashtable structure
- Required properties present:
  - SubscriptionId
  - TenantId
  - Location
  - ResourceGroup
  - Environment
- Required sections present:
  - Network
  - Storage
  - Groups
  - HostPool
  - Image
  - SessionHosts
  - Scaling
  - Tags
- Value validation:
  - Valid subscription/tenant IDs (not zeros)
  - Valid CIDR blocks for VNets and subnets
  - Valid VM sizes
  - Valid session counts (1-100)
  - Valid load balancer types (BreadthFirst, DepthFirst)

**Exit Codes**:
- 0: Configuration valid
- 1: Validation failed

**Output**:
- Detailed validation results
- Specific errors preventing deployment
- Warnings about suspicious values

**Example**:
```powershell
.\validate-config.ps1 -ConfigFile ".\config\avd-config.ps1"

=== AVD Configuration Validation ===
ℹ Validating configuration file: .\config\avd-config.ps1

=== Validating Configuration File ===
✓ Configuration file found: .\config\avd-config.ps1

=== Validating Configuration Structure ===
✓ Configuration hashtable loaded successfully
✓ Property present: SubscriptionId
...

=== Configuration Errors ===
✗ SubscriptionId must be set (current: 00000000-0000-0000-0000-000000000000)

=== Validation Summary ===
✗ Configuration validation FAILED
```

---

### debug_apps.ps1

**Purpose**: Debug installed applications on Windows VMs

**Usage** (run inside Windows VM):
```powershell
.\debug_apps.ps1
```

**What It Checks**:
- Chocolatey installation and packages
- Chrome installation location
- Adobe Reader installation location

**Exit Codes**:
- 0: Script completed (check output for actual status)

**Output**:
- Chocolatey: List of installed packages
- Chrome: Path to chrome.exe or "not found"
- Adobe Reader: Path to AcroRd32.exe or "not found"

**When to Use**:
- After deploying session hosts to verify software
- During VM configuration troubleshooting
- To debug missing applications

**Example Output**:
```
--- Checking Chocolatey ---
Chrome [91.0.4472.77]
AdobeReader [2021.005.20054]
...

--- Searching for Chrome ---
Found Chrome at: C:\Program Files\Google\Chrome\Application\chrome.exe

--- Searching for Adobe Reader ---
Found Adobe Reader at: C:\Program Files (x86)\Adobe\Reader\AdobeReader.exe
```

---

### recover_vm.sh

**Purpose**: Recover a Windows VM from a failed creation by reusing the OS disk

**Usage**:
```bash
./recover_vm.sh
```

**Prerequisites**:
- Azure CLI installed and authenticated
- `config.env` with resource group and location set
- Failed VM's OS disk must exist in resource group

**Environment Variables** (set in config.env):
```bash
RESOURCE_GROUP="RG-Azure-VDI-01"
LOCATION="centralus"
```

**Hardcoded Variables** (edit script):
- `OLD_VM_NAME` - Name of failed VM
- `NEW_VM_NAME` - Name for recovered VM

**What It Does**:
1. Retrieves OS disk ID from failed VM
2. Deletes failed VM
3. Creates new VM from existing OS disk
4. Reuses all existing configurations and data

**Exit Codes**:
- 0: Success
- 1: Error (disk not found, creation failed)

**When to Use**:
- VM creation failed but OS disk is intact
- Need to restore VM from existing disk
- Disk corruption or VM configuration issues

**Example**:
```bash
$ ./recover_vm.sh
Getting OS Disk ID...
OS Disk ID: /subscriptions/.../disks/avd-gold-pool_OsDisk_1234567890
Deleting old generalized VM...
Creating new VM from OS Disk...
Recovery VM created: avd-gold-pool-v2
You can now RDP into avd-gold-pool-v2 to install applications.
```

---

### export_deployment_config.ps1

**Purpose**: Export complete AVD deployment configuration to JSON for documentation and backup

**Usage**:
```powershell
.\export_deployment_config.ps1 `
    -ResourceGroupName "RG-Azure-VDI-01" `
    -OutputFile "avd-config.json"
```

**Parameters**:
- `-ResourceGroupName` (Required): Name of resource group to export
- `-OutputFile` (Optional): Output file path (default: "avd-deployment-config.json")

**What It Exports**:
- Resource group metadata (location, tags)
- Virtual networks and subnets
- Storage accounts (type, SKU)
- Host pools (type, load balancer, max sessions)
- Application groups
- Workspaces
- Virtual machines (size, status)
- Timestamps

**Exit Codes**:
- 0: Export successful
- Errors shown in output

**Output**:
JSON file with complete deployment configuration

**When to Use**:
- Document current deployment
- Backup configuration before changes
- Troubleshoot connectivity/permissions issues
- Generate reports for compliance/audit
- Plan scaling or migration

**Example Output** (JSON):
```json
{
  "ExportDate": "2025-12-04 14:30:00",
  "ResourceGroup": "RG-Azure-VDI-01",
  "Resources": {
    "ResourceGroup": {
      "Name": "RG-Azure-VDI-01",
      "Location": "centralus",
      "Tags": {...}
    },
    "VirtualNetworks": [{
      "Name": "avd-vnet",
      "AddressSpace": ["10.0.0.0/16"],
      "Subnets": [...]
    }],
    "HostPools": [...],
    ...
  }
}
```

---

## Calling Patterns

### From Bash Scripts
```bash
#!/bin/bash

# Run PowerShell scripts from bash
pwsh -NoProfile -ExecutionPolicy Bypass -File "./common/scripts/verify_prerequisites.ps1"

# Or call with parameters
pwsh -NoProfile -ExecutionPolicy Bypass -File "./common/scripts/validate-config.ps1" \
    -ConfigFile "./config.env"
```

### From PowerShell Scripts
```powershell
# Direct call
& ".\common\scripts\verify_prerequisites.ps1"

# With parameters
& ".\common\scripts\validate-config.ps1" -ConfigFile ".\config.ps1"

# With error checking
if (-not (& ".\common\scripts\verify_prerequisites.ps1")) {
    Write-Error "Prerequisites not met"
    exit 1
}
```

### From Deployment Steps
```bash
#!/bin/bash
# In a deployment step (01-12)

source ../common/scripts/verify_prerequisites.ps1  # For bash
pwsh -NoProfile -ExecutionPolicy Bypass -File "../common/scripts/verify_prerequisites.ps1"  # For PowerShell
```

---

## Adding New Scripts

To add a new utility script:

1. **Name it clearly**: `verb-noun.ps1` or `verb-noun.sh`
2. **Add header documentation**:
   ```powershell
   # Script description
   # Purpose: What this script does
   # Usage: How to call it
   # Prerequisites: What must be installed/configured
   ```

3. **Use consistent functions**:
   - `Write-LogSuccess` / `Write-LogError` for status
   - Color coding (Green = success, Red = error, Yellow = warning)
   - Exit code 0 for success, 1 for failure

4. **Test thoroughly** before committing

5. **Document in this README** in the Scripts Overview table

---

## Error Handling

All scripts follow consistent error handling:

**PowerShell**:
```powershell
$ErrorActionPreference = "Stop"  # Fail on any error
```

**Bash**:
```bash
set -e  # Exit on any error
```

**Output Codes**:
- ✓ (Green) = Success
- ✗ (Red) = Error
- ⚠ (Yellow) = Warning
- ℹ (Gray) = Info

---

## Logging

Scripts support logging:
- PowerShell: Color-coded console output
- Bash: Stdout/stderr
- Optional: Redirect to file with `>> logfile.txt 2>&1`

Example:
```bash
./scripts/verify_prerequisites.ps1 > logs/verify_$(date +%Y%m%d_%H%M%S).log 2>&1
```

---

## Performance

Expected runtimes:
- `verify_prerequisites.ps1`: < 10 seconds
- `validate-config.ps1`: < 5 seconds
- `debug_apps.ps1`: < 10 seconds
- `recover_vm.sh`: 5-15 minutes (Azure operations)
- `export_deployment_config.ps1`: 30-60 seconds

---

**Status**: All scripts ready for use
**Next**: Phase 2B - Function libraries and templates
