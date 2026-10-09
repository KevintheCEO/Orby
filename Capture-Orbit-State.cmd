@echo off
cd /d "%~dp0"
powershell.exe -NoProfile -File "%~dp0Capture-Orbit-State.ps1"
pause
