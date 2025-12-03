# Entra ID Group Setup for AVD

**Purpose:** Create user security groups and device dynamic groups required for AVD deployment, RBAC assignments, and Intune policy targeting

**Prerequisites:**
- Azure subscription with Owner or Contributor role
- Entra ID P1 or P2 licenses (for dynamic device groups)
- Admin access to Microsoft Entra admin center

**Overview:** This guide creates:
1. **User Security Groups** - Segregate standard users from administrators
2. **Device Dynamic Groups** - Auto-populate for Intune policy targeting
3. **Local Admin Configuration** - Grant admin group local admin rights on session hosts

---

## Part 1: Create User Security Groups

### Option A: Azure Portal (GUI)

#### Step 1: Create AVD-Users-Standard Group

1. **Navigate to Groups**
   - Microsoft Entra admin center → **Groups** → **All groups**
   - Click **+ New group**

2. **Basic Configuration**
   - Group type: **Security**
   - Group name: `AVD-Users-Standard`
   - Group description: `Standard AVD users with restricted permissions (390 users)`
   - Membership type: **Assigned**
   - Owners: (your admin account)
   - Click **Create**

3. **Verify Creation**
   - Group should appear in all groups list

#### Step 2: Create AVD-Users-Admins Group

1. Click **+ New group**

2. **Basic Configuration**
   - Group type: **Security**
   - Group name: `AVD-Users-Admins`
   - Group description: `AVD administrators with elevated permissions and local admin rights (10 users)`
   - Membership type: **Assigned**
   - Owners: (your admin account)
   - Click **Create**

3. **Verify Creation**
   - Group should appear in all groups list

---

### Option B: PowerShell

```powershell
# Connect to Microsoft Graph
Connect-MgGraph -Scopes "Group.Create"

# Create AVD-Users-Standard group
$standardGroupParams = @{
    DisplayName     = "AVD-Users-Standard"
    Description     = "Standard AVD users with restricted permissions (390 users)"
    GroupTypes      = @()  # Security group (empty array means no Office 365)
    SecurityEnabled = $true
    MailEnabled     = $false
}

$standardGroup = New-MgGroup @standardGroupParams
Write-Host "✓ Created: AVD-Users-Standard (ID: $($standardGroup.Id))" -ForegroundColor Green

# Create AVD-Users-Admins group
$adminGroupParams = @{
    DisplayName     = "AVD-Users-Admins"
    Description     = "AVD administrators with elevated permissions and local admin rights (10 users)"
    GroupTypes      = @()
    SecurityEnabled = $true
    MailEnabled     = $false
}

$adminGroup = New-MgGroup @adminGroupParams
Write-Host "✓ Created: AVD-Users-Admins (ID: $($adminGroup.Id))" -ForegroundColor Green

Write-Host "`n=== USER GROUPS CREATED ===" -ForegroundColor Cyan
Write-Host "Standard Users Group: $($standardGroup.DisplayName)" -ForegroundColor White
Write-Host "Admin Users Group: $($adminGroup.DisplayName)" -ForegroundColor White
```

---

## Part 2: Create Device Dynamic Groups

### Option A: Azure Portal (GUI)

#### Dynamic Group Configuration Template

For each device group below, follow these steps:

1. **Navigate to Groups**
   - Microsoft Entra admin center → **Groups** → **All groups**
   - Click **+ New group**

2. **Basic Configuration**
   - Group type: **Security**
   - Group name: `[Group name from below]`
   - Group description: `[Description from below]`
   - Membership type: **Dynamic Device**
   - Click **Create**

3. **Configure Dynamic Rule**
   - Click **Add dynamic query**
   - Operator: **And**
   - Property: `displayName`
   - Operator: `startsWith`
   - Value: `avd-pool-`
   - Click **Save**
   - Click **Create**

---

#### Group 1: AVD-Devices-Pooled-SSO

- **Group name:** `AVD-Devices-Pooled-SSO`
- **Description:** `Dynamic group for pooled AVD session hosts - SSO trusted devices (automatically populated based on VM naming)`
- **Dynamic Query:** `(device.displayName -startsWith "avd-pool-")`
- **Purpose:** Windows Cloud Login service principal trusted device group (eliminates SSO consent prompts)
- **Used in:** Guide 09 - SSO Configuration

---

#### Group 2: AVD-Devices-Pooled-FSLogix

- **Group name:** `AVD-Devices-Pooled-FSLogix`
- **Description:** `Dynamic group for pooled AVD session hosts - FSLogix configuration (automatically populated)`
- **Dynamic Query:** `(device.displayName -startsWith "avd-pool-")`
- **Purpose:** Target for FSLogix Intune configuration policies
- **Used in:** Guide 07 - Intune Configuration Part 1

---

#### Group 3: AVD-Devices-Pooled-Network

- **Group name:** `AVD-Devices-Pooled-Network`
- **Description:** `Dynamic group for pooled AVD session hosts - Network policies (automatically populated)`
- **Dynamic Query:** `(device.displayName -startsWith "avd-pool-")`
- **Purpose:** Target for network-related policies (UDP disable, TCP-only RDP)
- **Used in:** Guide 07 - Intune Configuration Part 2

---

#### Group 4: AVD-Devices-Pooled-Security

- **Group name:** `AVD-Devices-Pooled-Security`
- **Description:** `Dynamic group for pooled AVD session hosts - Security baselines (automatically populated)`
- **Dynamic Query:** `(device.displayName -startsWith "avd-pool-")`
- **Purpose:** Target for security baseline and compliance policies
- **Used in:** Future security policy assignments

---

#### Group 5: AVD-Devices-Clients-Corporate

- **Group name:** `AVD-Devices-Clients-Corporate`
- **Description:** `Corporate workstations and laptops that connect to AVD (manually assigned or dynamic)`
- **Dynamic Query:** `(device.deviceOwnership -eq "Company")`
  - **Alternative (if ownership not tagged):** Manually assign devices in Portal
- **Purpose:** Target for client-side AVD policies
- **Used in:** Guide 07 - Intune Configuration Part 3

---

### Option B: PowerShell

```powershell
# Connect to Microsoft Graph
Connect-MgGraph -Scopes "Group.Create"

