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
        --scripts "@capabilities/compute/operations/golden-image-install-fslogix.ps1" \
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

### Progress Markers

All PowerShell scripts executed via the run-command pattern must include standardized progress markers for the engine's progress tracker to function correctly.

For the canonical list of markers (`[START]`, `[PROGRESS]`, etc.) and implementation rules, see the main [**Development Rules Guide**](./.claude/docs/03-development-rules.md).

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

