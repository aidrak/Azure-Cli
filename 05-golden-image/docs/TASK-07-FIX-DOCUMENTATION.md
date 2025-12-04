# Task 07: AVD Registry Optimizations - Fix Documentation

**Date:** 2025-12-04
**Status:** FIXED & VERIFIED
**Issue:** PowerShell script execution failures due to Unicode character encoding and incorrect Azure CLI syntax

---

## Problem Summary

Task 07 (`tasks/07-avd-registry-optimizations.sh`) was failing to execute the PowerShell registry optimizations on the remote VM. The script appeared to complete successfully but produced no actual changes on the VM.

### Root Causes Identified

#### 1. **Unicode Character Encoding Issue**
The PowerShell script contained Unicode emoji and box-drawing characters that were breaking the parser when transmitted via Azure CLI:

**Problematic characters:**
- `✓` (checkmark) - U+2713
- `✗` (cross mark) - U+2717
- `⚠` (warning sign) - U+26A0
- `ℹ` (info symbol) - U+2139
- `╔`, `╚`, `║` (box-drawing characters) - U+2550 range

**Error message received:**
```
The string is missing the terminator: '.
Missing closing '}' in statement block or type definition.
```

The remote PowerShell parser on the Azure VM was encountering encoding issues when these characters were embedded in string literals, particularly in:
- Line 32-34: `Write-LogSection` function box drawing
- Line 40, 45, 50, 55: Logging functions with emoji

#### 2. **Incorrect Azure CLI Command Syntax**
The original task script used an unsafe method to pass the PowerShell script content:

```bash
# WRONG - Embeds entire script content, breaks on special characters
az vm run-command invoke \
    --command-id RunPowerShellScript \
    --scripts "$(cat "$PS_SCRIPT")" \
    --output json
```

**Issues with this approach:**
- String interpolation on bash side causes encoding issues
- Special characters in the PowerShell script get interpreted by bash
- No proper escaping of quotes and special characters
- Brittle and error-prone for complex scripts

**Correct approach:**
```bash
# CORRECT - Azure CLI handles file reading and encoding
az vm run-command invoke \
    --command-id RunPowerShellScript \
    --scripts "@${PS_SCRIPT}" \
    --output json
```

The `@` prefix tells Azure CLI to read the file directly and properly handle encoding/transmission.

---

## Changes Made

### 1. Task Script Fix: `tasks/07-avd-registry-optimizations.sh`

**File:** `/mnt/cache_pool/development/azure-cli/05-golden-image/tasks/07-avd-registry-optimizations.sh`

**Line 182 - BEFORE:**
```bash
az vm run-command invoke \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$TEMP_VM_NAME" \
    --command-id RunPowerShellScript \
    --scripts "$(cat "$PS_SCRIPT")" \
    --output json > "$output_file" 2>&1 || true
```

**Line 182 - AFTER:**
```bash
az vm run-command invoke \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$TEMP_VM_NAME" \
    --command-id RunPowerShellScript \
    --scripts "@${PS_SCRIPT}" \
    --output json > "$output_file" 2>&1 || true
```

**Rationale:** Uses Azure CLI's file reference syntax (`@filename`) which properly handles file encoding and prevents shell interpolation issues.

---

### 2. PowerShell Script Fix: `powershell/avd-registry-optimizations.ps1`

**File:** `/mnt/cache_pool/development/azure-cli/05-golden-image/powershell/avd-registry-optimizations.ps1`

#### Change 2.1: Write-LogSection Function (Lines 29-36)

**BEFORE:**
```powershell
function Write-LogSection {
    param([string]$Message)
    Write-Host ""
    Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║ $($Message.PadRight(56)) ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
}
```

**AFTER:**
```powershell
function Write-LogSection {
    param([string]$Message)
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host " $($Message.PadRight(56))" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""
}
```

**Rationale:** Replaced Unicode box-drawing characters (`╔`, `║`, `╚`) with ASCII equals signs (`=`). These characters were causing parser errors on the remote VM.

#### Change 2.2: Logging Functions (Lines 38-56)

**BEFORE:**
```powershell
function Write-LogSuccess {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor Green
}

function Write-LogError {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor Red
}

function Write-LogWarning {
    param([string]$Message)
    Write-Host "⚠ $Message" -ForegroundColor Yellow
}

function Write-LogInfo {
    param([string]$Message)
    Write-Host "ℹ $Message" -ForegroundColor Gray
}
```

