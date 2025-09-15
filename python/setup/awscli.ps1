# Get current user PATH
$currentPath = [Environment]::GetEnvironmentVariable("PATH", "User")

pip install awscli --upgrade --user

python -m site --user-base

# Add python scripts paths to user PATH environment variable
$pythonScripts = "$env:USERPROFILE\AppData\Roaming\Python\Python310\Scripts"

# Add python scripts path if not already present
if ($currentPath -notlike "*$pythonScripts*") {
  [Environment]::SetEnvironmentVariable("PATH",$pythonScripts + [Environment]::GetEnvironmentVariable("PATH", "User"),"User")
} else {
  Write-Host "$pythonScripts paths already exist in PATH."
}

# If error try to close and reopen vscode
aws --version