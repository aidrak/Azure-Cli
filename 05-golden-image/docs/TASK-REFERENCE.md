# Task Reference Guide

Detailed reference documentation for each task in the golden image creation workflow.

## Task 01: Create VM

**File**: `tasks/01-create-vm.sh`

**Purpose**: Create a temporary Windows 11 VM with TrustedLaunch security enabled.

### Prerequisites
- Azure CLI installed and authenticated
- Resource group exists
- VNet with required subnet exists
- `config.env` properly configured

### Inputs (from config.env)
| Variable | Purpose | Example |
|----------|---------|---------|
| RESOURCE_GROUP_NAME | Target resource group | RG-Azure-VDI-01 |
| TEMP_VM_NAME | VM name | gm-temp-vm |
| VM_SIZE | VM size/SKU | Standard_D4s_v6 |
| WINDOWS_IMAGE_SKU | Windows image | MicrosoftWindowsDesktop:windows-11:win11-25h2-avd:latest |
| LOCATION | Azure region | centralus |
| VNET_NAME | Virtual network | avd-vnet |
| SUBNET_NAME | Subnet | avd-subnet |
| ADMIN_USERNAME | Admin user | localadmin |
| ADMIN_PASSWORD | Admin password | (set via env var, not hardcoded) |
| TAGS | Resource tags | source=golden-image environment=production |

### Outputs
- **Azure Resource**: Windows 11 VM created and running
- **Log File**: `artifacts/01-create-vm_TIMESTAMP.log`
- **Details File**: `artifacts/01-create-vm_vm-details.txt` (contains IP addresses and VM ID)

### How It Works
1. Validates all prerequisites (Azure CLI, authentication, resource existence)
2. Checks if VM already exists (idempotent)
3. Creates VM using Azure CLI with:
   - TrustedLaunch security
   - Secure Boot enabled
   - vTPM enabled
   - Standard public IP
4. Retrieves and logs VM details (public IP, private IP, VM ID)

### Expected Duration
5-10 minutes

### Success Indicators
- VM appears in Azure Portal
- Public IP is assigned
- Log shows "VM is ready for configuration"

### Common Issues
| Issue | Cause | Solution |
|-------|-------|----------|
| Resource group not found | RESOURCE_GROUP_NAME incorrect | Check config.env, verify RG exists |
| VNet not found | VNET_NAME incorrect or RG wrong | Check config.env, verify VNet in correct RG |
| Subnet not found | SUBNET_NAME incorrect | Check config.env, verify subnet in correct VNet |
| Insufficient quota | Subscription doesn't have enough compute quota | Increase quota in subscription, use smaller VM size |
| Image not found | WINDOWS_IMAGE_SKU doesn't exist | Check image availability in region |

### Idempotency
✓ **Yes** - If VM already exists, task skips creation and returns VM details

### Next Task
Run Task 02: `./tasks/02-validate-vm.sh`

---

## Task 02: Validate VM

**File**: `tasks/02-validate-vm.sh`

**Purpose**: Wait for VM to be fully provisioned and ready for configuration.

### Prerequisites
- Task 01 completed successfully
- VM is running

### Inputs (from config.env)
| Variable | Purpose |
|----------|---------|
| RESOURCE_GROUP_NAME | Resource group containing VM |
| TEMP_VM_NAME | VM name to validate |

### Outputs
- **Status**: Confirms VM is running and ready
- **Log File**: `artifacts/02-validate-vm_TIMESTAMP.log`

### What It Checks
1. **Power State**: Waits for "VM running" (up to 30 minutes)
2. **OS State**: Checks "OS provisioned and ready for use"
3. **RDP Ready**: Tests port 3389 accessibility (up to 10 minutes)

### How It Works
1. Validates VM exists
2. Polls VM power state every 5 seconds until "VM running"
3. Checks OS provisioning state
4. Tests RDP port connectivity
5. Reports success when all checks pass

### Expected Duration
5-15 minutes (varies based on Azure infrastructure)

### Success Indicators
- Power state shows "VM running"
- OS state shows "OS provisioned and ready"
- RDP port 3389 responds to connection attempts
- Log shows "VM is ready for configuration"

