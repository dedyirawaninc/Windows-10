$taskName = "OpenClaw Node"
$gatewayHost = "192.168.100.107"
$gatewayPort = 8789
$gatewayUrl = "ws://$gatewayHost`:$gatewayPort"
$displayName = $env:COMPUTERNAME
$nodeId = "$($env:COMPUTERNAME)-PAIRING"
$targetNode = $displayName
$gatewayToken = "wmwz6b-GaPZj8ExQrsUXeeABd9MgL4E3Yzp5S6jrlVetx-ROKdyoW7hZ4O9Eclnc"
$oc = "$env:USERPROFILE\.openclaw"
$bak = "$env:USERPROFILE\.openclaw-backup-$(Get-Date -Format yyyyMMdd-HHmmss)"

$env:OPENCLAW_GATEWAY_URL = $gatewayUrl
$env:OPENCLAW_GATEWAY_TOKEN = $gatewayToken

function Get-AuthArgs {
  if ($gatewayToken) { return @("--token", $gatewayToken) }
  throw "Gateway auth token is missing."
}

function Approve-LatestPendingNode {
  $authArgs = Get-AuthArgs
  Write-Host "[5/6] Checking pending node pairing requests for '$targetNode'..." -ForegroundColor Cyan
  $pendingJson = & cmd /c openclaw.cmd nodes pending --url $gatewayUrl @authArgs --json

  if (-not $pendingJson) {
    Write-Host "No response from pending query." -ForegroundColor Yellow
    return
  }

  $pending = $pendingJson | ConvertFrom-Json
  if (-not $pending.pending -or $pending.pending.Count -eq 0) {
    Write-Host "No pending node pairing requests found." -ForegroundColor Green
    return
  }

  $candidates = $pending.pending | Sort-Object { $_.requestedAtMs } -Descending
  $targetCandidates = @()
  foreach ($candidate in $candidates) {
    $blob = ($candidate | ConvertTo-Json -Compress -Depth 8)
    if ($blob -match [Regex]::Escape($targetNode)) {
      $targetCandidates += $candidate
    }
  }
  if (-not $targetCandidates -or $targetCandidates.Count -eq 0) {
    Write-Host "No pending request matched '$targetNode'. Falling back to all pending requests." -ForegroundColor Yellow
    $targetCandidates = $candidates
  }

  foreach ($candidate in $targetCandidates) {
    $requestId = $candidate.requestId
    if (-not $requestId) { continue }

    Write-Host "Trying approval requestId: $requestId" -ForegroundColor Cyan
    $approveOut = & cmd /c openclaw.cmd nodes approve $requestId --url $gatewayUrl @authArgs --json 2>&1
    if ($LASTEXITCODE -eq 0) {
      $approveOut
      return
    }

    $approveText = ($approveOut | Out-String)
    if ($approveText -match "approval id does not match request") {
      Write-Host "Approval mismatch for requestId $requestId, trying next..." -ForegroundColor Yellow
      continue
    }

    Write-Host "Approval failed for requestId ${requestId}: $approveText" -ForegroundColor Yellow
  }

  Write-Host "All candidate approvals failed. Keep node session alive and retry." -ForegroundColor Yellow
}

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

Write-Host "[5/6] Installing and starting node service (background)..." -ForegroundColor Cyan
cmd /c openclaw.cmd node install --force --host $gatewayHost --port $gatewayPort --display-name $displayName
cmd /c openclaw.cmd node run --host $gatewayHost --port $gatewayPort --display-name $displayName --node-id $nodeId

Approve-LatestPendingNode

Write-Host "[6/6] Checking node service status..." -ForegroundColor Cyan
cmd /c openclaw.cmd node status --json
cmd /c openclaw.cmd node status

Write-Host "If status still shows 'pairing required', verify this token has approval permissions on the gateway." -ForegroundColor Yellow
