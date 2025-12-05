# Golden Image Creation Workflow

This document describes the complete workflow for creating an Azure Virtual Desktop golden image.

## Overview

The golden image creation process consists of 6 sequential tasks:

1. **Create VM** - Provision a temporary Windows 11 VM
2. **Validate VM** - Wait for VM to be fully booted and ready
3. **Configure VM** - Install software and apply optimizations
4. **Sysprep VM** - Prepare VM for image capture
5. **Capture Image** - Save VM as reusable image in gallery
6. **Cleanup** - Delete temporary resources

## Prerequisites

Before starting, ensure:

✓ Azure CLI is installed and authenticated (`az login`)
✓ You have Owner or Contributor permissions on subscription
✓ Resource group exists
✓ VNet with required subnet exists
✓ `config.env` is configured with your values
✓ Run `./config-validators/validate-prereqs.sh` to verify all prerequisites

## Workflow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│ START: Golden Image Creation Workflow                       │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ Task 01: Create Temporary VM                                │
│ └─ Creates Windows 11 VM with TrustedLaunch security       │
│ └─ Assigns public IP for RDP access                        │
│ └─ Duration: 5-10 minutes                                  │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ Task 02: Validate VM Readiness                              │
│ └─ Waits for Windows OS to boot                            │
│ └─ Verifies RDP port is accessible                         │
│ └─ Duration: 5-15 minutes                                  │
│ └─ Can be skipped if you monitor manually                  │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ Task 03: Configure VM                                       │
│ └─ Installs FSLogix                                         │
│ └─ Installs Chrome Enterprise                              │
│ └─ Installs Adobe Reader DC                                │
│ └─ Installs Microsoft Office 365                           │
│ └─ Runs AVD Optimization Tool (VDOT)                       │
│ └─ Applies registry optimizations                          │
│ └─ Duration: 30-60 minutes                                 │
│ └─ Executes non-interactively via Azure CLI                │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ Task 04: Sysprep VM                                         │
│ └─ Runs Windows Sysprep utility                            │
│ └─ Generalizes VM for image capture                        │
│ └─ VM shuts down automatically                             │
│ └─ Duration: 5-10 minutes                                  │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ Task 05: Capture Image                                      │
│ └─ Creates/verifies Azure Compute Gallery                  │
│ └─ Creates/verifies image definition                       │
│ └─ Captures VM as versioned image                          │
│ └─ Image available for reuse                               │
│ └─ Duration: 15-30 minutes                                 │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ Task 06: Cleanup Temporary Resources                        │
│ └─ Deletes temporary VM                                    │
│ └─ Deletes associated disks and NICs                       │
│ └─ Keeps image in gallery for reuse                        │
│ └─ Duration: 5-10 minutes                                  │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ END: Golden Image Ready for Deployment                      │
│ └─ Image available in Azure Compute Gallery                │
│ └─ Use in step 06-session-host-deployment to deploy VMs    │
└─────────────────────────────────────────────────────────────┘
```

## Execution Methods

### Method 1: Sequential Execution (Recommended)

Run tasks one-by-one in sequence, waiting for each to complete:

```bash
# Task 1: Create VM
./tasks/01-create-vm.sh

# Task 2: Validate VM (can take 5-15 minutes)
./tasks/02-validate-vm.sh

# Task 3: Configure VM (takes 30-60 minutes)
./tasks/03-configure-vm.sh

# Task 4: Sysprep VM (takes 5-10 minutes)
./tasks/04-sysprep-vm.sh

# Task 5: Capture Image (takes 15-30 minutes)
./tasks/05-capture-image.sh

# Task 6: Cleanup (takes 5-10 minutes)
./tasks/06-cleanup.sh
```

**Total time**: Approximately 90-150 minutes (1.5-2.5 hours)

### Method 2: Chained Execution

Run all tasks in sequence with single command:

```bash
./tasks/01-create-vm.sh && \
./tasks/02-validate-vm.sh && \
./tasks/03-configure-vm.sh && \
./tasks/04-sysprep-vm.sh && \
./tasks/05-capture-image.sh && \
./tasks/06-cleanup.sh
```

**Pros**: Fully automated, no manual intervention needed
**Cons**: If any task fails, you must fix and re-run from that point

### Method 3: Background Execution

Run full workflow in background:

```bash
(./tasks/01-create-vm.sh && \
./tasks/02-validate-vm.sh && \
./tasks/03-configure-vm.sh && \
./tasks/04-sysprep-vm.sh && \
./tasks/05-capture-image.sh && \
./tasks/06-cleanup.sh) > logs/golden-image-$(date +%Y%m%d_%H%M%S).log 2>&1 &

