# 导出目录树结构脚本
# Export Directory Tree Structure Script

# 设置控制台编码为 UTF-8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'

# 全局变量
$script:TargetPath = ""
$script:MaxDepth = 0
$script:IgnoreFolders = @()
$script:OutputFile = ""

# 显示主菜单
function Show-MainMenu {
    Clear-Host
    Write-Host "======================================" -ForegroundColor Cyan
    Write-Host "   目录树结构导出工具" -ForegroundColor Cyan
    Write-Host "======================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "当前配置:" -ForegroundColor Yellow
    Write-Host "  目标路径: $($script:TargetPath ? $script:TargetPath : '未设置')" -ForegroundColor White
    Write-Host "  搜索深度: $($script:MaxDepth -eq 0 ? '无限制' : $script:MaxDepth)" -ForegroundColor White
    Write-Host "  忽略文件夹: $($script:IgnoreFolders.Count -eq 0 ? '无' : ($script:IgnoreFolders -join ', '))" -ForegroundColor White
    Write-Host "  输出文件: $($script:OutputFile ? $script:OutputFile : '未设置')" -ForegroundColor White
    Write-Host ""
    Write-Host "1. 设置目标路径" -ForegroundColor Green
    Write-Host "2. 设置搜索深度" -ForegroundColor Green
    Write-Host "3. 设置忽略的文件夹" -ForegroundColor Green
    Write-Host "4. 设置输出文件路径" -ForegroundColor Green
    Write-Host "5. 预览目录树" -ForegroundColor Magenta
    Write-Host "6. 导出到文件" -ForegroundColor Magenta
    Write-Host "0. 退出" -ForegroundColor Red
    Write-Host ""
}

# 设置目标路径
function Set-TargetPath {
    Clear-Host
    Write-Host "======================================" -ForegroundColor Cyan
    Write-Host "   设置目标路径" -ForegroundColor Cyan
    Write-Host "======================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "当前路径: $((Get-Location).Path)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "请输入目标路径 (留空使用当前路径):" -ForegroundColor White
    $path = Read-Host
    
    if ([string]::IsNullOrWhiteSpace($path)) {
        $script:TargetPath = (Get-Location).Path
    } else {
        if (Test-Path $path) {
            $script:TargetPath = (Resolve-Path $path).Path
        } else {
            Write-Host "路径不存在！" -ForegroundColor Red
            Start-Sleep -Seconds 2
            return
        }
    }
    
    Write-Host "路径已设置为: $script:TargetPath" -ForegroundColor Green
    Start-Sleep -Seconds 1
}

# 设置搜索深度
function Set-MaxDepth {
    Clear-Host
    Write-Host "======================================" -ForegroundColor Cyan
    Write-Host "   设置搜索深度" -ForegroundColor Cyan
    Write-Host "======================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "当前深度: $($script:MaxDepth -eq 0 ? '无限制' : $script:MaxDepth)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "请输入最大搜索深度 (0 = 无限制):" -ForegroundColor White
    $depth = Read-Host
    
    if ($depth -match '^\d+$') {
        $script:MaxDepth = [int]$depth
        Write-Host "深度已设置为: $($script:MaxDepth -eq 0 ? '无限制' : $script:MaxDepth)" -ForegroundColor Green
    } else {
        Write-Host "请输入有效的数字！" -ForegroundColor Red
    }
    
    Start-Sleep -Seconds 1
}

