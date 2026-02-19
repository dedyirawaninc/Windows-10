param(
  [string]$GatewayUrl = "ws://192.168.100.107:8789",
  [string]$Token = "4df27d5c3e80a68873b43bc44a7fd1bed4bea33c0c870781",
  [string]$Password,
  [string]$RequestId,
  [switch]$ApproveLatest
)

$ErrorActionPreference = "Stop"

function Get-AuthArgs {
  if ($Password) { return @("--password", $Password) }
  if ($Token) { return @("--token", $Token) }
  throw "Provide -Token or -Password."
}

$authArgs = Get-AuthArgs

Write-Host "[1/2] Checking pending node pairing requests..." -ForegroundColor Cyan
& cmd /c openclaw.cmd nodes pending --url $GatewayUrl @authArgs --json

if ($RequestId) {
  Write-Host "[2/2] Approving request id: $RequestId" -ForegroundColor Cyan
  & cmd /c openclaw.cmd nodes approve $RequestId --url $GatewayUrl @authArgs --json
  exit $LASTEXITCODE
}

if ($ApproveLatest) {
  Write-Host "[2/2] Approving latest pending request..." -ForegroundColor Cyan
  $pendingJson = & cmd /c openclaw.cmd nodes pending --url $GatewayUrl @authArgs --json
  if (-not $pendingJson) { throw "No response from pending query." }

  $pending = $pendingJson | ConvertFrom-Json
  $latestId = $null

  if ($pending.pending -and $pending.pending.Count -gt 0) {
    $latest = $pending.pending | Sort-Object { $_.requestedAtMs } -Descending | Select-Object -First 1
    $latestId = $latest.requestId
  }

  if (-not $latestId) {
    throw "No pending requests found to approve."
  }

  & cmd /c openclaw.cmd nodes approve $latestId --url $GatewayUrl @authArgs --json
  exit $LASTEXITCODE
}

Write-Host "No approval action requested. Use -RequestId <id> or -ApproveLatest." -ForegroundColor Yellow
