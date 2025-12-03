# Host Pool & Workspace Creation

**Purpose:** Create AVD workspace, host pools, and application groups for 400 users

**Prerequisites:**
- Resource group: `RG-Azure-VDI-01` exists
- AVD spoke VNet with session host subnet created
- Golden images captured (or will be deployed later)
- PowerShell modules (for PowerShell option):
  ```powershell
  Install-Module -Name Az.DesktopVirtualization -Force
  ```

---

## Overview

**What we're creating:**
1. **Workspace** - User-facing workspace URL (single entry point)
2. **Host Pools** - Collections of session hosts
   - Pooled host pool (multi-session, for most users)
   - Personal host pool (optional, for power users)
3. **Application Groups** - Define what users access (desktop or apps)

**Architecture:**
```
Workspace: "Production Desktop"
    └── Application Group: Desktop (Pooled)
            └── Host Pool: Pool-Pooled-Prod (400 users, 40 VMs)
    └── Application Group: Desktop (Personal) [Optional]
            └── Host Pool: Pool-Personal-Prod (executives)
```

---

## Part 1: Create Workspace

### Option A: Azure Portal (GUI)

1. **Navigate to Azure Virtual Desktop**
   - Search "Azure Virtual Desktop" in Azure Portal
   - Click **Workspaces** in left menu
   - Click **+ Create**

2. **Basics Tab**
   - Subscription: Your subscription
   - Resource group: `RG-Azure-VDI-01`
   - Workspace name: `AVD-Workspace-Prod`
   - Location: `Central US`
   - Friendly name: `Production Desktop`
   - Description: `Azure Virtual Desktop for 400 users`
   - Click **Next: Application groups**

