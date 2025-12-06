- Built-in throttle limit
- Cleaner syntax

**Cons:**
- Requires PowerShell 7+ (not default on Windows Server)
- May not be available in Azure run-command

```powershell
$downloads | ForEach-Object -Parallel {
    Invoke-WebRequest -Uri $_.Url -OutFile $_.Path
} -ThrottleLimit 5
```

### Recommendation

Use **Start-Job** for Azure VM operations:
- Guaranteed compatibility with Windows Server images
- Works in `az vm run-command` context
- Sufficient for golden image creation (3-5 downloads max)

## Best Practices

### 1. Engine-Level Parallelization

```yaml
# Good: Independent Azure resources
operations:
  - id: "create-vnet"
    parallel_group: 1
  - id: "create-storage"
    parallel_group: 1

# Bad: VM run-command operations
operations:
  - id: "install-chrome"
    parallel_group: 1  # Will fail!
  - id: "install-adobe"
    parallel_group: 1  # Azure conflict
```

### 2. Script-Level Parallelization

```powershell
# Good: Parallel downloads, sequential installs
Download-InParallel @(Chrome, Adobe, Office)
Install-Sequentially @(Chrome, Adobe, Office)

# Bad: Parallel MSI installations
Start-Job { Install Chrome.msi }  # Will fail!
Start-Job { Install Office.msi }  # Windows Installer conflict
```

### 3. Error Handling

Always handle job failures:

```powershell
$job = Start-Job -ScriptBlock { ... }
$result = Receive-Job -Job $job -Wait

if ($result.Success -eq $false) {
    Write-Host "[ERROR] Job failed: $($result.Error)"
    exit 1
}
Remove-Job -Job $job
```

## Performance Tuning

### Download Parallelism

- **2-3 files**: Saves 1-2 minutes
- **5+ files**: Saves 3-5 minutes
- **Diminishing returns**: Beyond 10 files, network becomes bottleneck

### ThrottleLimit Guidelines

- **Azure VMs**: 3-5 concurrent jobs (network bandwidth)
- **Local execution**: 5-10 concurrent jobs (depends on CPU/network)
- **Start-Job**: Manually limit with `while (Get-Job -State Running).Count -ge $limit)`

## Testing Parallel Operations

### Test Engine-Level Parallelization

```bash
./core/engine.sh run <module-with-parallel-groups>
```

Watch for:
- `Parallel Group: N operations` message
- Multiple PIDs launching simultaneously
- All operations completing before next group starts

### Test Script-Level Parallelization

```bash
./core/engine.sh run 05-golden-image golden-image-install-apps-parallel
```

Check logs for:
- `[INFO] Waiting for N download(s) to complete...`
- Multiple download jobs running
- Sequential installation after downloads

## Troubleshooting

### Azure Run-Command Conflict

**Error:** `Run command extension execution is in progress`

**Cause:** Another `az vm run-command` is still running on the VM

**Solution:**
- Wait for previous command to complete (~2-5 minutes)
- Don't use engine-level parallel groups for VM operations
- Use script-level parallelization instead

### MSI Installation Failures

**Error:** MSI installation hangs or fails

**Cause:** Another MSI installation is running

**Solution:**
- Install MSI files sequentially
- Use `Start-Process -Wait` to ensure one completes before next starts
- Check for background Windows Update MSI operations

### Job Management Issues

**Problem:** Jobs not cleaning up

**Solution:**
```powershell
# Always remove jobs after receiving results
Get-Job | Remove-Job -Force

# Use try/finally for cleanup
try {
    $job = Start-Job -ScriptBlock { ... }
    Receive-Job -Job $job -Wait
} finally {
    Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
}
```

## References

- [Azure Virtual Desktop Golden Image](https://learn.microsoft.com/en-us/azure/virtual-desktop/set-up-golden-image)
- [PowerShell Parallel Execution](https://codelucky.com/powershell-parallel-execution/)
- [PowerShell ForEach-Object -Parallel](https://devblogs.microsoft.com/powershell/powershell-foreach-object-parallel-feature/)
- [Install Multiple MSI Files](https://stackoverflow.com/questions/54008974/install-multiple-msi-files-consecutively)
- [PowerShell Jobs Performance](https://learn.microsoft.com/en-us/powershell/scripting/dev-cross-plat/performance/parallel-execution)

## Future Enhancements

### Potential Optimizations

1. **Office 365 with ODT**: Parallelize component downloads before installation
2. **VDOT + Configure Defaults**: Run simultaneously (both are registry/file operations)
3. **Resource creation**: Parallelize networking, storage, and Entra group creation

### Considerations

- Test thoroughly before deploying to production
- Monitor Azure quotas and throttling limits
- Balance parallelization vs system stability
