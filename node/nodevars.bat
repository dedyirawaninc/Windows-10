@echo off

rem setup enviroment variable in file
set "ANDROID_HOME=F:\VBoxShared\Programs\Android\android-sdk-windows"
set "ANDROID_HOME=%ANDROID_HOME%;F:\VBoxShared\Programs\Android\android-sdk-windows\build-tools"
set "ANDROID_HOME=%ANDROID_HOME%;F:\VBoxShared\Programs\Android\android-sdk-windows\platform-tools"
set "ANDROID_HOME=%ANDROID_HOME%;F:\VBoxShared\Programs\Android\android-sdk-windows\tools"
set "GRADLE_HOME=F:\Gradle49"
set "GRADLE_HOME=%GRADLE_HOME%;F:\Gradle49\bin"
set "JAVA_HOME=C:\Program Files\Java\jdk1.8.0_161"
set "PATH=%PATH%;%ADB_HOME%;%ANDROID_HOME%;%GRADLE_HOME%;%JAVA_HOME%"

rem Ensure this Node.js and npm are first in the PATH
set "PATH=%APPDATA%\npm;%~dp0;%PATH%"

setlocal enabledelayedexpansion
pushd "%~dp0"

rem Figure out the Node.js version.
set print_version=.\node.exe -p -e "process.versions.node + ' (' + process.arch + ')'"
for /F "usebackq delims=" %%v in (`%print_version%`) do set version=%%v

rem Print message.
if exist npm.cmd (
  echo Your environment has been set up for using Node.js !version! and npm.
) else (
  echo Your environment has been set up for using Node.js !version!.
)

popd
endlocal

rem If we're in the Node.js directory, change to the user's home dir.
if "%CD%\"=="%~dp0" cd /d "%HOMEDRIVE%%HOMEPATH%"
