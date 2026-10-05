@echo off
cd /d "%~dp0"
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v Orby /t REG_SZ /d "\"%~dp0Start-Orby.cmd\"" /f
if errorlevel 1 echo Windows did not allow the per-user startup entry.
if not errorlevel 1 echo Orby will start with Windows for this user.
pause
