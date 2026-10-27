@echo off
REM Gear Audit Updater launcher.
REM Runs GearAuditUpdater.ps1 with -ExecutionPolicy Bypass for this
REM script only (does not change your system policy), in STA mode
REM so the folder-picker dialog works.
powershell -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0GearAuditUpdater.ps1"
if errorlevel 1 (
    echo.
    echo The updater closed with an error. Press any key to close this window.
    pause >nul
)
