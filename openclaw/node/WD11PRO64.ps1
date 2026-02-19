$taskName = "OpenClaw Node"
$gatewayHost = "192.168.100.107"
$gatewayPort = 8789
$displayName = $env:COMPUTERNAME
$nodeId = "$($env:COMPUTERNAME)-$(Get-Date -Format yyyyMMddHHmmss)"
$oc = "$env:USERPROFILE\.openclaw"
$bak = "$env:USERPROFILE\.openclaw-backup-$(Get-Date -Format yyyyMMdd-HHmmss)"

Write-Host "[1/5] Checking running OpenClaw node process..." -ForegroundColor Cyan
Get-CimInstance Win32_Process |
  Where-Object { $_.Name -eq "node.exe" -and $_.CommandLine -match "openclaw.*node run" } |
  Select-Object ProcessId, CommandLine

Write-Host "[2/5] Checking gateway connectivity to $gatewayHost`:$gatewayPort..." -ForegroundColor Cyan
Test-NetConnection $gatewayHost -Port $gatewayPort

Write-Host "[3/5] Stopping old node service/process..." -ForegroundColor Cyan
schtasks /End /TN $taskName 2>$null
Get-Process node -ErrorAction SilentlyContinue | Stop-Process -Force
cmd /c openclaw.cmd node uninstall 2>$null

Write-Host "[4/5] Resetting stale pairing files (with backup)..." -ForegroundColor Cyan
if (Test-Path $oc) { Copy-Item $oc $bak -Recurse -Force }
Get-ChildItem $oc -Recurse -File -ErrorAction SilentlyContinue |
  Where-Object { $_.Name -match 'pair|token|identity' } |
  Remove-Item -Force -ErrorAction SilentlyContinue

Write-Host "[5/5] Installing and starting node service (background)..." -ForegroundColor Cyan
cmd /c openclaw.cmd node install --force --host $gatewayHost --port $gatewayPort --display-name $displayName --node-id $nodeId
cmd /c openclaw.cmd node restart
cmd /c openclaw.cmd node status --json
cmd /c openclaw.cmd node status

Write-Host "If status shows 'pairing required', approve this node from an authorized client using 'openclaw nodes pending/approve'." -ForegroundColor Yellow
