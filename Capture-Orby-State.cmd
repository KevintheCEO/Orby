@echo off
cd /d "%~dp0"
powershell.exe -NoProfile -File "%~dp0Capture-Orby-State.ps1"
pause
