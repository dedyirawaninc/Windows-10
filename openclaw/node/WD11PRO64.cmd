@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "TARGET_PS1=%SCRIPT_DIR%WD11PRO64.ps1"

REM Block running inside VS Code terminal
if defined VSCODE_PID (
  echo This installer must be run from Windows PowerShell, not inside VS Code.
  echo Close VS Code terminal and run install.cmd in an elevated PowerShell.
  exit /b 1
)
if /I "%TERM_PROGRAM%"=="vscode" (
  echo This installer must be run from Windows PowerShell, not inside VS Code.
  echo Close VS Code terminal and run install.cmd in an elevated PowerShell.
  exit /b 1
)

REM Require Administrator privileges
net session >nul 2>&1
if errorlevel 1 (
  echo This installer must be run as Administrator.
  echo Right-click install.cmd and choose "Run as administrator".
  exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -Command "Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force; & '%TARGET_PS1%'"

endlocal
