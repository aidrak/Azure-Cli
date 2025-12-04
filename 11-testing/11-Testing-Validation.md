# Testing and Validation for AVD

**Purpose:** Comprehensive testing before production migration

**Run these tests after:**
- Infrastructure deployed
- Session hosts created
- Policies configured
- RBAC assigned
- PowerShell with Az modules

---

## Automated Deployment (Recommended)

### Using the Automation Script

**Script:** `11-Testing-Validation.ps1` (PowerShell)

**Quick Start:**

```powershell
# 1. Login to Azure
Connect-AzAccount

# 2. Run comprehensive validation
.\11-Testing-Validation.ps1 `
  -ResourceGroupName "RG-Azure-VDI-01" `
  -HostPoolName "Pool-Pooled-Prod" `
  -WorkspaceName "AVD-Workspace-Prod" `
  -StorageAccountName "fslogix52847"

# 3. Or run with minimal parameters (workspace is required)
.\11-Testing-Validation.ps1 `
  -ResourceGroupName "RG-Azure-VDI-01" `
  -HostPoolName "Pool-Pooled-Prod" `
  -WorkspaceName "AVD-Workspace-Prod"
```

**What the script does:**
1. **Resource Group Validation** - Verifies resource group exists
2. **Host Pool Testing** - Checks host pool configuration, session limits, load balancing
3. **Session Host Validation** - Enumerates all session hosts, verifies available count
4. **Workspace Verification** - Confirms workspace created and accessible
5. **Application Group Validation** - Checks app groups linked to host pool
6. **Storage Testing** (optional) - Verifies FSLogix storage account accessible
7. **Summary Report** - Provides pass/fail/warning counts

**Expected Runtime:** 2-3 minutes

**Output:**
- Console output with colored results (green=pass, yellow=warning, red=fail)
- Summary section with counts of passed/failed/warned tests
- Clear indication of what's ready for production

**Important Notes:**
- Script is read-only; no resources are modified
- Safe to run multiple times
- Storage account parameter is optional (skips storage tests if not provided)
- All validation checks are infrastructure-level only (not user access testing)

**Verification:**
After running the script, you should see:
- ✓ Resource group exists
- ✓ Host pool exists with correct configuration
- ✓ Session hosts available (all or most showing "Available" status)
- ✓ Workspace accessible
- ✓ Application groups configured
- ✓ Storage account accessible (if provided)

---

## Manual Deployment (Alternative)

### Quick Validation Script

```powershell
# Run on session host as administrator
Write-Host "=== AVD VALIDATION SUITE ===" -ForegroundColor Cyan

# Network
Write-Host "`n[1] FSLogix Storage..." -ForegroundColor Yellow
# Replace YOUR_STORAGE_ACCOUNT with your storage account name from Guide 02
$storageAccountName = "YOUR_STORAGE_ACCOUNT"
$storage = Test-NetConnection -ComputerName "$storageAccountName.file.core.windows.net" -Port 445
if ($storage.TcpTestSucceeded) { Write-Host "✓ Reachable" -ForegroundColor Green } else { Write-Host "✗ Failed" -ForegroundColor Red }

# DNS (Private Endpoint)
Write-Host "`n[2] DNS Resolution..." -ForegroundColor Yellow
$dns = Resolve-DnsName "$storageAccountName.file.core.windows.net" -Type A
$privateIp = $dns | Where-Object { $_.IPAddress -match '^10\.' } | Select-Object -First 1 -ExpandProperty IPAddress
if ($privateIp) { Write-Host "✓ Private IP: $privateIp" -ForegroundColor Green } else { Write-Host "⚠ Public IP" -ForegroundColor Yellow }

# Entra Join
Write-Host "`n[3] Entra Join..." -ForegroundColor Yellow
$dsreg = dsregcmd /status | Select-String "AzureAdJoined : YES"
if ($dsreg) { Write-Host "✓ Joined" -ForegroundColor Green } else { Write-Host "✗ Not joined" -ForegroundColor Red }

# Kerberos
Write-Host "`n[4] Kerberos..." -ForegroundColor Yellow
$kerb = klist get "cifs/$storageAccountName.file.core.windows.net" 2>&1
if ($LASTEXITCODE -eq 0) { Write-Host "✓ Ticket obtained" -ForegroundColor Green } else { Write-Host "✗ Failed" -ForegroundColor Red }

