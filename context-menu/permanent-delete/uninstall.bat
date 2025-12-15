@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion

:: Check for Administrator privileges
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Requesting Administrator privileges...
    powershell -Command "Start-Process '%~dpnx0' -Verb RunAs"
    exit /b
)

echo ========================================================
echo      永久秒删工具 v3.0 卸载程序
echo ========================================================
echo.

set "TARGET_DIR=C:\Scripts"
set "SOURCE_DIR=%~dp0"

echo [1/2] 移除右键菜单...
reg import "%SOURCE_DIR%Remove-PermanentDelete-ContextMenu.reg"

echo [2/2] 删除脚本文件...
if exist "%TARGET_DIR%\PermanentDelete.ps1" del /F "%TARGET_DIR%\PermanentDelete.ps1"
if exist "%TARGET_DIR%\Wrapper.vbs" del /F "%TARGET_DIR%\Wrapper.vbs"

:: Check if C:\Scripts is empty and remove it
dir /a /b "%TARGET_DIR%" 2>nul | findstr "^" >nul || rmdir "%TARGET_DIR%"

echo.
echo ========================================================
echo 卸载完成!
echo ========================================================
pause
