# Step 11 - Testing & Validation Commands Reference

Quick reference for validating AVD deployment.

## Prerequisites

```bash
# Ensure authenticated
az account show

# Set variables
RG="RG-Azure-VDI-01"
LOCATION="centralus"
HOSTPOOL="avd-hostpool"
VNET="avd-vnet"
STORAGE_ACCOUNT="avdfslogix001"
```

## Resource Validation

### Check Resource Group

```bash
# Verify resource group exists
az group show --name "$RG" --output json

# List all resources in group
az resource list --resource-group "$RG" --output table

# Get resource group location
az group show --name "$RG" --query "location" -o tsv
```

### Validate VNet Deployment

```bash
# Show VNet details
az network vnet show \
  --resource-group "$RG" \
  --name "$VNET" \
  --output json

# List subnets
az network vnet subnet list \
  --resource-group "$RG" \
  --vnet-name "$VNET" \
  --output table

# Check subnet IP availability
az network vnet subnet show \
  --resource-group "$RG" \
  --vnet-name "$VNET" \
  --name "session-hosts" \
  --query "addressPrefix" -o tsv
```

### Validate Storage Account

```bash
# Show storage account
az storage account show \
  --resource-group "$RG" \
  --name "$STORAGE_ACCOUNT" \
  --output json

# Check HTTPS only enabled
az storage account show \
  --resource-group "$RG" \
  --name "$STORAGE_ACCOUNT" \
  --query "supportsHttpsTrafficOnly" -o tsv

# List file shares
az storage share list \
  --account-name "$STORAGE_ACCOUNT" \
  --output table

# Check file share quota
az storage share show \
  --account-name "$STORAGE_ACCOUNT" \
  --name "fslogix-profiles" \
  --query "quota" -o tsv
```

### Validate Host Pool

```bash
# Show host pool details
az desktopvirtualization hostpool show \
  --name "$HOSTPOOL" \
  --resource-group "$RG" \
  --output json

# Check host pool type
az desktopvirtualization hostpool show \
  --name "$HOSTPOOL" \
  --resource-group "$RG" \
  --query "hostPoolType" -o tsv

# List session hosts in host pool
az desktopvirtualization sessionhost list \
  --host-pool-name "$HOSTPOOL" \
  --resource-group "$RG" \
  --output table
```

## Session Host Validation

### Check Running VMs

```bash
# List all session host VMs
az vm list \
  --resource-group "$RG" \
  --query "[?contains(name, 'avd-host')].{name: name, provisioningState: provisioningState, powerState: powerState}" \
  --output table

# Get VM count
az vm list \
  --resource-group "$RG" \
  --query "[?contains(name, 'avd-host')] | length(@)" -o tsv
```

### Check VM Power State

```bash
#!/bin/bash

RG="RG-Azure-VDI-01"

echo "=== Session Host Power States ==="

az vm get-instance-view \
  --resource-group "$RG" \
  --ids $(az vm list --resource-group "$RG" --query "[?contains(name, 'avd-host')].id" -o tsv) \
  --query "[].{name: name, powerState: instanceView.statuses[?starts_with(code, 'PowerState')].displayStatus}" \
  --output table
```

### Validate VM Networking

```bash
# Get VM network interfaces
az vm show \
  --resource-group "$RG" \
  --name "avd-session-host-1" \
  --query "networkProfile.networkInterfaces" -o json

# Get VM IP addresses
az vm list-ip-addresses \
  --resource-group "$RG" \
  --output table

# Check specific VM IP
az vm show \
  --resource-group "$RG" \
  --name "avd-session-host-1" \
  --output json | jq '.networkProfile.networkInterfaces'
```

## Security Validation

### Check NSG Rules

```bash
# List NSG rules
az network nsg rule list \
  --resource-group "$RG" \
  --nsg-name "nsg-session-hosts" \
  --output table

# Check specific rule
az network nsg rule show \
  --resource-group "$RG" \
  --nsg-name "nsg-session-hosts" \
  --name "allow-rdp" \
  --output json
```

### Check RBAC Assignments

```bash
# List all role assignments in resource group
az role assignment list \
  --resource-group "$RG" \
  --output table

# Check specific group assignments
GROUP_ID=$(az ad group show --group "AVD-Users" --query id -o tsv)
az role assignment list \
  --assignee "$GROUP_ID" \
  --output table
```

### Validate Private Endpoints

```bash
# List private endpoints
az network private-endpoint list \
  --resource-group "$RG" \
  --output table

# Check private endpoint details
az network private-endpoint show \
  --resource-group "$RG" \
  --name "pe-storage" \
  --output json
```

## Connectivity Tests

### Test Azure CLI Connectivity

```bash
# Simple connectivity test
az account show

# Test subscription access
az vm list --output none && echo "Access OK"

# Test resource group access
az resource list --resource-group "$RG" --output none && echo "Access OK"
```

### Test VNet Connectivity (from session host)

```powershell
# Run on session host VM

# Test DNS resolution
Resolve-DnsName -Name "storage.windows.net"

# Test connectivity to storage
Test-NetConnection -ComputerName "avdfslogix001.file.core.windows.net" -Port 445

# Test connectivity to Azure AD
Test-NetConnection -ComputerName "login.microsoftonline.com" -Port 443
```

### Test File Share Access

