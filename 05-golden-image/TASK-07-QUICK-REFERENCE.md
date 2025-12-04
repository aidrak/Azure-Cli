# Task 07: AVD Registry Optimizations - Quick Reference

## Status: ✅ FIXED & WORKING

**Last Updated:** 2025-12-04
**Verified:** Successfully applied all 8 registry optimization categories

---

## What This Task Does

Applies AVD-specific registry optimizations to the golden image VM for Pooled (multi-session) environments with FSLogix.

## Quick Usage

```bash
cd /mnt/cache_pool/development/azure-cli/05-golden-image
./tasks/07-avd-registry-optimizations.sh
```

## Prerequisites

- ✓ Azure CLI installed and authenticated
- ✓ `config.env` configured with VM details
- ✓ VM must be running and accessible
- ✓ Tasks 1-6 completed

## Expected Output

```
[OK] RDP timezone redirection enabled
[OK] FSLogix Defender exclusions added
[OK] Locale set to en-US
[OK] System Restore and VSS disabled
[OK] First logon animation disabled
[OK] OOBE privacy screens disabled
[OK] Windows Hello disabled
[OK] Default User profile configured
```

## Optimizations Applied

| Setting | Purpose |
|---------|---------|
| **RDP Timezone Redirection** | Users' local timezone shows correctly in sessions |
| **FSLogix Defender Exclusions** | Improves profile container performance |
| **Locale en-US** | Standard locale for all users |
| **System Restore & VSS Disabled** | Reduces image size and improves performance |
| **First Logon Animation Disabled** | Fixes potential black screen on first logon |
| **OOBE Privacy Screens Disabled** | Skips setup wizard on new user profiles |
| **Windows Hello Disabled** | Prevents login issues in pooled environments |
| **Default User Profile Optimized** | Disables app suggestions and telemetry |

## Recent Fixes (2025-12-04)

### Problem
Script appeared to run successfully but produced no registry changes on the VM.

### Root Cause
- Unicode emoji characters (✓, ⚠, ℹ) broke PowerShell parser on remote VM
- Azure CLI command used unsafe script transmission method

### Solution Applied
1. **File:** `tasks/07-avd-registry-optimizations.sh` Line 182
   - Changed: `--scripts "$(cat "$PS_SCRIPT")"`
   - To: `--scripts "@${PS_SCRIPT}"`

2. **File:** `powershell/avd-registry-optimizations.ps1` Lines 29-56
   - Removed Unicode emoji (✓, ✗, ⚠, ℹ)
   - Removed box-drawing characters (╔, ║, ╚)
   - Replaced with ASCII: `[OK]`, `[ERROR]`, `[WARN]`, `[INFO]`, `=`

### Result
✅ All 8 registry optimizations now apply successfully

## Logs and Output

After running, check:

```bash
# View most recent log
tail artifacts/07-avd-registry-optimizations_*.log

# View JSON output (for debugging)
cat artifacts/07-avd-registry-optimizations-output.json

# View execution details
cat artifacts/07-avd-registry-optimizations-details.txt
```

## Troubleshooting

### Script shows success but settings not applied

**Check 1:** Verify script actually ran
```bash
grep "All AVD-specific optimizations applied successfully" artifacts/07-avd-registry-optimizations_*.log
```

**Check 2:** Look for stderr errors
```bash
grep -A5 "StdErr" artifacts/07-avd-registry-optimizations-output.json
```

**Check 3:** Re-run the task
```bash
./tasks/07-avd-registry-optimizations.sh
```

### Parser errors in output

This indicates Unicode character encoding issues. The fixes should have resolved this. If you still see:
```
The string is missing the terminator
Missing closing '}'
```

The PowerShell script files may have been corrupted. Restore from git:
```bash
git checkout powershell/avd-registry-optimizations.ps1 tasks/07-avd-registry-optimizations.sh
```

## Workflow Integration

Task 07 fits in the golden image creation workflow:

```
1. Create VM
2. Validate VM
3. Configure VM (install software)
7. AVD Registry Optimizations ← You are here
8. Final Cleanup & Sysprep Prep
4. Sysprep
5. Capture Image
6. Cleanup
```

## Next Steps

After successful completion:

1. **Verify settings applied:**
   - Check logs show no errors
   - All 8 categories show `[OK]` status

2. **Continue workflow:**
   ```bash
   ./tasks/08-final-cleanup-sysprep.sh
   ./tasks/04-sysprep-vm.sh
   ./tasks/05-capture-image.sh
   ./tasks/06-cleanup.sh
   ```

## Performance Impact

- **Duration:** 2-5 minutes
- **VM Impact:** Minimal (registry modifications only)
- **VM Downtime:** None (runs while VM is active)

## Files Modified by This Task

On the VM, this task modifies:
- `HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server`
- `HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon`
- `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System`
- `HKLM:\SOFTWARE\Policies\Microsoft\Windows\OOBE`
- `HKLM:\SOFTWARE\Policies\Microsoft\PassportForWork`
- Defender exclusions for FSLogix
- Default User profile hive

## Configuration Used

Task 07 reads these values from `config.env`:
- `RESOURCE_GROUP_NAME` - Azure resource group
- `TEMP_VM_NAME` - Name of VM to optimize

## Support

For detailed documentation:
- **Full Fix Details:** `TASK-07-FIX-DOCUMENTATION.md`
- **Changelog:** `CHANGELOG.md`
- **General Help:** `README.md`

---

**Status:** ✅ Working
**Last Tested:** 2025-12-04 04:16:36 UTC
**All Optimizations:** Applied Successfully
