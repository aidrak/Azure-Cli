# Step 10 - Autoscaling Commands Reference

Quick reference for AVD autoscaling and scaling plans.

## Prerequisites

```bash
# Verify authenticated
az account show

# Register provider (if needed)
az provider register --namespace Microsoft.DesktopVirtualization
```

## Scaling Plan Operations

### Create Scaling Plan

```bash
# Create autoscaling plan
az desktopvirtualization scalingplan create \
  --resource-group "RG-Azure-VDI-01" \
  --name "avd-scaling-plan" \
  --location "centralus" \
  --time-zone "Central Standard Time" \
  --description "Autoscaling plan for AVD host pool" \
  --friendly-name "AVD Scaling Plan"
```

**Parameters:**
- `--time-zone`: Timezone for schedules
- Common timezones: "Central Standard Time", "Eastern Standard Time", "Pacific Standard Time"

### Add Host Pool to Scaling Plan

```bash
# Get host pool resource ID
HOSTPOOL_ID=$(az desktopvirtualization hostpool show \
  --resource-group "RG-Azure-VDI-01" \
  --name "avd-hostpool" \
  --query id -o tsv)

# Add to scaling plan
az rest --method POST \
  --uri "https://management.azure.com$HOSTPOOL_ID/scaling-plans/avd-scaling-plan" \
  --body '{"hostPoolReference":"'"$HOSTPOOL_ID"'"}'
```

## Scaling Schedules

### Create Ramp-Up Schedule (Morning)

```bash
# Schedule to start VMs in morning before peak hours
az desktopvirtualization scalingplan schedule create \
  --scalingplan-name "avd-scaling-plan" \
  --resource-group "RG-Azure-VDI-01" \
  --name "morning-rampup" \
  --days-of-week "Monday" "Tuesday" "Wednesday" "Thursday" "Friday" \
  --start-time "06:00" \
  --ramp-up-capacity-threshold-percent 80 \
  --ramp-up-load-balancing-algorithm "BreadthFirst" \
  --peak-start-time "08:00" \
  --peak-capacity-threshold-percent 90 \
  --peak-load-balancing-algorithm "DepthFirst" \
  --ramp-down-start-time "17:00" \
  --ramp-down-capacity-threshold-percent 50 \
  --ramp-down-load-balancing-algorithm "BreadthFirst" \
  --ramp-down-minimum-hosts-percent 10 \
  --ramp-down-force-logoff-users "true" \
  --ramp-down-wait-time-minutes 15 \
  --ramp-down-notification-message "Your session will end in 15 minutes" \
  --off-peak-start-time "22:00" \
  --off-peak-capacity-threshold-percent 10 \
  --off-peak-load-balancing-algorithm "BreadthFirst" \
  --off-peak-minimum-hosts-percent 5
```

### Create Custom Schedule via PowerShell

```powershell
# More flexible schedule configuration via PowerShell
$scalingPlan = Get-AzDesktopVirtualizationScalingPlan `
  -ResourceGroupName "RG-Azure-VDI-01" `
  -Name "avd-scaling-plan"

# Configure schedule
$schedule = @{
    dayOfWeek = @("Monday", "Tuesday", "Wednesday", "Thursday", "Friday")
    rampUpStartTime = "06:00"
    rampUpLoadBalancingAlgorithm = "BreadthFirst"
    rampUpMinimumHostsPercent = 20
    rampUpCapacityThresholdPercent = 80
    peakStartTime = "08:00"
    peakLoadBalancingAlgorithm = "DepthFirst"
    peakMinimumHostsPercent = 100
    peakCapacityThresholdPercent = 90
    rampDownStartTime = "17:00"
    rampDownLoadBalancingAlgorithm = "BreadthFirst"
    rampDownMinimumHostsPercent = 10
    rampDownCapacityThresholdPercent = 50
    rampDownForceLogoffUsers = $true
    rampDownWaitTimeMinutes = 15
    rampDownNotificationMessage = "Your session will end in 15 minutes"
    offPeakStartTime = "22:00"
    offPeakLoadBalancingAlgorithm = "BreadthFirst"
    offPeakMinimumHostsPercent = 5
}

# Note: Actual cmdlet may vary; check Azure PowerShell documentation
```

## List and Manage Scaling Plans

### List All Scaling Plans

```bash
az desktopvirtualization scalingplan list \
  --resource-group "RG-Azure-VDI-01" \
  --output table
```

### Show Scaling Plan Details

```bash
az desktopvirtualization scalingplan show \
  --resource-group "RG-Azure-VDI-01" \
  --name "avd-scaling-plan" \
  --output json
```

### Update Scaling Plan

```bash
# Update description
az desktopvirtualization scalingplan update \
  --resource-group "RG-Azure-VDI-01" \
  --name "avd-scaling-plan" \
  --description "Updated scaling plan description"

# Update timezone
az desktopvirtualization scalingplan update \
  --resource-group "RG-Azure-VDI-01" \
  --name "avd-scaling-plan" \
  --time-zone "Eastern Standard Time"
```

### Delete Scaling Plan

```bash
az desktopvirtualization scalingplan delete \
  --resource-group "RG-Azure-VDI-01" \
  --name "avd-scaling-plan" \
  --yes
```

