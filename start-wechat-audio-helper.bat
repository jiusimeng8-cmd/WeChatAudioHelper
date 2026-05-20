@echo off
setlocal
cd /d "%~dp0"
if exist "%~dp0WeChatAudioHelper.exe" (
    start "" "%~dp0WeChatAudioHelper.exe"
) else (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0WeChatAudioHelper.ps1"
)
endlocal