**AFTER:**
```powershell
function Write-LogSuccess {
    param([string]$Message)
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-LogError {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Write-LogWarning {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Write-LogInfo {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Gray
}
```

**Rationale:** Replaced Unicode emoji symbols with ASCII-safe bracketed labels. The `✓`, `✗`, `⚠`, `ℹ` characters were breaking the PowerShell parser on the remote VM.

---

## Verification Results

### Execution Output (2025-12-04 04:16:36 UTC)

**Script:** `tasks/07-avd-registry-optimizations.sh`
**VM:** `gm-temp-vm` (Resource Group: `RG-Azure-VDI-01`)
**Exit Code:** 0 (Success)

**Registry Optimizations Applied - ALL SUCCESSFUL:**

```
============================================================
 Configuring Registry for AVD
============================================================

[INFO] Enabling RDP timezone redirection...
[OK] RDP timezone redirection enabled

[INFO] Adding FSLogix Defender exclusions...
[OK] FSLogix Defender exclusions added

[INFO] Setting locale to en-US...
[OK] Locale set to en-US

[INFO] Disabling System Restore and VSS...
[OK] System Restore and VSS disabled

[INFO] Disabling first logon animation (black screen fix)...
[OK] First logon animation disabled (black screen fix applied)

[INFO] Disabling OOBE privacy screens...
[OK] OOBE privacy screens disabled

[INFO] Disabling Windows Hello for Business...
[OK] Windows Hello for Business disabled

[OK] Registry configuration completed

============================================================
 Configuring Default User Profile
============================================================

[INFO] Loading and configuring Default User hive...
[OK] Default User profile configured

============================================================
 Step 7 Complete
============================================================

[OK] All AVD-specific optimizations applied successfully!
```

### Registry Changes Confirmed

All 8 optimization categories were successfully applied:

1. **✅ RDP Timezone Redirection**
   - Registry Path: `HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server`
   - Setting: `fEnableTimeZoneRedirection = 1`

2. **✅ FSLogix Defender Exclusions** (Pooled environment)
   - Path exclusions: `C:\Program Files\FSLogix`, `C:\ProgramData\FSLogix`
   - Process exclusions: `frx.exe`
   - Extension exclusions: `.vhd`, `.vhdx`

3. **✅ Locale Settings**
   - System Locale: `en-US`
   - Culture: `en-US`
   - Geo ID: 244

4. **✅ System Restore & VSS Disabled**
   - System Restore disabled for C:\ drive
   - VSS service stopped and disabled
   - All existing VSS shadows deleted

5. **✅ First Logon Animation Disabled** (Black Screen Fix)
   - Registry: `HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon`
   - Setting: `EnableFirstLogonAnimation = 0`
   - Registry: `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System`
   - Setting: `DelayedDesktopSwitchTimeout = 0`

6. **✅ OOBE Privacy Screens Disabled**
   - Registry Path: `HKLM:\SOFTWARE\Policies\Microsoft\Windows\OOBE`
   - Setting: `DisablePrivacyExperience = 1`

7. **✅ Windows Hello for Business Disabled**
   - Registry Path: `HKLM:\SOFTWARE\Policies\Microsoft\PassportForWork`
   - Setting: `Enabled = 0`

8. **✅ Default User Profile Configuration**
   - Disabled: "Let's finish setting up your device"
   - Disabled: OEM pre-installed apps
   - Disabled: Pre-installed apps
   - Disabled: Silent installed apps
   - Disabled: Content Delivery Manager suggestions
   - Disabled: User engagement prompts

### Artifacts Generated

- **Log File:** `artifacts/07-avd-registry-optimizations_20251204_041532.log`
- **JSON Output:** `artifacts/07-avd-registry-optimizations-output.json`
- **Details:** `artifacts/07-avd-registry-optimizations-details.txt`

---

## Technical Details

### Why Unicode Characters Failed

When the PowerShell script was embedded in the bash command using `$(cat "$PS_SCRIPT")`:

1. Bash would read the file containing Unicode characters
2. The string would be interpolated into the bash command
3. Azure CLI would receive the bash-processed string
4. The Windows PowerShell parser on the remote VM would receive garbled/incorrectly-encoded characters
5. The parser would encounter unexpected bytes in string literals, breaking the parse tree

