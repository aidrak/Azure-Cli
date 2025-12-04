# Changelog - Golden Image Creation Workflow

## [FIXED] 2025-12-04 - Task 07 Registry Optimizations

### Summary
Fixed critical issues in Task 07 (AVD Registry Optimizations) that prevented remote PowerShell script execution on Azure VMs.

### Issues Fixed

#### Issue 1: Unicode Character Encoding Failures
**Problem:** The PowerShell script contained Unicode emoji and box-drawing characters that broke the remote PowerShell parser
**Symptoms:**
- Script execution appeared successful but produced no registry changes
- Remote stderr showed: "The string is missing the terminator: '. Missing closing '}'"
- Optimization task ran without errors but VM had no applied settings

**Root Cause:**
- Unicode characters (✓, ✗, ⚠, ℹ, ╔, ║, ╚) were being mangled during Azure CLI transmission
- Remote PowerShell parser encountered incorrectly-encoded bytes in string literals
- Parser error prevented entire script from executing

**Solution:**
- Removed all Unicode emoji from logging functions
- Replaced with ASCII-safe alternatives: `[OK]`, `[ERROR]`, `[WARN]`, `[INFO]`
- Replaced box-drawing characters with ASCII dashes

**Files Modified:** `powershell/avd-registry-optimizations.ps1`

#### Issue 2: Unsafe Azure CLI Script Transmission
**Problem:** Task script used unsafe method to pass PowerShell script to Azure VM
**Symptoms:** Same as Issue 1

**Root Cause:**
- Used `--scripts "$(cat "$PS_SCRIPT")"` which embeds script via bash interpolation
- Bash shell interpretation broke special character encoding
- Caused Unicode characters to be further corrupted

**Solution:**
- Changed to `--scripts "@${PS_SCRIPT}"` using Azure CLI file reference syntax
- Lets Azure CLI handle file encoding and transmission
- Prevents bash shell from interpreting special characters

**Files Modified:** `tasks/07-avd-registry-optimizations.sh`

### Changes Made

#### 1. Task Script (`tasks/07-avd-registry-optimizations.sh`)
- **Line 182:** Changed from `--scripts "$(cat "$PS_SCRIPT")"` to `--scripts "@${PS_SCRIPT}"`
- **Reason:** Use Azure CLI's native file reference syntax for proper encoding

#### 2. PowerShell Script (`powershell/avd-registry-optimizations.ps1`)
- **Lines 29-36:** Replaced box-drawing characters with ASCII equals
  - Changed: `╔════╗` to `============`
  - Changed: `║ message ║` to ` message`
  - Changed: `╚════╝` to `============`

- **Lines 38-56:** Replaced emoji with ASCII labels in 4 logging functions
  - Changed: `✓` to `[OK]`
  - Changed: `✗` to `[ERROR]`
  - Changed: `⚠` to `[WARN]`
  - Changed: `ℹ` to `[INFO]`

### Verification

**Test Results:**
- **Before Fix:** 0 registry settings applied, script parsed with errors
- **After Fix:** 8/8 registry optimization categories applied successfully

**Successful Output (2025-12-04 04:16:36 UTC):**
```
[OK] RDP timezone redirection enabled
[OK] FSLogix Defender exclusions added
[OK] Locale set to en-US
[OK] System Restore and VSS disabled
[OK] First logon animation disabled (black screen fix applied)
[OK] OOBE privacy screens disabled
[OK] Windows Hello for Business disabled
[OK] Default User profile configured
```

### Impact

- **Severity:** CRITICAL - Feature was completely non-functional
- **Scope:** Affects all users running Task 07 on Azure VMs
- **Breaking Changes:** None (improves functionality)
- **Migration:** Run Task 07 again with fixed script; previous failed runs had no effect

### Related Documentation

- **Detailed Fix Documentation:** See `TASK-07-FIX-DOCUMENTATION.md`
- **Task 07 Workflow:** See `tasks/07-avd-registry-optimizations.sh`
- **PowerShell Script:** See `powershell/avd-registry-optimizations.ps1`

---

## Version History

### Current: 2025-12-04 - v1.1.0 (Fixed)
- ✅ Task 07 registry optimizations functional
- ✅ Task 08 final cleanup available
- ✅ All 8 optimization categories applied successfully

### Previous: 2025-12-04 - v1.0.0 (Broken)
- ❌ Task 07 had Unicode character encoding issues
- ❌ Registry optimizations not applied to VMs
- ❌ Script appeared successful but had no effect

---

## Implementation Details

### Character Replacements

| Original | Replacement | Use Case |
|----------|-------------|----------|
| ✓ (U+2713) | [OK] | Success indicator |
| ✗ (U+2717) | [ERROR] | Error indicator |
| ⚠ (U+26A0) | [WARN] | Warning indicator |
| ℹ (U+2139) | [INFO] | Info indicator |
| ╔ ═ ╗ | = | Section header top |
| ║ | \| | Section header sides |
| ╚ ═ ╝ | = | Section header bottom |

### Azure CLI Best Practices

**DO:**
```bash
# Use file reference syntax - Azure CLI handles encoding
az vm run-command invoke --scripts "@${SCRIPT_PATH}"
```

**DON'T:**
```bash
# Don't embed script content - causes encoding issues
az vm run-command invoke --scripts "$(cat "$SCRIPT_PATH")"
```

---

## Testing Recommendations

### Future Changes to Remote Scripts

1. **Before deployment:**
   - Verify script uses only ASCII-safe characters
   - Test on local machine: `pwsh -File script.ps1`
   - Verify file encoding: `file -i script.ps1` (should be UTF-8)

2. **During deployment:**
   - Use `@filename` syntax in Azure CLI
   - Check stderr output for parser errors
   - Verify registry settings on VM post-execution

3. **Post-deployment:**
   - Run verification script to confirm settings
   - Check Application Event Log on VM for errors
   - Verify no "missing terminator" or "missing closing brace" errors

---

## Lessons Learned

1. **Unicode in Remote Scripts:** Avoid Unicode characters when scripts are transmitted to remote systems; use ASCII alternatives
2. **Azure CLI File Reference:** Always use `@filename` syntax instead of embedding script content
3. **Error Output Analysis:** Look at stderr in JSON output for clues about what went wrong
4. **Testing:** Even when script appears to run successfully, verify actual results

---

## Next Steps

- [ ] Verify Task 07 works with new VMs
- [ ] Document Azure CLI best practices in task template
- [ ] Review other task scripts for similar Unicode issues
- [ ] Add pre-flight script encoding validation to validators

---

## References

- **Azure CLI Run Command:** https://learn.microsoft.com/en-us/cli/azure/vm/run-command
- **PowerShell Character Encoding:** https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_character_encoding
- **UTF-8 Encoding Issues:** https://www.unicode.org/reports/tr36/

---

*Last Updated: 2025-12-04*
*Documented By: Claude Code Assistant*
