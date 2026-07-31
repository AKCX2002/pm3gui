@echo off
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\package-portable.ps1"
exit /b %ERRORLEVEL%
