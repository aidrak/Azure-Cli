# Advanced Topics

**Advanced patterns and techniques for complex scenarios**

## Table of Contents

1. [Remote PowerShell Execution](#remote-powerShell-execution)
2. [Handling Large PowerShell Scripts](#handling-large-powershell-scripts)
3. [Custom Validation Commands](#custom-validation-commands)
4. [Environment-Specific Operations](#environment-specific-operations)

---

## Remote PowerShell Execution

### Overview

Some operations execute PowerShell directly on Azure VMs rather than locally. This is particularly useful for VM customization, such as golden image preparation.

### Use Cases

- **Golden Image Preparation:** Install software, configure settings
- **VM Configuration:** Post-deployment customization
- **Software Installation:** Install applications on VMs
- **Registry Modifications:** Configure Windows settings
- **Service Configuration:** Start/stop/configure Windows services

### Template Type

```yaml
template:
  type: "powershell-remote"
  command: |
    # This script runs ON the VM, not locally
    # Executed via: az vm run-command invoke
```

### Example

```yaml
operation:
  id: "golden-image-install-apps"
  name: "Install Applications on Golden Image"
  
  template:
    type: "powershell-remote"
    command: |
      # This script runs on the Azure VM
      Write-Host "Running on Azure VM: $env:COMPUTERNAME"
      
      # Install Chocolatey
      Set-ExecutionPolicy Bypass -Scope Process -Force
      [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
      iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
      
      # Install applications
      choco install googlechrome -y
      choco install vlc -y
      choco install 7zip -y
      
      Write-Host "Applications installed successfully"
```

### Usage Pattern

The engine wraps the PowerShell script and executes it via Azure CLI:

```bash
# Engine generates this command
az vm run-command invoke \
  --resource-group "{{RESOURCE_GROUP}}" \
  --vm-name "{{VM_NAME}}" \
  --command-id "RunPowerShellScript" \
  --scripts @/tmp/remote-script.ps1
```

### Benefits

- **Direct VM Access:** No need for remote desktop or SSH
- **Automation:** Fully scriptable VM customization
- **Logging:** All output captured for auditing
- **Idempotency:** Can check VM state before running

### Limitations

- **Script Size:** Limited to ~256KB per execution
- **Execution Time:** Default timeout is 90 minutes
- **Output Size:** Output limited to ~4KB
- **No Interactivity:** Cannot prompt for user input

---

## Handling Large PowerShell Scripts

### Overview

For scripts larger than 10KB, store them in separate files to improve maintainability and readability.

### Directory Structure

```
capabilities/compute/operations/
├── golden-image-install-apps.yaml
└── scripts/
    ├── golden-image-install-apps.ps1
    ├── golden-image-install-office.ps1
    └── golden-image-configure-profile.ps1
```

### Operation References Script

**golden-image-install-apps.yaml:**
```yaml
operation:
  id: "golden-image-install-apps"
  name: "Install Applications"
  
  template:
    type: "powershell-remote"
    command: |
      # Load large script from file
      $scriptPath = "capabilities/compute/operations/scripts/golden-image-install-apps.ps1"
      
      # Execute script on VM
      az vm run-command invoke \
        --resource-group "{{RESOURCE_GROUP}}" \
        --vm-name "{{VM_NAME}}" \
        --command-id "RunPowerShellScript" \
        --scripts @"$scriptPath"
```

### Separate Script File

**scripts/golden-image-install-apps.ps1:**
```powershell
<#
.SYNOPSIS
    Install core applications on golden image VM

.DESCRIPTION
    Installs browsers, productivity tools, media players
    Uses Chocolatey for package management

.NOTES
    Execution: Remote (on Azure VM)
    Duration: ~15 minutes
#>

Write-Host "[START] Application installation"

# Install Chocolatey
Write-Host "Installing Chocolatey..."
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

# Install browsers
Write-Host "Installing browsers..."
choco install googlechrome -y
choco install firefox -y
choco install microsoft-edge -y

# Install productivity tools
Write-Host "Installing productivity tools..."
choco install adobereader -y
choco install 7zip -y
choco install notepadplusplus -y

# Install media players
Write-Host "Installing media players..."
choco install vlc -y

Write-Host "[DONE] Application installation complete"
```

### Benefits

- **Maintainability:** Easier to edit large scripts
- **Version Control:** Clear git diffs for script changes
- **Reusability:** Scripts can be used in multiple operations
- **Testing:** Scripts can be tested independently
- **IDE Support:** Better syntax highlighting and IntelliSense

---

## Custom Validation Commands

### Overview

For complex validation scenarios, use custom commands with full scripting logic.

### Use Case

When standard validation types (resource_exists, provisioning_state, property_equals) are insufficient.

### Example 1: Count-Based Validation

Verify at least N resources exist:

```yaml
validation:
  enabled: true
  checks:
    - type: "custom"
      command: |
        # Count VMs in resource group
        VM_COUNT=$(az vm list \
          --resource-group "{{RESOURCE_GROUP}}" \
          --query "length([])" -o tsv)
        
        # Require at least 1 VM
        if [ "$VM_COUNT" -ge 1 ]; then
          echo "Found $VM_COUNT VMs"
          exit 0  # Success
        else
          echo "No VMs found"
          exit 1  # Failure
        fi
      description: "At least one VM exists in resource group"
```

### Example 2: Multi-Property Validation

Verify multiple properties match expectations:

```yaml
validation:
  enabled: true
  checks:
    - type: "custom"
      command: |
        # Get VM details
        VM_JSON=$(az vm show \
          --resource-group "{{RESOURCE_GROUP}}" \
          --name "{{VM_NAME}}")
        
        # Check size
        SIZE=$(echo "$VM_JSON" | jq -r '.hardwareProfile.vmSize')
        if [ "$SIZE" != "Standard_D4s_v3" ]; then
          echo "Wrong VM size: $SIZE"
          exit 1
        fi
        
        # Check OS
        OS=$(echo "$VM_JSON" | jq -r '.storageProfile.osDisk.osType')
        if [ "$OS" != "Windows" ]; then
          echo "Wrong OS: $OS"
          exit 1
        fi
        
        echo "VM configuration validated"
        exit 0
      description: "VM size and OS are correct"
```

### Example 3: External Service Check

Verify connectivity or external dependencies:

```yaml
validation:
  enabled: true
  checks:
    - type: "custom"
      command: |
        # Test DNS resolution
        if nslookup "{{CUSTOM_DNS_NAME}}" > /dev/null 2>&1; then
          echo "DNS resolves correctly"
          exit 0
        else
