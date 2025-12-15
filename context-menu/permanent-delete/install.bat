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
echo      永久秒删工具 v3.5
echo ========================================================
echo.

set "TARGET_DIR=C:\Scripts"
set "SOURCE_DIR=%~dp0"

:: 1. Create Directory
if not exist "%TARGET_DIR%" mkdir "%TARGET_DIR%"

:: 2. Copy Scripts
echo [1/3] 复制脚本文件...
copy /Y "%SOURCE_DIR%PermanentDelete.ps1" "%TARGET_DIR%\"
copy /Y "%SOURCE_DIR%Wrapper.vbs" "%TARGET_DIR%\"

:: 3. Unblock files (remove network download security mark)
echo [2/3] 解除网络下载安全标记...
powershell -NoProfile -Command "Unblock-File -Path '%TARGET_DIR%\Wrapper.vbs'; Unblock-File -Path '%TARGET_DIR%\PermanentDelete.ps1'"

:: 4. Register Context Menu
echo [3/3] 注册右键菜单...
reg import "%SOURCE_DIR%Add-PermanentDelete-ContextMenu.reg"

echo.
echo ========================================================
echo 安装完成! 不会再弹出安全警告了。
echo ========================================================
pause
