Write-Output "--- Checking Chocolatey ---"
choco list --local-only

Write-Output "--- Searching for Chrome ---"
$chrome = Get-ChildItem -Path "C:\Program Files", "C:\Program Files (x86)" -Filter "chrome.exe" -Recurse -ErrorAction SilentlyContinue
if ($chrome) {
    Write-Output "Found Chrome at: $($chrome.FullName)"
} else {
    Write-Output "Chrome NOT found in standard paths."
}

Write-Output "--- Searching for Adobe Reader ---"
$adobe = Get-ChildItem -Path "C:\Program Files", "C:\Program Files (x86)" -Filter "AcroRd32.exe" -Recurse -ErrorAction SilentlyContinue
if ($adobe) {
    Write-Output "Found Adobe Reader at: $($adobe.FullName)"
} else {
    Write-Output "Adobe Reader NOT found in standard paths."
}
