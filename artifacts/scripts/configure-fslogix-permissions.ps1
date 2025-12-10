# Configure FSLogix Profile Share Permissions
# Run this from an Entra ID-joined Windows machine (e.g., golden image VM)

# Run this from powershell admin window
# fslogix-permissions.ps1
# fslogix-permissions.ps1

# Variables
$sharePath = "\\stavdfslogix63731.file.core.windows.net\fslogix-profiles"
$adminGroup = "AVD-Users-Admins"
$standardGroup = "AVD-Users-Standard"
$deviceGroup = "AVD-Devices-All"

Write-Host "[*] Configuring NTFS permissions for FSLogix profile share" -ForegroundColor Cyan
Write-Host "[*] Share path: $sharePath" -ForegroundColor Cyan

# Remove inheritance and existing permissions
Write-Host "[*] Removing inheritance..." -ForegroundColor Yellow
icacls $sharePath /inheritance:r

# CREATOR OWNER - Users get full control of their own profile folders
Write-Host "[*] Granting CREATOR OWNER permissions..." -ForegroundColor Yellow
icacls $sharePath /grant:r "CREATOR OWNER:(OI)(CI)(IO)(M)"

# AVD-Users-Admins - Full control for admins
Write-Host "[*] Granting $adminGroup permissions..." -ForegroundColor Yellow
icacls $sharePath /grant:r "AzureAD\${adminGroup}:(OI)(CI)(F)"

# AVD-Users-Standard - Modify permission for standard users (to create profile folders)
Write-Host "[*] Granting $standardGroup permissions..." -ForegroundColor Yellow
icacls $sharePath /grant:r "AzureAD\${standardGroup}:(M)"

# AVD-Devices-All - Session hosts need access to manage profiles
Write-Host "[*] Granting $deviceGroup permissions..." -ForegroundColor Yellow
icacls $sharePath /grant:r "AzureAD\${deviceGroup}:(OI)(CI)(M)"

Write-Host "[v] Permissions configured successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "[i] Verifying permissions:" -ForegroundColor Cyan
icacls $sharePath

# Legend:
# (OI) - Object Inherit
# (CI) - Container Inherit
# (IO) - Inherit Only
# (M)  - Modify
# (F)  - Full Control
