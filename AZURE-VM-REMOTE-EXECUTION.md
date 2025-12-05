# Azure VM Remote Execution - `az vm run-command` Pattern

Reference guide for executing PowerShell scripts on Azure VMs without RDP, used extensively in the YAML-based deployment engine.

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
- Entire script content passed to Azure
- Supports complex multi-function scripts
- Maximum script size: ~32KB

### 2. Synchronous by Default
- Command waits for PowerShell completion
- Full output (stdout/stderr/exitCode) in JSON response
- Suitable for sequential workflows
- No `--no-wait` flag = blocking operation

### 3. Async Option: `--no-wait`
```bash
az vm run-command invoke \
  --resource-group "$RG" \
  --name "$VM" \
  --command-id RunPowerShellScript \
  --scripts "$(cat script.ps1)" \
  --no-wait
```
- Returns immediately
- Operation continues in background
- Useful for 1+ hour operations
- Requires polling to check completion

### 4. JSON Output Format
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
      "level": "Info",
      "message": "stderr content here"
    }
  ]
}
```

### 5. Error Handling
```bash
# Continue on PowerShell errors (capture full output)
az vm run-command invoke \
  --scripts "$(cat script.ps1)" \
  --output json > output.json 2>&1 || true
```

## YAML Engine Integration

### In Operation Templates

YAML operations use inline PowerShell or external scripts:

#### Method 1: External PowerShell Script

```yaml
operation:
  id: "golden-image-install-fslogix"
  template:
    command: |
      az vm run-command invoke \
        --resource-group "{{AZURE_RESOURCE_GROUP}}" \
        --name "{{GOLDEN_IMAGE_TEMP_VM_NAME}}" \
        --command-id RunPowerShellScript \
        --scripts "@modules/05-golden-image/operations/install-fslogix.ps1" \
        --output json > artifacts/outputs/golden-image-install-fslogix.json
```

#### Method 2: Inline PowerShell

```yaml
operation:
  id: "golden-image-system-prep"
  powershell:
    content: |
      Write-Host "[START] System preparation: $(Get-Date -Format 'HH:mm:ss')"

      # Create temp directory
      if (!(Test-Path "C:\Temp")) {
          New-Item -Path "C:\Temp" -ItemType Directory -Force
      }

      Write-Host "[SUCCESS] System prepared"
      exit 0
```

The template engine extracts PowerShell to `artifacts/scripts/[operation].ps1` and executes via `az vm run-command`.

### Progress Markers (Required)

All PowerShell scripts **must** include:

```powershell
Write-Host "[START] Operation: $(Get-Date -Format 'HH:mm:ss')"
Write-Host "[PROGRESS] Step 1/4: Downloading..."
Write-Host "[PROGRESS] Step 2/4: Installing..."
Write-Host "[VALIDATE] Checking installation..."
Write-Host "[SUCCESS] Operation completed"
exit 0  # Required for success detection
```

**Supported Markers**:
- `[START]` - Operation begins
- `[PROGRESS]` - Step update (numbered: "Step X/Y")
- `[VALIDATE]` - Validation check
- `[SUCCESS]` - Completed successfully
- `[ERROR]` - Error occurred
- `[WARNING]` - Non-fatal issue

## Common Use Cases

### 1. Software Installation

```yaml
operation:
  powershell:
    content: |
      Write-Host "[START] Installing FSLogix"
      Write-Host "[PROGRESS] Step 1/3: Downloading installer..."

      $url = "https://aka.ms/fslogix_download"
      $dest = "C:\Temp\FSLogix.zip"
      Invoke-WebRequest -Uri $url -OutFile $dest -TimeoutSec 120

      Write-Host "[PROGRESS] Step 2/3: Extracting archive..."
      Expand-Archive -Path $dest -DestinationPath "C:\Temp\FSLogix"

      Write-Host "[PROGRESS] Step 3/3: Running installer..."
      Start-Process -FilePath "C:\Temp\FSLogix\x64\Release\FSLogixAppsSetup.exe" -ArgumentList "/install /quiet /norestart" -Wait

      Write-Host "[VALIDATE] Checking installation..."
      if (!(Test-Path "C:\Program Files\FSLogix\Apps\frx.exe")) {
          Write-Host "[ERROR] FSLogix not installed"
          exit 1
      }

      Write-Host "[SUCCESS] FSLogix installed"
      exit 0
```

### 2. System Configuration

```yaml
operation:
  powershell:
    content: |
      Write-Host "[START] Configuring AVD registry settings"

      # Configure timezone
      Set-TimeZone -Name "{{GOLDEN_IMAGE_TIMEZONE}}"

      # Disable automatic updates
      Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "NoAutoUpdate" -Value 1

      Write-Host "[SUCCESS] Configuration complete"
      exit 0
