# VM Cleanup and User Migration

**Purpose:** Migrate 400 users from individual VMs to pooled AVD environment and cleanup old resources

**Prerequisites:**
- New AVD environment tested and validated
- All tests from Guide 10 passed
- Communication sent to users
- Backup plan in place

---

## Migration Strategy

### Phased Approach (Recommended)

**Phase 1: Pilot (10-20 users)**
- Duration: 1-2 days
- Monitor closely for issues
- Collect feedback

**Phase 2: Batch Migration (50 users per batch)**
- Duration: 5-7 days
- Continue monitoring
- Address any issues

**Phase 3: Remaining Users**
- Complete migration
- Final cleanup

---

## Pre-Migration Checklist

```
Before starting migration:
□ All validation tests passed
□ Users notified of migration schedule
□ Windows App download instructions sent
□ Support team briefed
□ Rollback plan documented
□ Off-hours migration scheduled (if possible)
□ Backup critical data from old VMs
```

---

## Phase 1: Pilot Migration

### Step 1: Select Pilot Users

```powershell
# Identify pilot user group (10-20 users)
$pilotUsers = @(
    "user1@contoso.com",
    "user2@contoso.com"
    # ... 10-20 users total
)

# Verify users are in AVD-Users group
Connect-MgGraph -Scopes "Group.ReadWrite.All"
$avdGroup = Get-MgGroup -Filter "displayName eq 'AVD-Users'"

foreach ($user in $pilotUsers) {
    $userObj = Get-MgUser -Filter "userPrincipalName eq '$user'"
    $membership = Get-MgGroupMember -GroupId $avdGroup.Id | Where-Object { $_.Id -eq $userObj.Id }
    
    if (-not $membership) {
        New-MgGroupMember -GroupId $avdGroup.Id -DirectoryObjectId $userObj.Id
        Write-Host "✓ Added $user to AVD-Users" -ForegroundColor Green
    }
}
```

### Step 2: Communicate with Pilot Users

**Email template:**
```
Subject: New Virtual Desktop Environment - Action Required

Hello,

We're migrating to a new virtual desktop environment. Here's what you need to do:

1. Download Windows App: https://aka.ms/AVDClient
2. Install and sign in with your work credentials
3. Your desktop will appear - launch it
4. All your files will be there (profile roaming)

Timeline: [Date/Time]
Support: [Contact info]

Your old desktop will remain available for 1 week as backup.
```

### Step 3: Monitor Pilot

```powershell
# Check pilot user sessions
$hostPool = "Pool-Pooled-Prod"
$sessions = Get-AzWvdUserSession -ResourceGroupName "RG-Azure-VDI-01" -HostPoolName $hostPool

Write-Host "=== PILOT USER SESSIONS ===" -ForegroundColor Cyan
foreach ($user in $pilotUsers) {
    $userSession = $sessions | Where-Object { $_.UserPrincipalName -eq $user }
    if ($userSession) {
        Write-Host "✓ $user - Active session on $($userSession.SessionHostName)" -ForegroundColor Green
    } else {
        Write-Host "⚠ $user - No active session" -ForegroundColor Yellow
    }
}

# Check for issues
Write-Host "`nCheck for common issues:" -ForegroundColor Cyan
Write-Host "  - Users can't see desktop → RBAC issue" -ForegroundColor Gray
Write-Host "  - Credential prompt → SSO not working" -ForegroundColor Gray
Write-Host "  - Profile not loading → FSLogix/RBAC issue" -ForegroundColor Gray
```

### Step 4: Collect Feedback

**Wait 24-48 hours**

Questions to ask pilot users:
- Desktop appeared without issues? (SSO working?)
- Login time acceptable? (< 30 seconds)
- All applications work?
- Files/settings preserved?
- Performance acceptable?

**If major issues:** Pause migration, resolve issues, retest

**If minor issues:** Document and fix, proceed cautiously

---

## Phase 2: Batch Migration

### Batch Migration Script

```powershell
# Define batches (50 users each)
$batch1 = @("user21@contoso.com", "user22@contoso.com") # ... 50 users
$batch2 = @("user71@contoso.com", "user72@contoso.com") # ... 50 users
# ... continue

$currentBatch = $batch1  # Change for each batch

Write-Host "=== BATCH MIGRATION: $($currentBatch.Count) users ===" -ForegroundColor Cyan

