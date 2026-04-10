@echo off
setlocal

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0vm-cpu-usage.ps1"

echo ==========================================
echo Done.
pause