## Alternative: PowerShell Autoscaling Setup

```powershell
# Note: AVD autoscaling via PowerShell requires latest modules
Install-Module -Name Az.DesktopVirtualization -Force

# Get scaling plan
$scalingPlan = Get-AzDesktopVirtualizationScalingPlan `
  -ResourceGroupName "RG-Azure-VDI-01" `
  -Name "avd-scaling-plan"

# Get host pool
$hostPool = Get-AzDesktopVirtualizationHostpool `
  -ResourceGroupName "RG-Azure-VDI-01" `
  -Name "avd-hostpool"

# Associate host pool with scaling plan
$scalingPlan | Add-AzDesktopVirtualizationHostPoolReference `
  -HostPoolReference @($hostPool)

# Get assignments
$scalingPlan | Get-AzDesktopVirtualizationHostPoolReference
```

## Monitoring Scaling Plan

### Check Scaling Plan Status

```bash
# Get scaling plan details
az rest --method GET \
  --uri "/subscriptions/<sub-id>/resourceGroups/RG-Azure-VDI-01/providers/Microsoft.DesktopVirtualization/scalingPlans/avd-scaling-plan?api-version=2023-10-16-preview" \
  --output json | jq .
```

### Monitor VM Count

```bash
#!/bin/bash

HOSTPOOL="avd-hostpool"
RG="RG-Azure-VDI-01"

echo "=== Monitoring Session Hosts ==="

while true; do
  RUNNING=$(az vm list \
    --resource-group "$RG" \
    --query "[?contains(name, 'avd-')].{name: name, state: powerState}" \
    --output table)

  echo "$(date): $RUNNING"
  sleep 60
done
```

## Best Practices

### Recommended Schedule Configuration

| Period | Load Balancer | Min Hosts | Max Capacity | Actions |
|--------|---------------|-----------|-------------|---------|
| Off-Peak (10PM-6AM) | Breadth First | 5-10% | 20% | Deallocate non-essential VMs |
| Ramp-Up (6AM-8AM) | Breadth First | 20% | 80% | Start VMs gradually |
| Peak (8AM-5PM) | Depth First | 100% | 90% | All VMs available |
| Ramp-Down (5PM-10PM) | Breadth First | 10% | 50% | Graceful shutdown |

### Cost Optimization

```bash
# Example: Aggressive cost optimization
# Off-peak: Only 1 VM running
# Peak: All VMs available
# Saves: ~60-70% compute costs

# Off-peak minimum hosts: 1
# Peak minimum hosts: 100%
# Ramp-up/down gradual transitions
```

## Troubleshooting

### Scaling Not Working

```bash
# Check if host pool is registered
az desktopvirtualization hostpool show \
  --resource-group "RG-Azure-VDI-01" \
  --name "avd-hostpool" \
  --output json | jq '.registrationInfo'

# Verify scaling plan assignments
az rest --method GET \
  --uri "/subscriptions/<sub-id>/resourceGroups/RG-Azure-VDI-01/providers/Microsoft.DesktopVirtualization/scalingPlans" \
  --output json | jq '.value[].properties'
```

### VMs Not Starting/Stopping

- Check VM permissions and quotas
- Verify subnet has available IP addresses
- Check if VMs are in stopped vs deallocated state
- Review scaling plan schedule times against current timezone

### Schedule Not Applying

- Verify timezone is correct: `timedatectl status`
- Check schedule times are in 24-hour format
- Ensure host pool is linked to scaling plan
- Wait 5-10 minutes after creating schedule for policy to apply

## Complete Autoscaling Setup Example

```bash
#!/bin/bash

# Variables
RG="RG-Azure-VDI-01"
SCALING_PLAN="avd-scaling-plan"
HOSTPOOL="avd-hostpool"
LOCATION="centralus"
TIMEZONE="Central Standard Time"

echo "=== AVD Autoscaling Setup ==="

# Create scaling plan
echo "Creating scaling plan..."
az desktopvirtualization scalingplan create \
  --resource-group "$RG" \
  --name "$SCALING_PLAN" \
  --location "$LOCATION" \
  --time-zone "$TIMEZONE" \
  --description "Production autoscaling plan"

# Get host pool ID
HOSTPOOL_ID=$(az desktopvirtualization hostpool show \
  --resource-group "$RG" \
  --name "$HOSTPOOL" \
  --query id -o tsv)

echo "Scaling plan created: $SCALING_PLAN"
echo "Host pool: $HOSTPOOL_ID"

# Note: Adding host pool to scaling plan typically requires PowerShell
# See PowerShell section above

echo "Scaling plan setup complete"
```

## References

- [AVD Autoscaling](https://learn.microsoft.com/en-us/azure/virtual-desktop/autoscale-scaling-plan)
- [Scaling Plan Schedules](https://learn.microsoft.com/en-us/azure/virtual-desktop/autoscale-scaling-plan?tabs=powershell)
- [Cost Optimization](https://learn.microsoft.com/en-us/azure/virtual-desktop/autoscale-operations-insights)
- [Load Balancing Options](https://learn.microsoft.com/en-us/azure/virtual-desktop/troubleshoot-vm-configuration#load-balancing-concepts)