```

### 3. Running Sysprep

```yaml
operation:
  template:
    command: |
      az vm run-command invoke \
        --resource-group "{{AZURE_RESOURCE_GROUP}}" \
        --name "{{GOLDEN_IMAGE_TEMP_VM_NAME}}" \
        --command-id RunPowerShellScript \
        --scripts "C:\\Windows\\System32\\Sysprep\\sysprep.exe /oobe /generalize /shutdown /quiet"
```

### 4. Validation Checks

```yaml
operation:
  powershell:
    content: |
      Write-Host "[START] Validating installation"

      $checks = @(
          @{Path = "C:\Program Files\FSLogix\Apps\frx.exe"; Name = "FSLogix"},
          @{Path = "C:\Program Files\Google\Chrome\Application\chrome.exe"; Name = "Chrome"},
          @{Path = "C:\Program Files\Microsoft Office\root\Office16\WINWORD.EXE"; Name = "Office"}
      )

      $failed = @()
      foreach ($check in $checks) {
          Write-Host "[VALIDATE] Checking $($check.Name)..."
          if (!(Test-Path $check.Path)) {
              $failed += $check.Name
          }
      }

      if ($failed.Count -gt 0) {
          Write-Host "[ERROR] Missing: $($failed -join ', ')"
          exit 1
      }

      Write-Host "[SUCCESS] All components validated"
      exit 0
```

## Output Parsing

### Extract stdout

```bash
# Using jq
STDOUT=$(cat output.json | jq -r '.value[0].message')
echo "$STDOUT"

# Grep for specific markers
cat output.json | jq -r '.value[0].message' | grep '\[ERROR\]'
```

### Check Exit Code

```bash
# Azure CLI exit code (0 = command submitted successfully)
if [ $? -eq 0 ]; then
    echo "Command submitted successfully"
fi

# PowerShell script exit code (check stderr for errors)
if grep -q '\[ERROR\]' output.json; then
    echo "PowerShell script failed"
fi
```

## Best Practices

### 1. Always Use Timestamped Logs

```bash
TIMESTAMP=$(date +'%Y%m%d_%H%M%S')
az vm run-command invoke ... > artifacts/outputs/${OPERATION_ID}_${TIMESTAMP}.json
```

### 2. Save Full Output for Debugging

```bash
az vm run-command invoke \
  --scripts "$(cat script.ps1)" \
  --output json > artifacts/outputs/operation.json 2>&1 || true
```

### 3. Use ASCII Characters in Output

For compatibility with all Azure regions:
- Use `[v]` instead of `✓`
- Use `[x]` instead of `✗`
- Use `[!]` instead of `⚠`
- Use `[i]` instead of `ℹ`

### 4. Validate VM Prerequisites

```bash
# Check VM exists
if ! az vm show -g "$RG" -n "$VM" &> /dev/null; then
    echo "ERROR: VM not found"
    exit 1
fi

# Check VM is running
VM_STATE=$(az vm get-instance-view -g "$RG" -n "$VM" \
    --query "instanceView.statuses[?starts_with(code, 'PowerState')].displayStatus" -o tsv)
if [[ "$VM_STATE" != "VM running" ]]; then
    echo "ERROR: VM is not running (state: $VM_STATE)"
    exit 1
fi
```

### 5. Handle Long Operations

For operations taking 30+ minutes:
- Use `--no-wait` flag
- Log expected duration
- Poll for completion in next operation
- Don't block on completion

## Troubleshooting

### Script Execution Timed Out

**Cause**: Operation exceeds Azure timeout (~10 minutes)
**Solution**: Break into smaller scripts or use `--no-wait`

### File Not Found Errors

**Cause**: Script assumes files exist that weren't created
**Solution**: Use absolute paths and create directories first:

```powershell
if (!(Test-Path "C:\Temp")) {
    New-Item -Path "C:\Temp" -ItemType Directory -Force | Out-Null
}
```

### Access Denied Errors

**Cause**: Insufficient permissions
**Solution**: Scripts run as Administrator by default. Check:
- RBAC permissions in Azure
- VM agent is running

### PowerShell Execution Policy Errors

**Cause**: Execution policy too restrictive
**Solution**: Set in script:

```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
```

## References

- [Azure CLI: az vm run-command documentation](https://docs.microsoft.com/en-us/cli/azure/vm/run-command)
- [ARCHITECTURE.md](ARCHITECTURE.md) - YAML engine documentation
- [Module 05: Golden Image operations](modules/05-golden-image/operations/) - Production examples
- [Windows Desktop Optimization Tool (VDOT)](https://github.com/The-Virtual-Desktop-Team/Windows-Desktop-Optimization-Tool)

---

**Last Updated**: 2025-12-05
**Related**: YAML-based deployment engine
