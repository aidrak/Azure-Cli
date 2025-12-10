# AVD Authentication & SSO Fix - avd-pool-0

**Date:** 2025-12-08
**Issue:** Authentication error 0x0 and SSO not working
**Session Host:** avd-pool-0
**Host Pool:** hp-pooled-prod

---

## Diagnosed Issues

### 1. Primary Refresh Token (PRT) Missing
- **Status:** `AzureAdPrt: NO`
- **Impact:** SSO cannot function without PRT
- **Root Cause:** No Entra ID user has signed into Windows on the session host VM yet

### 2. Multiple Authentication Errors
- 18 AAD authentication errors in the last 2 hours
- Error types:
  - `Logon failure. Status: 0xC0000022` (Access Denied)
  - `sidtoname` API HTTP 400 errors
  - `Lookup name from SID returned error: 0xC00485D3`

### 3. Host Pool SSO Configuration
- **Status:** ✅ SSO enabled in host pool (`enablerdsaadauth:i:1`)
- **Session Host:** ✅ Entra ID joined
- **PRT:** ❌ Not available (no user signed in)

---

## The Solution

The session host is properly configured for SSO, but **requires a user to sign in locally to Windows first** to establish a Primary Refresh Token (PRT). After that, SSO will work for subsequent AVD connections.

### Fix Option 1: Use Local Admin (Immediate Access)

**For immediate testing/access:**

1. Connect to AVD using the **local admin credentials** instead of Entra ID
2. Username format: `.\AdminUser` or `avd-pool-0\AdminUser`
3. Password: Use the golden image admin password from secrets.yaml

