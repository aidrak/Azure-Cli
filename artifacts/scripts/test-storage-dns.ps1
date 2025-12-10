# Test DNS resolution for storage account
$storageFqdn = "stavdfslogix63731.file.core.windows.net"

Write-Host "[*] Testing DNS resolution for: $storageFqdn"
Write-Host ""

# Resolve DNS
$dnsResult = Resolve-DnsName -Name $storageFqdn -ErrorAction SilentlyContinue

if ($dnsResult) {
    Write-Host "[v] DNS Resolution Results:"
    $dnsResult | ForEach-Object {
        Write-Host "  Type: $($_.Type)"
        if ($_.Type -eq "A") {
            Write-Host "  IP Address: $($_.IPAddress)"
        }
        if ($_.Type -eq "CNAME") {
            Write-Host "  CNAME: $($_.NameHost)"
        }
    }
} else {
    Write-Host "[x] DNS resolution failed"
}

Write-Host ""
Write-Host "[*] Expected: Should resolve to private IP 10.0.3.4"
Write-Host "[*] If resolving to public IP (94.23.155.217), DNS is misconfigured"
Write-Host ""

# Test connectivity to private IP
Write-Host "[*] Testing connectivity to private IP 10.0.3.4:445"
$tcpTest = Test-NetConnection -ComputerName "10.0.3.4" -Port 445 -WarningAction SilentlyContinue
if ($tcpTest.TcpTestSucceeded) {
    Write-Host "[v] Can connect to private IP on port 445"
} else {
    Write-Host "[x] Cannot connect to private IP on port 445"
}
