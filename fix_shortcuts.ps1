$publicDesktop = "C:\Users\Public\Desktop"
$shell = New-Object -ComObject WScript.Shell

function Create-Shortcut {
    param($Path, $Target, $Desc)
    try {
        if (Test-Path $Target) {
            $s = $shell.CreateShortcut($Path)
            $s.TargetPath = $Target
            $s.Description = $Desc
            $s.Save()
            Write-Output "SUCCESS: Created $Path"
        } else {
            Write-Output "ERROR: Target not found for $Desc at $Target"
        }
    } catch {
        Write-Output "ERROR: Failed to create shortcut for $Desc. $_"
    }
}

Write-Output "--- Starting Shortcut Creation ---"

# Adobe Acrobat Reader
Create-Shortcut "$publicDesktop\Adobe Acrobat Reader.lnk" "C:\Program Files (x86)\Adobe\Acrobat Reader DC\Reader\AcroRd32.exe" "Adobe Acrobat Reader DC"

# Google Chrome
Create-Shortcut "$publicDesktop\Google Chrome.lnk" "C:\Program Files\Google\Chrome\Application\chrome.exe" "Google Chrome"

# Microsoft Outlook
Create-Shortcut "$publicDesktop\Microsoft Outlook.lnk" "C:\Program Files\Microsoft Office\root\Office16\OUTLOOK.EXE" "Microsoft Outlook"

# Microsoft Word
Create-Shortcut "$publicDesktop\Microsoft Word.lnk" "C:\Program Files\Microsoft Office\root\Office16\WINWORD.EXE" "Microsoft Word"

# Microsoft Excel
Create-Shortcut "$publicDesktop\Microsoft Excel.lnk" "C:\Program Files\Microsoft Office\root\Office16\EXCEL.EXE" "Microsoft Excel"

# Microsoft Access
Create-Shortcut "$publicDesktop\Microsoft Access.lnk" "C:\Program Files\Microsoft Office\root\Office16\MSACCESS.EXE" "Microsoft Access"

Write-Output "--- Verification ---"
$shortcuts = Get-ChildItem "$publicDesktop\*.lnk"
if ($shortcuts) {
    Write-Output "Found $($shortcuts.Count) shortcuts in ${publicDesktop}:"
    $shortcuts | Select-Object -ExpandProperty Name
} else {
    Write-Output "NO SHORTCUTS FOUND in $publicDesktop"
}
