# Automates Microsoft Entra SSO Configuration for Azure Virtual Desktop (AVD)
#
# Purpose: Enable passwordless Single Sign-On for Entra-only AVD environment and verify configuration
#
# Prerequisites:
# - Entra ID P1 or P2 licenses
# - Host pool created with `enablerdsaadauth:i:1` in RDP properties (if not, this script will add it)
# - Session hosts Entra-joined
# - Device dynamic group `AVD-Devices-Pooled-SSO` created (as per Guide 03)
# - User group `AVD-Users` created
# - PowerShell: Microsoft.Graph and Az modules
#
# Permissions required:
# - Global Administrator (for Microsoft Graph API calls)
# - User Access Administrator (for RBAC assignments)
# - Desktop Virtualization Contributor (for AVD host pool updates)
#
# Usage:
# .\09-SSO-Configuration.ps1 -ResourceGroupName "YourAVDRG" -HostPoolName "YourAVDHostPool" `
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
    [string]$AvdDevicesPooledSSOGroupName,

    [Parameter(Mandatory=$false)]
    [switch]$SkipVerification
)

$ErrorActionPreference = "Stop"

function Install-RequiredModules {
    Write-Host "Checking for required PowerShell modules..." -ForegroundColor Cyan

    $modules = @(
        "Microsoft.Graph.Authentication",
        "Microsoft.Graph.Applications",
        "Az.Accounts",
        "Az.Resources",
        "Az.DesktopVirtualization"
    )

    foreach ($module in $modules) {
        if (-not (Get-Module -ListAvailable -Name $module)) {
            Write-Host "Installing module: $module..." -ForegroundColor Yellow
            try {
                Install-Module -Name $module -Force -AllowClobber -Scope CurrentUser
                Write-Host "Successfully installed $module." -ForegroundColor Green
            }
            catch {
                Write-Error "Failed to install module $module. Error: $($_.Exception.Message)"
                exit 1
            }
        } else {
            Write-Host "Module $module is already installed." -ForegroundColor Green
        }
    }
    Write-Host "All required modules are installed." -ForegroundColor Cyan
}

function Connect-AzureServices {
    Write-Host "Connecting to Azure and Microsoft Graph..." -ForegroundColor Cyan
    try {
        # Check if already connected to MgGraph
        if (Get-MgContext -ErrorAction SilentlyContinue) {
            Write-Host "Already connected to Microsoft Graph." -ForegroundColor Green
        } else {
            Write-Host "Connecting to Microsoft Graph (requires Application.Read.All, Application-RemoteDesktopConfig.ReadWrite.All, Group.Read.All scopes)..." -ForegroundColor Yellow
            Connect-MgGraph -Scopes "Application.Read.All","Application-RemoteDesktopConfig.ReadWrite.All","Group.Read.All" -ErrorAction Stop
            Write-Host "Connected to Microsoft Graph." -ForegroundColor Green
        }

        # Check if already connected to Az
        if (Get-AzContext -ErrorAction SilentlyContinue) {
            Write-Host "Already connected to Azure AzAccount." -ForegroundColor Green
        } else {
            Write-Host "Connecting to Azure AzAccount..." -ForegroundColor Yellow
            Connect-AzAccount -ErrorAction Stop | Out-Null
            Write-Host "Connected to Azure AzAccount." -ForegroundColor Green
        }
    }
    catch {
        Write-Error "Failed to connect to Azure services. Error: $($_.Exception.Message)"
        exit 1
    }
}

function Enable-RdpAuthenticationOnServicePrincipal {
    Write-Host "`n=== Step 1: Enable RDP Authentication on Windows Cloud Login Service Principal ===" -ForegroundColor Blue
    try {
        # Get Windows Cloud Login service principal
        Write-Host "Retrieving Windows Cloud Login service principal..." -ForegroundColor Yellow
        $WCLsp = Get-MgServicePrincipal -Filter "AppId eq '270efc09-cd0d-444b-a71f-39af4910ec45'" -ErrorAction Stop
        if (-not $WCLsp) {
             throw "Windows Cloud Login service principal (AppId: 270efc09-cd0d-444b-a71f-39af4910ec45) not found!"
        }
        $WCLspId = $WCLsp.Id
        Write-Host "Found Windows Cloud Login service principal with ID: $WCLspId" -ForegroundColor Green

        # Enable RDP protocol
        Write-Host "Checking RDP protocol enablement status..." -ForegroundColor Yellow
        $config = Get-MgServicePrincipalRemoteDesktopSecurityConfiguration -ServicePrincipalId $WCLspId
        if ($config -and $config.IsRemoteDesktopProtocolEnabled) {
            Write-Host "✓ RDP protocol is already enabled." -ForegroundColor Green
        } else {
            Write-Host "Enabling RDP protocol on service principal..." -ForegroundColor Yellow
            Update-MgServicePrincipalRemoteDesktopSecurityConfiguration `
                -ServicePrincipalId $WCLspId `
                -IsRemoteDesktopProtocolEnabled:$true -ErrorAction Stop
            Write-Host "✓ RDP protocol enabled successfully." -ForegroundColor Green
        }
    }
    catch {
        Write-Error "Failed to enable RDP Authentication. Error: $($_.Exception.Message)"
        exit 1
    }
}

