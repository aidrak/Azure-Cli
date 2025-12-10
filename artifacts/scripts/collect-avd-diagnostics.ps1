# Collect AVD Session Host Diagnostics
# This script collects authentication, SSO, and AVD connection logs

Write-Host "[START] AVD Diagnostics Collection: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

# Create output directory
$outputDir = "C:\Temp\AVD-Diagnostics"
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    Write-Host "[*] Created output directory: $outputDir"
}

# Function to export event logs
function Export-EventLogData {
    param (
        [string]$LogName,
        [string]$OutputFile,
        [int]$MaxEvents = 100
    )

    Write-Host "[*] Collecting $LogName logs..."
    try {
        $events = Get-WinEvent -LogName $LogName -MaxEvents $MaxEvents -ErrorAction SilentlyContinue
        if ($events) {
            $events | Select-Object TimeCreated, Id, LevelDisplayName, Message |
                Export-Csv -Path $OutputFile -NoTypeInformation -Encoding UTF8
            Write-Host "[v] Exported $($events.Count) events to $OutputFile"
        } else {
            Write-Host "[i] No events found in $LogName"
        }
    } catch {
        Write-Host "[!] Could not access log $LogName : $_"
    }
}

# 1. Authentication logs (Entra ID / Azure AD)
Write-Host ""
Write-Host "[SECTION] 1. Authentication Logs"
Export-EventLogData -LogName "Microsoft-Windows-AAD/Operational" `
    -OutputFile "$outputDir\AAD-Auth.csv"

# 2. RDP/Remote Desktop logs
Write-Host ""
Write-Host "[SECTION] 2. Remote Desktop Logs"
Export-EventLogData -LogName "Microsoft-Windows-TerminalServices-RemoteConnectionManager/Operational" `
    -OutputFile "$outputDir\RDP-ConnectionManager.csv"

Export-EventLogData -LogName "Microsoft-Windows-TerminalServices-LocalSessionManager/Operational" `
    -OutputFile "$outputDir\RDP-SessionManager.csv"

Export-EventLogData -LogName "Microsoft-Windows-RemoteDesktopServices-RdpCoreTS/Operational" `
    -OutputFile "$outputDir\RDP-Core.csv"

