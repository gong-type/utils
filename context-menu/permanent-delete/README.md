# NukeIt v4.0 - Ultimate Silent Delete

🚀 **Windows 终极静默删除工具** - 100% 无窗口，处理一切疑难文件

## ✨ 核心特性

| 特性 | 说明 |
|------|------|
| 👻 **100% 静默** | 无弹窗、无黑框、无任何 UI 干扰，错误只写日志 |
| 💪 **6层删除策略** | 标准 → UNC路径 → CMD → Robocopy → 权限接管 → 进程解锁 |
| 📝 **保留名称支持** | 完美删除 `nul`, `con`, `aux`, `prn`, `com1-9`, `lpt1-9` |
| 📏 **长路径支持** | 突破 260 字符限制，使用 `\\?\` UNC 路径 |
| 🔓 **自动解锁** | 使用 RestartManager API 检测并终止占用进程 |
| 🛡️ **权限接管** | 自动 takeown + icacls 重置权限 |
| ⚡ **批量优化** | 多选文件合并处理，不重复弹窗 |
| 🔒 **系统保护** | 白名单保护 explorer, csrss, svchost 等关键进程 |

## 📁 文件结构

```
NukeIt/
├── NukeIt.vbs           # 主入口 (快速静默启动)
├── NukeIt.ps1           # 核心引擎 (6层删除策略)
├── install-nukeit.bat   # 一键安装
└── uninstall-nukeit.bat # 一键卸载
```

## 🚀 安装

双击运行 `install-nukeit.bat`，完成！

## 📖 使用方法

1. 选中任意文件或文件夹（支持多选）
2. 右键点击 **"NukeIt 强力删除"**
3. 文件瞬间消失（无任何提示）

> 💡 如果删除失败，错误信息会记录到 `%TEMP%\NukeIt.log`

## 🔧 工作原理

```
用户右键点击 (N 个文件)
        ↓
   wscript.exe (0延迟启动，完全无窗口)
        ↓
   NukeIt.vbs 写入任务队列
        ↓
   第一个实例获取锁，成为主处理器
        ↓
 ┌──────────────────────┐
 │ 路径类型判断         │
 │ • 普通文件 → VBS 快速 │
 │ • exe/保留名 → PS    │
 │ • 长路径 → PS        │
 └──────────────────────┘
        ↓
   VBS 快速删除 (99% 在此完成)
        ↓ 失败
   PowerShell 强力模式
        ↓
 ┌──────────────────────────────────────────┐
 │ 6层删除策略 (按顺序尝试)                 │
 │                                          │
 │ 1. Remove-Item 标准删除                  │
 │ 2. UNC 路径删除 (\\?\)                   │
 │ 3. CMD del/rd 命令                       │
 │ 4. Robocopy /MIR 空文件夹镜像            │
 │ 5. takeown + icacls 权限接管             │
 │ 6. RestartManager 解锁进程               │
 └──────────────────────────────────────────┘
```

## 🆚 v3.0 vs v4.0 对比

| 特性 | v3.0 | v4.0 |
|------|------|------|
| 删除失败提示 | 弹窗 | 日志文件 |
| 删除策略 | 3层 | 6层 |
| 保留名称 (`nul`) | 基本支持 | 完整支持 |
| 长路径 | 不支持 | 支持 |
| 权限问题 | 提权重试 | takeown + icacls |
| Robocopy 回退 | ❌ | ✅ |
| 错误日志 | ❌ | ✅ |

## 📋 日志查看

```powershell
# 查看最近的删除日志
Get-Content $env:TEMP\NukeIt.log -Tail 50
```

## ⚠️ 注意事项

- **不可恢复**: 删除的文件不经过回收站，无法恢复
- **系统保护**: 自动跳过系统关键进程，但仍需谨慎
- **日志大小**: 日志文件超过 1MB 自动轮换

## 🔧 手动使用

```powershell
# 直接调用 PowerShell 核心
powershell -File C:\Scripts\NukeIt.ps1 "path\to\file"

# 删除 nul 文件
powershell -File C:\Scripts\NukeIt.ps1 "C:\test\nul"

# 批量删除
powershell -File C:\Scripts\NukeIt.ps1 "file1" "file2" "folder1"
```

## 📜 License

MIT License
