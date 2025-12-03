# Clean temp folders
Remove-Item -Path "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "C:\Windows\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue

# Clear Event Logs
wevtutil el | ForEach-Object { wevtutil cl "$_" }

# Run Sysprep (Generalize and Shutdown)
Start-Process -FilePath "C:\Windows\System32\Sysprep\sysprep.exe" -ArgumentList "/oobe /generalize /shutdown /quiet" -Wait
