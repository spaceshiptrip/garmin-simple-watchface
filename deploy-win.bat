@echo off
setlocal

set "SDK_BIN=%APPDATA%\Garmin\ConnectIQ\Sdks\connectiq-sdk-win-9.1.0-2026-03-09-6a872a80b\bin"
set "DEVELOPER_KEY=%USERPROFILE%\Workspaces\garmin-fenix-simple-intervals\developer_key"

echo Building watchface...
call "%SDK_BIN%\monkeyc.bat" -f monkey.jungle -o build.prg -y "%DEVELOPER_KEY%" -d epix2pro51mm
if %ERRORLEVEL% neq 0 (
    echo Build failed!
    exit /b 1
)

echo Deploying to watch...
powershell -ExecutionPolicy Bypass -File "%~dp0deploy-watch.ps1"
