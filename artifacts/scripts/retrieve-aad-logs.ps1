# Retrieve specific AAD authentication logs to diagnose the error
Write-Host "[*] Retrieving Azure AD authentication logs..."

# Get recent AAD authentication events
$aadLogs = Get-WinEvent -LogName "Microsoft-Windows-AAD/Operational" -MaxEvents 50 |
    Where-Object { $_.TimeCreated -gt (Get-Date).AddHours(-2) } |
    Select-Object TimeCreated, Id, LevelDisplayName, Message

Write-Host "[*] Recent AAD Events (last 2 hours):"
$aadLogs | Format-Table -AutoSize -Wrap

# Check PRT (Primary Refresh Token) status
Write-Host ""
Write-Host "[*] Checking PRT status..."
$dsregOutput = dsregcmd /status

Write-Host ""
Write-Host "=== FULL DSREGCMD OUTPUT ==="
$dsregOutput

# Extract SSO State section
Write-Host ""
Write-Host "=== SSO STATE DETAILS ==="
$ssoSection = $false
foreach ($line in $dsregOutput) {
    if ($line -match "SSO State") {
        $ssoSection = $true
    }
    if ($ssoSection) {
        Write-Host $line
        if ($line -match "^\s*$") {
            break
        }
    }
}

# Check if PRT is available
$prtStatus = $dsregOutput | Select-String "AzureAdPrt\s*:\s*(\w+)"
if ($prtStatus) {
    $prtValue = $prtStatus.Matches.Groups[1].Value
    Write-Host ""
    Write-Host "[CRITICAL] AzureAdPrt: $prtValue"

    if ($prtValue -eq "NO") {
        Write-Host "[ERROR] Primary Refresh Token (PRT) is NOT available"
        Write-Host "[INFO] This is likely the cause of authentication error 0x0"
        Write-Host ""
        Write-Host "PRT is required for SSO to work. Without it, users must authenticate."
        Write-Host ""
        Write-Host "Common causes:"
        Write-Host "  1. Device is not properly Entra ID joined"
        Write-Host "  2. User has not signed in to Windows with Entra ID credentials"
        Write-Host "  3. Conditional Access policies blocking PRT acquisition"
        Write-Host "  4. Time sync issues between device and Azure AD"
    } else {
        Write-Host "[v] PRT is available - SSO should work"
    }
}

# Check for specific authentication error events
Write-Host ""
Write-Host "[*] Checking for authentication errors..."
$authErrors = Get-WinEvent -LogName "Microsoft-Windows-AAD/Operational" -MaxEvents 100 |
    Where-Object { $_.LevelDisplayName -eq "Error" -and $_.TimeCreated -gt (Get-Date).AddHours(-2) }

if ($authErrors) {
    Write-Host "[!] Found $($authErrors.Count) authentication errors:"
    $authErrors | ForEach-Object {
        Write-Host "  [$($.TimeCreated)] Event $($_.Id): $($_.Message.Substring(0, [Math]::Min(200, $_.Message.Length)))..."
    }
} else {
    Write-Host "[v] No recent authentication errors found"
}

exit 0
