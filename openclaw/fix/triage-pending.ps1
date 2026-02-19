param(
  [string]$GatewayUrl = "ws://192.168.100.107:8789",
  [string]$Token = "4df27d5c3e80a68873b43bc44a7fd1bed4bea33c0c870781",
  [string]$Password,
  [string]$RequestId,
  [switch]$ApproveLatest,
  [string]$TargetNode = "WD11PRO64",
  [switch]$BootstrapExecAllowlist = $true,
  [int]$WaitTimeoutSeconds = 60,
  [int]$PollIntervalSeconds = 3
)

$ErrorActionPreference = "Stop"

function Get-AuthArgs {
  if ($Password) { return @("--password", $Password) }
  if ($Token) { return @("--token", $Token) }
  throw "Provide -Token or -Password."
}

function Add-ExecAllowlistDefaults {
  param(
    [string]$Node,
    [string]$Url,
    [array]$AuthArgs
  )

  if (-not $BootstrapExecAllowlist) { return }

  Write-Host "[post] Bootstrapping exec allowlist defaults for '$Node'..." -ForegroundColor Cyan
  $patterns = @(
    "C:\\Windows\\System32\\cmd.exe",
    "C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe",
    "C:\\Program Files\\PowerShell\\7\\pwsh.exe",
    "C:\\Program Files\\nodejs\\node.exe",
    "C:\\Python314\\python.exe"
  )

  foreach ($pattern in $patterns) {
    $out = & cmd /c openclaw.cmd approvals allowlist add --gateway --node $Node --agent "*" --url $Url @AuthArgs "$pattern" --json 2>&1
    if ($LASTEXITCODE -eq 0) {
      Write-Host "Allowlisted: $pattern" -ForegroundColor Green
      continue
    }

    $text = ($out | Out-String)
    if ($text -match "already exists|duplicate|already in allowlist") {
      Write-Host "Already allowlisted: $pattern" -ForegroundColor DarkYellow
      continue
    }

    Write-Host "Allowlist add failed for $pattern" -ForegroundColor Yellow
    Write-Host $text -ForegroundColor DarkYellow
  }
}

$authArgs = Get-AuthArgs

if (-not $RequestId -and -not $ApproveLatest) {
  Write-Host "No approval flag provided. Auto-enabling -ApproveLatest." -ForegroundColor Yellow
  $ApproveLatest = $true
}

Write-Host "[1/2] Checking pending node pairing requests..." -ForegroundColor Cyan
& cmd /c openclaw.cmd nodes pending --url $GatewayUrl @authArgs --json

if ($RequestId) {
  Write-Host "[2/2] Approving request id: $RequestId" -ForegroundColor Cyan
  & cmd /c openclaw.cmd nodes approve $RequestId --url $GatewayUrl @authArgs --json
  if ($LASTEXITCODE -eq 0) {
    Add-ExecAllowlistDefaults -Node $TargetNode -Url $GatewayUrl -AuthArgs $authArgs
  }
  exit $LASTEXITCODE
}

if ($ApproveLatest) {
  Write-Host "[2/2] Approving pending request for target node '$TargetNode' (newest first, with mismatch fallback)..." -ForegroundColor Cyan
  $deadline = (Get-Date).AddSeconds($WaitTimeoutSeconds)
  $candidates = @()
  while ((Get-Date) -lt $deadline) {
    $pendingJson = & cmd /c openclaw.cmd nodes pending --url $GatewayUrl @authArgs --json
    if (-not $pendingJson) { throw "No response from pending query." }

    $pending = $pendingJson | ConvertFrom-Json
    if ($pending.pending -and $pending.pending.Count -gt 0) {
      $candidates = $pending.pending | Sort-Object { $_.requestedAtMs } -Descending
      break
    }

    Write-Host "No pending pair yet. Waiting $PollIntervalSeconds seconds..." -ForegroundColor Yellow
    Start-Sleep -Seconds $PollIntervalSeconds
  }

  if (-not $candidates -or $candidates.Count -eq 0) {
    throw "No pending requests found within timeout (${WaitTimeoutSeconds}s). Keep triage-node running and retry."
  }

  $targetCandidates = @()
  foreach ($candidate in $candidates) {
    $blob = ($candidate | ConvertTo-Json -Compress -Depth 8)
    if ($blob -match [Regex]::Escape($TargetNode)) {
      $targetCandidates += $candidate
    }
  }

  if (-not $targetCandidates -or $targetCandidates.Count -eq 0) {
    Write-Host "No pending request matched target node '$TargetNode'. Falling back to all pending requests." -ForegroundColor Yellow
    $targetCandidates = $candidates
  }

  foreach ($candidate in $targetCandidates) {
    $candidateId = $candidate.requestId
    if (-not $candidateId) { continue }

    Write-Host "Trying approve requestId: $candidateId" -ForegroundColor Cyan
    $approveOut = & cmd /c openclaw.cmd nodes approve $candidateId --url $GatewayUrl @authArgs --json 2>&1
    $approveCode = $LASTEXITCODE

    if ($approveCode -eq 0) {
      $approveOut
      Add-ExecAllowlistDefaults -Node $TargetNode -Url $GatewayUrl -AuthArgs $authArgs
      exit 0
    }

    $approveText = ($approveOut | Out-String)
    if ($approveText -match "approval id does not match request") {
      Write-Host "RequestId mismatch for $candidateId, trying next pending request..." -ForegroundColor Yellow
      continue
    }

    throw "Approval failed for requestId $candidateId. Output: $approveText"
  }

  throw "All pending requests failed with approval-id mismatch. Refresh pending list and try again while node run stays active."
}
