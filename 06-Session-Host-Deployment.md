# Session Host Deployment from Golden Images

**Purpose:** Deploy AVD session hosts from captured golden images

**Prerequisites:**
- Golden images in Azure Compute Gallery
- Host pool: `Pool-Pooled-Prod`
- VNet and subnets created

---

## Deploy via Host Pool

### Azure Portal

1. Azure Virtual Desktop → Host pools → `Pool-Pooled-Prod`
2. **Session hosts** → **+ Add**
3. **Virtual machines:**
   - Name prefix: `avd-pool-`
   - Image: **Browse all** → My Items → Gallery → `Win11-AVD-Pooled`
   - Size: `Standard_D4ds_v4` (12 sessions)
   - Number of VMs: `10`
4. **Network:**
   - VNet: `vnet-avd-prod`
   - Subnet: `snet-avd-sessionhosts`
   - Public IP: **No**
5. **Domain:**
   - Microsoft Entra ID: **Yes**
   - Enroll with Intune: **Yes** ⚠️ CRITICAL
6. Admin account: `entra-admin` / (password)
7. **Review + create**
8. Wait 15-20 minutes

---

## Verification

### Check Session Hosts

```powershell
Get-AzWvdSessionHost -ResourceGroupName "RG-Azure-VDI-01" -HostPoolName "Pool-Pooled-Prod"
# Status should be: Available
```

### Check Entra Join

1. Microsoft Entra admin center → **Devices** → Search `avd-pool-`
2. Join type: **Microsoft Entra joined**

### Check Intune Enrollment

1. Intune admin center → **Devices** → Search `avd-pool-`
2. Managed by: **Intune**

### On Session Host (RDP in)

```powershell
# Entra join
dsregcmd /status
# AzureAdJoined: YES

# FSLogix
Get-ItemProperty -Path "HKLM:\SOFTWARE\FSLogix\Profiles" -Name "Enabled"

# UDP disabled
Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" -Name "SelectTransport"

# Storage connectivity
Test-NetConnection -ComputerName fslogix112125.file.core.windows.net -Port 445

# Kerberos
klist get cifs/fslogix112125.file.core.windows.net
```

---

## Scaling

### Calculate VMs Needed

```
Users: 400
Sessions per VM: 12
Buffer: 20%

Required: (400 / 12) * 1.2 = 40 VMs
```

### Add More VMs

1. Host pool → Session hosts → **+ Add**
2. Number of VMs: `10`
3. Same settings as initial deployment

**Strategy:**
- Deploy 10 → Test
- Add 10 more → Validate
- Continue to 40 total
- Use autoscaling for power management

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Status "Unavailable" | Regenerate registration token, reinstall AVD agent |
| Not in Entra ID | Check managed identity, install AADLoginForWindows extension |
| FSLogix not working | Verify Intune enrollment, check policy assignment |

---

**Next:** Configure Intune policies (Guide 07), then RBAC (Guide 08)