# 设置忽略的文件夹
function Set-IgnoreFolders {
    if ([string]::IsNullOrWhiteSpace($script:TargetPath)) {
        Write-Host "请先设置目标路径！" -ForegroundColor Red
        Start-Sleep -Seconds 2
        return
    }
    
    Clear-Host
    Write-Host "======================================" -ForegroundColor Cyan
    Write-Host "   设置忽略的文件夹" -ForegroundColor Cyan
    Write-Host "======================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "当前忽略: $($script:IgnoreFolders.Count -eq 0 ? '无' : ($script:IgnoreFolders -join ', '))" -ForegroundColor Yellow
    Write-Host ""
    
    # 获取目标路径下的所有文件夹
    Write-Host "正在扫描文件夹..." -ForegroundColor Gray
    $allFolders = Get-ChildItem -Path $script:TargetPath -Directory -Force -ErrorAction SilentlyContinue | 
                  Sort-Object Name
    
    if ($null -eq $allFolders -or $allFolders.Count -eq 0) {
        Write-Host "未找到任何文件夹" -ForegroundColor Yellow
        Start-Sleep -Seconds 2
        return
    }
    
    Clear-Host
    Write-Host "======================================" -ForegroundColor Cyan
    Write-Host "   选择要忽略的文件夹" -ForegroundColor Cyan
    Write-Host "======================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "路径: $script:TargetPath" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "选择方式:" -ForegroundColor White
    Write-Host "  1. 从文件夹列表中选择" -ForegroundColor Green
    Write-Host "  2. 手动输入文件夹名称" -ForegroundColor Green
    Write-Host "  3. 清空忽略列表" -ForegroundColor Green
    Write-Host "  0. 返回" -ForegroundColor Red
    Write-Host ""
    $mode = Read-Host "请选择"
    
    switch ($mode) {
        "1" {
            # 从列表选择
            Clear-Host
            Write-Host "======================================" -ForegroundColor Cyan
            Write-Host "   文件夹列表" -ForegroundColor Cyan
            Write-Host "======================================" -ForegroundColor Cyan
            Write-Host ""
            
            # 显示文件夹列表
            $folderList = @()
            for ($i = 0; $i -lt $allFolders.Count; $i++) {
                $folder = $allFolders[$i]
                $isIgnored = $script:IgnoreFolders -contains $folder.Name
                $status = if ($isIgnored) { "[已忽略]" } else { "        " }
                $color = if ($isIgnored) { "Yellow" } else { "White" }
                Write-Host ("{0,3}. {1} {2}" -f ($i + 1), $status, $folder.Name) -ForegroundColor $color
                $folderList += $folder.Name
            }
            
            Write-Host ""
            Write-Host "输入要忽略的文件夹编号 (用逗号或空格分隔，如: 1,3,5 或 1 3 5)" -ForegroundColor Cyan
            Write-Host "输入 'all' 忽略所有，留空保持当前设置" -ForegroundColor Gray
            $selection = Read-Host
            
            if ([string]::IsNullOrWhiteSpace($selection)) {
                Write-Host "保持当前设置" -ForegroundColor Yellow
            } elseif ($selection -eq 'all') {
                $script:IgnoreFolders = $folderList
                Write-Host "已忽略所有 $($folderList.Count) 个文件夹" -ForegroundColor Green
            } else {
                $selectedIndices = $selection -replace ',', ' ' -split '\s+' | 
                                   Where-Object { $_ -match '^\d+$' } | 
                                   ForEach-Object { [int]$_ - 1 }
                
                $newIgnores = @()
                foreach ($index in $selectedIndices) {
                    if ($index -ge 0 -and $index -lt $folderList.Count) {
                        $newIgnores += $folderList[$index]
                    }
                }
                
                if ($newIgnores.Count -gt 0) {
                    $script:IgnoreFolders = $newIgnores | Select-Object -Unique
                    Write-Host "已设置 $($script:IgnoreFolders.Count) 个忽略文件夹" -ForegroundColor Green
                } else {
                    Write-Host "未选择有效的文件夹" -ForegroundColor Yellow
                }
            }
        }
        "2" {
            # 手动输入
            Clear-Host
            Write-Host "请输入要忽略的文件夹名称 (用逗号分隔):" -ForegroundColor White
            Write-Host "常用示例: node_modules, .git, bin, obj, .vs, .vscode, dist, build" -ForegroundColor Gray
            $folders = Read-Host
            
            if (![string]::IsNullOrWhiteSpace($folders)) {
                $script:IgnoreFolders = $folders -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
                Write-Host "已设置 $($script:IgnoreFolders.Count) 个忽略文件夹" -ForegroundColor Green
            }
        }
        "3" {
            # 清空列表
            $script:IgnoreFolders = @()
            Write-Host "已清除忽略列表" -ForegroundColor Green
        }
        "0" {
            return
        }
        default {
            Write-Host "无效选择" -ForegroundColor Red
        }
    }
    
    Start-Sleep -Seconds 2
}