# FSLogix
Write-Host "`n[5] FSLogix Configuration..." -ForegroundColor Yellow
$fslogix = Get-ItemProperty -Path "HKLM:\SOFTWARE\FSLogix\Profiles" -Name "Enabled" -ErrorAction SilentlyContinue
if ($fslogix.Enabled -eq 1) { Write-Host "✓ Enabled" -ForegroundColor Green } else { Write-Host "✗ Not configured" -ForegroundColor Red }

# TCP Only
Write-Host "`n[6] TCP-Only Mode..." -ForegroundColor Yellow
$tcp = Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" -Name "SelectTransport" -ErrorAction SilentlyContinue
if ($tcp.SelectTransport -eq 1) { Write-Host "✓ TCP only" -ForegroundColor Green } else { Write-Host "⚠ May use UDP" -ForegroundColor Yellow }

Write-Host "`n=== VALIDATION COMPLETE ===" -ForegroundColor Cyan
```

---

## User Login Test

### Steps:

1. **Launch Windows App** (https://aka.ms/AVDClient)
2. **Sign in** with test user Entra ID credentials
3. **Expected:**
   - ✓ Desktop appears without credential prompt (SSO)
   - ✓ Launches within 10-15 seconds
   - ✓ Connection icon shows **TCP** transport (not UDP)

### Check Profile Creation:

```powershell
# After user logs in, check VHD
frxcmd.exe list-vhds

# Check storage (replace YOUR_STORAGE_ACCOUNT with your storage account name from Guide 02)
Get-ChildItem "\\YOUR_STORAGE_ACCOUNT.file.core.windows.net\fslogix-profiles" -Filter "*USERNAME*.vhdx"
```

---

## Performance Check

```powershell
# Resource usage
$cpu = [math]::Round((Get-Counter '\Processor(_Total)\% Processor Time').CounterSamples.CookedValue, 2)
$mem = Get-CimInstance Win32_OperatingSystem
$memPercent = [math]::Round((($mem.TotalVisibleMemorySize - $mem.FreePhysicalMemory) / $mem.TotalVisibleMemorySize) * 100, 2)

Write-Host "CPU: $cpu% | Memory: $memPercent%"

# Target: CPU < 80%, Memory < 90%
```

---

## Security Check

```powershell
# No public IPs on session hosts
Get-AzVM -ResourceGroupName "RG-Azure-VDI-01" | Where-Object { $_.Name -like "avd-pool-*" } | ForEach-Object {
    $nic = Get-AzNetworkInterface | Where-Object { $_.Id -eq $_.NetworkProfile.NetworkInterfaces[0].Id }
    if ($nic.IpConfigurations[0].PublicIpAddress) {
        Write-Host "⚠ Public IP on $($_.Name)" -ForegroundColor Yellow
    }
}

# Storage public access disabled
$storage = Get-AzStorageAccount -ResourceGroupName "RG-Azure-VDI-01" -Name "fslogix112125"
if ($storage.PublicNetworkAccess -eq "Disabled") {
    Write-Host "✓ Storage public access disabled" -ForegroundColor Green
}
```

---

## Test Checklist

```
Infrastructure:
□ FSLogix storage reachable
□ DNS resolves to private IP
□ Entra joined
□ Kerberos working
□ FSLogix configured
□ TCP-only enforced

User Experience:
□ SSO working (no credential prompt)
□ Desktop loads < 30 sec
□ TCP transport confirmed
□ Profile created and roaming
□ File server accessible

Performance:
□ CPU < 80% under load
□ Memory < 90%
□ 10+ concurrent sessions stable

Security:
□ No public IPs
□ Storage access restricted
□ RBAC configured correctly
```

---

## Common Issues

| Issue | Check | Fix |
|-------|-------|-----|
| No SSO | RDP property `enablerdsaadauth:i:1` | Update host pool RDP properties |
| Profile fails | Storage RBAC | Assign "Storage File Data SMB Share Contributor" |
| UDP still used | Registry `SelectTransport` | Verify Intune policy, restart |
| DNS public IP | Private DNS zone | Link VNet to private DNS zone |

---

**Next:** Begin migration (Guide 12)
