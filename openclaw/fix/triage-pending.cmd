@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "TARGET_PS1=%SCRIPT_DIR%triage-pending.ps1"

powershell -NoProfile -ExecutionPolicy Bypass -File "%TARGET_PS1%" %*

endlocal
