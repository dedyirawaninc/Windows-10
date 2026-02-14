@echo off
echo.
set CMDEXE=npm install -g webpack
echo Executing
echo %CMDEXE%
call %CMDEXE%
echo.
set CMDEXE=npm install -g webpack-cli
echo Executing
echo %CMDEXE%
call %CMDEXE%
