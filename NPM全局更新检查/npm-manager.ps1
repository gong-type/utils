#!/usr/bin/env pwsh
<#
.SYNOPSIS
    NPM 全局包管理平台
.DESCRIPTION
    提供全局包列表、更新检查、安装、卸载等功能的交互式管理工具
#>

# 清屏并显示主菜单
function Show-Menu {
    Clear-Host
    Write-Host ""
    Write-Host "  ╔═══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║         NPM 全局包管理平台 v2.0                       ║" -ForegroundColor Cyan
    Write-Host "  ╚═══════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "    [1] 📋 列出所有全局包" -ForegroundColor White
    Write-Host "    [2] 🔍 检查可更新的包" -ForegroundColor White
    Write-Host "    [3] 🚀 一键更新所有过期包" -ForegroundColor White
    Write-Host "    [4] 📦 更新指定包" -ForegroundColor White
    Write-Host "    [5] 🗑️  卸载指定包" -ForegroundColor White
    Write-Host "    [6] ➕ 安装新全局包" -ForegroundColor White
    Write-Host "    [7] ℹ️  查看 npm 自身状态" -ForegroundColor White
    Write-Host "    [0] ❌ 退出" -ForegroundColor White
    Write-Host ""
    Write-Host "  ─────────────────────────────────────────────────────────" -ForegroundColor Gray
}

# 获取全局包列表
function Get-GlobalPackages {
    $raw = npm list -g --depth=0 --json 2>$null
    if (-not $raw) { return $null }
    $data = $raw | ConvertFrom-Json
    if (-not $data.dependencies) { return @() }
    return $data.dependencies.PSObject.Properties
}

# [1] 列出所有全局包
function Show-AllPackages {
    Write-Host ""
    Write-Host "  📋 正在获取全局包列表..." -ForegroundColor Yellow
    $packages = Get-GlobalPackages
    if (-not $packages) {
        Write-Host "  ⚠️  未找到任何全局包" -ForegroundColor Yellow
        return
    }
    $count = @($packages).Count
    Write-Host ""
    Write-Host "  全局包列表（共 $count 个）" -ForegroundColor Cyan
    Write-Host "  ─────────────────────────────────────────────────────" -ForegroundColor Gray
    Write-Host ("    " + "包名".PadRight(40) + "版本") -ForegroundColor Gray
    Write-Host "  ─────────────────────────────────────────────────────" -ForegroundColor Gray
    foreach ($pkg in $packages | Sort-Object Name) {
        $name = $pkg.Name
        $ver = $pkg.Value.version
        if (-not $ver) { $ver = "未知" }
        Write-Host ("    " + $name.PadRight(40) + $ver) -ForegroundColor White
    }
    Write-Host "  ─────────────────────────────────────────────────────" -ForegroundColor Gray
}

# [2] 检查可更新的包
function Check-Updates {
    Write-Host ""
    Write-Host "  🔍 正在检查更新..." -ForegroundColor Yellow
    $packages = Get-GlobalPackages
    if (-not $packages) {
        Write-Host "  ⚠️  未找到任何全局包" -ForegroundColor Yellow
        return @()
    }
    $count = @($packages).Count
    Write-Host ""
    Write-Host "  版本对比（共 $count 个包）" -ForegroundColor Cyan
    Write-Host "  ─────────────────────────────────────────────────────────────────────" -ForegroundColor Gray
    Write-Host ("    " + "包名".PadRight(35) + "当前版本".PadRight(12) + "最新版本".PadRight(12) + "状态") -ForegroundColor Gray
    Write-Host "  ─────────────────────────────────────────────────────────────────────" -ForegroundColor Gray

    $outdated = @()
    foreach ($pkg in $packages | Sort-Object Name) {
        $name = $pkg.Name
        $currentVer = $pkg.Value.version
        if (-not $currentVer) { $currentVer = "未知" }

        $latestVerRaw = npm view $name version 2>$null
        $latestVer = if ($latestVerRaw) { $latestVerRaw.Trim() } else { "未知" }

        if ($currentVer -eq $latestVer) {
            $status = "✅ 已最新"
            $color = "Green"
        } elseif ($latestVer -eq "未知") {
            $status = "❓ 私有包"
            $color = "Cyan"
        } else {
            $status = "🔄 可更新"
            $color = "Yellow"
            $outdated += $name
        }

        Write-Host ("    " + $name.PadRight(35)) -NoNewline -ForegroundColor White
        Write-Host ($currentVer.PadRight(12)) -NoNewline
        Write-Host ($latestVer.PadRight(12)) -NoNewline
        Write-Host $status -ForegroundColor $color
    }
    Write-Host "  ─────────────────────────────────────────────────────────────────────" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  📊 可更新: $($outdated.Count) 个" -ForegroundColor Yellow
    return $outdated
}

# [3] 一键更新所有过期包
function Update-AllOutdated {
    $outdated = Check-Updates
    if ($outdated.Count -eq 0) {
        Write-Host "  ✅ 所有包都已是最新版本！" -ForegroundColor Green
        return
    }
    Write-Host ""
    $updateCmd = "npm update -g " + ($outdated -join " ")
    Write-Host "  🚀 即将执行: $updateCmd" -ForegroundColor Cyan
    Write-Host ""
    $confirm = Read-Host "  确认更新? (y/n)"
    if ($confirm -match '^[Yy]') {
        Write-Host ""
        Write-Host "  开始更新..." -ForegroundColor Yellow
        Invoke-Expression $updateCmd
        if ($LASTEXITCODE -eq 0) {
            Write-Host ""
            Write-Host "  ✅ 更新完成！" -ForegroundColor Green
        } else {
            Write-Host ""
            Write-Host "  ⚠️  更新过程中可能出现问题，请查看上方输出" -ForegroundColor Red
        }
    } else {
        Write-Host "  已取消更新" -ForegroundColor Gray
    }
}

