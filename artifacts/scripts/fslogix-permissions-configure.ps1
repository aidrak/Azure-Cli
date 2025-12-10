# Configure FSLogix Profile Share Permissions
$sharePath = "\\stavdfslogix63731.file.core.windows.net\fslogix-profiles"
$tenantName = "odieserverfit.onmicrosoft.com"

Write-Host "[*] Configuring NTFS permissions for FSLogix profile share"
Write-Host "[*] Share path: $sharePath"

# Remove inheritance and existing permissions
Write-Host "[*] Removing inheritance..."
icacls $sharePath /inheritance:r
if ($LASTEXITCODE -ne 0) { Write-Host "[x] Failed to remove inheritance"; exit 1 }

# CREATOR OWNER - Users get full control of their own profile folders
Write-Host "[*] Granting CREATOR OWNER permissions..."
icacls $sharePath /grant:r "CREATOR OWNER:(OI)(CI)(IO)(M)"
if ($LASTEXITCODE -ne 0) { Write-Host "[x] Failed to grant CREATOR OWNER"; exit 1 }

# AVD-Users-Admins - Full control for admins
Write-Host "[*] Granting AVD-Users-Admins permissions..."
icacls $sharePath /grant:r "AzureAD\AVD-Users-Admins@$tenantName:(OI)(CI)(F)"
if ($LASTEXITCODE -ne 0) { Write-Host "[x] Failed to grant AVD-Users-Admins"; exit 1 }

# AVD-Users-Standard - Modify permission for standard users
Write-Host "[*] Granting AVD-Users-Standard permissions..."
icacls $sharePath /grant:r "AzureAD\AVD-Users-Standard@$tenantName:(M)"
if ($LASTEXITCODE -ne 0) { Write-Host "[x] Failed to grant AVD-Users-Standard"; exit 1 }

# AVD-Devices-All - Session hosts need access to manage profiles
Write-Host "[*] Granting AVD-Devices-All permissions..."
icacls $sharePath /grant:r "AzureAD\AVD-Devices-All@$tenantName:(OI)(CI)(M)"
if ($LASTEXITCODE -ne 0) { Write-Host "[x] Failed to grant AVD-Devices-All"; exit 1 }

Write-Host "[v] Permissions configured successfully!"
Write-Host ""
Write-Host "[i] Verifying permissions:"
icacls $sharePath

exit 0

