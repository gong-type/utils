@echo off
setlocal EnableDelayedExpansion

:: Check for Administrator privileges
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Requesting Administrator privileges...
    powershell -Command "Start-Process '%~dpnx0' -Verb RunAs"
    exit /b
)

echo ========================================================
echo       Install Directory Tree Export Tool
echo ========================================================
echo.

set "TARGET_DIR=C:\Scripts"
set "SOURCE_DIR=%~dp0"

:: 1. Create Directory
if not exist "%TARGET_DIR%" (
    echo [1/3] Creating %TARGET_DIR%...
    mkdir "%TARGET_DIR%"
) else (
    echo [1/3] Target directory exists.
)

:: 2. Copy Scripts
echo [2/3] Copying scripts...
copy /Y "%SOURCE_DIR%Export-DirectoryTree.ps1" "%TARGET_DIR%\"
copy /Y "%SOURCE_DIR%ExportTree-ContextMenu.ps1" "%TARGET_DIR%\"

:: 3. Register Context Menu
echo [3/3] Registering context menu...
reg import "%SOURCE_DIR%Add-ExportTree-ContextMenu.reg"

echo.
echo ========================================================
echo Installation Complete!
echo.
pause
