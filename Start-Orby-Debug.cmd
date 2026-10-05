@echo off
cd /d "%~dp0"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0Orby.ps1" -DebugMode
echo.
echo Log: %%LOCALAPPDATA%%\Orby\orby.log
pause