**Remote Desktop Connection settings:**
- Computer: `avd-pool-0` (or use the public IP: check Azure Portal)
- Username: `.\AdminUser` (the `.\` forces local authentication)
- This bypasses Entra ID and SSO

---

### Fix Option 2: Enable Full Entra ID SSO (Recommended for Production)

#### Step 1: Grant RBAC Permissions

Users need the "Virtual Machine User Login" role to authenticate with Entra ID:

```bash
# Grant role to a specific user
az role assignment create \
  --role "Virtual Machine User Login" \
  --assignee "<user@domain.com>" \
  --scope "/subscriptions/<subscription-id>/resourceGroups/RG-Azure-VDI-01/providers/Microsoft.Compute/virtualMachines/avd-pool-0"

# Or grant to a group
az role assignment create \
  --role "Virtual Machine User Login" \
  --assignee "<group-object-id>" \
  --scope "/subscriptions/<subscription-id>/resourceGroups/RG-Azure-VDI-01"
```

#### Step 2: Configure Windows Cloud Login Service Principal

The Windows Cloud Login service principal must have RDP authentication enabled:

```bash
# Run this script (requires Microsoft Graph permissions)
cd /mnt/cache_pool/development/azure-projects/test-01
pwsh artifacts/scripts/enable-sso.ps1
```

**Manual alternative:**
1. Go to Azure Portal → Entra ID → Enterprise Applications
2. Search for "Windows Cloud Login" (AppId: 270efc09-cd0d-444b-a71f-39af4910ec45)
3. Enable RDP authentication via Microsoft Graph API

#### Step 3: First User Sign-In

A user must sign into Windows on the VM **once** to establish PRT:

**Option A: RDP directly to the VM (before AVD)**
```
1. Get VM public IP from Azure Portal
2. RDP to: <public-ip>
3. Sign in with: AzureAD\user@domain.com
4. Password: <Entra ID password>
5. This establishes PRT on the VM
6. Now SSO will work for AVD connections
```

**Option B: Use Azure Bastion** (if configured)
```
1. Azure Portal → Virtual Machines → avd-pool-0
2. Connect → Bastion
3. Sign in with Entra ID credentials
4. This establishes PRT
```

#### Step 4: Verify PRT

After user signs in, verify PRT is available:

```bash
az vm run-command invoke \
  --resource-group "RG-Azure-VDI-01" \
  --name "avd-pool-0" \
  --command-id RunPowerShellScript \
  --scripts "dsregcmd /status | Select-String -Pattern 'AzureAdPrt'"
```

Expected output: `AzureAdPrt : YES`

---

## Verification Steps

### 1. Check RBAC Permissions

```bash
# List current role assignments on the VM
az role assignment list \
  --scope "/subscriptions/<subscription-id>/resourceGroups/RG-Azure-VDI-01/providers/Microsoft.Compute/virtualMachines/avd-pool-0" \
  --query "[?roleDefinitionName=='Virtual Machine User Login'].{User:principalName, Role:roleDefinitionName}" \
  --output table
```

### 2. Check Windows Cloud Login Service Principal

```bash
pwsh -Command "
  Connect-MgGraph -Scopes 'Application.Read.All'
  $sp = Get-MgServicePrincipal -Filter \"AppId eq '270efc09-cd0d-444b-a71f-39af4910ec45'\"
  if (\$sp) { Write-Host 'Service Principal exists' } else { Write-Host 'NOT FOUND - needs consent' }
"
```

### 3. Test AVD Connection

1. Open Windows App or Remote Desktop client
2. Subscribe to workspace: `https://rdweb.wvd.microsoft.com`
3. Sign in with Entra ID credentials
4. Launch desktop session
5. **Expected:** No additional credential prompt (SSO working)
6. **If prompted:** PRT is not available yet

---

## Current Diagnostics Data

**Collected:** 2025-12-08 16:07:33 UTC
**Location:** `C:\Temp\AVD-Diagnostics\` (on avd-pool-0)

### Log Files Created:
- `AAD-Auth.csv` - 100 Azure AD authentication events
- `RDP-ConnectionManager.csv` - 100 RDP connection events
- `RDP-SessionManager.csv` - 100 session manager events
- `RDP-Core.csv` - 100 RDP core events
- `Security-Auth.csv` - 50 security authentication events
- `Application-Errors.csv` - 21 application errors/warnings
- `Services-Status.csv` - AVD service status
- `Network-Tests.csv` - Connectivity tests (all passed ✅)
- `DsregCmd-Status.txt` - Full Entra ID join status
- `AVD-Registry.txt` - AVD agent registration data
- `System-Info.json` - System information
- `SUMMARY.txt` - Summary report

### Key Findings:
- ✅ VM is Entra ID joined
- ✅ AVD agent registered
- ✅ Network connectivity OK (Azure AD, AVD Service, Broker)
- ✅ Required services running (RDAgentBootLoader, SessionEnv, TermService, UmRdpService)
- ❌ PRT not available (no user signed in)
- ❌ 18 authentication errors (due to missing PRT)
- ⚠️ WVDAgentManager service not found (may be deprecated/renamed)

---

## Troubleshooting Commands

### Check PRT Status
```bash
az vm run-command invoke \
  --resource-group "RG-Azure-VDI-01" \
  --name "avd-pool-0" \
  --command-id RunPowerShellScript \
  --scripts "dsregcmd /status"
```

### Check Recent AAD Errors
```bash
az vm run-command invoke \
  --resource-group "RG-Azure-VDI-01" \
  --name "avd-pool-0" \
  --command-id RunPowerShellScript \
  --scripts "Get-WinEvent -LogName 'Microsoft-Windows-AAD/Operational' -MaxEvents 20 | Where-Object { \$_.LevelDisplayName -eq 'Error' } | Format-Table TimeCreated, Id, Message -AutoSize"
```

### Check AVD Agent Status
```bash
az vm run-command invoke \
  --resource-group "RG-Azure-VDI-01" \
  --name "avd-pool-0" \
  --command-id RunPowerShellScript \
  --scripts "Get-Service RDAgentBootLoader, SessionEnv, TermService | Format-Table Name, Status, StartType"
```

---

## Recommended Immediate Action

**For immediate access (testing):**
1. Use local admin account with RDP
2. Username: `.\AdminUser`
3. Password: From secrets.yaml

**For production SSO:**
1. Grant "Virtual Machine User Login" RBAC role to users/groups
2. Enable Windows Cloud Login service principal
3. Have one user RDP to the VM directly with Entra ID credentials (establishes PRT)
4. Then AVD SSO will work for all users

---

## Additional Notes

- The host pool RDP properties correctly include `enablerdsaadauth:i:1`
- WebAuthn redirection is enabled for FIDO2 keys (`redirectwebauthn:i:1`)
- The VM is in a healthy state (all services running, network OK)
- The authentication error 0x0 is specifically due to missing PRT
- Once PRT is established, the authentication errors will stop

---

**Generated by:** Claude Code AVD Diagnostics
**Script Location:** `/mnt/cache_pool/development/azure-projects/test-01/artifacts/scripts/collect-avd-diagnostics.ps1`
