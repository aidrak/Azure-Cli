# Autoscaling Configuration for AVD

**Purpose:** Configure cost-saving autoscaling for host pool based on demand

**Prerequisites:**
- Host pool deployed: `Pool-Pooled-Prod`
- Session hosts deployed (10-40 VMs)
- PowerShell with Az.DesktopVirtualization and Az.Accounts modules
- Logged into Azure

**Benefits:**
- Automatically power on/off VMs based on schedule
- Reduce costs during off-hours
- Maintain performance during peak times

---

## Automated Deployment (Recommended)

### Using the Automation Script

**Script:** `10-Autoscaling-Setup.ps1` (PowerShell)

**Quick Start:**

```powershell
# 1. Login to Azure
Connect-AzAccount

# 2. Run the script with defaults
.\10-Autoscaling-Setup.ps1 `
  -ResourceGroupName "RG-Azure-VDI-01" `
  -HostPoolName "Pool-Pooled-Prod" `
  -ScalingPlanName "ScalingPlan-Pooled-Prod"

# 3. Or customize timezone and plan name
.\10-Autoscaling-Setup.ps1 `
  -ResourceGroupName "RG-Azure-VDI-01" `
  -HostPoolName "Pool-Pooled-Prod" `
  -ScalingPlanName "ScalingPlan-Pooled-Prod" `
  -TimeZone "Pacific Standard Time"
```

**What the script does:**
1. Validates prerequisites (host pool exists, Azure login)
2. Grants AVD service principal `Desktop Virtualization Power On Off Contributor` role
3. Creates scaling plan `ScalingPlan-Pooled-Prod`
4. Documents recommended scaling schedules:
   - **Ramp Up** (07:00): Minimum 20% sessions, BreadthFirst load balancing
   - **Peak** (09:00): Minimum 100% sessions, DepthFirst load balancing
   - **Ramp Down** (17:00): Minimum 10% sessions, BreadthFirst
   - **Off-Peak** (19:00): Minimum 5% sessions, stops all hosts on weekends
5. Assigns scaling plan to host pool
6. Documents manual steps for capacity threshold alerts

**Expected Runtime:** 2-3 minutes

**Important Notes:**
- Default schedule is Central Standard Time; adjust TimeZone parameter for your region
- Schedules are recommendations; adjust based on your organization's working hours
- Off-peak period stops session hosts on weekends completely to save costs
- Requires Azure PowerShell SDK 1.0.0+ for scaling plans

**Verification:**
```powershell
# Check scaling plan created
Get-AzWvdScalingPlan -ResourceGroupName "RG-Azure-VDI-01" -Name "ScalingPlan-Pooled-Prod"

# Verify host pool assigned
Get-AzWvdHostPoolSchedule -ResourceGroupName "RG-Azure-VDI-01" -HostPoolName "Pool-Pooled-Prod"
```

---

## Manual Deployment (Alternative)

### Part 1: Prerequisites Check

### Assign Required RBAC Role

#### Option A: Azure Portal

1. Navigate to **Subscription** → **Access Control (IAM)**
2. Click **+ Add** → **Add role assignment**
3. Search: `Desktop Virtualization Power On Off Contributor`
4. **Members** tab:
   - Assign to: **Managed identity**
   - Select: **Azure Virtual Desktop** (service principal)
5. **Review + assign**

#### Option B: Azure CLI

```bash
# Get subscription ID
subscriptionId=$(az account show --query id -o tsv)

# Get Azure Virtual Desktop service principal
avdSpId=$(az ad sp list --filter "displayName eq 'Azure Virtual Desktop'" --query "[0].id" -o tsv)

# Assign role
az role assignment create \
  --assignee $avdSpId \
  --role "Desktop Virtualization Power On Off Contributor" \
  --scope "/subscriptions/$subscriptionId"

echo "✓ RBAC role assigned"
```

#### Option C: PowerShell

```powershell
# Get subscription
$subscription = Get-AzSubscription | Select-Object -First 1