# Monitor progress
tail -f logs/golden-image-*.log
```

## Step-by-Step Walkthrough

### Before You Start

1. **Validate prerequisites**:
   ```bash
   ./config-validators/validate-prereqs.sh
   ```
   Fix any issues before proceeding.

2. **Review and update `config.env`**:
   ```bash
   # Set credentials securely (do not hardcode in file!)
   export ADMIN_PASSWORD="YourSecurePassword123!"

   # Optional: Override any settings
   export TEMP_VM_NAME="my-golden-vm"
   export VM_SIZE="Standard_D4s_v6"
   ```

### Task 1: Create VM

```bash
./tasks/01-create-vm.sh
```

**What happens**:
- Azure CLI creates a Windows 11 VM with TrustedLaunch security
- VM is provisioned in your specified VNet/subnet
- Public IP is assigned for RDP access
- Logs are saved to `artifacts/01-create-vm_*.log`
- VM details are saved to `artifacts/01-create-vm_vm-details.txt`

**Success criteria**:
- VM appears in Azure Portal
- Public IP is assigned
- Log shows "VM is ready for configuration"

**If it fails**:
- Check logs: `tail -f artifacts/01-create-vm_*.log`
- Verify resource group and network settings in `config.env`
- Ensure you have sufficient quota in subscription
- Try running task again (idempotent - safe to re-run)

### Task 2: Validate VM

```bash
./tasks/02-validate-vm.sh
```

**What happens**:
- Waits for VM to reach "running" state (up to 30 minutes)
- Checks that Windows OS is provisioned and ready
- Tests RDP port accessibility
- Logs progress to `artifacts/02-validate-vm_*.log`

**Success criteria**:
- VM power state shows "VM running"
- OS state shows "OS provisioned and ready for use"
- RDP port 3389 is responding

**Expected duration**: 5-15 minutes

**If it fails**:
- This is usually timing - network provisioning can take time
- Review logs to see current VM state
- Run the task again (it's idempotent)
- If VM never reaches ready state, check Azure Portal for issues

**Skip option**: If you're monitoring VM status manually, you can skip this task and proceed directly to task 3 once you see VM is running and RDP is accessible.

### Task 3: Configure VM

```bash
./tasks/03-configure-vm.sh
```

**What happens**:
- Executes configuration PowerShell script on running VM
- Installs:
  - FSLogix (for profile management in pooled deployments)
  - Google Chrome Enterprise
  - Adobe Acrobat Reader DC
  - Microsoft Office 365
  - Virtual Desktop Optimization Tool (VDOT)
- Configures:
  - Registry settings for AVD
  - Default user profile
  - Security settings (BitLocker disabled for sysprep)
  - Windows Updates

**Expected duration**: 30-60 minutes

**Success criteria**:
- Configuration execution completes (check exit code in log)
- No critical errors in output
- All software installed successfully

**Notes**:
- This is the longest task
- Execution is non-interactive (no manual steps required)
- Output is captured in `artifacts/03-configure-vm_execution-output.json`
- Review logs if there are any warning messages

**If it fails**:
- Check logs for specific error: `cat artifacts/03-configure-vm_*.log | grep -i error`
- Common issues:
  - Network download failures (temporary - retry)
  - Disk space issues (VM may be too small)
  - License/permission issues (check Azure subscription)
- Options:
  - Fix and re-run (VM is still running)
  - Start over with larger VM (delete this VM, increase VM_SIZE in config.env)

### Task 4: Sysprep VM

```bash
./tasks/04-sysprep-vm.sh
```

**What happens**:
- Issues sysprep command to VM via Azure CLI
- VM generalizes itself (removes unique identifiers)
- VM shuts down automatically (expected behavior)
- Script waits for shutdown completion
- Logs to `artifacts/04-sysprep-vm_*.log`

**Expected duration**: 5-10 minutes

**Success criteria**:
- Sysprep command completes without errors
- VM transitions to "deallocated" or "stopped" state
- Log shows "VM has been sysprepped and is deallocated"

**Important notes**:
- VM shutting down is normal and expected
- Do NOT manually power on the VM after sysprep
- VM must be deallocated for next step

**If it fails**:
- Check if VM reached deallocated state: `az vm get-instance-view -g RG -n vm-name | jq '.instanceView.statuses'`
- If VM is stuck:
  - Manually deallocate: `az vm deallocate -g RG -n vm-name --no-wait`
  - Wait 5-10 minutes and proceed to task 5

### Task 5: Capture Image

```bash
./tasks/05-capture-image.sh
```

**What happens**:
- Verifies VM is deallocated
- Creates Azure Compute Gallery (if not exists)
- Creates image definition (if not exists)
- Captures VM as image version with timestamp (e.g., 2025.1204.0530)
- Image is immediately available for deployment
- Logs to `artifacts/05-capture-image_*.log`
- Image details saved to `artifacts/05-capture-image_image-details.txt`

**Expected duration**: 15-30 minutes

**Success criteria**:
- Gallery "IMAGE_GALLERY_NAME" appears in Azure Portal
- Image definition "IMAGE_DEFINITION_NAME" is created
- Image version with timestamp is created
- Log shows image successfully captured

**Image location**:
After capture, your image is available at:
```
/subscriptions/{subscription}/resourceGroups/{rg}/providers/Microsoft.Compute/galleries/{gallery-name}/images/{image-definition-name}/versions/{timestamp}
```

**If it fails**:
- Check logs for specific error
- Verify VM is deallocated before retry
- Common issues:
  - Gallery name not unique globally (rename in config.env)
  - Insufficient permissions for Compute Gallery
  - VM not properly generalized (re-run sysprep)

### Task 6: Cleanup

```bash
./tasks/06-cleanup.sh
```

**What happens**:
- Deletes temporary VM (safe - image is already captured)
- Deletes associated disks and NICs
- Deletes unassociated public IPs
- Keeps Azure Compute Gallery intact
- Creates summary report
- Logs to `artifacts/06-cleanup_*.log`

**Expected duration**: 5-10 minutes

**Success criteria**:
- VM no longer appears in Azure Portal
- Associated disks are removed
- Network interfaces are removed
- Azure Compute Gallery still exists with your image

**If it fails**:
- Check logs for which resource failed to delete
- Some resources may have references preventing deletion
- Manually delete via Azure Portal if needed
- Image in gallery is safe (will not be deleted)

## Troubleshooting

### Common Issues

#### "VM not found"
- **Cause**: VM was never created (task 1 failed)
- **Solution**: Check task 1 logs, fix issues, re-run task 1

#### "VM not transitioning to running state"
- **Cause**: Provisioning taking longer than expected
- **Solution**: Wait longer, run task 2 again, check Azure Portal for issues

#### "RDP port not responding"
- **Cause**: Networking configuration issue
- **Solution**: Check NSG rules, VNet configuration, try different approach

#### "Configuration script failures"
- **Cause**: Download failures, disk space, permissions
- **Solution**: Check logs, retry task 3, ensure VM has internet access

#### "Sysprep hanging"
- **Cause**: Configuration script not fully complete
- **Solution**: Wait longer, check Task 3 logs, manually deallocate if needed

#### "Image capture stuck in creating state"
- **Cause**: Large image, network issue
- **Solution**: Check logs, verify VM is properly generalized, wait longer

### Recovery Procedures

#### Resume from Task Failure

If any task fails:

1. **Review the failure**:
   ```bash
   tail -n 50 artifacts/0X-task-name_*.log
   ```

2. **Fix the issue** (varies by error)

3. **Re-run the task**:
   ```bash
   ./tasks/0X-task-name.sh
   ```

4. **If task still fails**:
   - Check Task Reference documentation
   - Review command reference for specific Azure CLI commands
   - Check Azure Portal for resource state

#### Restart from Specific Task

You can restart from any task:

```bash
# Start from Task 3 if Tasks 1-2 already completed
./tasks/03-configure-vm.sh && \
./tasks/04-sysprep-vm.sh && \
./tasks/05-capture-image.sh && \
./tasks/06-cleanup.sh
```

**Important**: Don't skip tasks - each task depends on previous state.

#### Complete Restart

To start from scratch:

1. Clean up failed resources manually in Azure Portal
2. Verify `config.env` settings
3. Run `./config-validators/validate-prereqs.sh`
4. Start from task 1: `./tasks/01-create-vm.sh`

## Next Steps

After golden image is successfully created:

1. **Verify image in gallery**:
   ```bash
   az sig image-version list \
       --resource-group "$RESOURCE_GROUP_NAME" \
       --gallery-name "$IMAGE_GALLERY_NAME" \
       --gallery-image-definition "$IMAGE_DEFINITION_NAME" \
       --output table
   ```

2. **Deploy session hosts**:
   - Use the image version ID in step 06-Session-Host-Deployment
   - Multiple session hosts can be deployed from same image

3. **Optional: Replicate image to other regions**:
   - See COMMANDS.md for replication commands
   - Speeds up deployment in other regions

4. **Optional: Delete old image versions**:
   - See COMMANDS.md for cleanup commands
   - Reduces storage costs

5. **Document deployment**:
   - Save image version ID
   - Record creation date and software versions
   - Note any customizations made

## Support and Documentation

- **Command Reference**: See `COMMANDS.md` for individual Azure CLI commands
- **Task Details**: See `TASK-REFERENCE.md` for detailed task documentation
- **Troubleshooting**: See `TROUBLESHOOTING.md` for specific errors
- **Architecture**: See `ARCHITECTURE.md` for design decisions

## Time Estimates

| Task | Minimum | Typical | Maximum | Notes |
|------|---------|---------|---------|-------|
| 01-create-vm | 3 min | 7 min | 10 min | VM provisioning |
| 02-validate-vm | 2 min | 10 min | 30 min | Waiting for OS boot |
| 03-configure-vm | 20 min | 45 min | 60 min | Software install + Windows Updates |
| 04-sysprep-vm | 3 min | 8 min | 15 min | Sysprep + shutdown |
| 05-capture-image | 10 min | 20 min | 30 min | Image capture + replication |
| 06-cleanup | 2 min | 5 min | 10 min | Resource deletion |
| **TOTAL** | **~40 min** | **~95 min** | **~155 min** | Full workflow |

**Total elapsed time**: Plan for 1.5-2.5 hours
