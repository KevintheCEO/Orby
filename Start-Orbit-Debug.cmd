@echo off
setlocal
cd /d "%~dp0"
echo [Orbit] Starting v1.3 log-state fix debug build...
echo.
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0Orby.ps1" -DebugMode
echo.
echo Orbit exited. Log: %%LOCALAPPDATA%%\Orby\orby.log
pause
