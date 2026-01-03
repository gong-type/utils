@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion

:: ============================================================================
:: NukeIt v4.0 Uninstaller
:: ============================================================================

title NukeIt 卸载程序

:: Check for Administrator privileges
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo 正在请求管理员权限...
    powershell -Command "Start-Process '%~dpnx0' -Verb RunAs"
    exit /b
)

cls
echo.
echo  ╔══════════════════════════════════════════════════════════════════╗
echo  ║                     NukeIt 卸载程序                               ║
echo  ╚══════════════════════════════════════════════════════════════════╝
echo.

set "TARGET_DIR=C:\Scripts"

echo [1/3] 移除右键菜单...
reg delete "HKCU\Software\Classes\AllFilesystemObjects\shell\NukeIt" /f >nul 2>&1
reg delete "HKCU\Software\Classes\AllFilesystemObjects\shell\PermanentDelete" /f >nul 2>&1
reg delete "HKCU\Software\Classes\*\shell\PermanentDelete" /f >nul 2>&1
reg delete "HKCU\Software\Classes\Directory\shell\PermanentDelete" /f >nul 2>&1

echo [2/3] 删除脚本文件...
if exist "%TARGET_DIR%\NukeIt.ps1" del /F "%TARGET_DIR%\NukeIt.ps1"
if exist "%TARGET_DIR%\NukeIt.vbs" del /F "%TARGET_DIR%\NukeIt.vbs"
if exist "%TARGET_DIR%\PermanentDelete.ps1" del /F "%TARGET_DIR%\PermanentDelete.ps1"
if exist "%TARGET_DIR%\Wrapper.vbs" del /F "%TARGET_DIR%\Wrapper.vbs"

echo [3/3] 清理临时文件...
if exist "%TEMP%\NukeIt_Queue" rd /s /q "%TEMP%\NukeIt_Queue" 2>nul
if exist "%TEMP%\PD_Queue_v3" rd /s /q "%TEMP%\PD_Queue_v3" 2>nul
if exist "%TEMP%\NukeIt.log" del /f "%TEMP%\NukeIt.log" 2>nul

:: Check if C:\Scripts is empty and remove it
dir /a /b "%TARGET_DIR%" 2>nul | findstr "^" >nul || rmdir "%TARGET_DIR%" 2>nul

echo.
echo  ╔══════════════════════════════════════════════════════════════════╗
echo  ║  ✓ 卸载完成！                                                     ║
echo  ╚══════════════════════════════════════════════════════════════════╝
echo.
pause