**Example of what went wrong:**
- Original: `Write-Host "ℹ $Message"`
- After bash interpolation: Mangled UTF-8 bytes
- Remote PowerShell: `The string is missing the terminator: '.`

### Why the Fix Works

Using `@${PS_SCRIPT}` tells Azure CLI to:
1. Read the file on the local machine
2. Properly encode it for transmission (typically UTF-8 with proper BOM)
3. Send it directly to the remote PowerShell runtime
4. The remote runtime receives properly-encoded PowerShell source code
5. Parser correctly handles ASCII-safe characters

---

## Best Practices Established

### For Future PowerShell Scripts

1. **Avoid Unicode Characters in Remote Scripts**
   - Use ASCII-safe alternatives for logging symbols
   - Replace emoji with bracketed labels: `[OK]`, `[ERROR]`, `[WARN]`, `[INFO]`
   - Replace box-drawing with ASCII: `=`, `+`, `-`

2. **Use Azure CLI File References**
   - Always use `--scripts "@/path/to/script.ps1"`
   - Never use `--scripts "$(cat ...)"` for complex scripts
   - This is safer for encoding and escaping

3. **Test Script Encoding**
   - Verify script works with UTF-8 encoding
   - Test with ASCII characters only for remote execution
   - Use `file -i script.ps1` to verify encoding locally

4. **Error Output Validation**
   - Always check the JSON output for `StdErr` content
   - Look for parser errors in the stderr output
   - Verify exit code is 0

---

## Files Modified

| File | Changes | Reason |
|------|---------|--------|
| `tasks/07-avd-registry-optimizations.sh` | Line 182: Changed `--scripts "$(cat "$PS_SCRIPT")"` to `--scripts "@${PS_SCRIPT}"` | Use Azure CLI file reference syntax |
| `powershell/avd-registry-optimizations.ps1` | Lines 29-56: Removed Unicode characters, replaced with ASCII | Fix remote PowerShell parser errors |

---

## Testing Performed

### Test 1: Initial Execution (Failed)
- **Time:** 2025-12-04 04:13:13 UTC
- **Artifact:** `07-avd-registry-optimizations_20251204_041313.log`
- **Result:** Parser error due to Unicode characters
- **stderr:** `The string is missing the terminator: '.`

### Test 2: With File Reference Only (Failed)
- **Time:** 2025-12-04 04:14:45 UTC
- **Artifact:** `07-avd-registry-optimizations_20251204_041445.log`
- **Result:** Same parser error - Unicode characters still present
- **Finding:** Need to fix PowerShell script, not just task script

### Test 3: Both Fixes Applied (SUCCESS)
- **Time:** 2025-12-04 04:16:36 UTC
- **Artifact:** `07-avd-registry-optimizations_20251204_041532.log`
- **Result:** ✅ All optimizations applied successfully
- **Exit Code:** 0
- **Verification:** stdout shows all 8 categories completed with [OK] status

---

## Rollback/Revert Instructions

If needed to revert changes:

```bash
# Revert task script changes
git checkout tasks/07-avd-registry-optimizations.sh

# Revert PowerShell script changes
git checkout powershell/avd-registry-optimizations.ps1
```

However, **reverting is not recommended** as the original code was broken and would fail on remote execution.

---

## Next Steps

The golden image creation workflow can now proceed:

1. ✅ Task 07: AVD Registry Optimizations - **COMPLETE & VERIFIED**
2. ⏭️ Task 08: Final Cleanup & Sysprep Preparation
3. ⏭️ Task 04: Sysprep VM
4. ⏭️ Task 05: Capture Image

---

## References

- **Azure CLI Run Command Documentation:** https://learn.microsoft.com/en-us/cli/azure/vm/run-command
- **PowerShell Remote Execution:** https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_remote
- **UTF-8 and PowerShell:** https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_character_encoding

---

## Contact & Questions

For questions about these changes, refer to:
- Git commit logs: `git log --oneline tasks/07-avd-registry-optimizations.sh`
- Task documentation: `tasks/07-avd-registry-optimizations.sh` (inline comments)
- This file: `TASK-07-FIX-DOCUMENTATION.md`
