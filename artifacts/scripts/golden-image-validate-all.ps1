# ==============================================================================
# Validate All Installations and Configurations
# ==============================================================================

Write-Host "[START] Comprehensive validation: $(Get-Date -Format 'HH:mm:ss')"

try {
    $validationResults = @()
    $failedChecks = @()
    $passedChecks = 0

    # Helper function to test and log validation
    function Test-Validation {
        param($Name, $Test, $Path, $Required = $true)

        Write-Host "[VALIDATE] Checking: $Name..."

        $result = & $Test
        if ($result) {
            Write-Host "[VALIDATE] PASS: $Name"
            $script:passedChecks++
            $script:validationResults += "[PASS] $Name"
            return $true
        }
        else {
            if ($Required) {
                Write-Host "[VALIDATE] FAIL: $Name"
                $script:failedChecks += $Name
                $script:validationResults += "[FAIL] $Name (Path: $Path)"
            }
            else {
                Write-Host "[VALIDATE] OPTIONAL: $Name (not found)"
                $script:validationResults += "[OPTIONAL] $Name"
            }
            return $false
        }
    }

    # ========================================================================
    # Step 1: Validate FSLogix
    # ========================================================================

    Write-Host "[PROGRESS] Step 1/8: Validating FSLogix..."

    Test-Validation -Name "FSLogix Executable" -Test {
        Test-Path "C:\Program Files\FSLogix\Apps\frx.exe"
    } -Path "C:\Program Files\FSLogix\Apps\frx.exe" -Required $true

    Test-Validation -Name "FSLogix Registry Key" -Test {
        Test-Path "HKLM:\SOFTWARE\FSLogix"
    } -Path "HKLM:\SOFTWARE\FSLogix" -Required $true

    # ========================================================================
    # Step 2: Validate Google Chrome
    # ========================================================================

    Write-Host "[PROGRESS] Step 2/8: Validating Google Chrome..."

    Test-Validation -Name "Chrome Executable" -Test {
        Test-Path "C:\Program Files\Google\Chrome\Application\chrome.exe"
    } -Path "C:\Program Files\Google\Chrome\Application\chrome.exe" -Required $true

    # ========================================================================
    # Step 3: Validate Adobe Reader - SKIPPED per user request
    # ========================================================================

    Write-Host "[PROGRESS] Step 3/8: Skipping Adobe Reader validation (not installed)..."

    # Adobe Reader validation skipped - not installed per user decision

    # ========================================================================
    # Step 4: Validate Microsoft Office 365
    # ========================================================================

    Write-Host "[PROGRESS] Step 4/8: Validating Microsoft Office 365..."

    Test-Validation -Name "Office Word" -Test {
        Test-Path "C:\Program Files\Microsoft Office\root\Office16\WINWORD.EXE"
    } -Path "C:\Program Files\Microsoft Office\root\Office16\WINWORD.EXE" -Required $true

    Test-Validation -Name "Office Excel" -Test {
        Test-Path "C:\Program Files\Microsoft Office\root\Office16\EXCEL.EXE"
    } -Path "C:\Program Files\Microsoft Office\root\Office16\EXCEL.EXE" -Required $true

    Test-Validation -Name "Office Outlook" -Test {
        Test-Path "C:\Program Files\Microsoft Office\root\Office16\OUTLOOK.EXE"
    } -Path "C:\Program Files\Microsoft Office\root\Office16\OUTLOOK.EXE" -Required $true

    # ========================================================================
    # Step 5: Validate Desktop Shortcuts
    # ========================================================================

    Write-Host "[PROGRESS] Step 5/8: Validating desktop shortcuts..."

    Test-Validation -Name "Adobe Reader Shortcut" -Test {
        Test-Path "C:\Users\Public\Desktop\Adobe Acrobat Reader.lnk"
    } -Path "C:\Users\Public\Desktop\Adobe Acrobat Reader.lnk" -Required $false

    Test-Validation -Name "Chrome Shortcut" -Test {
        Test-Path "C:\Users\Public\Desktop\Google Chrome.lnk"
    } -Path "C:\Users\Public\Desktop\Google Chrome.lnk" -Required $true

    Test-Validation -Name "Word Shortcut" -Test {
        Test-Path "C:\Users\Public\Desktop\Microsoft Word.lnk"
    } -Path "C:\Users\Public\Desktop\Microsoft Word.lnk" -Required $true

    # ========================================================================
    # Step 6: Validate VDOT
    # ========================================================================

    Write-Host "[PROGRESS] Step 6/8: Validating VDOT execution..."

    Test-Validation -Name "VDOT Script" -Test {
        Test-Path "C:\Temp\VDOT\Virtual-Desktop-Optimization-Tool-main\Windows_VDOT.ps1"
    } -Path "C:\Temp\VDOT\...\Windows_VDOT.ps1" -Required $false

    # ========================================================================
    # Step 7: Validate Registry Configuration
    # ========================================================================

    Write-Host "[PROGRESS] Step 7/8: Validating registry configuration..."

    Test-Validation -Name "RDP Registry Key" -Test {
        Test-Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server"
    } -Path "HKLM:\SYSTEM\...\Terminal Server" -Required $true

    Test-Validation -Name "OOBE Registry Key" -Test {
        Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OOBE"
    } -Path "HKLM:\SOFTWARE\...\OOBE" -Required $true

    Test-Validation -Name "Windows Hello Disabled" -Test {
        Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\PassportForWork"
    } -Path "HKLM:\SOFTWARE\...\PassportForWork" -Required $true

    # ========================================================================
    # Step 8: Validate Default User Profile
    # ========================================================================

    Write-Host "[PROGRESS] Step 8/8: Validating default user profile..."

    Test-Validation -Name "Default User Hive" -Test {
        Test-Path "C:\Users\Default\NTUSER.DAT"
    } -Path "C:\Users\Default\NTUSER.DAT" -Required $true

    # ========================================================================
    # Generate Validation Report
    # ========================================================================

    Write-Host "[PROGRESS] Generating validation report..."

    $reportPath = "C:\Temp\golden-image-validation-report.txt"
    $report = @"
==============================================================================
Golden Image Validation Report
==============================================================================
Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

Summary:
--------
Total Checks: $($validationResults.Count)
Passed: $passedChecks
Failed: $($failedChecks.Count)
Status: $(if ($failedChecks.Count -eq 0) { "ALL PASSED" } else { "FAILED" })

Detailed Results:
-----------------
$($validationResults -join "`n")

$(if ($failedChecks.Count -gt 0) {
"
Failed Checks:
--------------
$($failedChecks -join "`n")
"
} else {
"
All validation checks passed successfully!
"
})

==============================================================================
"@

    $report | Out-File -FilePath $reportPath -Encoding UTF8 -Force

    Write-Host "[PROGRESS] Validation report saved to: $reportPath"

    # ========================================================================
    # Final Result
    # ========================================================================

    if ($failedChecks.Count -gt 0) {
        Write-Host ""
        Write-Host "[ERROR] Validation FAILED - $($failedChecks.Count) check(s) failed:"
        foreach ($check in $failedChecks) {
            Write-Host "[ERROR]   - $check"
        }
        Write-Host ""
        exit 1
    }
    else {
        Write-Host ""
        Write-Host "[SUCCESS] All validation checks passed!"
        Write-Host "[SUCCESS] Total: $passedChecks checks validated successfully"
        Write-Host "[SUCCESS] Golden image is ready for capture"
        Write-Host ""
        exit 0
    }

} catch {
    Write-Host "[ERROR] Exception occurred during validation: $($_.Exception.Message)"
    Write-Host "[ERROR] Stack trace: $($_.ScriptStackTrace)"
    exit 1
}

