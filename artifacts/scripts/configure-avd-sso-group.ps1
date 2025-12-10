[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$GroupNamePattern = "AVD-Users",

    [Parameter(Mandatory=$false)]
    [string]$DynamicGroupName = "AVD-SessionHosts-SSO"
)

# Configure AVD SSO Dynamic Group
# This script:
# 1. Creates a dynamic group for all AVD session hosts
# 2. Adds the group to the Windows Cloud Login SSO configuration to hide consent prompts

Write-Host "[START] Configuring AVD SSO Dynamic Group"

try {
    # Import required modules
    Write-Host "[*] Importing Microsoft Graph modules..."
    Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
    Import-Module Microsoft.Graph.Applications -ErrorAction Stop
    Import-Module Microsoft.Graph.Groups -ErrorAction Stop
    Write-Host "[v] Modules imported successfully"

    # Connect to Microsoft Graph
    Write-Host "[*] Connecting to Microsoft Graph..."
    Write-Host "[!] You will need to authenticate in your browser"
    Connect-MgGraph -Scopes "Application.Read.All","Application-RemoteDesktopConfig.ReadWrite.All","Group.ReadWrite.All" -UseDeviceAuthentication

    # Verify connection
    $context = Get-MgContext
    Write-Host "[v] Connected as: $($context.Account)"

    # Check if dynamic group already exists
    Write-Host "[*] Checking for existing dynamic group: $DynamicGroupName"
    $existingGroup = Get-MgGroup -Filter "displayName eq '$DynamicGroupName'" -ErrorAction SilentlyContinue

    if ($existingGroup) {
        Write-Host "[v] Dynamic group already exists"
        $groupId = $existingGroup.Id
        Write-Host "[i] Group ID: $groupId"
    } else {
        Write-Host "[*] Creating dynamic group for AVD session hosts..."

        # Dynamic membership rule: All devices that start with "avd-"
        $membershipRule = '(device.displayName -startsWith "avd-")'

        $groupParams = @{
            DisplayName = $DynamicGroupName
            Description = "Dynamic group for all AVD session hosts - used for SSO configuration"
            MailEnabled = $false
            SecurityEnabled = $true
            MailNickname = ($DynamicGroupName -replace '[^a-zA-Z0-9]', '')
            GroupTypes = @("DynamicMembership")
            MembershipRule = $membershipRule
            MembershipRuleProcessingState = "On"
        }

        $newGroup = New-MgGroup -BodyParameter $groupParams
        $groupId = $newGroup.Id
        Write-Host "[v] Dynamic group created: $DynamicGroupName"
        Write-Host "[i] Group ID: $groupId"
        Write-Host "[i] Membership Rule: $membershipRule"
        Write-Host "[!] Note: Dynamic group membership will update within 5-10 minutes"
    }

    # Get Windows Cloud Login service principal
    Write-Host "[*] Getting Windows Cloud Login service principal..."
    $WCLsp = Get-MgServicePrincipal -Filter "AppId eq '270efc09-cd0d-444b-a71f-39af4910ec45'"

    if (-not $WCLsp) {
        Write-Host "[x] ERROR: Windows Cloud Login service principal not found"
        exit 1
    }

    $WCLspId = $WCLsp.Id
    Write-Host "[v] Windows Cloud Login SP ID: $WCLspId"

    # Get current target device groups
    Write-Host "[*] Checking current SSO target device groups..."
    $currentGroups = Get-MgServicePrincipalRemoteDesktopSecurityConfigurationTargetDeviceGroup -ServicePrincipalId $WCLspId -ErrorAction SilentlyContinue

    # Check if our group is already added
    $groupAlreadyAdded = $false
    if ($currentGroups) {
        foreach ($group in $currentGroups) {
            Write-Host "[i] Existing target group: $($group.DisplayName) ($($group.Id))"
            if ($group.Id -eq $groupId) {
                $groupAlreadyAdded = $true
            }
        }
    }

    if ($groupAlreadyAdded) {
        Write-Host "[v] Dynamic group already added to SSO configuration"
    } else {
        # Add the dynamic group to SSO configuration
        Write-Host "[*] Adding dynamic group to SSO configuration..."

        $targetDeviceGroup = @{
            Id = $groupId
            DisplayName = $DynamicGroupName
        }

        New-MgServicePrincipalRemoteDesktopSecurityConfigurationTargetDeviceGroup `
            -ServicePrincipalId $WCLspId `
            -BodyParameter $targetDeviceGroup

        Write-Host "[v] Dynamic group added to SSO configuration!"
        Write-Host "[i] Users will no longer see consent prompts when connecting to AVD session hosts"
    }

    # Verify final configuration
    Write-Host "[*] Verifying final configuration..."
    $finalGroups = Get-MgServicePrincipalRemoteDesktopSecurityConfigurationTargetDeviceGroup -ServicePrincipalId $WCLspId
    Write-Host "[SUCCESS] Current SSO Target Device Groups:"
    foreach ($group in $finalGroups) {
        Write-Host "  - $($group.DisplayName) (ID: $($group.Id))"
    }

    # Save output
    $output = @{
        GroupId = $groupId
        GroupName = $DynamicGroupName
        MembershipRule = $membershipRule
        ServicePrincipalId = $WCLspId
    }
    $output | ConvertTo-Json | Out-File -FilePath "$PSScriptRoot/../outputs/sso-group-config.json" -Force
    Write-Host "[i] Configuration saved to: $PSScriptRoot/../outputs/sso-group-config.json"

    Write-Host "[SUCCESS] AVD SSO dynamic group configuration completed"
    exit 0

} catch {
    Write-Host "[x] ERROR: $($_.Exception.Message)"
    Write-Host "[x] Stack Trace: $($_.ScriptStackTrace)"
    exit 1
}