# Get service principal
$avdSp = Get-AzADServicePrincipal -DisplayName "Azure Virtual Desktop"

# Assign role
New-AzRoleAssignment `
    -ObjectId $avdSp.Id `
    -RoleDefinitionName "Desktop Virtualization Power On Off Contributor" `
    -Scope "/subscriptions/$($subscription.Id)"

Write-Host "✓ RBAC role assigned" -ForegroundColor Green
```

---

### Verify Host Pool Settings

```powershell
# Check max session limit
$hostPool = Get-AzWvdHostPool `
    -ResourceGroupName "RG-Azure-VDI-01" `
    -Name "Pool-Pooled-Prod"

Write-Host "Max session limit: $($hostPool.MaxSessionLimit)" -ForegroundColor Cyan
# Should be 12 or configured value

# If not set:
# Update-AzWvdHostPool -ResourceGroupName "RG-Azure-VDI-01" -Name "Pool-Pooled-Prod" -MaxSessionLimit 12
```

---

## Part 2: Create Scaling Plan

### Option A: Azure Portal

1. **Navigate to Scaling Plans**
   - Search "Azure Virtual Desktop" → **Scaling plans**
   - Click **+ Create**

2. **Basics Tab**
   - Subscription: Your subscription
   - Resource group: `RG-Azure-VDI-01`
   - Name: `Production-Weekday-Scaling`
   - Region: `Central US` (same as host pool)
   - Time zone: `(US) Central Time` (adjust for your location)
   - Click **Next: Schedules**

3. **Schedules Tab - Add Weekday Schedule**
   - Click **+ Add schedule**
   
   **General:**
   - Name: `Weekday-Schedule`
   - Repeat on: Monday, Tuesday, Wednesday, Thursday, Friday
   
   **Ramp-Up Phase:**
   - Start time: `7:00 AM`
   - Load balancing: **Breadth-first**
   - Minimum % of hosts: `25%` (10 VMs if you have 40 total)
   - Capacity threshold: `70%`
   
   **Peak Hours:**
   - Start time: `9:00 AM`
   - Load balancing: **Breadth-first**
   - Capacity threshold: `70%`
   
   **Ramp-Down Phase:**
   - Start time: `5:00 PM`
   - Load balancing: **Depth-first**
   - Minimum % of hosts: `10%` (4 VMs)
   - Capacity threshold: `80%`
   - Stop hosts when: **Sessions below capacity threshold**
   - Force logoff users: **Yes**
   - Wait time (minutes): `20`
   - Notification message: `Your session will end in 20 minutes. Please save your work.`
   
   **Off-Peak Hours:**
   - Start time: `7:00 PM`
   - Load balancing: **Depth-first**
   - Minimum % of hosts: `5%` (2 VMs)
   - Capacity threshold: `90%`
   
   - Click **Add**

4. **Add Weekend Schedule**
   - Click **+ Add schedule** again
   
   **General:**
   - Name: `Weekend-OffPeak`
   - Repeat on: Saturday, Sunday
   
   **Off-Peak (24 hours):**
   - Start time: `12:00 AM`
   - Load balancing: **Depth-first**
   - Minimum % of hosts: `5%` (2 VMs)
   - Capacity threshold: `85%`
   
   - Click **Add**
   - Click **Next: Host pool assignments**

5. **Host Pool Assignments Tab**
   - Click **+ Add host pool**
   - Select: `Pool-Pooled-Prod`
   - Enable autoscale: **Yes** ⚠️
   - Click **Add**
   - Click **Next: Tags**

6. **Tags** → **Next: Review + create** → **Create**

---

### Option B: Azure CLI