# 3. AVD Agent logs
Write-Host ""
Write-Host "[SECTION] 3. AVD Agent Logs"
Export-EventLogData -LogName "Microsoft-Windows-TerminalServices-RemoteDesktopServices/Operational" `
    -OutputFile "$outputDir\AVD-Agent.csv"

# 4. Security logs (authentication events)
Write-Host ""
Write-Host "[SECTION] 4. Security Logs (Authentication)"
try {
    $secEvents = Get-WinEvent -FilterHashtable @{
        LogName = 'Security'
        ID = @(4624, 4625, 4648, 4776, 4768, 4769)
    } -MaxEvents 50 -ErrorAction SilentlyContinue

    if ($secEvents) {
        $secEvents | Select-Object TimeCreated, Id, LevelDisplayName, Message |
            Export-Csv -Path "$outputDir\Security-Auth.csv" -NoTypeInformation -Encoding UTF8
        Write-Host "[v] Exported $($secEvents.Count) security events"
    }
} catch {
    Write-Host "[!] Could not access Security log: $_"
}

# 5. Check AVD services status
Write-Host ""
Write-Host "[SECTION] 5. AVD Services Status"
$services = @(
    "RDAgentBootLoader",
    "WVDAgentManager",
    "SessionEnv",
    "TermService",
    "UmRdpService"
)

$serviceStatus = @()
foreach ($svc in $services) {
    $service = Get-Service -Name $svc -ErrorAction SilentlyContinue
    if ($service) {
        $serviceStatus += [PSCustomObject]@{
            ServiceName = $svc
            Status = $service.Status
            StartType = $service.StartType
        }
        Write-Host "[i] $svc : $($service.Status)"
    } else {
        Write-Host "[!] Service not found: $svc"
    }
}
$serviceStatus | Export-Csv -Path "$outputDir\Services-Status.csv" -NoTypeInformation -Encoding UTF8

# 6. Check SSO/Entra ID join status
Write-Host ""
Write-Host "[SECTION] 6. Entra ID Join Status"
try {
    $dsregStatus = dsregcmd /status
    $dsregStatus | Out-File -FilePath "$outputDir\DsregCmd-Status.txt" -Encoding UTF8

    # Parse key values
    $isAzureJoined = ($dsregStatus | Select-String "AzureAdJoined\s*:\s*YES") -ne $null
    $ssoState = ($dsregStatus | Select-String "SSO State" -Context 0,5) | Out-String

    Write-Host "[i] Azure AD Joined: $isAzureJoined"
    Write-Host "[i] SSO State: $ssoState"
} catch {
    Write-Host "[!] Could not run dsregcmd: $_"
}

# 7. Network connectivity tests
Write-Host ""
Write-Host "[SECTION] 7. Network Connectivity"
$networkTests = @()

# Test Azure AD endpoints
$endpoints = @(
    @{Name="Azure AD"; Url="https://login.microsoftonline.com"},
    @{Name="AVD Service"; Url="https://rdweb.wvd.microsoft.com"},
    @{Name="AVD Broker"; Url="https://rdbroker.wvd.microsoft.com"}
)

foreach ($endpoint in $endpoints) {
    try {
        $result = Test-NetConnection -ComputerName ($endpoint.Url -replace "https://", "") -Port 443 -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
        $networkTests += [PSCustomObject]@{
            Endpoint = $endpoint.Name
            Url = $endpoint.Url
            Reachable = $result.TcpTestSucceeded
        }
        Write-Host "[i] $($endpoint.Name): $(if ($result.TcpTestSucceeded) { 'OK' } else { 'FAIL' })"
    } catch {
        Write-Host "[!] Could not test $($endpoint.Name)"
    }
}
$networkTests | Export-Csv -Path "$outputDir\Network-Tests.csv" -NoTypeInformation -Encoding UTF8

# 8. Host pool registration status
Write-Host ""
Write-Host "[SECTION] 8. Host Pool Registration"
try {
    $regPath = "HKLM:\SOFTWARE\Microsoft\RDInfraAgent"
    if (Test-Path $regPath) {
        $regData = Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue
        $regData | Out-File -FilePath "$outputDir\AVD-Registry.txt" -Encoding UTF8
        Write-Host "[i] IsRegistered: $($regData.IsRegistered)"
        Write-Host "[i] RegistrationToken: $(if ($regData.RegistrationToken) { 'Present' } else { 'Missing' })"
    } else {
        Write-Host "[!] AVD agent registry key not found"
    }
} catch {
    Write-Host "[!] Could not read registry: $_"
}

# 9. Recent application logs
Write-Host ""
Write-Host "[SECTION] 9. Application Logs (Errors/Warnings)"
try {
    $appErrors = Get-WinEvent -FilterHashtable @{
        LogName = 'Application'
        Level = @(2,3)
    } -MaxEvents 50 -ErrorAction SilentlyContinue

    if ($appErrors) {
        $appErrors | Select-Object TimeCreated, Id, LevelDisplayName, ProviderName, Message |
            Export-Csv -Path "$outputDir\Application-Errors.csv" -NoTypeInformation -Encoding UTF8
        Write-Host "[v] Exported $($appErrors.Count) application errors/warnings"
    }
} catch {
    Write-Host "[!] Could not access Application log"
}

# 10. System information
Write-Host ""
Write-Host "[SECTION] 10. System Information"
$sysInfo = @{
    ComputerName = $env:COMPUTERNAME
    OSVersion = (Get-CimInstance Win32_OperatingSystem).Caption
    LastBootTime = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
    TimeZone = (Get-TimeZone).DisplayName
    CurrentTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
}
$sysInfo | ConvertTo-Json | Out-File -FilePath "$outputDir\System-Info.json" -Encoding UTF8
Write-Host "[v] System info saved"

# Create summary report
Write-Host ""
Write-Host "[SECTION] Creating Summary Report"
$summary = @"
AVD Diagnostics Summary
=======================
Collection Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC')
Computer: $($sysInfo.ComputerName)
OS: $($sysInfo.OSVersion)

Entra ID Join Status:
---------------------
Azure AD Joined: $isAzureJoined

Service Status:
---------------
$(($serviceStatus | Format-Table -AutoSize | Out-String).Trim())

Network Connectivity:
--------------------
$(($networkTests | Format-Table -AutoSize | Out-String).Trim())

Files Collected:
----------------
"@

Get-ChildItem -Path $outputDir -File | ForEach-Object {
    $summary += "`n  - $($_.Name) ($([math]::Round($_.Length/1KB, 2)) KB)"
}

$summary | Out-File -FilePath "$outputDir\SUMMARY.txt" -Encoding UTF8

Write-Host ""
Write-Host "[SUCCESS] Diagnostics collection complete"
Write-Host "[i] Output directory: $outputDir"
Write-Host "[i] Files collected: $(Get-ChildItem -Path $outputDir -File | Measure-Object | Select-Object -ExpandProperty Count)"
Write-Host ""
Write-Host "To retrieve logs, use:"
Write-Host "  az vm run-command invoke --command-id RunPowerShellScript --scripts @artifacts/scripts/retrieve-diagnostics.ps1"
Write-Host ""

# Output the directory for capture
Write-Host "DIAGNOSTICS_PATH=$outputDir"

exit 0
