# RBAC Role Assignments for AVD

**Purpose:** Assign necessary permissions for users to access AVD resources and FSLogix profiles

**Prerequisites:**
- Entra ID user groups created (Guide 03):
  - `AVD-Users-Standard` (390 standard users)
  - `AVD-Users-Admins` (10 admin users)
- FSLogix storage account and file share created (Guide 02)
- Host pools and application groups created (Guide 04)
- Resource group `RG-Azure-VDI-01` exists

**RBAC Assignments by User Group:**

**For AVD-Users-Standard (390 standard users):**
1. **Storage File Data SMB Share Contributor** → Can read/write own FSLogix profile only
2. **Virtual Machine User Login** → Standard user login to session hosts (no admin)
3. **Desktop Virtualization User** → Access to AVD desktop application group

**For AVD-Users-Admins (10 IT admin users) - ADDITIONAL assignments:**
1. **Storage File Data SMB Share Elevated Contributor** → Manage all FSLogix profiles (elevated access)
2. **Virtual Machine Administrator Login** → Admin login to session hosts with local admin rights
3. **Desktop Virtualization Power On Off Contributor** → Manage session host power state (optional)

---

## Part 1: Storage Permissions (FSLogix) - Standard Users

### Option A: Azure Portal

1. Storage account `YOUR_STORAGE_ACCOUNT` (from Guide 02, e.g., `fslogix52847`) → File shares → `fslogix-profiles`
2. Access control (IAM) → Add role assignment
3. Role: `Storage File Data SMB Share Contributor`
4. Members: `AVD-Users-Standard` group → Review + assign

---

## Part 1B: Storage Permissions (FSLogix) - Admin Users

### Option A: Azure Portal

1. Storage account `YOUR_STORAGE_ACCOUNT` (from Guide 02, e.g., `fslogix52847`) → File shares → `fslogix-profiles`
2. Access control (IAM) → Add role assignment
3. Role: `Storage File Data SMB Share Elevated Contributor` (elevated - can manage all profiles)
4. Members: `AVD-Users-Admins` group → Review + assign

### Option B: PowerShell

```powershell
Connect-AzAccount
Connect-MgGraph -Scopes "Group.Read.All"

$resourceGroup = "RG-Azure-VDI-01"
# Replace with your storage account name from Guide 02 (e.g., fslogix52847)
$storageAccountName = "YOUR_STORAGE_ACCOUNT"
$fileShareName = "fslogix-profiles"

$storageAccount = Get-AzStorageAccount -ResourceGroupName $resourceGroup -Name $storageAccountName
$fileShareResourceId = "$($storageAccount.Id)/fileServices/default/fileshares/$fileShareName"

# Assign Storage File Data SMB Share Contributor to standard users
Write-Host "Assigning standard user storage permissions..." -ForegroundColor Cyan
$standardGroup = Get-MgGroup -Filter "displayName eq 'AVD-Users-Standard'"

New-AzRoleAssignment `
    -ObjectId $standardGroup.Id `
    -RoleDefinitionName "Storage File Data SMB Share Contributor" `
    -Scope $fileShareResourceId

Write-Host "✓ Standard users: Storage File Data SMB Share Contributor assigned" -ForegroundColor Green

# Assign Storage File Data SMB Share Elevated Contributor to admin users
Write-Host "`nAssigning admin user storage permissions (elevated)..." -ForegroundColor Cyan
$adminGroup = Get-MgGroup -Filter "displayName eq 'AVD-Users-Admins'"

New-AzRoleAssignment `
    -ObjectId $adminGroup.Id `
    -RoleDefinitionName "Storage File Data SMB Share Elevated Contributor" `
    -Scope $fileShareResourceId

Write-Host "✓ Admin users: Storage File Data SMB Share Elevated Contributor assigned" -ForegroundColor Green
```

---

## Part 2: VM Login Permissions - Standard Users

### Option A: Azure Portal

1. Resource group `RG-Azure-VDI-01` → Access control (IAM)
2. Add role assignment
3. Role: `Virtual Machine User Login` (standard user)
4. Members: `AVD-Users-Standard` group → Review + assign

---

## Part 2B: VM Admin Login Permissions - Admin Users

### Option A: Azure Portal

1. Resource group `RG-Azure-VDI-01` → Access control (IAM)
2. Add role assignment
3. Role: `Virtual Machine Administrator Login` (elevated - admin access)
4. Members: `AVD-Users-Admins` group → Review + assign

### Option B: PowerShell

```powershell
$rg = Get-AzResourceGroup -Name "RG-Azure-VDI-01"

# Standard users: Virtual Machine User Login
Write-Host "Assigning standard user VM login permissions..." -ForegroundColor Cyan
$standardGroup = Get-MgGroup -Filter "displayName eq 'AVD-Users-Standard'"

New-AzRoleAssignment `
    -ObjectId $standardGroup.Id `
    -RoleDefinitionName "Virtual Machine User Login" `
    -Scope $rg.ResourceId

Write-Host "✓ Standard users: Virtual Machine User Login assigned" -ForegroundColor Green

# Admin users: Virtual Machine Administrator Login
Write-Host "`nAssigning admin user VM login permissions (elevated)..." -ForegroundColor Cyan
$adminGroup = Get-MgGroup -Filter "displayName eq 'AVD-Users-Admins'"

New-AzRoleAssignment `
    -ObjectId $adminGroup.Id `
    -RoleDefinitionName "Virtual Machine Administrator Login" `
    -Scope $rg.ResourceId

Write-Host "✓ Admin users: Virtual Machine Administrator Login assigned" -ForegroundColor Green

# Admin users (optional): Desktop Virtualization Power On Off Contributor
Write-Host "`nAssigning admin power management permissions (optional)..." -ForegroundColor Cyan

