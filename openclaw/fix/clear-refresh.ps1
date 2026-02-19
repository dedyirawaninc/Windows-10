# ===== Windows: stop scheduled task + kill node =====
schtasks /End /TN "OpenClaw Node" 2>$null
Get-Process node -ErrorAction SilentlyContinue | Stop-Process -Force

# ===== Windows: backup .openclaw =====
$oc="$env:USERPROFILE\.openclaw"
$bak="$env:USERPROFILE\.openclaw-backup-$(Get-Date -Format yyyyMMdd-HHmmss)"
if (Test-Path $oc) { Copy-Item $oc $bak -Recurse -Force }

# ===== Windows: clear stale node identity/token/pair files =====
Get-ChildItem $oc -Recurse -File -ErrorAction SilentlyContinue |
  Where-Object { $_.Name -match 'pair|token|identity|node.*json|gateway.*json' } |
  Remove-Item -Force -ErrorAction SilentlyContinue

# ===== Windows: set fresh gateway URL/token =====
$env:OPENCLAW_GATEWAY_URL="ws://192.168.100.107:8789"
$env:OPENCLAW_GATEWAY_TOKEN="wmwz6b-GaPZj8ExQrsUXeeABd9MgL4E3Yzp5S6jrlVetx-ROKdyoW7hZ4O9Eclnc"

# ===== Windows: run node foreground with new node-id =====
openclaw node run --host 192.168.100.107 --port 8789 --display-name WD11PRO64 --node-id WD11PRO64-FRESH-$(Get-Date -Format yyyyMMddHHmmss)