# [4] 更新指定包
function Update-SpecificPackage {
    Write-Host ""
    $pkgName = Read-Host "  请输入要更新的包名"
    if ([string]::IsNullOrWhiteSpace($pkgName)) {
        Write-Host "  ⚠️  包名不能为空" -ForegroundColor Yellow
        return
    }
    Write-Host ""
    Write-Host "  🔄 正在更新 $pkgName ..." -ForegroundColor Yellow
    npm update -g $pkgName
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "  ✅ $pkgName 更新完成！" -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "  ⚠️  更新失败，请检查包名是否正确" -ForegroundColor Red
    }
}

# [5] 卸载指定包
function Uninstall-Package {
    Write-Host ""
    $pkgName = Read-Host "  请输入要卸载的包名"
    if ([string]::IsNullOrWhiteSpace($pkgName)) {
        Write-Host "  ⚠️  包名不能为空" -ForegroundColor Yellow
        return
    }
    Write-Host ""
    $confirm = Read-Host "  确认卸载 $pkgName ? (y/n)"
    if ($confirm -match '^[Yy]') {
        Write-Host ""
        Write-Host "  🗑️  正在卸载 $pkgName ..." -ForegroundColor Yellow
        npm uninstall -g $pkgName
        if ($LASTEXITCODE -eq 0) {
            Write-Host ""
            Write-Host "  ✅ $pkgName 已卸载！" -ForegroundColor Green
        } else {
            Write-Host ""
            Write-Host "  ⚠️  卸载失败，请检查包名是否正确" -ForegroundColor Red
        }
    } else {
        Write-Host "  已取消卸载" -ForegroundColor Gray
    }
}

# [6] 安装新全局包
function Install-NewPackage {
    Write-Host ""
    $pkgName = Read-Host "  请输入要安装的包名（可带版本如 package@latest）"
    if ([string]::IsNullOrWhiteSpace($pkgName)) {
        Write-Host "  ⚠️  包名不能为空" -ForegroundColor Yellow
        return
    }
    Write-Host ""
    Write-Host "  ➕ 正在安装 $pkgName ..." -ForegroundColor Yellow
    npm install -g $pkgName
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "  ✅ $pkgName 安装完成！" -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "  ⚠️  安装失败，请检查包名或网络" -ForegroundColor Red
    }
}

# [7] 查看 npm 自身状态
function Show-NpmStatus {
    Write-Host ""
    Write-Host "  ℹ️  NPM 状态" -ForegroundColor Cyan
    Write-Host "  ─────────────────────────────────────────" -ForegroundColor Gray
    
    $npmCurrent = npm -v
    $npmLatestRaw = npm view npm version 2>$null
    $npmLatest = if ($npmLatestRaw) { $npmLatestRaw.Trim() } else { "未知" }
    
    Write-Host "    当前版本: $npmCurrent" -ForegroundColor White
    Write-Host "    最新版本: $npmLatest" -ForegroundColor White
    
    if ($npmCurrent -eq $npmLatest) {
        Write-Host "    ✅ NPM 已是最新版本" -ForegroundColor Green
    } else {
        Write-Host "    ⚠️  NPM 可更新" -ForegroundColor Yellow
        Write-Host ""
        $confirm = Read-Host "  是否更新 npm? (y/n)"
        if ($confirm -match '^[Yy]') {
            Write-Host ""
            Write-Host "  🔄 正在更新 npm ..." -ForegroundColor Yellow
            npm install -g npm@latest
            if ($LASTEXITCODE -eq 0) {
                Write-Host ""
                Write-Host "  ✅ npm 更新完成！" -ForegroundColor Green
            } else {
                Write-Host ""
                Write-Host "  ⚠️  更新失败" -ForegroundColor Red
            }
        }
    }
    
    Write-Host ""
    Write-Host "  📍 npm 路径: $(Get-Command npm | Select-Object -ExpandProperty Source)" -ForegroundColor Gray
    Write-Host "  📍 全局目录: $(npm root -g)" -ForegroundColor Gray
    Write-Host "  📍 缓存目录: $(npm config get cache)" -ForegroundColor Gray
}

# 等待用户按键
function Wait-ForKey {
    Write-Host ""
    Write-Host "  按任意键返回菜单..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# 主循环
while ($true) {
    Show-Menu
    $choice = Read-Host "  请输入选项"
    
    switch ($choice) {
        "1" { Show-AllPackages; Wait-ForKey }
        "2" { Check-Updates | Out-Null; Wait-ForKey }
        "3" { Update-AllOutdated; Wait-ForKey }
        "4" { Update-SpecificPackage; Wait-ForKey }
        "5" { Uninstall-Package; Wait-ForKey }
        "6" { Install-NewPackage; Wait-ForKey }
        "7" { Show-NpmStatus; Wait-ForKey }
        "0" { 
            Clear-Host
            Write-Host ""
            Write-Host "  👋 再见！" -ForegroundColor Cyan
            Write-Host ""
            exit 0
        }
        default {
            Write-Host ""
            Write-Host "  ⚠️  无效选项，请重新输入" -ForegroundColor Yellow
            Start-Sleep -Seconds 1
        }
    }
}
