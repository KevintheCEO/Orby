@echo off
setlocal
cd /d "%~dp0"
echo Keep ChatGPT visible and actively THINKING/WORKING before pressing a key.
pause
powershell.exe -NoLogo -NoProfile -STA -File "%~dp0Capture-ChatGPT-UI.ps1"
echo.
echo Send this file to ChatGPT if detection still misses:
echo %%LOCALAPPDATA%%\OrbitNotch\chatgpt-ui-capture.txt
pause