### Common Issues
| Issue | Cause | Solution |
|-------|-------|----------|
| Timeout waiting for running state | VM taking longer to provision | Run task again (idempotent) |
| RDP not responding | NSG rules blocking, network issues | Check NSG rules, verify connectivity |
| OS not provisioned | Windows taking longer to boot | Wait longer, run task again |

### Idempotency
✓ **Yes** - Task only validates current state, doesn't modify anything

### Skip Option
You can skip this task if:
- You're monitoring VM status manually in Azure Portal
- You see "VM running" in Portal and can RDP to it
- You want to proceed immediately

Simply run Task 03 next.

### Next Task
Run Task 03: `./tasks/03-configure-vm.sh`

---

## Task 03: Configure VM

**File**: `tasks/03-configure-vm.sh`

**Purpose**: Install software and apply optimizations to VM.

### Prerequisites
- Task 02 completed (VM is running and ready)
- VM has internet connectivity
- Sufficient disk space (30+ GB free)

### Inputs (from config.env)
| Variable | Purpose |
|----------|---------|
| RESOURCE_GROUP_NAME | Resource group containing VM |
| TEMP_VM_NAME | VM to configure |
| FSLOGIX_VERSION | FSLogix version to install |
| VDOT_VERSION | AVD Optimization Tool version |

### Outputs
- **Changes**: VM with all software and optimizations installed
- **Log File**: `artifacts/03-configure-vm_TIMESTAMP.log`
- **Output File**: `artifacts/03-configure-vm_execution-output.json` (command execution output)

### What It Installs
1. **FSLogix** - Profile and container management for pooled deployments
2. **Google Chrome Enterprise** - Web browser
3. **Adobe Reader DC** - PDF viewer
4. **Microsoft Office 365** - Productivity suite
5. **Windows Updates** - Latest security patches
6. **VDOT (Virtual Desktop Optimization Tool)** - Performance optimizations
   - Disables unnecessary services
   - Removes bloatware
   - Optimizes group policies
   - Configures registry for AVD

### Configuration Changes
- **Registry optimizations**: AVD-specific settings
- **Default user profile**: Pre-configured for all users
- **BitLocker**: Disabled (required for sysprep)
- **System Restore**: Disabled
- **Windows Hello**: Disabled
- **Timezone redirection**: Enabled
- **Printer redirection**: Configured
- **FSLogix exclusions**: Defender exclusions for performance

### How It Works
1. Validates VM exists and is running
2. Sends PowerShell configuration script via `az vm run-command`
3. Script runs inside VM non-interactively
4. Captures output and saves to JSON file
5. Reports success/failure

### Expected Duration
30-60 minutes
- Windows Updates: 15-30 minutes
- FSLogix installation: 5 minutes
- Other software: 10 minutes
- VDOT optimization: 10-15 minutes

### Success Indicators
- Exit code 0 in execution output
- No critical errors in log
- Configuration output shows completed sections

### Common Issues
| Issue | Cause | Solution |
|-------|-------|----------|
| Download failures | Network connectivity | Temporary - retry task |
| Disk space errors | VM disk too small | Use larger VM size (Standard_D4s_v6 or larger) |
| Long execution time | Windows Updates downloading | Normal - wait for completion |
| Partial completion | Task timeout | Check logs, may need manual intervention |
| Software installation failures | Missing dependencies | Review logs, ensure internet access |

### Troubleshooting
1. **Check logs**: `cat artifacts/03-configure-vm_*.log`
2. **Check execution output**: `cat artifacts/03-configure-vm_execution-output.json | jq`
3. **Verify VM internet access**: Ping external sites from VM
4. **Retry**: Task is safe to re-run (idempotent where possible)

### Idempotency
⚠ **Partial** - Most operations are idempotent, but Windows Updates may re-apply

### Next Task
Run Task 04: `./tasks/04-sysprep-vm.sh`

---

## Task 04: Sysprep VM

**File**: `tasks/04-sysprep-vm.sh`

**Purpose**: Prepare VM for image capture by generalizing it with Windows Sysprep.

### Prerequisites
- Task 03 completed
- VM is configured and running

### Inputs (from config.env)
| Variable | Purpose |
|----------|---------|
| RESOURCE_GROUP_NAME | Resource group containing VM |
| TEMP_VM_NAME | VM to sysprep |