```bash
resourceGroup="RG-Azure-VDI-01"
scalingPlanName="Production-Weekday-Scaling"
location="centralus"
hostPoolId="/subscriptions/<sub-id>/resourceGroups/RG-Azure-VDI-01/providers/Microsoft.DesktopVirtualization/hostPools/Pool-Pooled-Prod"

# Create scaling plan with weekday schedule
az desktopvirtualization scaling-plan create \
  --resource-group $resourceGroup \
  --name $scalingPlanName \
  --location $location \
  --time-zone "Central Standard Time" \
  --schedules '[
    {
      "name": "Weekday-Schedule",
      "daysOfWeek": ["Monday","Tuesday","Wednesday","Thursday","Friday"],
      "rampUpStartTime": {"hour": 7, "minute": 0},
      "rampUpLoadBalancingAlgorithm": "BreadthFirst",
      "rampUpMinimumHostsPct": 25,
      "rampUpCapacityThresholdPct": 70,
      "peakStartTime": {"hour": 9, "minute": 0},
      "peakLoadBalancingAlgorithm": "BreadthFirst",
      "rampDownStartTime": {"hour": 17, "minute": 0},
      "rampDownLoadBalancingAlgorithm": "DepthFirst",
      "rampDownMinimumHostsPct": 10,
      "rampDownCapacityThresholdPct": 80,
      "rampDownForceLogoffUsers": true,
      "rampDownWaitTimeMinutes": 20,
      "rampDownNotificationMessage": "Your session will end in 20 minutes. Please save your work.",
      "rampDownStopHostsWhen": "ZeroSessions",
      "offPeakStartTime": {"hour": 19, "minute": 0},
      "offPeakLoadBalancingAlgorithm": "DepthFirst"
    }
  ]' \
  --host-pool-references "[{\"hostPoolArmPath\":\"$hostPoolId\",\"scalingPlanEnabled\":true}]"

echo "✓ Scaling plan created"
```

**Note:** Azure CLI JSON formatting can be tricky. Use Portal method for easier setup.

---

### Option C: PowerShell

```powershell
$resourceGroup = "RG-Azure-VDI-01"
$scalingPlanName = "Production-Weekday-Scaling"
$location = "centralus"
$timeZone = "Central Standard Time"
$hostPoolName = "Pool-Pooled-Prod"

# Get host pool
$hostPool = Get-AzWvdHostPool -ResourceGroupName $resourceGroup -Name $hostPoolName

# Create scaling plan
Write-Host "Creating scaling plan..." -ForegroundColor Cyan

# Weekday schedule
$weekdaySchedule = @{
    Name = "Weekday-Schedule"
    DaysOfWeek = @("Monday", "Tuesday", "Wednesday", "Thursday", "Friday")
    RampUpStartTime = @{ Hour = 7; Minute = 0 }
    RampUpLoadBalancingAlgorithm = "BreadthFirst"
    RampUpMinimumHostsPct = 25
    RampUpCapacityThresholdPct = 70
    PeakStartTime = @{ Hour = 9; Minute = 0 }
    PeakLoadBalancingAlgorithm = "BreadthFirst"
    RampDownStartTime = @{ Hour = 17; Minute = 0 }
    RampDownLoadBalancingAlgorithm = "DepthFirst"
    RampDownMinimumHostsPct = 10
    RampDownCapacityThresholdPct = 80
    RampDownForceLogoffUsers = $true
    RampDownWaitTimeMinutes = 20
    RampDownNotificationMessage = "Your session will end in 20 minutes. Please save your work."
    RampDownStopHostsWhen = "ZeroSessions"
    OffPeakStartTime = @{ Hour = 19; Minute = 0 }
    OffPeakLoadBalancingAlgorithm = "DepthFirst"
}

# Create via New-AzWvdScalingPlan
# Note: PowerShell cmdlet support may vary by Az.DesktopVirtualization module version
# Recommend using Azure Portal for easiest setup

Write-Host "⚠️ For complex schedules, use Azure Portal method" -ForegroundColor Yellow
```

---

## Part 3: Verify Autoscaling

### Check Scaling Plan Status

#### Azure Portal

1. Azure Virtual Desktop → **Scaling plans** → `Production-Weekday-Scaling`
2. **Properties:**
   - Status should show enabled
   - Host pool assignments should show `Pool-Pooled-Prod`

#### Azure CLI