# Add users to AVD-Users group
Connect-MgGraph -Scopes "Group.ReadWrite.All"
$avdGroup = Get-MgGroup -Filter "displayName eq 'AVD-Users'"

foreach ($user in $currentBatch) {
    try {
        $userObj = Get-MgUser -Filter "userPrincipalName eq '$user'"
        $membership = Get-MgGroupMember -GroupId $avdGroup.Id | Where-Object { $_.Id -eq $userObj.Id }
        
        if (-not $membership) {
            New-MgGroupMember -GroupId $avdGroup.Id -DirectoryObjectId $userObj.Id
            Write-Host "✓ $user added to AVD" -ForegroundColor Green
        } else {
            Write-Host "  $user already in group" -ForegroundColor Gray
        }
    } catch {
        Write-Host "✗ Failed to add $user : $_" -ForegroundColor Red
    }
}

Write-Host "`nSend Windows App instructions to batch users"
Write-Host "Monitor for 24 hours before next batch"
```

### Monitor Batch Health

```powershell
# Daily health check during migration
$sessions = Get-AzWvdUserSession -ResourceGroupName "RG-Azure-VDI-01" -HostPoolName "Pool-Pooled-Prod"
$sessionHosts = Get-AzWvdSessionHost -ResourceGroupName "RG-Azure-VDI-01" -HostPoolName "Pool-Pooled-Prod"

Write-Host "=== DAILY HEALTH CHECK ===" -ForegroundColor Cyan
Write-Host "Total active sessions: $($sessions.Count)" -ForegroundColor White
Write-Host "Available session hosts: $(($sessionHosts | Where-Object { $_.Status -eq 'Available' }).Count)" -ForegroundColor White

# Check for overloaded hosts
foreach ($host in $sessionHosts) {
    $hostSessions = $sessions | Where-Object { $_.SessionHostName -eq $host.Name }
    $sessionCount = $hostSessions.Count
    
    if ($sessionCount -gt 10) {
        Write-Host "⚠ $($host.Name): $sessionCount sessions (high load)" -ForegroundColor Yellow
    } else {
        Write-Host "✓ $($host.Name): $sessionCount sessions" -ForegroundColor Green
    }
}
```

---

## Phase 3: Cleanup Old VMs

### ⚠️ CRITICAL: Only delete after confirming users migrated successfully

### Step 1: Identify Old VMs

```powershell
# List all VMs (assuming naming pattern different from new ones)
$allVMs = Get-AzVM -ResourceGroupName "RG-Azure-VDI-01"

# Identify old individual VMs (NOT avd-pool-* VMs)
$oldVMs = $allVMs | Where-Object { $_.Name -notlike "avd-pool-*" }

Write-Host "=== OLD VMS TO CLEANUP ===" -ForegroundColor Cyan
Write-Host "Total old VMs: $($oldVMs.Count)" -ForegroundColor Yellow

foreach ($vm in $oldVMs) {
    Write-Host "  - $($vm.Name)" -ForegroundColor Gray
}

Write-Host "`n⚠️ Review this list carefully before proceeding!" -ForegroundColor Yellow
```

### Step 2: Pre-Deletion Verification

```powershell
# Verify users are using new environment
$activeSessions = Get-AzWvdUserSession -ResourceGroupName "RG-Azure-VDI-01" -HostPoolName "Pool-Pooled-Prod"
$migratedUserCount = ($activeSessions | Select-Object -Unique UserPrincipalName).Count

Write-Host "=== PRE-DELETION VERIFICATION ===" -ForegroundColor Cyan
Write-Host "Users with active sessions in new environment: $migratedUserCount" -ForegroundColor White
Write-Host "Old VMs to delete: $($oldVMs.Count)" -ForegroundColor Yellow

if ($migratedUserCount -lt 350) {
    Write-Host "`n⚠️ WARNING: Less than 350 users migrated" -ForegroundColor Red
    Write-Host "Do NOT proceed with deletion yet!" -ForegroundColor Red
    exit
}

Write-Host "`n✓ Safe to proceed with cleanup" -ForegroundColor Green
```

### Step 3: Delete VMs in Batches

```bash
# Azure CLI - Delete VMs in batches of 10

resourceGroup="RG-Azure-VDI-01"

# Get list of old VMs (adjust filter as needed)
oldVMs=$(az vm list --resource-group $resourceGroup --query "[?!starts_with(name, 'avd-pool-')].name" -o tsv)

