@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "TARGET_PS1=%SCRIPT_DIR%install.ps1"

powershell -NoProfile -ExecutionPolicy Bypass -Command "Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force; & '%TARGET_PS1%'"

endlocal
