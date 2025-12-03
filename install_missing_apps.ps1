Write-Output "--- Retrying App Installation (Ignore Checksums) ---"

# Refresh env vars
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

Write-Output "Installing Adobe Reader..."
choco install adobereader -y --verbose --ignore-checksums

Write-Output "Installing Google Chrome..."
choco install googlechrome -y --verbose --ignore-checksums

# Retry Shortcuts
$publicDesktop = "C:\Users\Public\Desktop"
$shell = New-Object -ComObject WScript.Shell

function Create-Shortcut {
    param($Path, $Target, $Desc)
    if (Test-Path $Target) {
        $s = $shell.CreateShortcut($Path)
        $s.TargetPath = $Target
        $s.Description = $Desc
        $s.Save()
        Write-Output "SUCCESS: Created $Path"
    } else {
        Write-Output "ERROR: Target still not found: $Target"
    }
}

Write-Output "--- Re-creating Shortcuts ---"
Create-Shortcut "$publicDesktop\Adobe Acrobat Reader.lnk" "C:\Program Files (x86)\Adobe\Acrobat Reader DC\Reader\AcroRd32.exe" "Adobe Acrobat Reader DC"
Create-Shortcut "$publicDesktop\Google Chrome.lnk" "C:\Program Files\Google\Chrome\Application\chrome.exe" "Google Chrome"

# Set Default PDF
cmd /c assoc .pdf=AcroExch.Document.DC