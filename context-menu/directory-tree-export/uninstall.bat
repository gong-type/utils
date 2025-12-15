@echo off
setlocal EnableDelayedExpansion
chcp 65001 >nul 2>&1

net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Requesting Administrator...
    powershell -Command "Start-Process '%~dpnx0' -Verb RunAs"
    exit /b
)

cls
echo.
echo  ══════════════════════════════════════════════════════════════
echo              Directory Tree Export - Uninstall
echo  ══════════════════════════════════════════════════════════════
echo.

set "SOURCE_DIR=%~dp0"

echo  [1/2] Removing context menu...
reg import "%SOURCE_DIR%uninstall.reg" >nul 2>&1
if %errorLevel% equ 0 (
    echo        Done
) else (
    echo        Already removed or not found
)
echo.

echo  [2/2] Removing script file...
if exist "C:\Scripts\ExportTree.ps1" (
    del /F "C:\Scripts\ExportTree.ps1" >nul 2>&1
    echo        Done
) else (
    echo        Not found
)
echo.

echo  ══════════════════════════════════════════════════════════════
echo                      Uninstall Complete!
echo  ══════════════════════════════════════════════════════════════
echo.
pause