function Configure-TrustedDeviceGroupsForServicePrincipal {
    Write-Host "`n=== Step 2: Configure Trusted Device Groups ===" -ForegroundColor Blue
    try {
        # Get Windows Cloud Login service principal
        $WCLsp = Get-MgServicePrincipal -Filter "AppId eq '270efc09-cd0d-444b-a71f-39af4910ec45'" -ErrorAction Stop
         if (-not $WCLsp) {
             throw "Windows Cloud Login service principal not found!"
        }
        $WCLspId = $WCLsp.Id

        # Get device group
        Write-Host "Retrieving device group '$AvdDevicesPooledSSOGroupName'..." -ForegroundColor Yellow
        $deviceGroup = Get-MgGroup -Filter "displayName eq '$AvdDevicesPooledSSOGroupName'" -ErrorAction Stop
        if (-not $deviceGroup) {
            throw "Device group '$AvdDevicesPooledSSOGroupName' not found!"
        }
        Write-Host "Found device group ID: $($deviceGroup.Id)" -ForegroundColor Green

        # Check if the group is already added
        Write-Host "Checking if '$AvdDevicesPooledSSOGroupName' is already a trusted device group..." -ForegroundColor Yellow
        $existingGroups = Get-MgServicePrincipalRemoteDesktopSecurityConfigurationTargetDeviceGroup -ServicePrincipalId $WCLspId
        if ($existingGroups -and ($existingGroups.Id -contains $deviceGroup.Id)) {
            Write-Host "✓ Device group '$AvdDevicesPooledSSOGroupName' is already configured as trusted." -ForegroundColor Green
        } else {
            # Create target device group object
            $tdg = New-Object -TypeName Microsoft.Graph.PowerShell.Models.MicrosoftGraphTargetDeviceGroup
            $tdg.Id = $deviceGroup.Id
            $tdg.DisplayName = $deviceGroup.DisplayName

            # Add to service principal
            Write-Host "Adding device group '$AvdDevicesPooledSSOGroupName' to service principal..." -ForegroundColor Yellow
            New-MgServicePrincipalRemoteDesktopSecurityConfigurationTargetDeviceGroup `
                -ServicePrincipalId $WCLspId `
                -BodyParameter $tdg -ErrorAction Stop
            Write-Host "✓ Trusted device group configured successfully." -ForegroundColor Green
            Write-Host "  Users will not see consent prompts" -ForegroundColor Gray
        }
    }
    catch {
        Write-Error "Failed to configure trusted device groups. Error: $($_.Exception.Message)"
        exit 1
    }
}

