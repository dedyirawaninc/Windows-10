# Add pyenv-win paths to user PATH environment variable
$scriptRoot = "$env:USERPROFILE\.pyenv\pyenv-win"
$scriptPath = "$scriptRoot\Scripts"

pip install awscli --upgrade --user
python -m site --user-base

# Get current user PATH
$currentPath = [Environment]::GetEnvironmentVariable("PATH", "User")

# Add shims path if not already present
if ($currentPath -notlike "*$scriptPath*") {
  [Environment]::SetEnvironmentVariable("PATH",$scriptPath + [Environment]::GetEnvironmentVariable("PATH", "User"),"User")
} else {
  Write-Host "$scriptPath paths already exist in PATH."
}

# If error try to close and reopen vscode
aws --version