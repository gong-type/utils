@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion

:: ============================================================================
:: NukeIt v4.0 Installer - Ultimate Silent Delete
:: ============================================================================

title NukeIt v4.0 安装程序

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
echo  ║                                                                    ║
echo  ║     ███╗   ██╗██╗   ██╗██╗  ██╗███████╗██╗████████╗               ║
echo  ║     ████╗  ██║██║   ██║██║ ██╔╝██╔════╝██║╚══██╔══╝               ║
echo  ║     ██╔██╗ ██║██║   ██║█████╔╝ █████╗  ██║   ██║                  ║
echo  ║     ██║╚██╗██║██║   ██║██╔═██╗ ██╔══╝  ██║   ██║                  ║
echo  ║     ██║ ╚████║╚██████╔╝██║  ██╗███████╗██║   ██║                  ║
echo  ║     ╚═╝  ╚═══╝ ╚═════╝ ╚═╝  ╚═╝╚══════╝╚═╝   ╚═╝                  ║
echo  ║                                                                    ║
echo  ║                 Ultimate Silent Delete v4.0                        ║
echo  ╚══════════════════════════════════════════════════════════════════╝
echo.
echo  特性：
echo    • 100%% 静默删除，无弹窗，无黑框
echo    • 6层删除策略，处理各种疑难文件
echo    • 支持 nul/con/aux 等 Windows 保留名称
echo    • 支持超长路径（260+ 字符）
echo    • 自动解锁被占用的文件
echo    • 自动处理权限问题
echo.

set "TARGET_DIR=C:\Scripts"
set "SOURCE_DIR=%~dp0"

:: 1. Create Directory
echo [1/4] 创建目标目录...
if not exist "%TARGET_DIR%" mkdir "%TARGET_DIR%"

:: 2. Copy Scripts
echo [2/4] 复制脚本文件...
copy /Y "%SOURCE_DIR%NukeIt.ps1" "%TARGET_DIR%\" >nul
copy /Y "%SOURCE_DIR%NukeIt.vbs" "%TARGET_DIR%\" >nul

:: 3. Unblock files
echo [3/4] 解除网络下载安全标记...
powershell -NoProfile -Command "Get-ChildItem '%TARGET_DIR%\NukeIt.*' | Unblock-File" 2>nul

:: 4. Register Context Menu
echo [4/4] 注册右键菜单...

:: Remove old entries first
reg delete "HKCU\Software\Classes\AllFilesystemObjects\shell\PermanentDelete" /f >nul 2>&1
reg delete "HKCU\Software\Classes\*\shell\PermanentDelete" /f >nul 2>&1
reg delete "HKCU\Software\Classes\Directory\shell\PermanentDelete" /f >nul 2>&1
reg delete "HKCU\Software\Classes\AllFilesystemObjects\shell\NukeIt" /f >nul 2>&1

:: Add new entry
reg add "HKCU\Software\Classes\AllFilesystemObjects\shell\NukeIt" /ve /d "" /f >nul
reg add "HKCU\Software\Classes\AllFilesystemObjects\shell\NukeIt" /v "MUIVerb" /t REG_SZ /d "NukeIt 强力删除" /f >nul
reg add "HKCU\Software\Classes\AllFilesystemObjects\shell\NukeIt" /v "Icon" /t REG_SZ /d "shell32.dll,-240" /f >nul
reg add "HKCU\Software\Classes\AllFilesystemObjects\shell\NukeIt" /v "Position" /t REG_SZ /d "top" /f >nul
reg add "HKCU\Software\Classes\AllFilesystemObjects\shell\NukeIt" /v "MultiSelectModel" /t REG_SZ /d "Player" /f >nul
reg add "HKCU\Software\Classes\AllFilesystemObjects\shell\NukeIt\command" /ve /t REG_SZ /d "wscript.exe \"C:\Scripts\NukeIt.vbs\" \"%%1\"" /f >nul

echo.
echo  ╔══════════════════════════════════════════════════════════════════╗
echo  ║  ✓ 安装完成！                                                     ║
echo  ║                                                                    ║
echo  ║  使用方法：右键点击任意文件或文件夹，选择 "NukeIt 强力删除"       ║
echo  ║                                                                    ║
echo  ║  删除日志位置：%%TEMP%%\NukeIt.log                                  ║
echo  ╚══════════════════════════════════════════════════════════════════╝
echo.
pause
