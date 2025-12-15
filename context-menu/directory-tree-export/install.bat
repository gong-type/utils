@echo off
setlocal EnableDelayedExpansion
chcp 65001 >nul 2>&1

:: ============================================================
::  目录结构导出工具 - 安装脚本
:: ============================================================

:: 检查管理员权限
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo 正在请求管理员权限...
    powershell -Command "Start-Process '%~dpnx0' -Verb RunAs"
    exit /b
)

cls
echo.
echo  ══════════════════════════════════════════════════════════════
echo  ║           目录结构导出工具 - 安装程序                      ║
echo  ══════════════════════════════════════════════════════════════
echo.

set "TARGET_DIR=C:\Scripts"
set "SOURCE_DIR=%~dp0"

:: 1. 创建目录
echo  [1/3] 检查目标目录...
if not exist "%TARGET_DIR%" (
    echo        正在创建 %TARGET_DIR%...
    mkdir "%TARGET_DIR%"
    echo        √ 目录已创建
) else (
    echo        √ 目录已存在
)
echo.

:: 2. 复制脚本
echo  [2/3] 复制脚本文件...
copy /Y "%SOURCE_DIR%ExportTree.ps1" "%TARGET_DIR%\" >nul
if %errorLevel% equ 0 (
    echo        √ ExportTree.ps1 已复制
) else (
    echo        × 复制失败
    goto :error
)
echo.

:: 3. 注册右键菜单
echo  [3/3] 注册右键菜单...
reg import "%SOURCE_DIR%install.reg" >nul 2>&1
if %errorLevel% equ 0 (
    echo        √ 右键菜单已注册
) else (
    echo        × 注册失败
    goto :error
)
echo.

echo  ══════════════════════════════════════════════════════════════
echo  ║                    √ 安装完成!                              ║
echo  ══════════════════════════════════════════════════════════════
echo.
echo  使用方法:
echo    - 在文件夹上右键 → "目录结构导出"
echo    - 在文件夹空白处右键 → "目录结构导出"
echo.
echo  快捷键:
echo    [1-9]    切换深度层级
echo    [Ctrl+C] 复制到剪贴板
echo    [Ctrl+S] 保存到文件
echo    [F5]     刷新预览
echo    [Esc]    关闭窗口
echo.
echo  卸载方法: 双击运行 uninstall.reg
echo.
pause
exit /b 0

:error
echo.
echo  ══════════════════════════════════════════════════════════════
echo  ║                    × 安装失败!                              ║
echo  ══════════════════════════════════════════════════════════════
echo.
pause
exit /b 1