### Outputs
- **Changes**: VM generalized, unique identifiers removed
- **State**: VM deallocated (shut down after sysprep)
- **Log File**: `artifacts/04-sysprep-vm_TIMESTAMP.log`

### What Sysprep Does
- Removes Windows activation IDs
- Removes security identifiers (SIDs)
- Clears event logs
- Removes hardware-specific settings
- Prepares for image distribution

### How It Works
1. Validates VM exists
2. Issues sysprep command via Azure CLI
3. Waits for VM to deallocate (up to 10 minutes)
4. Verifies deallocated state
5. Manually deallocates if auto-shutdown fails

### Expected Duration
5-10 minutes

### Important Notes
- VM will shut down automatically (expected behavior)
- **DO NOT** manually power on VM after sysprep
- VM must be deallocated before image capture
- Sysprep is point of no return for VM

### Success Indicators
- Sysprep command completes without errors
- VM transitions to "deallocated" or "stopped" state
- Log shows "VM has been sysprepped and is deallocated"

### Common Issues
| Issue | Cause | Solution |
|-------|-------|----------|
| Sysprep timeout | VM not shutting down | Wait, check logs, manual deallocate if needed |
| VM stuck running | Sysprep failed | Check event logs in portal, consider restart |
| Deallocate timeout | Background process hanging | Manually deallocate via portal or CLI |

### Troubleshooting
1. **Check VM state**:
   ```bash
   az vm get-instance-view -g $RG -n $VM | jq '.instanceView.statuses'
   ```

2. **Manually deallocate**:
   ```bash
   az vm deallocate -g $RG -n $VM --no-wait
   ```

3. **Check event logs** (via Azure Portal):
   - System events for sysprep errors
   - Application events for configuration issues

### Idempotency
❌ **No** - Task modifies VM state. Don't re-run unless VM failed to deallocate.

### Next Task
Run Task 05: `./tasks/05-capture-image.sh`

---

## Task 05: Capture Image

**File**: `tasks/05-capture-image.sh`

**Purpose**: Save the sysprepped VM as a reusable image in Azure Compute Gallery.

### Prerequisites
- Task 04 completed
- VM is deallocated and generalized

### Inputs (from config.env)
| Variable | Purpose | Example |
|----------|---------|---------|
| RESOURCE_GROUP_NAME | Resource group | RG-Azure-VDI-01 |
| TEMP_VM_NAME | VM to capture | gm-temp-vm |
| IMAGE_GALLERY_NAME | Gallery name | avd_gallery |
| IMAGE_DEFINITION_NAME | Definition name | windows11-golden-image |
| IMAGE_PUBLISHER | Publisher name | YourCompany |
| IMAGE_OFFER | Offer name | AVD |
| IMAGE_SKU_NAME | SKU name | Win11-Pooled-FSLogix |
| LOCATION | Region | centralus |

### Outputs
- **Azure Resources**:
  - Shared Image Gallery created (if not exists)
  - Image definition created (if not exists)
  - Image version created with timestamp
- **Log File**: `artifacts/05-capture-image_TIMESTAMP.log`
- **Details File**: `artifacts/05-capture-image_image-details.txt`

### Image Versioning
Image versions use timestamp format: `YYYY.MMDD.HHMM`

Example:
- `2025.1204.0530` = December 4, 2025, 05:30 AM
- `2025.1204.1430` = December 4, 2025, 02:30 PM

### Gallery Structure
```
Shared Image Gallery
└── avd_gallery
    └── windows11-golden-image (Image Definition)
        ├── 2025.1204.0530 (Image Version)
        ├── 2025.1203.1400 (Image Version)
        └── 2025.1202.0900 (Image Version)
```

### How It Works
1. Validates VM is deallocated and generalized
2. Creates Shared Image Gallery (if needed)
3. Creates image definition (if needed)
4. Marks VM as generalized
5. Creates image version from VM
6. Retrieves and logs image IDs
7. Saves image details to file

### Expected Duration
15-30 minutes

### Success Indicators
- Gallery exists in Azure Portal
- Image definition is created
- Image version appears in gallery
- Log shows "Image successfully captured"

### Image IDs
After capture, you get:
- **Gallery ID**: `/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.Compute/galleries/{name}`
- **Image Definition ID**: `.../galleries/{name}/images/{definition}`
- **Image Version ID**: `.../images/{definition}/versions/{version}`

