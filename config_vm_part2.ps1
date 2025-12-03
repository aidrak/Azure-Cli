# --- 8b. Enable RDP Client Timezone Redirection ---
Write-Host "Enabling RDP Timezone Redirection..."
$rdpPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server"
if (!(Test-Path $rdpPath)) { New-Item -Path $rdpPath -Force | Out-Null }
Set-ItemProperty -Path $rdpPath -Name "fEnableTimeZoneRedirection" -Value 1 -Type DWord -Force
Write-Host "✓ RDP timezone redirection enabled" -ForegroundColor Green

# --- 8c. Configure Windows Defender FSLogix Exclusions ---
Write-Host "Configuring Windows Defender Exclusions..."
Add-MpPreference -ExclusionPath "C:\Program Files\FSLogix" -ErrorAction SilentlyContinue
Add-MpPreference -ExclusionPath "C:\ProgramData\FSLogix" -ErrorAction SilentlyContinue
Add-MpPreference -ExclusionProcess "frx.exe" -ErrorAction SilentlyContinue
Add-MpPreference -ExclusionProcess "frxdrvvt.sys" -ErrorAction SilentlyContinue
Add-MpPreference -ExclusionProcess "frxsvc.exe" -ErrorAction SilentlyContinue
Add-MpPreference -ExclusionExtension "vhd" -ErrorAction SilentlyContinue
Add-MpPreference -ExclusionExtension "vhdx" -ErrorAction SilentlyContinue
Write-Host "✓ Windows Defender FSLogix exclusions configured" -ForegroundColor Green

# --- 8d. Configure Language & Locale Settings ---
Write-Host "Configuring Language & Locale (en-US)..."
Set-WinSystemLocale -SystemLocale "en-US"
Set-Culture -CultureInfo "en-US"
Set-WinHomeLocation -GeoId 244
$languages = New-WinUserLanguageList "en-US"
Set-WinUserLanguageList $languages -Force
Write-Host "✓ Language and locale configured" -ForegroundColor Green

# --- 8e. Disable System Restore & Volume Shadow Copy ---
Write-Host "Disabling System Restore and VSS..."
Disable-ComputerRestore -Drive "C:\" -ErrorAction SilentlyContinue
vssadmin delete shadows /all /quiet
Set-Service -Name VSS -StartupType Disabled
Stop-Service -Name VSS -Force -ErrorAction SilentlyContinue
Write-Host "✓ System Restore and VSS disabled" -ForegroundColor Green

# --- 8f. Verify VDOT Optimizations ---
Write-Host "`n=== VDOT Optimization Verification ===" -ForegroundColor Cyan
$wsearch = Get-Service WSearch -ErrorAction SilentlyContinue
if ($wsearch.Status -eq 'Stopped' -and $wsearch.StartType -eq 'Disabled') {
    Write-Host "✓ Windows Search: Disabled" -ForegroundColor Green
} else {
    Write-Host "✗ Windows Search: Still enabled (check VDOT)" -ForegroundColor Yellow
}

$sysmain = Get-Service SysMain -ErrorAction SilentlyContinue
if ($sysmain.Status -eq 'Stopped' -and $sysmain.StartType -eq 'Disabled') {
    Write-Host "✓ Superfetch (SysMain): Disabled" -ForegroundColor Green
} else {
    Write-Host "✗ Superfetch: Still enabled" -ForegroundColor Yellow
}
Write-Host "`nVDOT verification complete." -ForegroundColor Cyan

# --- 10b. Golden Image Health Check (Pre-Sysprep Quality Gate) ---
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Golden Image Health Check" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$checksPassed = 0
$checksTotal = 0

# Check 1: FSLogix Agent
$checksTotal++
if (Test-Path "C:\Program Files\FSLogix\Apps\frx.exe") {
    Write-Host "✓ FSLogix Agent installed" -ForegroundColor Green
    $checksPassed++
} else {
    Write-Host "✗ FSLogix Agent NOT found" -ForegroundColor Red
}

