@echo off
cd /d "%~dp0"
if exist "%~dp0Orby.exe" (
    start "" /min "%~dp0Orby.exe"
) else (
    start "" /min powershell.exe -NoLogo -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -STA -File "%~dp0Orby.ps1"
)
