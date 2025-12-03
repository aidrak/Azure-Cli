# --- Cleanup Chocolatey ---
Write-Host "Cleaning up Chocolatey..."
Remove-Item -Path "C:\ProgramData\chocolatey" -Recurse -Force -ErrorAction SilentlyContinue
$env:Path = ($env:Path -split ';' | Where-Object { $_ -notlike "*chocolatey*" }) -join ';'
[Environment]::SetEnvironmentVariable("Path", $env:Path, "Machine")

# --- Install Google Chrome (Direct MSI) ---
Write-Host "Downloading Google Chrome Enterprise..."
$chromeUrl = "https://dl.google.com/dl/chrome/install/googlechromestandaloneenterprise64.msi"
Invoke-WebRequest -Uri $chromeUrl -OutFile "C:\Temp\Chrome.msi"

Write-Host "Installing Chrome..."
Start-Process "msiexec.exe" -ArgumentList "/i C:\Temp\Chrome.msi /quiet /norestart" -Wait
Write-Host "Chrome Installed."

# --- Install Adobe Reader (Direct EXE) ---
Write-Host "Downloading Adobe Reader..."
# Using the Enterprise generic link or a specific version if needed. 
# This is the standard Enterprise DC installer link structure.
$adobeUrl = "https://ardownload2.adobe.com/pub/adobe/reader/win/AcrobatDC/2300320201/AcroRdrDC2300320201_en_US.exe"
Invoke-WebRequest -Uri $adobeUrl -OutFile "C:\Temp\AdobeReader.exe"

Write-Host "Installing Adobe Reader..."
# /sAll = Silent All, /rs = Reboot Suppress, /msi EULA_ACCEPT=YES
Start-Process "C:\Temp\AdobeReader.exe" -ArgumentList "/sAll /rs /msi EULA_ACCEPT=YES" -Wait
Write-Host "Adobe Reader Installed."

# --- Re-create Shortcuts ---
Write-Host "Creating Shortcuts..."
$publicDesktop = "C:\Users\Public\Desktop"
$shell = New-Object -ComObject WScript.Shell

function Create-Shortcut {
    param($Path, $Target, $Desc)
    if (Test-Path $Target) {
        $s = $shell.CreateShortcut($Path)
        $s.TargetPath = $Target
        $s.Description = $Desc
        $s.Save()
        Write-Host "SUCCESS: Created $Path"
    } else {
        Write-Host "ERROR: Target not found: $Target"
    }
}

# Note: Paths might differ slightly for 64-bit vs 32-bit Adobe.
# We check both common locations for Adobe.
$adobePath = "C:\Program Files\Adobe\Acrobat DC\Acrobat\Acrobat.exe"
if (!(Test-Path $adobePath)) { $adobePath = "C:\Program Files (x86)\Adobe\Acrobat Reader DC\Reader\AcroRd32.exe" }

Create-Shortcut "${publicDesktop}\Adobe Acrobat Reader.lnk" $adobePath "Adobe Acrobat Reader DC"
Create-Shortcut "${publicDesktop}\Google Chrome.lnk" "C:\Program Files\Google\Chrome\Application\chrome.exe" "Google Chrome"

# Set Default PDF
cmd /c assoc .pdf=AcroExch.Document.DC
