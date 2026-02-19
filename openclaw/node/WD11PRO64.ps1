# stop scheduled task + kill node

schtasks /End /TN "OpenClaw Node" 2>$null
Get-Process node -ErrorAction SilentlyContinue | Stop-Process -Force

# clear stale node identity (backup first)

$oc="$env:USERPROFILE\.openclaw"
$bak="$env:USERPROFILE\.openclaw-backup-$(Get-Date -Format yyyyMMdd-HHmmss)"

if (Test-Path $oc) { Copy-Item $oc $bak -Recurse -Force }

Get-ChildItem $oc -Recurse -File -ErrorAction SilentlyContinue |
  Where-Object { $_.Name -match 'pair|token|identity|node' } |
  Remove-Item -Force -ErrorAction SilentlyContinue

# run node foreground once with explicit gateway auth

$env:OPENCLAW_GATEWAY_URL="ws://192.168.100.107:8789"
$env:OPENCLAW_GATEWAY_TOKEN="4df27d5c3e80a68873b43bc44a7fd1bed4bea33c0c870781"
openclaw node run --host 192.168.100.107 --port 8789 --display-name WD11PRO64
openclaw node install --host 192.168.100.107 --port 8789 --display-name "WD11PRO64"
openclaw node status
