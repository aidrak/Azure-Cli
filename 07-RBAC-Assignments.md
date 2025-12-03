# RBAC Role Assignments for AVD

**Purpose:** Assign necessary permissions for users to access AVD resources and FSLogix profiles

**Prerequisites:**
- Entra ID group created for AVD users (e.g., `AVD-Users`)
- FSLogix storage account and file share created
- Host pools and application groups created
- Resource group `RG-Azure-VDI-01` exists

**Three critical RBAC assignments:**
1. **Storage File Data SMB Share Contributor** → FSLogix profiles
2. **Virtual Machine User Login** → Session host VMs
3. **Desktop Virtualization User** → Application groups

---

## Part 1: Storage Permissions (FSLogix)

### Option A: Azure Portal

1. Storage account `fslogix112125` → File shares → `fslogix-profiles`
2. Access control (IAM) → Add role assignment
3. Role: `Storage File Data SMB Share Contributor`
4. Members: `AVD-Users` group → Review + assign

### Option B: PowerShell

```powershell
Connect-AzAccount
Connect-MgGraph -Scopes "Group.Read.All"

$resourceGroup = "RG-Azure-VDI-01"
$storageAccountName = "fslogix112125"
$fileShareName = "fslogix-profiles"
$avdUsersGroupName = "AVD-Users"

$storageAccount = Get-AzStorageAccount -ResourceGroupName $resourceGroup -Name $storageAccountName
$fileShareResourceId = "$($storageAccount.Id)/fileServices/default/fileshares/$fileShareName"
$group = Get-MgGroup -Filter "displayName eq '$avdUsersGroupName'"

New-AzRoleAssignment `
    -ObjectId $group.Id `
    -RoleDefinitionName "Storage File Data SMB Share Contributor" `
    -Scope $fileShareResourceId

Write-Host "✓ Storage permissions assigned" -ForegroundColor Green
```

---

## Part 2: VM Login Permissions (SSO)

### Option A: Azure Portal

1. Resource group `RG-Azure-VDI-01` → Access control (IAM)
2. Add role assignment
3. Role: `Virtual Machine User Login`
4. Members: `AVD-Users` group → Review + assign

### Option B: PowerShell

```powershell
$rg = Get-AzResourceGroup -Name $resourceGroup

New-AzRoleAssignment `
    -ObjectId $group.Id `
    -RoleDefinitionName "Virtual Machine User Login" `
    -Scope $rg.ResourceId

Write-Host "✓ VM login permissions assigned" -ForegroundColor Green
```

---

## Part 3: Application Group Permissions

### Option A: Azure Portal

1. Azure Virtual Desktop → Application groups → `AG-Desktop-Pooled`
2. Access control (IAM) → Add role assignment
3. Role: `Desktop Virtualization User`
4. Members: `AVD-Users` group → Review + assign

### Option B: PowerShell

```powershell
$appGroup = Get-AzWvdApplicationGroup -ResourceGroupName $resourceGroup -Name "AG-Desktop-Pooled"

New-AzRoleAssignment `
    -ObjectId $group.Id `
    -RoleDefinitionName "Desktop Virtualization User" `
    -Scope $appGroup.Id

Write-Host "✓ Application group permissions assigned" -ForegroundColor Green
```

---

## Verification Script

```powershell
# Verify all three assignments
$group = Get-MgGroup -Filter "displayName eq 'AVD-Users'"
$rg = Get-AzResourceGroup -Name "RG-Azure-VDI-01"
$storageAccount = Get-AzStorageAccount -ResourceGroupName "RG-Azure-VDI-01" -Name "fslogix112125"
$fileShareResourceId = "$($storageAccount.Id)/fileServices/default/fileshares/fslogix-profiles"
$appGroup = Get-AzWvdApplicationGroup -ResourceGroupName "RG-Azure-VDI-01" -Name "AG-Desktop-Pooled"

Write-Host "=== RBAC VERIFICATION ===" -ForegroundColor Cyan

# Check storage
$storageCheck = Get-AzRoleAssignment -ObjectId $group.Id -Scope $fileShareResourceId -RoleDefinitionName "Storage File Data SMB Share Contributor"
if ($storageCheck) { Write-Host "✓ Storage permissions OK" -ForegroundColor Green } else { Write-Host "✗ Storage permissions MISSING" -ForegroundColor Red }

# Check VM login
$vmCheck = Get-AzRoleAssignment -ObjectId $group.Id -Scope $rg.ResourceId -RoleDefinitionName "Virtual Machine User Login"
if ($vmCheck) { Write-Host "✓ VM login permissions OK" -ForegroundColor Green } else { Write-Host "✗ VM login permissions MISSING" -ForegroundColor Red }

# Check app group
$appCheck = Get-AzRoleAssignment -ObjectId $group.Id -Scope $appGroup.Id -RoleDefinitionName "Desktop Virtualization User"
if ($appCheck) { Write-Host "✓ App group permissions OK" -ForegroundColor Green } else { Write-Host "✗ App group permissions MISSING" -ForegroundColor Red }
```

---

## Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| "Credentials are incorrect" | VM login role missing | Assign Virtual Machine User Login |
| No desktops visible | App group role missing | Assign Desktop Virtualization User |
| FSLogix profile fails | Storage role missing | Assign Storage File Data SMB Share Contributor |
| Roles don't take effect | Propagation delay | Wait 5-10 minutes, sign out/in |

---

**Document Version:** 1.0  
**Last Updated:** December 2, 2025