# Helper function to create dynamic device groups
function New-AVDDynamicDeviceGroup {
    param(
        [string]$DisplayName,
        [string]$Description,
        [string]$DynamicRule
    )

    $groupParams = @{
        DisplayName           = $DisplayName
        Description           = $Description
        GroupTypes            = @("DynamicMembership")
        SecurityEnabled       = $true
        MailEnabled           = $false
        MembershipRule        = $DynamicRule
        MembershipRuleProcessingState = "On"
    }

    $group = New-MgGroup @groupParams
    return $group
}

Write-Host "Creating device dynamic groups..." -ForegroundColor Cyan

# Group 1: SSO
$ssoGroup = New-AVDDynamicDeviceGroup `
    -DisplayName "AVD-Devices-Pooled-SSO" `
    -Description "Dynamic group for pooled AVD session hosts - SSO trusted devices (automatically populated)" `
    -DynamicRule '(device.displayName -startsWith "avd-pool-")'
Write-Host "✓ Created: AVD-Devices-Pooled-SSO (ID: $($ssoGroup.Id))" -ForegroundColor Green

# Group 2: FSLogix
$fslogixGroup = New-AVDDynamicDeviceGroup `
    -DisplayName "AVD-Devices-Pooled-FSLogix" `
    -Description "Dynamic group for pooled AVD session hosts - FSLogix configuration (automatically populated)" `
    -DynamicRule '(device.displayName -startsWith "avd-pool-")'
Write-Host "✓ Created: AVD-Devices-Pooled-FSLogix (ID: $($fslogixGroup.Id))" -ForegroundColor Green