# 设置输出文件路径
function Set-OutputFile {
    Clear-Host
    Write-Host "======================================" -ForegroundColor Cyan
    Write-Host "   设置输出文件路径" -ForegroundColor Cyan
    Write-Host "======================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "当前输出文件: $($script:OutputFile ? $script:OutputFile : '未设置')" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "当前工作目录: $(Get-Location)" -ForegroundColor Gray
    if (![string]::IsNullOrWhiteSpace($script:TargetPath) -and $script:TargetPath -ne (Get-Location).Path) {
        Write-Host "目标扫描目录: $script:TargetPath" -ForegroundColor Gray
    }
    Write-Host ""
    Write-Host "选择保存位置:" -ForegroundColor White
    Write-Host "  1. 当前工作目录" -ForegroundColor Green
    if (![string]::IsNullOrWhiteSpace($script:TargetPath) -and $script:TargetPath -ne (Get-Location).Path) {
        Write-Host "  2. 目标扫描目录" -ForegroundColor Green
        Write-Host "  3. 自定义路径" -ForegroundColor Green
    } else {
        Write-Host "  2. 自定义路径" -ForegroundColor Green
    }
    Write-Host "  0. 返回" -ForegroundColor Red
    Write-Host ""
    $choice = Read-Host "请选择"
    
    $defaultFileName = "tree_output_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
    
    switch ($choice) {
        "1" {
            $script:OutputFile = Join-Path (Get-Location).Path $defaultFileName
            Write-Host "输出文件已设置为: $script:OutputFile" -ForegroundColor Green
        }
        "2" {
            if (![string]::IsNullOrWhiteSpace($script:TargetPath) -and $script:TargetPath -ne (Get-Location).Path) {
                $script:OutputFile = Join-Path $script:TargetPath $defaultFileName
                Write-Host "输出文件已设置为: $script:OutputFile" -ForegroundColor Green
            } else {
                # 自定义路径
                Write-Host ""
                Write-Host "请输入完整的文件路径（包含文件名）:" -ForegroundColor White
                Write-Host "示例: C:\Users\YourName\Desktop\tree.txt" -ForegroundColor Gray
                $file = Read-Host
                
                if (![string]::IsNullOrWhiteSpace($file)) {
                    $script:OutputFile = $file
                    Write-Host "输出文件已设置为: $script:OutputFile" -ForegroundColor Green
                } else {
                    Write-Host "未设置，保持原有设置" -ForegroundColor Yellow
                }
            }
        }
        "3" {
            # 自定义路径（仅当选项3存在时）
            if (![string]::IsNullOrWhiteSpace($script:TargetPath) -and $script:TargetPath -ne (Get-Location).Path) {
                Write-Host ""
                Write-Host "请输入完整的文件路径（包含文件名）:" -ForegroundColor White
                Write-Host "示例: C:\Users\YourName\Desktop\tree.txt" -ForegroundColor Gray
                $file = Read-Host
                
                if (![string]::IsNullOrWhiteSpace($file)) {
                    $script:OutputFile = $file
                    Write-Host "输出文件已设置为: $script:OutputFile" -ForegroundColor Green
                } else {
                    Write-Host "未设置，保持原有设置" -ForegroundColor Yellow
                }
            }
        }
        "0" {
            return
        }
        default {
            Write-Host "无效选择" -ForegroundColor Red
        }
    }
    
    Start-Sleep -Seconds 2
}

