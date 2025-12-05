param(
    [string]$AppName,
    [int]$ProcessId
)

$logDir = "C:\DeployLogs"
if (-not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force
}

$heartbeatFile = "$logDir\$($AppName).heartbeat"
$parentProcess = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue

Write-Host "[HEARTBEAT] Starting for $AppName (PID: $ProcessId)"

while ($parentProcess) {
    $timestamp = [datetime]::UtcNow.ToString("o")
    Set-Content -Path $heartbeatFile -Value $timestamp
    Start-Sleep -Seconds 30
    $parentProcess = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
}

Write-Host "[HEARTBEAT] Parent process $ProcessId for $AppName has exited. Stopping heartbeat."