3. **Application groups Tab**
   - Skip for now (we'll add after creating host pools)
   - Click **Next: Tags**

4. **Tags Tab** (optional)
   - Add tags:
     - `Environment`: `Production`
     - `Purpose`: `AVD-Workspace`
   - Click **Next: Review + create**

5. **Review + Create**
   - Click **Create**
   - Wait 30 seconds for deployment

6. **Get Workspace URL (for later)**
   - Open workspace → **Properties**
   - Copy **Workspace URL** (looks like: `https://rdweb.wvd.microsoft.com/api/arm/feeddiscovery`)
   - Users will use this to connect via Windows App

---

### Option B: PowerShell

```powershell
# Login to Azure
Connect-AzAccount

# Set variables
$resourceGroup = "RG-Azure-VDI-01"
$location = "centralus"
$workspaceName = "AVD-Workspace-Prod"
$friendlyName = "Production Desktop"
$description = "Azure Virtual Desktop for 400 users"

# Create workspace
Write-Host "Creating AVD workspace..." -ForegroundColor Cyan
New-AzWvdWorkspace `
    -ResourceGroupName $resourceGroup `
    -Name $workspaceName `
    -Location $location `
    -FriendlyName $friendlyName `
    -Description $description

Write-Host "✓ Workspace created: $workspaceName" -ForegroundColor Green

# Get workspace details
$workspace = Get-AzWvdWorkspace `
    -ResourceGroupName $resourceGroup `
    -Name $workspaceName

Write-Host "`n=== WORKSPACE DETAILS ===" -ForegroundColor Cyan
Write-Host "Name: $workspaceName" -ForegroundColor White
Write-Host "Friendly Name: $friendlyName" -ForegroundColor White
Write-Host "Resource ID: $($workspace.Id)" -ForegroundColor Gray
Write-Host "`nNext Step: Create Host Pools" -ForegroundColor Cyan
```

---

## Part 2: Create Pooled Host Pool

**For:** 400 standard users, multi-session Windows 11

### Option A: Azure Portal (GUI)

1. **Navigate to Host Pools**
   - Azure Virtual Desktop → **Host pools**
   - Click **+ Create**

2. **Basics Tab**
   - Subscription: Your subscription
   - Resource group: `RG-Azure-VDI-01`
   - Host pool name: `Pool-Pooled-Prod`
   - Location: `Central US`
   - Validation environment: **No** (set to Yes for testing updates first)
   - Preferred app group type: **Desktop**
   - Host pool type: **Pooled**
   - Max session limit: `12`
     - ⚠️ Adjust based on VM size
     - Standard_D4ds_v4 (4 vCPU) → 8-12 sessions
     - Standard_D8ds_v4 (8 vCPU) → 16-20 sessions
   - Load balancing algorithm: **Breadth-first**
     - Use Breadth-first for even distribution
     - Use Depth-first for cost savings (during ramp-down)
   - Click **Next: Virtual Machines**

3. **Virtual Machines Tab**
   - **Skip for now** (we'll add session hosts later from golden image)
   - Toggle: **Add Azure virtual machines:** No
   - Click **Next: Workspace**

4. **Workspace Tab**
   - Register desktop app group: **Yes**
   - Register desktop app group to: Select `AVD-Workspace-Prod`
   - Click **Next: Networking**

5. **Networking Tab**
   - **RDP Shortpath for managed networks:** Disabled
   - **RDP Shortpath for managed networks with ICE/STUN:** Disabled
   - **RDP Shortpath for public networks with ICE/STUN:** Disabled  
   - **RDP Shortpath for public networks via TURN:** Disabled
   - ⚠️ All UDP/RDP Shortpath options should be **Disabled** per requirements
   - Click **Next: Advanced**

6. **Advanced Tab - RDP Properties**
   - Custom RDP properties: **Customize**
   - Paste this string:
   ```
   enablerdsaadauth:i:1;use udp:i:0;audiocapturemode:i:1;audiomode:i:0;videoplaybackmode:i:1;redirectclipboard:i:1;redirectprinters:i:0;devicestoredirect:s:;drivestoredirect:s:;redirectcomports:i:0;redirectsmartcards:i:0;usbdevicestoredirect:s:;keyboardhook:i:2;camerastoredirect:s:*;
   ```
   
   **Key settings explained:**
   - `enablerdsaadauth:i:1` → Enable Entra SSO (CRITICAL)
   - `use udp:i:0` → Disable UDP, TCP only (CRITICAL per requirements)
   - `audiocapturemode:i:1` → Enable microphone redirection
   - `audiomode:i:0` → Play audio on local device
   - `redirectclipboard:i:1` → Enable clipboard
   - `redirectprinters:i:0` → Disable printer redirection
   - `keyboardhook:i:2` → Apply Windows key combos in session
   
   - Start connection automatically on login: No
   - Click **Next: Tags**

7. **Tags Tab** (optional)
   - Add tags as needed
   - Click **Next: Review + create**

8. **Review + Create**
   - Verify all settings, especially:
     - Max session limit: 12
     - Load balancing: Breadth-first
     - RDP properties include `use udp:i:0`
   - Click **Create**
   - Wait 1-2 minutes

---

### Option B: PowerShell

```powershell
# Continue from workspace creation or re-login
Connect-AzAccount

# Set variables
$resourceGroup = "RG-Azure-VDI-01"
$location = "centralus"
$hostPoolName = "Pool-Pooled-Prod"
$workspaceName = "AVD-Workspace-Prod"
$friendlyName = "Pooled Desktop"
$maxSessionLimit = 12

# RDP properties with SSO enabled and UDP disabled
$rdpProperties = "enablerdsaadauth:i:1;use udp:i:0;audiocapturemode:i:1;audiomode:i:0;videoplaybackmode:i:1;redirectclipboard:i:1;redirectprinters:i:0;devicestoredirect:s:;drivestoredirect:s:;redirectcomports:i:0;redirectsmartcards:i:0;usbdevicestoredirect:s:;keyboardhook:i:2;camerastoredirect:s:*;"

# Create pooled host pool
Write-Host "Creating pooled host pool..." -ForegroundColor Cyan
New-AzWvdHostPool `
    -ResourceGroupName $resourceGroup `
    -Name $hostPoolName `
    -Location $location `
    -HostPoolType Pooled `
    -LoadBalancerType BreadthFirst `
    -MaxSessionLimit $maxSessionLimit `
    -PreferredAppGroupType Desktop `
    -FriendlyName $friendlyName `
    -CustomRdpProperty $rdpProperties `
    -ValidationEnvironment:$false

Write-Host "✓ Host pool created: $hostPoolName" -ForegroundColor Green

# Verify host pool
$hostPool = Get-AzWvdHostPool `
    -ResourceGroupName $resourceGroup `
    -Name $hostPoolName

Write-Host "`n=== HOST POOL DETAILS ===" -ForegroundColor Cyan
Write-Host "Name: $hostPoolName" -ForegroundColor White
Write-Host "Type: $($hostPool.HostPoolType)" -ForegroundColor White
Write-Host "Max Sessions: $($hostPool.MaxSessionLimit)" -ForegroundColor White
Write-Host "Load Balancer: $($hostPool.LoadBalancerType)" -ForegroundColor White
Write-Host "`nRDP Properties:" -ForegroundColor Yellow
Write-Host $rdpProperties -ForegroundColor Gray

# Verify UDP disabled
if ($rdpProperties -match "use udp:i:0") {
    Write-Host "`n✓ UDP is DISABLED (TCP only)" -ForegroundColor Green
} else {
    Write-Host "`n⚠ WARNING: UDP setting not found!" -ForegroundColor Red
}

# Verify SSO enabled
if ($rdpProperties -match "enablerdsaadauth:i:1") {
    Write-Host "✓ Entra SSO is ENABLED" -ForegroundColor Green
} else {
    Write-Host "⚠ WARNING: Entra SSO not found!" -ForegroundColor Red
}

Write-Host "`nNext Step: Create Application Group" -ForegroundColor Cyan
```

---

## Next Steps

1. ✓ Workspace created
2. ✓ Host pool(s) created with TCP-only and SSO enabled
3. ⏭ Create Application Groups (Part 3)
4. ⏭ Deploy session hosts from golden image (Guide 05)
5. ⏭ Assign RBAC to users (Guide 07)

---

**Document Version:** 1.0  
**Last Updated:** December 2, 2025
