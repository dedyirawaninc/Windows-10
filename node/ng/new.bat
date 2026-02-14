@echo off
echo.
set CURRDIR00=%~dp0
set CURFILE00=%~nx0
set CURNAME00=%~n0
rem split path with delimiter
for /f "tokens=1,2,3,4,5,6,7,8,9 delims=\ " %%a in ("%~dp0") do (
  set CURRDIR01=%%a & set CURRDIR02=%%b & set CURRDIR03=%%c
  set CURRDIR04=%%d & set CURRDIR05=%%e & set CURRDIR06=%%f
  set CURRDIR07=%%g & set CURRDIR08=%%h & set CURRDIR09=%%i
)
rem trim spaces
echo........
if not "%CURRDIR01%"=="" set CURRDIR01=%CURRDIR01: =%
if not "%CURRDIR02%"=="" set CURRDIR02=%CURRDIR02: =%
if not "%CURRDIR03%"=="" set CURRDIR03=%CURRDIR03: =%
if not "%CURRDIR04%"=="" set CURRDIR04=%CURRDIR04: =%
if not "%CURRDIR05%"=="" set CURRDIR05=%CURRDIR05: =%
if not "%CURRDIR06%"=="" set CURRDIR06=%CURRDIR06: =%
if not "%CURRDIR07%"=="" set CURRDIR07=%CURRDIR07: =%
if not "%CURRDIR08%"=="" set CURRDIR08=%CURRDIR08: =%
if not "%CURRDIR09%"=="" set CURRDIR09=%CURRDIR09: =%
rem display individual variable
echo. [%CURRDIR00%] [%CURFILE00%] [%CURNAME00%]
echo. [%CURRDIR01%] [%CURRDIR02%] [%CURRDIR03%]
echo. [%CURRDIR04%] [%CURRDIR05%] [%CURRDIR06%]
echo. [%CURRDIR07%] [%CURRDIR08%] [%CURRDIR09%]
rem display and change path
echo........
