param(
  [switch]$Quiet
)

$ErrorActionPreference = "Stop"

$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
  [Security.Principal.WindowsBuiltInRole]::Administrator
)

if (-not $isAdmin) {
  Write-Warning "AWS CLI v2 requires Administrator rights on Windows."
  Write-Host "Open PowerShell as Administrator, then run:"
  Write-Host "  cd `"$PWD`""
  Write-Host "  powershell -ExecutionPolicy Bypass -File `".\python\setup\awscli.ps1`""
  exit 1
}

$uri = "https://awscli.amazonaws.com/AWSCLIV2.msi"
$installer = Join-Path $env:TEMP "AWSCLIV2.msi"
$log = Join-Path $env:TEMP "AWSCLIV2-install.log"

$existingAws = Get-Command aws -ErrorAction SilentlyContinue
if ($existingAws) {
  Write-Host "Current aws command: $($existingAws.Source)"
}

Write-Host "Downloading AWS CLI v2 installer..."
Invoke-WebRequest -Uri $uri -UseBasicParsing -OutFile $installer

$msiArgs = @("/i", "`"$installer`"", "/L*v", "`"$log`"")
if ($Quiet) {
  $msiArgs += "/qn"
} else {
  $msiArgs += "/passive"
}

Write-Host "Installing AWS CLI v2..."
$process = Start-Process -FilePath "msiexec.exe" -ArgumentList $msiArgs -Wait -PassThru
if ($process.ExitCode -ne 0) {
  Write-Host "Installer log: $log"
  if (Test-Path $log) {
    Write-Host "Recent MSI errors:"
    Select-String -Path $log -Pattern "Return value 3|Error [0-9]+|MSI .* failed|Installation failed" |
      Select-Object -Last 20 |
      ForEach-Object { Write-Host "  $($_.Line.Trim())" }
  }
  Write-Error "AWS CLI installer failed with exit code $($process.ExitCode)."
  exit $process.ExitCode
}

$machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
$env:Path = "$machinePath;$userPath"

Write-Host "AWS CLI installed successfully."
aws --version
