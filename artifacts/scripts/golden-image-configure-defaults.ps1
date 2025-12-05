# ==============================================================================
# Configure Default Applications and Create Desktop Shortcuts
# ==============================================================================

Write-Host "[START] Configuring default applications: $(Get-Date -Format 'HH:mm:ss')"

try {
    $tempPath = "C:\Temp"
    $publicDesktop = "C:\Users\Public\Desktop"

    # ========================================================================
    # Part 1: Set Default Applications
    # ========================================================================

    Write-Host "[PROGRESS] Step 1/2: Setting default applications..."

    # Set Adobe Reader as default PDF application
    Write-Host "[PROGRESS] Setting Adobe Reader as default PDF handler..."
    try {
        cmd /c assoc .pdf=AcroExch.Document.DC 2>&1 | Out-Null

        # Create XML for DISM (for new user profiles)
        $xmlPath = "$tempPath\AdobeDefaults.xml"
        $xmlContent = @"
<?xml version="1.0" encoding="UTF-8"?>
<DefaultAssociations>
  <Association Identifier=".pdf" ProgId="AcroExch.Document.DC" ApplicationName="Adobe Acrobat Reader DC" />
  <Association Identifier=".pdfxml" ProgId="AcroExch.Document.DC" ApplicationName="Adobe Acrobat Reader DC" />
  <Association Identifier=".acrobatsecuritysettings" ProgId="AcroExch.Document.DC" ApplicationName="Adobe Acrobat Reader DC" />
  <Association Identifier=".fdf" ProgId="AcroExch.Document.DC" ApplicationName="Adobe Acrobat Reader DC" />
  <Association Identifier=".xfdf" ProgId="AcroExch.Document.DC" ApplicationName="Adobe Acrobat Reader DC" />
</DefaultAssociations>
"@

        $xmlContent | Out-File -FilePath $xmlPath -Encoding UTF8
        dism.exe /Online /Import-DefaultAppAssociations:$xmlPath 2>&1 | Out-Null

        Write-Host "[PROGRESS] Adobe Reader set as default PDF application"
    }
    catch {
        Write-Host "[PROGRESS] Note: Some default application settings may require user login"
    }

    # ========================================================================
    # Part 2: Create Public Desktop Shortcuts
    # ========================================================================

    Write-Host "[PROGRESS] Step 2/2: Creating desktop shortcuts..."

    $shell = New-Object -ComObject WScript.Shell

    # Helper function to create shortcuts
    function New-DesktopShortcut {
        param($Name, $Target, $Description)

        if (Test-Path $Target) {
            $shortcutPath = "$publicDesktop\$Name.lnk"
            $shortcut = $shell.CreateShortcut($shortcutPath)
            $shortcut.TargetPath = $Target
            $shortcut.Description = $Description
            $shortcut.Save()
            Write-Host "[PROGRESS] Created shortcut: $Name"
            return $true
        }
        else {
            Write-Host "[PROGRESS] Skipped $Name (target not found: $Target)"
            return $false
        }
    }

    # Check both Adobe paths
    $adobePath = "C:\Program Files\Adobe\Acrobat DC\Acrobat\Acrobat.exe"
    if (!(Test-Path $adobePath)) {
        $adobePath = "C:\Program Files (x86)\Adobe\Acrobat Reader DC\Reader\AcroRd32.exe"
    }

    # Create shortcuts
    $created = 0
    $created += New-DesktopShortcut "Adobe Acrobat Reader" $adobePath "Adobe Acrobat Reader DC"
    $created += New-DesktopShortcut "Google Chrome" "C:\Program Files\Google\Chrome\Application\chrome.exe" "Google Chrome"
    $created += New-DesktopShortcut "Microsoft Outlook" "C:\Program Files\Microsoft Office\root\Office16\OUTLOOK.EXE" "Microsoft Outlook"
    $created += New-DesktopShortcut "Microsoft Word" "C:\Program Files\Microsoft Office\root\Office16\WINWORD.EXE" "Microsoft Word"
    $created += New-DesktopShortcut "Microsoft Excel" "C:\Program Files\Microsoft Office\root\Office16\EXCEL.EXE" "Microsoft Excel"

    # Validation
    Write-Host "[VALIDATE] Verifying shortcuts created..."

    $requiredShortcuts = @(
        "$publicDesktop\Adobe Acrobat Reader.lnk",
        "$publicDesktop\Google Chrome.lnk",
        "$publicDesktop\Microsoft Word.lnk"
    )

    $missing = @()
    foreach ($shortcut in $requiredShortcuts) {
        if (-not (Test-Path $shortcut)) {
            $missing += $shortcut
        }
    }

    if ($missing.Count -gt 0) {
        Write-Host "[ERROR] Some required shortcuts were not created:"
        foreach ($s in $missing) {
            Write-Host "[ERROR]   - $s"
        }
        exit 1
    }

    Write-Host "[SUCCESS] Default applications configured and desktop shortcuts created"
    Write-Host "[SUCCESS] Created $created shortcuts in $publicDesktop"
    exit 0

} catch {
    Write-Host "[ERROR] Exception occurred: $($_.Exception.Message)"
    Write-Host "[ERROR] Stack trace: $($_.ScriptStackTrace)"
    exit 1
}

