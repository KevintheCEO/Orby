@echo off
setlocal
cd /d "%~dp0"
start "Orbit Notch" powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -STA -File "%~dp0Orby.ps1"
exit /b 0
