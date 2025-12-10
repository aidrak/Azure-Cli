# Enable SSO for Azure Virtual Desktop using Microsoft Entra Authentication
# This script enables RDP authentication on the Windows Cloud Login service principal

Write-Host "[*] Installing Microsoft Graph PowerShell modules if not present..."
$modules = @("Microsoft.Graph.Authentication", "Microsoft.Graph.Applications")
foreach ($module in $modules) {
    if (!(Get-Module -ListAvailable -Name $module)) {
        Write-Host "[*] Installing $module..."
        Install-Module -Name $module -Force -AllowClobber -Scope CurrentUser
    } else {
        Write-Host "[v] $module already installed"
    }
}

Write-Host "[*] Importing Microsoft Graph modules..."
Import-Module Microsoft.Graph.Authentication
Import-Module Microsoft.Graph.Applications

Write-Host "[*] Connecting to Microsoft Graph..."
try {
    Connect-MgGraph -Scopes "Application.Read.All","Application-RemoteDesktopConfig.ReadWrite.All" -NoWelcome
    Write-Host "[v] Connected to Microsoft Graph"
} catch {
    Write-Host "[x] Failed to connect to Microsoft Graph: $_"
    exit 1
}

Write-Host "[*] Getting Windows Cloud Login service principal..."
$WCLspId = (Get-MgServicePrincipal -Filter "AppId eq '270efc09-cd0d-444b-a71f-39af4910ec45'").Id
if ($WCLspId) {
    Write-Host "[v] Found Windows Cloud Login service principal: $WCLspId"
} else {
    Write-Host "[x] Windows Cloud Login service principal not found"
    exit 1
}

Write-Host "[*] Checking current RDP authentication status..."
$currentConfig = Get-MgServicePrincipalRemoteDesktopSecurityConfiguration -ServicePrincipalId $WCLspId
if ($currentConfig.IsRemoteDesktopProtocolEnabled -eq $true) {
    Write-Host "[v] RDP authentication is already enabled"
} else {
    Write-Host "[*] Enabling RDP authentication..."
    try {
        Update-MgServicePrincipalRemoteDesktopSecurityConfiguration -ServicePrincipalId $WCLspId -IsRemoteDesktopProtocolEnabled
        Write-Host "[v] RDP authentication enabled successfully"
    } catch {
        Write-Host "[x] Failed to enable RDP authentication: $_"
        exit 1
    }
}

Write-Host "[*] Verifying final configuration..."
$finalConfig = Get-MgServicePrincipalRemoteDesktopSecurityConfiguration -ServicePrincipalId $WCLspId
Write-Host "[i] IsRemoteDesktopProtocolEnabled: $($finalConfig.IsRemoteDesktopProtocolEnabled)"

if ($finalConfig.IsRemoteDesktopProtocolEnabled -eq $true) {
    Write-Host "[SUCCESS] SSO configuration complete!"
    exit 0
} else {
    Write-Host "[x] SSO configuration verification failed"
    exit 1
}