```bash
az desktopvirtualization scaling-plan show \
  --resource-group "RG-Azure-VDI-01" \
  --name "Production-Weekday-Scaling" \
  --query "{name:name, hostPools:hostPoolReferences}" \
  --output table
```

---

### Monitor Autoscaling in Action

```powershell
# Check session host power states
$sessionHosts = Get-AzWvdSessionHost `
    -ResourceGroupName "RG-Azure-VDI-01" `
    -HostPoolName "Pool-Pooled-Prod"

Write-Host "=== SESSION HOST POWER STATES ===" -ForegroundColor Cyan
foreach ($host in $sessionHosts) {
    $vmName = $host.Name.Split('/')[1].Split('.')[0]
    $vm = Get-AzVM -ResourceGroupName "RG-Azure-VDI-01" -Name $vmName -Status
    $powerState = ($vm.Statuses | Where-Object { $_.Code -like "PowerState/*" }).DisplayStatus
    
    Write-Host "$vmName : $powerState" -ForegroundColor $(if ($powerState -eq "VM running") { "Green" } else { "Yellow" })
}

# Expected during off-peak: Only 5% (2 VMs) running
# Expected during peak: 70%+ VMs running based on load
```

---

## Part 4: Testing Autoscaling

### Test Ramp-Up (Monday 7 AM)

1. **Before 7 AM:**
   - Check session hosts → Should see minimal VMs running (5% = 2 VMs)

2. **At 7 AM:**
   - Autoscaling triggers ramp-up
   - Check after 5 minutes → Should see 25% (10 VMs) powered on

3. **At 9 AM (Peak):**
   - Additional VMs power on based on capacity threshold (70%)
   - If load exceeds 70% on running hosts → More VMs start

### Test Ramp-Down (Monday 5 PM)

1. **At 5 PM:**
   - Load balancing switches to Depth-first
   - New sessions directed to existing hosts
   - Lightly loaded hosts drain sessions

2. **After 5:20 PM:**
   - Hosts with zero sessions for 20 minutes → Shut down
   - Users get 20-minute warning before forced logoff

3. **At 7 PM (Off-Peak):**
   - Minimum 5% (2 VMs) remain running
   - All other hosts deallocated

---

## Understanding Capacity Thresholds

**Capacity Threshold = 70% means:**
- Max sessions per host: 12
- 70% capacity: 8.4 sessions (rounds to 8-9)
- If all running hosts reach 8-9 sessions → Start another VM

**Example with 40 total VMs:**

| Phase | Time | Min Hosts | Running | Capacity | Behavior |
|-------|------|-----------|---------|----------|----------|
| Off-Peak | 10 PM - 7 AM | 5% (2) | 2 | 90% | Keep 2 VMs always on |
| Ramp-Up | 7 AM - 9 AM | 25% (10) | 10+ | 70% | Power on 10 VMs minimum |
| Peak | 9 AM - 5 PM | N/A | 10-40 | 70% | Scale based on load |
| Ramp-Down | 5 PM - 7 PM | 10% (4) | 4-10 | 80% | Drain to 4 VMs |

---

## Customization Options

### Adjust for Your Environment

**Heavy morning load (8 AM rush):**
```
Ramp-Up Start: 6:30 AM
Minimum Hosts: 35% (14 VMs)
```

**Light weekends but some usage:**
```
Weekend Min Hosts: 10% (4 VMs)
Weekend Capacity: 75%
```

**Global team (24/7 operations):**
```
Use only Peak phase
Keep 30% minimum always running
```

### Notification Message Customization

Examples:
- `"System maintenance in 20 minutes. Please save and log off."`
- `"Your session will disconnect in 20 minutes due to scheduled scaling."`
- `"Please save your work. The system will log you off in 20 minutes."`

---

## Cost Savings Calculation

**Before Autoscaling:**
- 40 VMs × 24 hours × 30 days = 28,800 VM-hours/month
- Cost: ~$28,800/month (at $1/hour example rate)