```powershell
# Mount test on session host
$storageKey = "YOUR_STORAGE_KEY"
$mount = "\\avdfslogix001.file.core.windows.net\fslogix-profiles"

# Test mount
New-PSDrive -Name "FSLogix" -PSProvider "FileSystem" -Root $mount `
  -Credential $(New-Object -TypeName System.Management.Automation.PSCredential `
    -ArgumentList "Azure\avdfslogix001", (ConvertTo-SecureString -String $storageKey -AsPlainText -Force))

# List directory
Get-ChildItem -Path "FSLogix:\"

# Clean up
Remove-PSDrive -Name "FSLogix"
```

## Performance Testing

### Check VM Performance Metrics

```bash
# Get CPU metrics
az monitor metrics list \
  --resource "/subscriptions/<sub-id>/resourceGroups/$RG/providers/Microsoft.Compute/virtualMachines/avd-session-host-1" \
  --metric "Percentage CPU" \
  --output table
```

### Monitor Event Logs (PowerShell)

```powershell
# Run on session host

# Check System event log for errors
Get-EventLog -LogName System -EntryType Error -Newest 10

# Check AVD agent logs
Get-EventLog -LogName "Application" -Source "RDAgentBootLoader" -Newest 10

# Check network connectivity events
Get-EventLog -LogName System -Source "Tcpip" -Newest 10
```

## Deployment Validation Script

```bash
#!/bin/bash

RG="RG-Azure-VDI-01"
HOSTPOOL="avd-hostpool"
VNET="avd-vnet"
STORAGE="avdfslogix001"

echo "=== AVD Deployment Validation Report ==="
echo "Timestamp: $(date)"
echo "Resource Group: $RG"
echo ""

# 1. Resource Group
echo "=== 1. Resource Group Validation ==="
if az group exists --name "$RG" | grep -q "true"; then
  echo "✓ Resource group exists: $RG"
else
  echo "✗ Resource group NOT found: $RG"
fi
echo ""

# 2. VNet
echo "=== 2. Virtual Network Validation ==="
if az network vnet show --resource-group "$RG" --name "$VNET" &>/dev/null; then
  echo "✓ VNet exists: $VNET"
  SUBNET_COUNT=$(az network vnet subnet list --resource-group "$RG" --vnet-name "$VNET" --query "length(@)" -o tsv)
  echo "  Subnets: $SUBNET_COUNT"
else
  echo "✗ VNet NOT found: $VNET"
fi
echo ""

# 3. Storage Account
echo "=== 3. Storage Account Validation ==="
if az storage account show --resource-group "$RG" --name "$STORAGE" &>/dev/null; then
  echo "✓ Storage account exists: $STORAGE"
  az storage share list --account-name "$STORAGE" --query "[].name" -o tsv | while read SHARE; do
    echo "  File share: $SHARE"
  done
else
  echo "✗ Storage account NOT found: $STORAGE"
fi
echo ""

# 4. Host Pool
echo "=== 4. Host Pool Validation ==="
if az desktopvirtualization hostpool show --resource-group "$RG" --name "$HOSTPOOL" &>/dev/null; then
  echo "✓ Host pool exists: $HOSTPOOL"
  HP_TYPE=$(az desktopvirtualization hostpool show --resource-group "$RG" --name "$HOSTPOOL" --query "hostPoolType" -o tsv)
  echo "  Type: $HP_TYPE"
else
  echo "✗ Host pool NOT found: $HOSTPOOL"
fi
echo ""

# 5. Session Hosts
echo "=== 5. Session Host Validation ==="
VM_COUNT=$(az vm list --resource-group "$RG" --query "[?contains(name, 'avd-host')] | length(@)" -o tsv)
echo "Total session hosts: $VM_COUNT"

az vm list \
  --resource-group "$RG" \
  --query "[?contains(name, 'avd-host')].{name: name, state: powerState}" \
  --output table

echo ""
echo "=== Validation Complete ==="
```

## Remediation Commands

### If Issues Found

```bash
# Restart session host if unresponsive
az vm restart --resource-group "$RG" --name "avd-session-host-1"

# Start deallocated VMs
az vm start --resource-group "$RG" --ids $(az vm list --resource-group "$RG" --query "[?contains(name, 'avd-host')].id" -o tsv)

# Regenerate host pool registration token if expired
az desktopvirtualization hostpool update \
  --name "$HOSTPOOL" \
  --resource-group "$RG" \
  --registration-info expiration-time="2025-12-11T23:59:59Z" registration-token-operation="Update"

# Verify storage account connectivity
az storage account show --resource-group "$RG" --name "$STORAGE" --query "primaryEndpoints"
```

## Troubleshooting Steps

1. **Check Azure CLI authentication**: `az account show`
2. **Verify subscription**: `az account list --output table`
3. **Check resource access**: `az resource list --resource-group "$RG"`
4. **Test VM access**: `az vm get-instance-view --resource-group "$RG" --name "avd-session-host-1"`
5. **Check logs**: Review Azure Portal Activity Log or VM logs
6. **Test connectivity**: `ping`, `nslookup`, `Test-NetConnection` from host
7. **Verify permissions**: `az role assignment list --resource-group "$RG"`

## References

- [AVD Troubleshooting](https://learn.microsoft.com/en-us/azure/virtual-desktop/troubleshoot)
- [Diagnostics and Feedback](https://learn.microsoft.com/en-us/azure/virtual-desktop/diagnostics-role-service)
- [Monitoring and Alerts](https://learn.microsoft.com/en-us/azure/virtual-desktop/diagnostic-role-service)
