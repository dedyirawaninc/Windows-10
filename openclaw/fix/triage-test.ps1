$gatewayHost = "192.168.100.107"
$gatewayPort = 8789
$displayName = $env:COMPUTERNAME

Write-Host "[1/3] Checking running OpenClaw node process..." -ForegroundColor Cyan
Get-CimInstance Win32_Process |
  Where-Object { $_.Name -eq "node.exe" -and $_.CommandLine -match "openclaw.*node run" } |
  Select-Object ProcessId, CommandLine

Write-Host "[2/3] Checking gateway connectivity to $gatewayHost`:$gatewayPort..." -ForegroundColor Cyan
Test-NetConnection $gatewayHost -Port $gatewayPort

Write-Host "[3/3] Running node in foreground with debug logs..." -ForegroundColor Cyan
Write-Host "If you see 'pairing required', approve this node from an authorized client using 'openclaw nodes pending/approve'." -ForegroundColor Yellow
$env:DEBUG = "openclaw:*"
cmd /c openclaw.cmd node run --host $gatewayHost --port $gatewayPort --display-name $displayName