**After Autoscaling:**
- Off-Peak (7 PM - 7 AM): 2 VMs × 12 hours = 24 VM-hours/day
- Ramp-Up/Peak/Ramp-Down: Avg 20 VMs × 12 hours = 240 VM-hours/day
- Total per day: 264 VM-hours
- Month: 264 × 30 = 7,920 VM-hours
- **Cost: ~$7,920/month**

**Savings: 72% (~$20,880/month)**

---

## Troubleshooting

### Issue: VMs not powering on during ramp-up

**Checks:**
1. Verify RBAC role assigned to "Azure Virtual Desktop" service principal
2. Check scaling plan is enabled
3. Verify host pool is assigned to scaling plan
4. Wait 15 minutes for first cycle

**Solution:**
```powershell
# Re-assign RBAC if needed
$subscription = Get-AzSubscription | Select-Object -First 1
$avdSp = Get-AzADServicePrincipal -DisplayName "Azure Virtual Desktop"

New-AzRoleAssignment `
    -ObjectId $avdSp.Id `
    -RoleDefinitionName "Desktop Virtualization Power On Off Contributor" `
    -Scope "/subscriptions/$($subscription.Id)"
```

### Issue: Users complaining about forced logoff

**Adjust settings:**
1. Increase wait time: 20 → 30 minutes
2. Adjust ramp-down start time: 5 PM → 6 PM
3. Change capacity threshold: 80% → 90% (keep more hosts running)

### Issue: Too many VMs running during off-peak

**Check:**
- Minimum % hosts setting
- Capacity threshold too low
- Active sessions preventing shutdown

**Solution:**
- Lower minimum %: 10% → 5%
- Review who's working late/early
- Consider excluding certain users from forced logoff

---

## Advanced: Multiple Scaling Plans

**Scenario:** Different schedules for different user groups

**Example:**
1. **Plan A:** Standard users (9-5)
   - Host pool: `Pool-Pooled-Prod`
   - Schedule: Weekday 7 AM - 7 PM

2. **Plan B:** 24/7 operations
   - Host pool: `Pool-24x7-Ops`
   - Schedule: Always 50% minimum, no forced logoff

**Note:** One host pool = one scaling plan

---

## Monitoring and Alerts

### Set Up Alerts

```powershell
# Example: Alert when >90% capacity
# Create via Azure Monitor → Alerts → New alert rule
# Metric: Session Count
# Condition: When session count > 90% of max capacity
# Action: Email ops team
```

### Review Insights

1. Azure Virtual Desktop → Host pools → `Pool-Pooled-Prod`
2. **Insights** tab
3. Review:
   - Session count over time
   - Host utilization
   - Autoscaling events

---

## Best Practices

✅ **Do:**
- Start conservative (higher minimums)
- Monitor for 1 week before optimizing
- Give users 20-30 minute warning
- Keep 5-10% minimum for immediate availability
- Test during maintenance windows first

❌ **Don't:**
- Set minimum to 0% (slow first login)
- Use aggressive capacity thresholds initially
- Force logoff without warning
- Change multiple settings at once

---

## Next Steps

1. ✓ Autoscaling configured
2. ✓ RBAC assigned
3. ⏭ Monitor for 1 week
4. ⏭ Adjust based on usage patterns
5. ⏭ Review cost savings
6. ⏭ Document final configuration

---

## Configuration Reference

**Scaling Plan:** `Production-Weekday-Scaling`  
**Host Pool:** `Pool-Pooled-Prod`  
**Time Zone:** Central Standard Time

**Weekday Schedule:**
- Ramp-Up: 7:00 AM (25% min, 70% capacity)
- Peak: 9:00 AM - 5:00 PM (70% capacity)
- Ramp-Down: 5:00 PM (10% min, 80% capacity, 20 min warning)
- Off-Peak: 7:00 PM (5% min, 90% capacity)

**Weekend Schedule:**
- Off-Peak 24/7 (5% min, 85% capacity)

---

**Document Version:** 1.0  
**Last Updated:** December 2, 2025
