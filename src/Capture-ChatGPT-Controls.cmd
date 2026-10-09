@echo off
cd /d "%~dp0"
powershell.exe -NoProfile -STA -File "%~dp0Capture-ChatGPT-Controls.ps1"
pause
