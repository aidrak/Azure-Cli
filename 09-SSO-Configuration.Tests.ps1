# Verification Script for Entra SSO Configuration
#
# Purpose: Validate that the SSO configuration steps (09-SSO-Configuration.ps1) were successful
#
# Prerequisites:
# - Must be run after running `09-SSO-Configuration.ps1`
# - Requires same permissions (Global Admin, User Access Admin, Desktop Virtualization Contributor)
#
# Usage:
# .\09-SSO-Configuration.Tests.ps1 -ResourceGroupName "YourAVDRG" -HostPoolName "YourAVDHostPool" `
#   -AvdUsersGroupName "AVD-Users" -AvdDevicesPooledSSOGroupName "AVD-Devices-Pooled-SSO"

[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory=$true)]
    [string]$HostPoolName,

    [Parameter(Mandatory=$true)]
    [string]$AvdUsersGroupName,

    [Parameter(Mandatory=$true)]
    [string]$AvdDevicesPooledSSOGroupName
)

$ErrorActionPreference = "Stop"

function Connect-AzureServices {
    Write-Host "Connecting to Azure and Microsoft Graph for verification..." -ForegroundColor Cyan
    try {
         if (-not (Get-MgContext -ErrorAction SilentlyContinue)) {
            Connect-MgGraph -Scopes "Application.Read.All","Application-RemoteDesktopConfig.ReadWrite.All","Group.Read.All" -ErrorAction Stop
        }
        if (-not (Get-AzContext -ErrorAction SilentlyContinue)) {
            Connect-AzAccount -ErrorAction Stop | Out-Null
        }
    }
    catch {
        Write-Error "Failed to connect to Azure services. Error: $($_.Exception.Message)"
        exit 1
    }
}

function Test-RdpProtocolEnabled {
    Write-Host "`n[Test 1] Verifying RDP Protocol on Windows Cloud Login Service Principal..." -ForegroundColor Yellow
    try {
        $WCLsp = Get-MgServicePrincipal -Filter "AppId eq '270efc09-cd0d-444b-a71f-39af4910ec45'" -ErrorAction Stop
        if (-not $WCLsp) {
            Write-Host "FAIL: Windows Cloud Login service principal not found." -ForegroundColor Red
            return
        }

        $config = Get-MgServicePrincipalRemoteDesktopSecurityConfiguration -ServicePrincipalId $WCLsp.Id
        if ($config -and $config.IsRemoteDesktopProtocolEnabled) {
            Write-Host "PASS: RDP protocol is enabled." -ForegroundColor Green
        } else {
            Write-Host "FAIL: RDP protocol is NOT enabled." -ForegroundColor Red
        }
    }
    catch {
        Write-Host "FAIL: Error during verification. $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Test-TrustedDeviceGroupConfigured {
    Write-Host "`n[Test 2] Verifying Trusted Device Group Configuration..." -ForegroundColor Yellow
    try {
        $WCLsp = Get-MgServicePrincipal -Filter "AppId eq '270efc09-cd0d-444b-a71f-39af4910ec45'" -ErrorAction Stop
        $deviceGroup = Get-MgGroup -Filter "displayName eq '$AvdDevicesPooledSSOGroupName'" -ErrorAction Stop
        
        if (-not $deviceGroup) {
             Write-Host "FAIL: Device group '$AvdDevicesPooledSSOGroupName' not found." -ForegroundColor Red
             return
        }

        $existingGroups = Get-MgServicePrincipalRemoteDesktopSecurityConfigurationTargetDeviceGroup -ServicePrincipalId $WCLsp.Id
        if ($existingGroups -and ($existingGroups.Id -contains $deviceGroup.Id)) {
            Write-Host "PASS: Device group '$AvdDevicesPooledSSOGroupName' is trusted." -ForegroundColor Green
        } else {
            Write-Host "FAIL: Device group '$AvdDevicesPooledSSOGroupName' is NOT in the trusted list." -ForegroundColor Red
        }
    }
    catch {
        Write-Host "FAIL: Error during verification. $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Test-HostPoolRdpPropertiesForSSO {
    Write-Host "`n[Test 3] Verifying Host Pool RDP Properties..." -ForegroundColor Yellow
    try {
        $hostPool = Get-AzWvdHostPool -ResourceGroupName $ResourceGroupName -Name $HostPoolName -ErrorAction Stop
        
        $rdpProps = $hostPool.CustomRdpProperty
        $hasSSO = $rdpProps -match "enablerdsaadauth:i:1"
        $hasNoUDP = $rdpProps -match "use udp:i:0"

        if ($hasSSO) {
             Write-Host "PASS: SSO property (enablerdsaadauth:i:1) found." -ForegroundColor Green
        } else {
             Write-Host "FAIL: SSO property (enablerdsaadauth:i:1) MISSING." -ForegroundColor Red
        }

        if ($hasNoUDP) {
             Write-Host "PASS: UDP disabled property (use udp:i:0) found." -ForegroundColor Green
        } else {
             Write-Host "WARN: UDP disabled property (use udp:i:0) missing (optional but recommended)." -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "FAIL: Error verifying host pool. $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Test-VmUserLoginRoleAssigned {
    Write-Host "`n[Test 4] Verifying 'Virtual Machine User Login' RBAC Role..." -ForegroundColor Yellow
    try {
        $avdGroup = Get-MgGroup -Filter "displayName eq '$AvdUsersGroupName'" -ErrorAction Stop
        $rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction Stop

        if (-not $avdGroup) {
            Write-Host "FAIL: User group '$AvdUsersGroupName' not found." -ForegroundColor Red
            return
        }

        $assignment = Get-AzRoleAssignment `
            -ObjectId $avdGroup.Id `
            -Scope $rg.ResourceId `
            -RoleDefinitionName "Virtual Machine User Login" -ErrorAction SilentlyContinue

        if ($assignment) {
            Write-Host "PASS: 'Virtual Machine User Login' role is assigned correctly." -ForegroundColor Green
        } else {
            Write-Host "FAIL: 'Virtual Machine User Login' role is NOT assigned to '$AvdUsersGroupName' on resource group '$ResourceGroupName'." -ForegroundColor Red
        }
    }
    catch {
        Write-Host "FAIL: Error verifying RBAC role. $($_.Exception.Message)" -ForegroundColor Red
    }
}

# --- Main Execution ---
Write-Host "Starting SSO Configuration Verification..." -ForegroundColor Green

Connect-AzureServices
Test-RdpProtocolEnabled
Test-TrustedDeviceGroupConfigured
Test-HostPoolRdpPropertiesForSSO
Test-VmUserLoginRoleAssigned

Write-Host "`nVerification Completed." -ForegroundColor Green