New-AzRoleAssignment `
    -ObjectId $adminGroup.Id `
    -RoleDefinitionName "Desktop Virtualization Power On Off Contributor" `
    -Scope $rg.ResourceId

Write-Host "✓ Admin users: Desktop Virtualization Power On Off Contributor assigned" -ForegroundColor Green
```

---

## Part 3: Application Group Permissions

### Option A: Azure Portal

1. Azure Virtual Desktop → Application groups → `AG-Desktop-Pooled`
2. Access control (IAM) → Add role assignment
3. Role: `Desktop Virtualization User`
4. Members: Select both `AVD-Users-Standard` AND `AVD-Users-Admins` groups → Review + assign

### Option B: PowerShell

```powershell
$appGroup = Get-AzWvdApplicationGroup -ResourceGroupName "RG-Azure-VDI-01" -Name "AG-Desktop-Pooled"

# Assign to both standard and admin users
Write-Host "Assigning application group permissions to standard users..." -ForegroundColor Cyan
$standardGroup = Get-MgGroup -Filter "displayName eq 'AVD-Users-Standard'"

New-AzRoleAssignment `
    -ObjectId $standardGroup.Id `
    -RoleDefinitionName "Desktop Virtualization User" `
    -Scope $appGroup.Id

Write-Host "✓ Standard users: Application group access assigned" -ForegroundColor Green

Write-Host "`nAssigning application group permissions to admin users..." -ForegroundColor Cyan
$adminGroup = Get-MgGroup -Filter "displayName eq 'AVD-Users-Admins'"

New-AzRoleAssignment `
    -ObjectId $adminGroup.Id `
    -RoleDefinitionName "Desktop Virtualization User" `
    -Scope $appGroup.Id

Write-Host "✓ Admin users: Application group access assigned" -ForegroundColor Green
```

---

## Verification Script

```powershell
Connect-AzAccount
Connect-MgGraph -Scopes "Group.Read.All"

$rg = Get-AzResourceGroup -Name "RG-Azure-VDI-01"
$storageAccount = Get-AzStorageAccount -ResourceGroupName "RG-Azure-VDI-01" -Name "fslogix37402"
$fileShareResourceId = "$($storageAccount.Id)/fileServices/default/fileshares/fslogix-profiles"
$appGroup = Get-AzWvdApplicationGroup -ResourceGroupName "RG-Azure-VDI-01" -Name "AG-Desktop-Pooled"

$standardGroup = Get-MgGroup -Filter "displayName eq 'AVD-Users-Standard'"
$adminGroup = Get-MgGroup -Filter "displayName eq 'AVD-Users-Admins'"

Write-Host "=== RBAC VERIFICATION ===" -ForegroundColor Cyan

# Standard user permissions
Write-Host "`n[STANDARD USERS]" -ForegroundColor White

$storageCheck = Get-AzRoleAssignment -ObjectId $standardGroup.Id -Scope $fileShareResourceId -RoleDefinitionName "Storage File Data SMB Share Contributor"
if ($storageCheck) { Write-Host "✓ Storage Data SMB Share Contributor" -ForegroundColor Green } else { Write-Host "✗ Storage Data SMB Share Contributor MISSING" -ForegroundColor Red }

$vmCheck = Get-AzRoleAssignment -ObjectId $standardGroup.Id -Scope $rg.ResourceId -RoleDefinitionName "Virtual Machine User Login"
if ($vmCheck) { Write-Host "✓ Virtual Machine User Login" -ForegroundColor Green } else { Write-Host "✗ Virtual Machine User Login MISSING" -ForegroundColor Red }

$appCheck = Get-AzRoleAssignment -ObjectId $standardGroup.Id -Scope $appGroup.Id -RoleDefinitionName "Desktop Virtualization User"
if ($appCheck) { Write-Host "✓ Desktop Virtualization User" -ForegroundColor Green } else { Write-Host "✗ Desktop Virtualization User MISSING" -ForegroundColor Red }

# Admin user permissions
Write-Host "`n[ADMIN USERS]" -ForegroundColor White

$storageElevatedCheck = Get-AzRoleAssignment -ObjectId $adminGroup.Id -Scope $fileShareResourceId -RoleDefinitionName "Storage File Data SMB Share Elevated Contributor"
if ($storageElevatedCheck) { Write-Host "✓ Storage File Data SMB Share Elevated Contributor" -ForegroundColor Green } else { Write-Host "✗ Storage File Data SMB Share Elevated Contributor MISSING" -ForegroundColor Red }

$vmAdminCheck = Get-AzRoleAssignment -ObjectId $adminGroup.Id -Scope $rg.ResourceId -RoleDefinitionName "Virtual Machine Administrator Login"
if ($vmAdminCheck) { Write-Host "✓ Virtual Machine Administrator Login" -ForegroundColor Green } else { Write-Host "✗ Virtual Machine Administrator Login MISSING" -ForegroundColor Red }

$appCheckAdmin = Get-AzRoleAssignment -ObjectId $adminGroup.Id -Scope $appGroup.Id -RoleDefinitionName "Desktop Virtualization User"
if ($appCheckAdmin) { Write-Host "✓ Desktop Virtualization User" -ForegroundColor Green } else { Write-Host "✗ Desktop Virtualization User MISSING" -ForegroundColor Red }

$powerCheck = Get-AzRoleAssignment -ObjectId $adminGroup.Id -Scope $rg.ResourceId -RoleDefinitionName "Desktop Virtualization Power On Off Contributor"
if ($powerCheck) { Write-Host "✓ Desktop Virtualization Power On Off Contributor" -ForegroundColor Green } else { Write-Host "⚠ Desktop Virtualization Power On Off Contributor (optional)" -ForegroundColor Yellow }
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
