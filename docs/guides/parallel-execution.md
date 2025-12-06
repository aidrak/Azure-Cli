# Parallel Execution and Optimization

This document explains the parallel execution capabilities of the deployment engine and optimizations for Azure Virtual Desktop golden image creation.

## Overview

The engine supports two levels of parallelization:
1. **Engine-level parallel groups** - For operations that don't use `az vm run-command`
2. **Script-level parallel downloads** - For optimizing software installation within VMs

## Engine-Level Parallel Groups

### How It Works

Operations in `module.yaml` can specify a `parallel_group` number. Operations with the same group number execute simultaneously:

```yaml
operations:
  - id: "create-vnet"
    parallel_group: 1

  - id: "create-storage"
    parallel_group: 1

  - id: "create-nsg"
    parallel_group: 1
```

The engine:
1. Groups operations by `parallel_group` number
2. Launches all operations in a group as background processes
3. Waits for all to complete before moving to the next group
4. Operations without `parallel_group` run sequentially

### When to Use

**Good use cases:**
- Creating multiple Azure resources (VNets, Storage Accounts, NSGs)
- Running independent validation checks
- Local file operations
- Any operations that don't use `az vm run-command`

**Bad use cases:**
- VM run-command operations (Azure limitation - see below)
- Operations with dependencies on each other
- MSI installations (Windows Installer limitation - see below)

### Implementation

See `core/engine.sh`:
- `execute_parallel_group()` - Launches operations in background
- `execute_module()` - Groups and executes parallel operations

## Azure VM Run-Command Limitation

### The Problem

Azure does NOT support concurrent `az vm run-command` executions on the same VM:

```
ERROR: (Conflict) Run command extension execution is in progress.
Please wait for completion before invoking a run command.
```

This means you cannot run multiple VM operations in parallel at the engine level.

### The Solution: Script-Level Parallelization

Instead of parallel engine operations, use **parallel downloads within a single PowerShell script**:

```powershell
# Download installers in parallel using Start-Job
$jobs = @()
foreach ($download in $downloads) {
    $job = Start-Job -ScriptBlock {
        param($url, $outFile)
        Invoke-WebRequest -Uri $url -OutFile $outFile
    } -ArgumentList $download.Url, $download.OutFile
    $jobs += $job
}

# Wait for all downloads
$jobs | Receive-Job -Wait | Remove-Job

# Install sequentially
Install-Chrome
Install-Adobe
```

## Windows Installer (MSI) Limitation

### The Problem

Windows Installer uses a **system-wide mutex lock** that prevents multiple MSI installations from running simultaneously.

**Source:** [Stack Overflow - Install Multiple MSI files](https://stackoverflow.com/questions/54008974/install-multiple-msi-files-consecutively)

### The Workaround

1. **Parallelize downloads** - Download all MSI files concurrently
2. **Sequential installation** - Install MSI files one at a time
3. **Mixed installation** - EXE installers *may* run parallel with MSI (test carefully)

### Example: Chrome (MSI) + Adobe (EXE)

```powershell
# Phase 1: Parallel downloads (saves time)
Start-Job { Download Chrome.msi }
Start-Job { Download AdobeReader.exe }
Wait for all downloads

# Phase 2: Sequential installation (required)
Install Chrome.msi (MSI - uses Windows Installer)
Install AdobeReader.exe (EXE - may contain MSI internally)
```

## Golden Image Optimization Strategy

### Current Implementation

The `golden-image-install-apps-parallel` operation:

1. **Downloads in parallel** (saves ~2 minutes):
   - Chrome Enterprise MSI
   - Adobe Reader DC EXE

2. **Installs sequentially** (required):
   - Chrome (msiexec)
   - Adobe (silent EXE)

### File Location

- Operation: `capabilities/compute/operations/golden-image-install-apps-parallel.yaml`
- PowerShell: Embedded in YAML (extracted to artifacts/scripts/)

### Performance Impact

| Approach | Download Time | Install Time | Total |
|----------|---------------|--------------|-------|
| Sequential (old) | 2+3 = 5 min | 3+2 = 5 min | 10 min |
| Optimized (new) | ~3 min (parallel) | 3+2 = 5 min | ~8 min |
| **Savings** | **~2 minutes** | - | **~2 minutes** |

## PowerShell Parallel Techniques

### Option 1: Start-Job (PowerShell 5.1+)

**Pros:**
- Compatible with Windows Server 2019/2022
- Works in Azure VM run-command
- Good for I/O-bound tasks (downloads)

**Cons:**
- Higher overhead (separate processes)
- No throttle limit parameter
- Manual job management required

```powershell
$job = Start-Job -ScriptBlock { Download-File }
$result = Receive-Job -Job $job -Wait
Remove-Job -Job $job
```

### Option 2: ForEach-Object -Parallel (PowerShell 7+)

**Pros:**
- Lower overhead (runspaces vs processes)

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