Use Image Version ID when deploying session hosts.

### Common Issues
| Issue | Cause | Solution |
|-------|-------|----------|
| Gallery name taken | Name already exists globally | Use unique name in config.env |
| Insufficient permissions | User doesn't have Compute Gallery permissions | Verify RBAC roles |
| VM not generalized | Sysprep didn't complete | Verify task 04 completed |
| Image creation timeout | Large image size | Wait longer, check storage |

### Idempotency
⚠ **Partial** - Gallery/definition idempotent, but image version always created fresh

### Next Task
Run Task 06: `./tasks/06-cleanup.sh`

---

## Task 06: Cleanup

**File**: `tasks/06-cleanup.sh`

**Purpose**: Delete temporary resources after image is captured.

### Prerequisites
- Task 05 completed
- Image successfully captured in gallery

### Inputs (from config.env)
| Variable | Purpose |
|----------|---------|
| RESOURCE_GROUP_NAME | Resource group |
| TEMP_VM_NAME | Temporary VM to delete |

### Outputs
- **Deletions**: Temporary VM and associated resources removed
- **Kept**: Azure Compute Gallery and images remain
- **Log File**: `artifacts/06-cleanup_TIMESTAMP.log`
- **Summary**: `artifacts/06-cleanup_summary.txt`

### What Gets Deleted
- Temporary VM
- VM operating system disk
- VM data disks
- Network interfaces
- Public IP addresses
- Any other resources tagged with VM name

### What Does NOT Get Deleted
- ✓ Azure Compute Gallery (and all images)
- ✓ Image definition
- ✓ Image versions
- ✓ VNet and subnets
- ✓ Resource group

### How It Works
1. Validates image was captured in gallery
2. Deletes VM (idempotent - skips if doesn't exist)
3. Deletes associated disks
4. Deletes network interfaces
5. Deletes public IPs
6. Generates cleanup summary

### Expected Duration
5-10 minutes

### Success Indicators
- VM no longer appears in Azure Portal
- Associated disks are removed
- Cleanup summary is created
- Gallery still contains your image

### Common Issues
| Issue | Cause | Solution |
|-------|-------|----------|
| Disk deletion fails | Disk referenced elsewhere | Check for other resources, manual deletion |
| NIC deletion fails | NIC still attached | Wait longer, check attachment status |
| Cleanup timeout | Resource deletion taking long | Continue with next step, cleanup happens in background |

### Idempotency
✓ **Yes** - Safe to run multiple times. Skips resources that don't exist.

### Cleanup Summary
Review the summary file to confirm what was deleted:

```bash
cat artifacts/06-cleanup_summary.txt
```

Contains:
- Cleanup timestamp
- Resource group and VM name
- Gallery information
- Next steps

### Next Steps
Your golden image is now ready for deployment!

1. **Verify image**:
   ```bash
   source config.env
   az sig image-version list \
       -g "$RESOURCE_GROUP_NAME" \
       -r "$IMAGE_GALLERY_NAME" \
       -i "$IMAGE_DEFINITION_NAME"
   ```

2. **Deploy session hosts**:
   - Use Step 06: Session Host Deployment
   - Reference the image version ID from image details file

3. **Optional: Replicate to other regions**:
   - See COMMANDS.md for replication commands

---

## Common Task Parameters

### Configuration File (config.env)
All tasks read from `config.env`:
- Required variables defined
- Sourced from centralized config
- Environment variables can override

### Logging
All tasks create logs in `artifacts/`:
- Timestamped log files
- Human-readable format
- Searchable for errors/warnings
- Appended (not overwritten)

### Exit Codes
- **0**: Success
- **1**: Error/failure

### Log Levels
- ✓ (Green): Success
- ✗ (Red): Error
- ⚠ (Yellow): Warning
- ℹ (Yellow): Information

---

## Task Dependencies

```
Task 01 (Create VM)
    ↓
Task 02 (Validate VM) [Optional: manual validation]
    ↓
Task 03 (Configure VM)
    ↓
Task 04 (Sysprep VM)
    ↓
Task 05 (Capture Image)
    ↓
Task 06 (Cleanup)
```

**Critical path**: Tasks must run in order
**Flexible**: Task 02 can be skipped with manual monitoring
**Resumable**: Can resume from any failed task after fixing
