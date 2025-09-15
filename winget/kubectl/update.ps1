# Install latest stable kubectl for Windows (x86_64)
# - Downloads from dl.k8s.io
# - Verifies SHA256
# - Installs to C:\Program Files\Kubernetes
# - Adds install dir to Machine PATH
# - Prints kubectl client version

# ----- Admin check -----
$IsAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $IsAdmin) {
  Write-Error "Please run this script in an elevated PowerShell (Run as Administrator)."
  exit 1
}

# ----- Prep -----
$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$InstallDir = "C:\Program Files\Kubernetes"
if (-not (Test-Path $InstallDir)) {
  New-Item -ItemType Directory -Path $InstallDir | Out-Null
}

# Temp working folder
$WorkDir = Join-Path $env:TEMP ("kubectl_install_{0}" -f ([guid]::NewGuid()))
New-Item -ItemType Directory -Path $WorkDir | Out-Null

try {
  Write-Host "Fetching latest stable version tag..." -ForegroundColor Cyan
  $stable = (Invoke-WebRequest -UseBasicParsing -Uri "https://dl.k8s.io/release/stable.txt").Content.Trim()
  if ([string]::IsNullOrWhiteSpace($stable)) { throw "Could not determine latest stable version." }
  Write-Host "Latest stable: $stable"

  $exeUrl = "https://dl.k8s.io/$stable/bin/windows/amd64/kubectl.exe"
  $shaUrl = "https://dl.k8s.io/$stable/bin/windows/amd64/kubectl.exe.sha256"

  $exePath = Join-Path $WorkDir "kubectl.exe"
  $shaPath = Join-Path $WorkDir "kubectl.exe.sha256"

  Write-Host "Downloading kubectl.exe ..." -ForegroundColor Cyan
  Invoke-WebRequest -UseBasicParsing -Uri $exeUrl -OutFile $exePath

  Write-Host "Downloading SHA256 checksum ..." -ForegroundColor Cyan
  Invoke-WebRequest -UseBasicParsing -Uri $shaUrl -OutFile $shaPath

  # Verify SHA256
  $expectedHash = (Get-Content $shaPath).Trim().ToLower()
  $actualHash   = (Get-FileHash $exePath -Algorithm SHA256).Hash.ToLower()
  if ($expectedHash -ne $actualHash) {
    throw "SHA256 mismatch! Expected $expectedHash but got $actualHash"
  }
  Write-Host "Checksum verified." -ForegroundColor Green

  # Install
  $destExe = Join-Path $InstallDir "kubectl.exe"

  # If file is locked, try to rename existing
  if (Test-Path $destExe) {
    try {
      Move-Item -Path $destExe -Destination ($destExe + ".old") -Force
    } catch {
      # If rename failed, attempt to stop any running kubectl (unlikely)
      Get-Process kubectl -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
      Start-Sleep -Milliseconds 300
      Move-Item -Path $destExe -Destination ($destExe + ".old") -Force
    }
  }

  Move-Item -Path $exePath -Destination $destExe -Force
  Write-Host "Installed: $destExe" -ForegroundColor Green

  # Ensure Machine PATH contains install dir
  $machinePath = [Environment]::GetEnvironmentVariable("Path","Machine")
  $pathParts = $machinePath.Split(';') | Where-Object { $_ -ne "" }
  if (-not ($pathParts -contains $InstallDir)) {
    $newMachinePath = ($machinePath.TrimEnd(';') + ";" + $InstallDir).Trim(';')
    [Environment]::SetEnvironmentVariable("Path", $newMachinePath, "Machine")
    Write-Host "Added to system PATH: $InstallDir" -ForegroundColor Green
  } else {
    Write-Host "System PATH already contains: $InstallDir"
  }

  # Update current session PATH so we can verify immediately
  $env:Path = [Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [Environment]::GetEnvironmentVariable("Path","User")

  # Verify
  Write-Host "Verifying kubectl installation..." -ForegroundColor Cyan
  $kubectl = Get-Command kubectl -ErrorAction Stop
  & $kubectl.Source version --client

  Write-Host "`nkubectl is installed and ready. You may need to open a new terminal for PATH changes to apply everywhere." -ForegroundColor Green
}
finally {
  # Clean up temp dir
  try { Remove-Item -Recurse -Force $WorkDir | Out-Null } catch {}
}