@echo off
setlocal

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0vm_cpu_usage.ps1"

echo ==========================================
echo Done.
pause