echo "=== DELETING OLD VMS ==="
echo "$oldVMs" | head -10 | while read vmName; do
    echo "Deleting: $vmName"
    
    # Delete VM and associated resources
    az vm delete \
      --resource-group $resourceGroup \
      --name $vmName \
      --yes \
      --no-wait
    
    echo "✓ $vmName deletion started"
done

echo "Batch deletion started. Monitor in Azure Portal."
echo "Wait 30 minutes before next batch."
```

### Step 4: Cleanup Associated Resources

```bash
# After VMs deleted, cleanup orphaned resources

echo "=== CLEANING UP NICS ==="
az network nic list --resource-group $resourceGroup \
  --query "[?virtualMachine==null].name" -o tsv | while read nicName; do
    echo "Deleting NIC: $nicName"
    az network nic delete --resource-group $resourceGroup --name $nicName --no-wait
done

echo "=== CLEANING UP DISKS ==="
az disk list --resource-group $resourceGroup \
  --query "[?managedBy==null].name" -o tsv | while read diskName; do
    echo "Deleting disk: $diskName"
    az disk delete --resource-group $resourceGroup --name $diskName --yes --no-wait
done

echo "=== CLEANING UP PUBLIC IPS ==="
az network public-ip list --resource-group $resourceGroup \
  --query "[?ipConfiguration==null].name" -o tsv | while read pipName; do
    echo "Deleting public IP: $pipName"
    az network public-ip delete --resource-group $resourceGroup --name $pipName --no-wait
done

echo "Cleanup complete. Orphaned resources deleted."
```

---

## Rollback Plan

### If Critical Issues During Migration:

1. **Stop migration immediately**
2. **Keep old VMs running**
3. **Remove affected users from AVD-Users group**
4. **Users revert to old VMs**
5. **Investigate and fix issues**
6. **Retest thoroughly**
7. **Resume migration when ready**

```powershell
# Emergency: Remove user from AVD
$userToRevert = "user@contoso.com"
Connect-MgGraph -Scopes "Group.ReadWrite.All"
$avdGroup = Get-MgGroup -Filter "displayName eq 'AVD-Users'"
$user = Get-MgUser -Filter "userPrincipalName eq '$userToRevert'"

Remove-MgGroupMemberByRef -GroupId $avdGroup.Id -DirectoryObjectId $user.Id

Write-Host "✓ $userToRevert removed from AVD. They can use old VM." -ForegroundColor Green
```

---

## Post-Migration Tasks

### Week 1-2 After Full Migration

```
□ Monitor user feedback
□ Review AVD Insights dashboards
□ Optimize autoscaling schedules
□ Fine-tune host pool sizing
□ Document lessons learned
□ Update runbooks
□ Train help desk on AVD troubleshooting
□ Schedule golden image updates (monthly)
```

### Confirm All Users Migrated

```powershell
# Final verification
$avdUsers = Get-MgGroupMember -GroupId (Get-MgGroup -Filter "displayName eq 'AVD-Users'").Id
Write-Host "Total users in AVD-Users group: $($avdUsers.Count)" -ForegroundColor Cyan

if ($avdUsers.Count -ge 400) {
    Write-Host "✓ All 400 users migrated" -ForegroundColor Green
} else {
    Write-Host "⚠ Only $($avdUsers.Count) users migrated" -ForegroundColor Yellow
    Write-Host "Expected: 400" -ForegroundColor Gray
}
```

---

## Cost Savings After Cleanup

**Before:** 400 individual VMs running 24/7  
**After:** 40 pooled VMs with autoscaling (avg 60% utilization)

**Estimated savings:** 70-80% on compute costs

---

## Migration Timeline

| Phase | Duration | Action |
|-------|----------|--------|
| Pilot | Days 1-2 | 10-20 users, monitor closely |
| Batch 1 | Days 3-4 | 50 users |
| Batch 2 | Days 5-6 | 50 users |
| Batch 3-7 | Days 7-14 | 50 users per batch |
| Cleanup | Days 15-17 | Delete old VMs in batches |
| Validation | Days 18-21 | Final verification |

**Total: ~3 weeks for full migration**

---

## Success Criteria

```
✓ 400 users migrated successfully
✓ FSLogix profiles working for all users
✓ SSO working (no credential prompts)
✓ Performance acceptable (< 30 sec login)
✓ Old VMs cleaned up
✓ Cost savings achieved
✓ User satisfaction > 80%
```

---

**Document Version:** 1.0  
**Last Updated:** December 2, 2025