# Group 3: Network
$networkGroup = New-AVDDynamicDeviceGroup `
    -DisplayName "AVD-Devices-Pooled-Network" `
    -Description "Dynamic group for pooled AVD session hosts - Network policies (automatically populated)" `
    -DynamicRule '(device.displayName -startsWith "avd-pool-")'
Write-Host "✓ Created: AVD-Devices-Pooled-Network (ID: $($networkGroup.Id))" -ForegroundColor Green

# Group 4: Security
$securityGroup = New-AVDDynamicDeviceGroup `
    -DisplayName "AVD-Devices-Pooled-Security" `
    -Description "Dynamic group for pooled AVD session hosts - Security baselines (automatically populated)" `
    -DynamicRule '(device.displayName -startsWith "avd-pool-")'
Write-Host "✓ Created: AVD-Devices-Pooled-Security (ID: $($securityGroup.Id))" -ForegroundColor Green

# Group 5: Client Devices (Corporate)
$clientGroup = New-AVDDynamicDeviceGroup `
    -DisplayName "AVD-Devices-Clients-Corporate" `
    -Description "Corporate workstations and laptops that connect to AVD" `
    -DynamicRule '(device.deviceOwnership -eq "Company")'
Write-Host "✓ Created: AVD-Devices-Clients-Corporate (ID: $($clientGroup.Id))" -ForegroundColor Green

Write-Host "`n=== DEVICE GROUPS CREATED ===" -ForegroundColor Cyan
Write-Host "5 dynamic device groups created successfully" -ForegroundColor White
Write-Host "`nNote: Dynamic groups take 5-10 minutes to populate membership" -ForegroundColor Yellow
Write-Host "Device membership will auto-populate when session hosts are deployed" -ForegroundColor Yellow
```

---

## Part 3: Assign Test Users to Groups

### Add Users to AVD-Users-Standard

#### Option A: Azure Portal

1. **Navigate to Group**
   - Groups → **AVD-Users-Standard**
   - Click **Members** → **+ Add members**

2. **Add Test Users**
   - Search for and select test user accounts
   - Click **Select**

#### Option B: PowerShell

```powershell
# Connect to Microsoft Graph
Connect-MgGraph -Scopes "Group.ReadWrite.All", "User.Read.All"

# Get the group
$standardGroup = Get-MgGroup -Filter "displayName eq 'AVD-Users-Standard'"

# Define test users (replace with your actual test users)
$testUsers = @(
    "testuser1@yourdomain.com",
    "testuser2@yourdomain.com"
    # Add more test users as needed
)

Write-Host "Adding users to AVD-Users-Standard..." -ForegroundColor Cyan

foreach ($userEmail in $testUsers) {
    try {
        $user = Get-MgUser -Filter "userPrincipalName eq '$userEmail'"

        if ($user) {
            New-MgGroupMember -GroupId $standardGroup.Id -DirectoryObjectId $user.Id
            Write-Host "✓ Added: $userEmail" -ForegroundColor Green
        } else {
            Write-Host "✗ User not found: $userEmail" -ForegroundColor Red
        }
    } catch {
        Write-Host "✗ Error adding $userEmail : $_" -ForegroundColor Red
    }
}
```

### Add Users to AVD-Users-Admins

#### Option A: Azure Portal

1. **Navigate to Group**
   - Groups → **AVD-Users-Admins**
   - Click **Members** → **+ Add members**

2. **Add Admin Test Users**
   - Search for and select IT admin test accounts
   - Click **Select**

#### Option B: PowerShell

```powershell
# Get the admin group
$adminGroup = Get-MgGroup -Filter "displayName eq 'AVD-Users-Admins'"

# Define admin test users
$adminUsers = @(
    "admin1@yourdomain.com",
    "admin2@yourdomain.com"
    # Add more admin users as needed
)

Write-Host "Adding users to AVD-Users-Admins..." -ForegroundColor Cyan

