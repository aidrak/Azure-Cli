# Disable BitLocker (prevent issues during sysprep/capture)
Disable-BitLocker -MountPoint "C:" -ErrorAction SilentlyContinue

# Create Temp Directory
New-Item -Path "C:\Temp" -ItemType Directory -Force | Out-Null

# --- Install FSLogix ---
Write-Host "Installing FSLogix..."
Invoke-WebRequest -Uri "https://aka.ms/fslogix-latest" -OutFile "C:\Temp\FSLogix.zip"
Expand-Archive -Path "C:\Temp\FSLogix.zip" -DestinationPath "C:\Temp\FSLogix" -Force
Set-Location "C:\Temp\FSLogix\x64\Release"
.\FSLogixAppsSetup.exe /install /quiet /norestart

# --- VDOT Optimizations ---
Write-Host "Downloading and running VDOT..."
Invoke-WebRequest `
  -Uri "https://github.com/The-Virtual-Desktop-Team/Virtual-Desktop-Optimization-Tool/archive/refs/heads/main.zip" `
  -OutFile "C:\Temp\VDOT.zip"
Expand-Archive -Path "C:\Temp\VDOT.zip" -DestinationPath "C:\Temp\VDOT" -Force
Set-Location "C:\Temp\VDOT\Virtual-Desktop-Optimization-Tool-main"
# Run Optimizations (All)
.\Windows_VDOT.ps1 -Optimizations All -AcceptEULA -Verbose

# --- Cloud Kerberos & Entra Settings ---
Write-Host "Configuring Kerberos/Entra keys..."
$kerbPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\Kerberos\Parameters"
if (!(Test-Path $kerbPath)) { New-Item -Path $kerbPath -Force | Out-Null }
Set-ItemProperty -Path $kerbPath -Name "CloudKerberosTicketRetrievalEnabled" -Value 1 -Type DWord -Force

$azurePath = "HKLM:\Software\Policies\Microsoft\AzureADAccount"
if (!(Test-Path $azurePath)) { New-Item -Path $azurePath -Force | Out-Null }
Set-ItemProperty -Path $azurePath -Name "LoadCredKeyFromProfile" -Value 1 -Type DWord -Force

Write-Host "Configuration Complete."
