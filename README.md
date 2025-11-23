# Windows-10

Bugfix 250910 Error

.\wsl-v1\Ubuntu-20.04.ps1 : File Z:\Windows-10\wsl-v1\Ubuntu-20.04.ps1 cannot be loaded. The file
Z:\Windows-10\wsl-v1\Ubuntu-20.04.ps1 is not digitally signed. You cannot run this script on the current system. For
more information about running scripts and setting execution policy, see about_Execution_Policies at
https:/go.microsoft.com/fwlink/?LinkID=135170.
At line:1 char:1
+ .\wsl-v1\Ubuntu-20.04.ps1
+ ~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : SecurityError: (:) [], PSSecurityException
    + FullyQualifiedErrorId : UnauthorizedAccess

Solution

Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