foreach ($adminEmail in $adminUsers) {
    try {
        $user = Get-MgUser -Filter "userPrincipalName eq '$adminEmail'"

        if ($user) {
            New-MgGroupMember -GroupId $adminGroup.Id -DirectoryObjectId $user.Id
            Write-Host "✓ Added: $adminEmail" -ForegroundColor Green
        } else {
            Write-Host "✗ User not found: $adminEmail" -ForegroundColor Red
        }
    } catch {
        Write-Host "✗ Error adding $adminEmail : $_" -ForegroundColor Red
    }
}
```

---

## Part 4: Configure Local Admin Rights for AVD-Users-Admins

Local admin rights will be granted when session hosts are deployed using Intune configuration policies in Guide 07.

**Method:** Create Intune policy to add `AVD-Users-Admins` group to local Administrators group on session hosts

**When to Configure:** After session hosts are deployed (Guide 06)

**Reference:** See Guide 07 - Intune Configuration for detailed implementation

---

## Part 5: Verification

### Verify User Groups Created

```powershell
Connect-MgGraph -Scopes "Group.Read.All"

Write-Host "=== USER GROUP VERIFICATION ===" -ForegroundColor Cyan

$groups = Get-MgGroup -Filter "displayName in ('AVD-Users-Standard', 'AVD-Users-Admins')"

foreach ($group in $groups) {
    $members = Get-MgGroupMember -GroupId $group.Id
    Write-Host "`n$($group.DisplayName)" -ForegroundColor White
    Write-Host "  ID: $($group.Id)" -ForegroundColor Gray
    Write-Host "  Members: $($members.Count)" -ForegroundColor Yellow
}
```

### Verify Device Groups Created

```powershell
Write-Host "`n=== DEVICE GROUP VERIFICATION ===" -ForegroundColor Cyan

$deviceGroups = Get-MgGroup -Filter "displayName startsWith 'AVD-Devices-'" -All

foreach ($group in $deviceGroups) {
    Write-Host "`n$($group.DisplayName)" -ForegroundColor White
    Write-Host "  ID: $($group.Id)" -ForegroundColor Gray
    Write-Host "  Type: Dynamic Device" -ForegroundColor Yellow
    Write-Host "  Status: Will populate when session hosts deploy" -ForegroundColor Cyan
}
```

### Verify Dynamic Rules

```powershell
Write-Host "`n=== DYNAMIC RULE VERIFICATION ===" -ForegroundColor Cyan

$deviceGroups = Get-MgGroup -Filter "displayName startsWith 'AVD-Devices-'" -All

foreach ($group in $deviceGroups) {
    $dynamicRule = Get-MgGroupDynamicMembershipRule -GroupId $group.Id -ErrorAction SilentlyContinue

    if ($dynamicRule) {
        Write-Host "`n$($group.DisplayName)" -ForegroundColor White
        Write-Host "  Rule: $($dynamicRule.MembershipRule)" -ForegroundColor Gray
        Write-Host "  Status: $($dynamicRule.MembershipRuleProcessingState)" -ForegroundColor Yellow
    }
}
```

---

## Group Summary Reference

| Group Name | Type | Purpose | Members |
|---|---|---|---|
| `AVD-Users-Standard` | Security | Standard AVD users | 390 users |
| `AVD-Users-Admins` | Security | IT admin users | 10 users |
| `AVD-Devices-Pooled-SSO` | Dynamic Device | SSO trusted devices | Auto-populate (avd-pool-*) |
| `AVD-Devices-Pooled-FSLogix` | Dynamic Device | FSLogix policies | Auto-populate (avd-pool-*) |
| `AVD-Devices-Pooled-Network` | Dynamic Device | Network policies | Auto-populate (avd-pool-*) |
| `AVD-Devices-Pooled-Security` | Dynamic Device | Security policies | Auto-populate (avd-pool-*) |
| `AVD-Devices-Clients-Corporate` | Dynamic Device | Corporate endpoints | Auto-populate or assigned |

---

## Next Steps

1. ✓ User security groups created
2. ✓ Device dynamic groups created
3. ✓ Test users assigned to groups
4. ⏭ Deploy session hosts (Guide 04) - session hosts will auto-join device groups
5. ⏭ Configure Intune policies (Guide 07) - assign to specific device groups
6. ⏭ Assign RBAC roles (Guide 08) - assign to user groups

---

**Document Version:** 1.0
**Last Updated:** December 3, 2025
