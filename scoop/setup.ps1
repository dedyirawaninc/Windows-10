$policy = Get-ExecutionPolicy

if ($policy -eq 'Restricted' -or $policy -eq 'AllSigned') {
  try {
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force -ErrorAction Stop
  }
  catch {
    Write-Warning "Could not update CurrentUser execution policy. Effective policy is '$policy'."
    Write-Warning $_.Exception.Message
  }
}

Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
