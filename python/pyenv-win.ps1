if (Test-Path "./install-pyenv-win.ps1") {
  Remove-Item "./install-pyenv-win.ps1"
}

Invoke-WebRequest -UseBasicParsing -Uri "https://raw.githubusercontent.com/pyenv-win/pyenv-win/master/pyenv-win/install-pyenv-win.ps1" -OutFile "./install-pyenv-win.ps1"
&"./install-pyenv-win.ps1"

# Add pyenv-win paths to user PATH environment variable
$pyenvRoot = "$env:USERPROFILE\.pyenv\pyenv-win"
$binPath = "$pyenvRoot\bin"
$shimsPath = "$pyenvRoot\shims"

# Get current user PATH
$currentPath = [Environment]::GetEnvironmentVariable("PATH", "User")

# Add bin path if not already present
if ($currentPath -notlike "*$binPath*") {
  [Environment]::SetEnvironmentVariable("PATH",$binPath + [Environment]::GetEnvironmentVariable("PATH", "User"),"User")
} else {
  Write-Host "$binPath paths already exist in PATH."
}

# Add shims path if not already present
if ($currentPath -notlike "*$shimsPath*") {
  [Environment]::SetEnvironmentVariable("PATH",$shimsPath + [Environment]::GetEnvironmentVariable("PATH", "User"),"User")
} else {
  Write-Host "$shimsPath paths already exist in PATH."
}

pyenv --version