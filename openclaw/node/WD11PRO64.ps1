# stop task/service + kill node process

$taskName = "OpenClaw Node"
$gatewayHost = "192.168.100.107"
$gatewayPort = 8789
$displayName = $env:COMPUTERNAME
$nodeId = "$($env:COMPUTERNAME)-$(Get-Date -Format yyyyMMddHHmmss)"

schtasks /End /TN $taskName 2>$null
Get-Process node -ErrorAction SilentlyContinue | Stop-Process -Force
cmd /c openclaw.cmd node uninstall 2>$null

# clear stale pairing identity (backup first), but keep node runtime files

$oc = "$env:USERPROFILE\.openclaw"
$bak = "$env:USERPROFILE\.openclaw-backup-$(Get-Date -Format yyyyMMdd-HHmmss)"

if (Test-Path $oc) { Copy-Item $oc $bak -Recurse -Force }

Get-ChildItem $oc -Recurse -File -ErrorAction SilentlyContinue |
  Where-Object { $_.Name -match 'pair|token|identity' } |
  Remove-Item -Force -ErrorAction SilentlyContinue

# reinstall service with a fresh node id (clears old pairing token)

cmd /c openclaw.cmd node install --force --host $gatewayHost --port $gatewayPort --display-name $displayName --node-id $nodeId
cmd /c openclaw.cmd node restart
cmd /c openclaw.cmd node status --json
