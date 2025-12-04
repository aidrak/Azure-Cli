# Azure VM Remote Execution Pattern

## Overview

Execute PowerShell scripts and commands on Azure VMs without RDP using `az vm run-command`. This is the foundation of the automated golden image creation workflow, enabling fully scriptable VM configuration.

## Basic Pattern

```bash
az vm run-command invoke \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --name "$VM_NAME" \
  --command-id RunPowerShellScript \
  --scripts "$(cat /path/to/script.ps1)" \
  --output json > output.json
```

## Key Characteristics

### 1. Script Loading: `$(cat script.ps1)`
- Reads local PowerShell script into bash string
- Entire script content is passed to Azure
- Allows complex multi-function scripts to run remotely
- Works with scripts up to ~32KB in size

### 2. Synchronous by Default
- Command WAITS for PowerShell execution to complete
- No `--no-wait` flag means blocking operation
- Full output (stdout/stderr/exitCode) returned in JSON response
- Suitable for sequential workflow steps

### 3. Async Option with `--no-wait`
```bash
az vm run-command invoke \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --name "$VM_NAME" \
  --command-id RunPowerShellScript \
  --scripts "$(cat script.ps1)" \
  --no-wait
```
- Command returns immediately
- Operation continues on VM in background
- Useful for very long operations (1+ hour)
- Requires polling to check completion status

### 4. Output Format: JSON with Structure
```json
{
  "value": [
    {
      "code": "ComponentStatus/StdOut/succeeded",
      "displayStatus": "Provisioning succeeded",
      "level": "Info",
      "message": "stdout content here"
    },
    {
      "code": "ComponentStatus/StdErr/succeeded",
      "displayStatus": "Provisioning succeeded",
      "level": "Info",
      "message": "stderr content here"
    }
  ]
}
```

### 5. Error Handling: Use `|| true` to Continue
```bash
az vm run-command invoke \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --name "$VM_NAME" \
  --command-id RunPowerShellScript \
  --scripts "$(cat script.ps1)" \
  --output json > output.json 2>&1 || true
```

- PowerShell errors won't cause bash script to exit
- Allows capture of full output for debugging
- Script can check exit code and stderr separately

## Use Cases

### VM Configuration and Software Installation
```bash
# Install applications, configure settings
az vm run-command invoke \
  --command-id RunPowerShellScript \
  --scripts "$(cat config_vm.ps1)"
```

### Running Optimization Tools
```bash
# Download and run WDOT (Windows Desktop Optimization Tool)
az vm run-command invoke \
  --command-id RunPowerShellScript \
  --scripts "$(cat run-wdot.ps1)"
```

### Executing Sysprep for Image Capture
```bash
# Generalize VM before image capture
az vm run-command invoke \
  --command-id RunPowerShellScript \
  --scripts "C:\\Windows\\System32\\Sysprep\\sysprep.exe /oobe /generalize /shutdown /quiet"
```

### Diagnostic Commands and Troubleshooting
```bash
# Check system information
az vm run-command invoke \
  --command-id RunPowerShellScript \
  --scripts "Get-ComputerInfo; Get-Disk; Get-NetAdapter"
```

## Output Parsing Examples

### Extract stdout from JSON Response
```bash
STDOUT=$(cat output.json | jq -r '.value[0].message')
echo "$STDOUT"
```

### Extract with grep and sed (backward compatible)
```bash
STDOUT=$(cat output.json | grep -o '"message":"[^"]*"' | sed 's/"message":"\(.*\)"/\1/' | head -1)
echo "$STDOUT"
```

### Check Exit Code
```bash
# Note: `az vm run-command invoke` CLI command exit code (0=success)
# Different from PowerShell script exit code (check stderr for errors)
if [ $? -eq 0 ]; then
    echo "Command submitted successfully"
fi
```

## Golden Image Workflow Example

The golden image creation uses this pattern across multiple tasks:

### Task 01: Create VM
```bash
# Direct Azure resource creation (no remote execution)
az vm create --resource-group ... --name gm-temp-vm ...
```

### Task 02: Validate VM
```bash
# Poll VM state (no remote execution)
az vm get-instance-view --query "instanceView.statuses[?starts_with(code, 'PowerState')]"
```

### Task 03: Configure VM (30-60 minutes)
```bash
# Remote execution of comprehensive configuration script
az vm run-command invoke \
  --command-id RunPowerShellScript \
  --scripts "$(cat config_vm.ps1)" \
  --output json > artifacts/03-configure-vm_output.json
```

