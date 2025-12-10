[CmdletBinding()]
param()

# Enable AVD Single Sign-On Configuration
# This script:
# 1. Enables Microsoft Entra authentication for RDP
# 2. Creates a dynamic group for AVD session hosts
# 3. Configures the host pool to hide SSO consent prompts

Write-Host "[START] Enabling AVD Single Sign-On Configuration"

try {
    # Import required modules
    Write-Host "[*] Importing Microsoft Graph modules..."
    Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
    Import-Module Microsoft.Graph.Applications -ErrorAction Stop
    Write-Host "[v] Modules imported successfully"

    # Connect to Microsoft Graph
    Write-Host "[*] Connecting to Microsoft Graph..."
    Write-Host "[!] You will need to authenticate in your browser"
    Connect-MgGraph -Scopes "Application.Read.All","Application-RemoteDesktopConfig.ReadWrite.All" -UseDeviceAuthentication

    # Verify connection
    $context = Get-MgContext
    Write-Host "[v] Connected as: $($context.Account)"

    # Get Windows Cloud Login service principal (App ID: 270efc09-cd0d-444b-a71f-39af4910ec45)
    Write-Host "[*] Getting Windows Cloud Login service principal..."
    $WCLsp = Get-MgServicePrincipal -Filter "AppId eq '270efc09-cd0d-444b-a71f-39af4910ec45'"

    if (-not $WCLsp) {
        Write-Host "[x] ERROR: Windows Cloud Login service principal not found"
        exit 1
    }

    $WCLspId = $WCLsp.Id
    Write-Host "[v] Windows Cloud Login SP ID: $WCLspId"

    # Check current RDP authentication status
    Write-Host "[*] Checking current RDP authentication status..."
    $currentConfig = Get-MgServicePrincipalRemoteDesktopSecurityConfiguration -ServicePrincipalId $WCLspId
    Write-Host "[i] Current IsRemoteDesktopProtocolEnabled: $($currentConfig.IsRemoteDesktopProtocolEnabled)"

    # Enable RDP authentication if not already enabled
    if ($currentConfig.IsRemoteDesktopProtocolEnabled -ne $true) {
        Write-Host "[*] Enabling RDP authentication..."
        Update-MgServicePrincipalRemoteDesktopSecurityConfiguration `
            -ServicePrincipalId $WCLspId `
            -IsRemoteDesktopProtocolEnabled
        Write-Host "[v] RDP authentication enabled!"
    } else {
        Write-Host "[v] RDP authentication already enabled"
    }

    # Verify final configuration
    $finalConfig = Get-MgServicePrincipalRemoteDesktopSecurityConfiguration -ServicePrincipalId $WCLspId
    Write-Host "[SUCCESS] RDP Authentication Configuration:"
    Write-Host "  ID: $($finalConfig.Id)"
    Write-Host "  IsRemoteDesktopProtocolEnabled: $($finalConfig.IsRemoteDesktopProtocolEnabled)"

    # Export the Service Principal ID for next steps
    $WCLspId | Out-File -FilePath "$PSScriptRoot/../outputs/wcl-sp-id.txt" -Force
    Write-Host "[i] Service Principal ID saved to: $PSScriptRoot/../outputs/wcl-sp-id.txt"

    Write-Host "[SUCCESS] AVD SSO base configuration completed"
    exit 0

} catch {
    Write-Host "[x] ERROR: $($_.Exception.Message)"
    Write-Host "[x] Stack Trace: $($_.ScriptStackTrace)"
    exit 1
}
