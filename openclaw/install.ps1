$uri = "https://openclaw.ai/install.ps1"
$tmp = Join-Path $env:TEMP "openclaw-install.ps1"

Invoke-WebRequest -Uri $uri -UseBasicParsing -OutFile $tmp

Write-Host "Downloaded installer to: $tmp"
Write-Host "Installer content:"
Write-Host "------------------"
Get-Content $tmp
Write-Host "------------------"

$answer = Read-Host "Run the installer now? (Yes/No)"
if ($answer -match '^(?i:yes|y)$') {
  nvm install v22
  nvm use v22
  & powershell -ExecutionPolicy Bypass -File $tmp
} else {
  Write-Host "Skipped. You can run it later with:"
  Write-Host "  powershell -ExecutionPolicy Bypass -File `"$tmp`""
}
