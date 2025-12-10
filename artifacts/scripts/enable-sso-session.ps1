#!/usr/bin/env pwsh

# Enable SSO for Azure Virtual Desktop
Import-Module Microsoft.Graph.Authentication
Import-Module Microsoft.Graph.Applications

Write-Host "[*] Connecting to Microsoft Graph..."
Connect-MgGraph -Scopes "Application.Read.All","Application-RemoteDesktopConfig.ReadWrite.All" -NoWelcome

Write-Host "[*] Getting Windows Cloud Login service principal..."
$WCLspId = (Get-MgServicePrincipal -Filter "AppId eq '270efc09-cd0d-444b-a71f-39af4910ec45'").Id

if ($WCLspId) {
    Write-Host "[v] Found service principal: $WCLspId"

    Write-Host "[*] Checking current RDP authentication status..."
    $config = Get-MgServicePrincipalRemoteDesktopSecurityConfiguration -ServicePrincipalId $WCLspId
    Write-Host "[i] Current IsRemoteDesktopProtocolEnabled: $($config.IsRemoteDesktopProtocolEnabled)"

    if ($config.IsRemoteDesktopProtocolEnabled -ne $true) {
        Write-Host "[*] Enabling RDP authentication..."
        Update-MgServicePrincipalRemoteDesktopSecurityConfiguration -ServicePrincipalId $WCLspId -IsRemoteDesktopProtocolEnabled
        Write-Host "[v] RDP authentication enabled"
    } else {
        Write-Host "[v] RDP authentication already enabled"
    }

    Write-Host "[*] Verifying final configuration..."
    $final = Get-MgServicePrincipalRemoteDesktopSecurityConfiguration -ServicePrincipalId $WCLspId
    Write-Host "[SUCCESS] IsRemoteDesktopProtocolEnabled: $($final.IsRemoteDesktopProtocolEnabled)"
} else {
    Write-Host "[x] Service principal not found"
    exit 1
}
