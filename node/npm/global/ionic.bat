@echo off
echo.
set CMDEXE=npm uninstall -g ionic
echo Executing
echo %CMDEXE%
call %CMDEXE%
echo.
set CMDEXE=npm install -g @ionic/cli
echo Executing
echo %CMDEXE%
call %CMDEXE%