Executes:
- Disable BitLocker
- Install FSLogix Agent
- Install Google Chrome Enterprise
- Install Adobe Reader DC
- Install Microsoft Office 365
- Run VDOT optimizations
- Configure AVD registry settings
- Configure Default User profile

### Task 04: Sysprep VM (5-10 minutes)
```bash
# Remote execution of sysprep command
az vm run-command invoke \
  --command-id RunPowerShellScript \
  --scripts "C:\\Windows\\System32\\Sysprep\\sysprep.exe /oobe /generalize /shutdown /quiet" \
  --output json > artifacts/04-sysprep-vm_output.json
```

### Task 05: Capture Image (15-30 minutes)
```bash
# Direct Azure operations (no remote execution)
az sig image-version create \
  --gallery-name AVD_Image_Gallery \
  --gallery-image-definition "Win11-25H2-AVD-Pooled" \
  --gallery-image-version "1.0.0"
```

### Task 06: Cleanup (5-10 minutes)
```bash
# Async deletion of resources
az vm delete --resource-group ... --name gm-temp-vm --yes --no-wait
```

## Best Practices

### 1. Always Use Timestamped Logs
```bash
TIMESTAMP=$(date +'%Y%m%d_%H%M%S')
LOG_FILE="artifacts/task_${TIMESTAMP}.log"
az vm run-command invoke ... --output json > output.json
```

### 2. Save Full Output for Debugging
```bash
az vm run-command invoke \
  --scripts "$(cat script.ps1)" \
  --output json > artifacts/full_output.json 2>&1 || true
```

### 3. Handle Long-Running Operations
For operations taking 30+ minutes:
- Use `--no-wait` flag
- Log that operation started with expected duration
- Poll for completion in next task's pre-flight checks
- Don't block user waiting for completion

### 4. Validate VM Prerequisites Before Execution
```bash
# Check VM exists and is running
if ! az vm show -g "$RESOURCE_GROUP_NAME" -n "$VM_NAME" &> /dev/null; then
    echo "ERROR: VM '$VM_NAME' not found"
    exit 1
fi

# Check VM is running
VM_STATE=$(az vm get-instance-view -g "$RESOURCE_GROUP_NAME" -n "$VM_NAME" \
    --query "instanceView.statuses[?starts_with(code, 'PowerState')].displayStatus" -o tsv)
if [[ "$VM_STATE" != "VM running" ]]; then
    echo "ERROR: VM is not running (current state: $VM_STATE)"
    exit 1
fi
```

### 5. Use ASCII Characters in Remote Scripts
When executing via `az vm run-command`, stick to ASCII characters in output:
- Use `[v]` instead of `✓`
- Use `[x]` instead of `✗`
- Use `[!]` instead of `⚠`
- Use `[i]` instead of `ℹ`

This ensures compatibility with all Azure regions and encoding.

## Common Issues and Solutions

### Issue: "Script execution timed out"
**Cause**: Operation takes longer than Azure's timeout (typically 10 minutes for small scripts)
**Solution**: Break into smaller scripts or use `--no-wait` for long operations

### Issue: "File not found" errors
**Cause**: Script assumes files exist on VM that weren't created
**Solution**: Use absolute paths and create directories first:
```powershell
if (!(Test-Path "C:\Temp")) {
    New-Item -Path "C:\Temp" -ItemType Directory -Force | Out-Null
}
```

### Issue: "Access Denied" errors
**Cause**: Command requires admin privileges
**Solution**: Scripts run as Administrator by default. If still failing, check:
- User account has proper RBAC permissions in Azure
- VM agent is running (`az vm run-command` requires VM agent)

### Issue: "PowerShell execution policy" errors
**Cause**: Execution policy too restrictive
**Solution**: Set in script:
```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
```

## References

- [Azure CLI: az vm run-command documentation](https://docs.microsoft.com/en-us/cli/azure/vm/run-command)
- [Golden Image Task Scripts](./05-golden-image/tasks/)
- [AI Interaction Guide - Remote VM Execution](./AI-INTERACTION-GUIDE.md#remote-vm-execution)
- [Windows Desktop Optimization Tool (VDOT)](https://github.com/The-Virtual-Desktop-Team/Windows-Desktop-Optimization-Tool)
