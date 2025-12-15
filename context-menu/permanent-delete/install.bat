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
echo      永久秒删工具 v3.0 (极速无感版)
echo ========================================================
echo.
echo 新版特性:
echo   - 🚀 极速启动: 使用 VBS 替代 PowerShell 作为入口
echo   - 👻 完全无感: 普通删除无黑框、无弹窗
echo   - 💪 智能强力: 仅在需要时自动调用 PowerShell 解锁
echo.

set "TARGET_DIR=C:\Scripts"
set "SOURCE_DIR=%~dp0"

:: 1. Create Directory
if not exist "%TARGET_DIR%" mkdir "%TARGET_DIR%"

:: 2. Copy Scripts
echo [1/2] 复制脚本文件...
copy /Y "%SOURCE_DIR%PermanentDelete.ps1" "%TARGET_DIR%\"
copy /Y "%SOURCE_DIR%Wrapper.vbs" "%TARGET_DIR%\"

:: 3. Register Context Menu
echo [2/2] 注册右键菜单...
reg import "%SOURCE_DIR%Add-PermanentDelete-ContextMenu.reg"

echo.
echo ========================================================
echo 安装完成!
echo ========================================================
pause