function Update-HostPoolRdpProperties {
    Write-Host "`n=== Step 4: Verify and Update Host Pool RDP Properties ===" -ForegroundColor Blue
    try {
        Write-Host "Retrieving host pool '$HostPoolName' in resource group '$ResourceGroupName'..." -ForegroundColor Yellow
        $hostPool = Get-AzWvdHostPool `
            -ResourceGroupName $ResourceGroupName `
            -Name $HostPoolName -ErrorAction Stop
        
        $currentRdpProperties = $hostPool.CustomRdpProperty
        $ssoEnabled = $currentRdpProperties -match "enablerdsaadauth:i:1"
        $udpDisabled = $currentRdpProperties -match "use udp:i:0"

        if ($ssoEnabled -and $udpDisabled) {
            Write-Host "✓ SSO and UDP settings are already correctly configured in host pool RDP properties." -ForegroundColor Green
        } else {
            Write-Host "SSO or UDP settings are incorrect. Updating host pool RDP properties..." -ForegroundColor Yellow
            $newRdpProperties = "enablerdsaadauth:i:1;use udp:i:0;audiocapturemode:i:1;audiomode:i:0;"
            Update-AzWvdHostPool `
                -ResourceGroupName $ResourceGroupName `
                -Name $HostPoolName `
                -CustomRdpProperty $newRdpProperties -ErrorAction Stop
            Write-Host "✓ RDP properties updated successfully to: '$newRdpProperties'" -ForegroundColor Green
        }
    }
    catch {
        Write-Error "Failed to update host pool RDP properties. Error: $($_.Exception.Message)"
        exit 1
    }
}

function Assign-VirtualMachineUserLoginRole {
    Write-Host "`n=== Step 5: Assign RBAC Role 'Virtual Machine User Login' ===" -ForegroundColor Blue
    try {
        Write-Host "Retrieving AVD users group '$AvdUsersGroupName'..." -ForegroundColor Yellow
        $avdGroup = Get-MgGroup -Filter "displayName eq '$AvdUsersGroupName'" -ErrorAction Stop
        if (-not $avdGroup) {
            throw "AVD Users group '$AvdUsersGroupName' not found!"
        }
        Write-Host "Found AVD users group ID: $($avdGroup.Id)" -ForegroundColor Green

        Write-Host "Retrieving resource group '$ResourceGroupName'..." -ForegroundColor Yellow
        $rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction Stop
        Write-Host "Found resource group ID: $($rg.ResourceId)" -ForegroundColor Green

        Write-Host "Checking if 'Virtual Machine User Login' role is already assigned to '$AvdUsersGroupName' on '$ResourceGroupName'..." -ForegroundColor Yellow
        $existingAssignment = Get-AzRoleAssignment `
            -ObjectId $avdGroup.Id `
            -Scope $rg.ResourceId `
            -RoleDefinitionName "Virtual Machine User Login" -ErrorAction SilentlyContinue

        if ($existingAssignment) {
            Write-Host "✓ 'Virtual Machine User Login' role is already assigned." -ForegroundColor Green
        } else {
            Write-Host "Assigning 'Virtual Machine User Login' role to '$AvdUsersGroupName' on resource group '$ResourceGroupName'..." -ForegroundColor Yellow
            New-AzRoleAssignment `
                -ObjectId $avdGroup.Id `
                -RoleDefinitionName "Virtual Machine User Login" `
                -Scope $rg.ResourceId -ErrorAction Stop
            Write-Host "✓ 'Virtual Machine User Login' role assigned successfully." -ForegroundColor Green
        }
    }
    catch {
        Write-Error "Failed to assign 'Virtual Machine User Login' RBAC role. Error: $($_.Exception.Message)"
        exit 1
    }
}

# --- Verification Functions ---

function Test-RdpProtocolEnabled {
    Write-Host "`n[Verification] Verifying RDP Protocol on Windows Cloud Login Service Principal..." -ForegroundColor Yellow
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
    Write-Host "`n[Verification] Verifying Trusted Device Group Configuration..." -ForegroundColor Yellow
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
    Write-Host "`n[Verification] Verifying Host Pool RDP Properties..." -ForegroundColor Yellow
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
    Write-Host "`n[Verification] Verifying 'Virtual Machine User Login' RBAC Role..." -ForegroundColor Yellow
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
Write-Host "Starting Azure AVD SSO Configuration Script..." -ForegroundColor Green

Install-RequiredModules
Connect-AzureServices

# Run Configuration Steps
Enable-RdpAuthenticationOnServicePrincipal
Configure-TrustedDeviceGroupsForServicePrincipal
Update-HostPoolRdpProperties
Assign-VirtualMachineUserLoginRole

# Run Verification Steps (unless skipped)
if (-not $SkipVerification) {
    Write-Host "`n=== Running Automatic Verification ===" -ForegroundColor Cyan
    Test-RdpProtocolEnabled
    Test-TrustedDeviceGroupConfigured
    Test-HostPoolRdpPropertiesForSSO
    Test-VmUserLoginRoleAssigned
} else {
    Write-Host "`nVerification skipped by user." -ForegroundColor Gray
}

Write-Host "`nAzure AVD SSO Configuration Script Completed." -ForegroundColor Green
Write-Host "NOTE: Conditional Access policies (Step 3) must be configured manually as detailed in the documentation." -ForegroundColor Yellow