# 生成目录树
function Get-DirectoryTree {
    param(
        [string]$Path,
        [int]$CurrentDepth = 0,
        [string]$Prefix = "",
        [bool]$IsLast = $true
    )
    
    # 检查深度限制
    if ($script:MaxDepth -gt 0 -and $CurrentDepth -ge $script:MaxDepth) {
        return
    }
    
    try {
        # 获取所有项目
        $items = Get-ChildItem -Path $Path -Force -ErrorAction SilentlyContinue | 
                 Where-Object { 
                     if ($_.PSIsContainer) {
                         $script:IgnoreFolders -notcontains $_.Name
                     } else {
                         $true
                     }
                 } | 
                 Sort-Object -Property PSIsContainer, Name -Descending
        
        if ($null -eq $items) { return }
        
        $itemCount = @($items).Count
        
        for ($i = 0; $i -lt $itemCount; $i++) {
            $item = $items[$i]
            $isLastItem = ($i -eq ($itemCount - 1))
            
            # 决定使用的符号
            $branch = if ($isLastItem) { "└── " } else { "├── " }
            $extension = if ($isLastItem) { "    " } else { "│   " }
            
            # 显示项目
            $line = $Prefix + $branch + $item.Name
            
            if ($item.PSIsContainer) {
                Write-Output ($line + "\")
                # 递归处理子文件夹
                Get-DirectoryTree -Path $item.FullName -CurrentDepth ($CurrentDepth + 1) -Prefix ($Prefix + $extension) -IsLast $isLastItem
            } else {
                Write-Output $line
            }
        }
    } catch {
        Write-Output "$Prefix[无法访问: $_]"
    }
}

# 预览目录树
function Show-Preview {
    if ([string]::IsNullOrWhiteSpace($script:TargetPath)) {
        Write-Host "请先设置目标路径！" -ForegroundColor Red
        Start-Sleep -Seconds 2
        return
    }
    
    Clear-Host
    Write-Host "======================================" -ForegroundColor Cyan
    Write-Host "   目录树预览" -ForegroundColor Cyan
    Write-Host "======================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "路径: $script:TargetPath" -ForegroundColor Yellow
    Write-Host ""
    
    # 显示根目录
    Write-Host $script:TargetPath -ForegroundColor Green
    
    # 生成并显示树
    Get-DirectoryTree -Path $script:TargetPath
    
    Write-Host ""
    Write-Host "按任意键返回主菜单..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# 导出到文件
function Export-ToFile {
    if ([string]::IsNullOrWhiteSpace($script:TargetPath)) {
        Write-Host "请先设置目标路径！" -ForegroundColor Red
        Start-Sleep -Seconds 2
        return
    }
    
    if ([string]::IsNullOrWhiteSpace($script:OutputFile)) {
        $script:OutputFile = Join-Path (Get-Location).Path "tree_output.txt"
    }
    
    Clear-Host
    Write-Host "======================================" -ForegroundColor Cyan
    Write-Host "   导出目录树到文件" -ForegroundColor Cyan
    Write-Host "======================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "正在导出..." -ForegroundColor Yellow
    
    try {
        # 生成文件头
        $header = @"
目录树结构
生成时间: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
目标路径: $script:TargetPath
搜索深度: $($script:MaxDepth -eq 0 ? '无限制' : $script:MaxDepth)
忽略文件夹: $($script:IgnoreFolders.Count -eq 0 ? '无' : ($script:IgnoreFolders -join ', '))
======================================

"@
        
        # 写入文件头
        $header | Out-File -FilePath $script:OutputFile -Encoding UTF8
        
        # 写入根目录
        $script:TargetPath | Out-File -FilePath $script:OutputFile -Append -Encoding UTF8
        
        # 生成并写入树结构
        Get-DirectoryTree -Path $script:TargetPath | Out-File -FilePath $script:OutputFile -Append -Encoding UTF8
        
        Write-Host ""
        Write-Host "导出成功！" -ForegroundColor Green
        Write-Host "文件位置: $script:OutputFile" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "是否打开文件? (Y/N)" -ForegroundColor Yellow
        $response = Read-Host
        
        if ($response -eq 'Y' -or $response -eq 'y') {
            Invoke-Item $script:OutputFile
        }
    } catch {
        Write-Host "导出失败: $_" -ForegroundColor Red
    }
    
    Write-Host ""
    Write-Host "按任意键返回主菜单..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# 主循环
function Start-Main {
    # 设置默认值
    if ([string]::IsNullOrWhiteSpace($script:TargetPath)) {
        $script:TargetPath = (Get-Location).Path
    }
    
    if ([string]::IsNullOrWhiteSpace($script:OutputFile)) {
        $script:OutputFile = Join-Path (Get-Location).Path "tree_output.txt"
    }
    
    while ($true) {
        Show-MainMenu
        $choice = Read-Host "请选择"
        
        switch ($choice) {
            "1" { Set-TargetPath }
            "2" { Set-MaxDepth }
            "3" { Set-IgnoreFolders }
            "4" { Set-OutputFile }
            "5" { Show-Preview }
            "6" { Export-ToFile }
            "0" { 
                Write-Host "再见！" -ForegroundColor Cyan
                return 
            }
            default { 
                Write-Host "无效选择！" -ForegroundColor Red
                Start-Sleep -Seconds 1
            }
        }
    }
}

# 启动脚本
Start-Main