# Check 2: Defender Exclusions
$checksTotal++
$exclusions = Get-MpPreference | Select-Object -ExpandProperty ExclusionPath
if ($exclusions -contains "C:\Program Files\FSLogix") {
    Write-Host "✓ Windows Defender FSLogix exclusions configured" -ForegroundColor Green
    $checksPassed++
} else {
    Write-Host "✗ Defender exclusions missing" -ForegroundColor Red
}

# Check 3: Office 365 Installed
$checksTotal++
if (Test-Path "C:\Program Files\Microsoft Office\root\Office16\WINWORD.EXE") {
    Write-Host "✓ Office 365 installed" -ForegroundColor Green
    $checksPassed++
} else {
    Write-Host "✗ Office 365 NOT installed" -ForegroundColor Red
}

# Check 4: Chrome Installed
$checksTotal++
if (Test-Path "C:\Program Files\Google\Chrome\Application\chrome.exe") {
    Write-Host "✓ Google Chrome installed" -ForegroundColor Green
    $checksPassed++
} else {
    Write-Host "✗ Chrome NOT installed" -ForegroundColor Red
}

# Check 5: Adobe Reader Installed
$checksTotal++
if (Test-Path "C:\Program Files (x86)\Adobe\Acrobat Reader DC\Reader\AcroRd32.exe") {
    Write-Host "✓ Adobe Reader installed" -ForegroundColor Green
    $checksPassed++
} else {
    Write-Host "✗ Adobe Reader NOT installed" -ForegroundColor Red
}

# Check 6: Public Desktop Shortcuts
$checksTotal++
$shortcuts = Get-ChildItem "C:\Users\Public\Desktop\*.lnk" -ErrorAction SilentlyContinue
if ($shortcuts.Count -ge 6) {
    Write-Host "✓ Public desktop shortcuts created ($($shortcuts.Count) shortcuts)" -ForegroundColor Green
    $checksPassed++
} else {
    Write-Host "✗ Desktop shortcuts missing (found $($shortcuts.Count), expected 6)" -ForegroundColor Red
}

# Check 7: Windows Hello Suppressed
$checksTotal++
$helloReg = Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "NoStartupApp" -ErrorAction SilentlyContinue
if ($helloReg.NoStartupApp -eq 1) {
    Write-Host "✓ Windows Hello suppressed" -ForegroundColor Green
    $checksPassed++
} else {
    Write-Host "✗ Hello suppression NOT configured" -ForegroundColor Red
}

# Check 8: Cloud Kerberos Enabled
$checksTotal++
$kerbReg = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\Kerberos\Parameters" -Name "CloudKerberosTicketRetrievalEnabled" -ErrorAction SilentlyContinue
if ($kerbReg.CloudKerberosTicketRetrievalEnabled -eq 1) {
    Write-Host "✓ Cloud Kerberos enabled" -ForegroundColor Green
    $checksPassed++
} else {
    Write-Host "✗ Cloud Kerberos NOT enabled" -ForegroundColor Red
}

# Check 9: RDP Timezone Redirection
$checksTotal++
$rdpReg = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" -Name "fEnableTimeZoneRedirection" -ErrorAction SilentlyContinue
if ($rdpReg.fEnableTimeZoneRedirection -eq 1) {
    Write-Host "✓ RDP timezone redirection enabled" -ForegroundColor Green
    $checksPassed++
} else {
    Write-Host "✗ Timezone redirection NOT enabled" -ForegroundColor Red
}

# Check 10: System Restore Disabled
$checksTotal++
$vss = Get-Service VSS -ErrorAction SilentlyContinue
if ($vss.StartType -eq 'Disabled') {
    Write-Host "✓ System Restore/VSS disabled" -ForegroundColor Green
    $checksPassed++
} else {
    Write-Host "✗ VSS still enabled" -ForegroundColor Red
}

Write-Host "`nHealth Check: $checksPassed / $checksTotal" -ForegroundColor Cyan
