# 实用工具合集 (Utils Collection)

这是一个实用工具的集合，每个文件夹包含一个独立的工具。

## 🛠️ 工具列表

### WindowsShutdown - Windows 关机助手
一个现代化设计的 Windows 关机程序，提供友好的触摸屏界面和流畅的动画效果。

- **功能**: 一键关机，无需管理员权限
- **特色**: Material Design 风格、触摸屏优化、丝滑动画
- **技术栈**: .NET 6.0 WPF
- **文件大小**: 约 66MB（单文件自包含）
- **使用说明**: 查看 `WindowsShutdown/README.md`

### 永久秒删
一个Windows工具，用于永久删除文件，绕过回收站。

- **功能**: 右键菜单永久删除文件/文件夹，支持检测文件占用进程
- **特色**:
  - 使用 .NET API 快速删除
  - 删除失败时显示占用进程信息（PID、进程名、路径）
- **安装**: 复制 `PermanentDelete.ps1` 到 `C:\Scripts\`，运行 `Add-PermanentDelete-ContextMenu.reg`
- **卸载**: 运行 `Remove-PermanentDelete-ContextMenu.reg`
- **使用说明**: 查看 `使用说明.md`

### 右键菜单进入环境变量
快速打开系统环境变量设置的快捷工具。

- **功能**: 在桌面或文件夹背景右键菜单添加"环境变量"选项
- **安装**: 运行 `envvars_menu.reg`
- **卸载**: 运行 `remove_envvars_menu.reg`

### 目录结构导出工具（输出结构树）
一个功能强大的 PowerShell 脚本，用于生成和导出目录树结构。

- **功能**: 导出文件夹结构树，支持自定义设置
- **特色**: 
  - 支持右键菜单"输出结构树"（GUI界面）
  - 支持设置搜索深度
  - 支持忽略指定文件夹（如 node_modules, .git 等）
  - 支持导出到文件或复制到剪贴板
- **安装**: 复制 `ExportTree-ContextMenu.ps1` 到 `C:\Scripts\`，运行 `Add-ExportTree-ContextMenu.reg`
- **使用**: 右键文件夹 → "输出结构树"，或运行 `Export-DirectoryTree.ps1`（命令行版）
- **使用说明**: 查看 `使用说明.md`

### NPM 全局更新检查
一个交互式 PowerShell 工具，用于查看、更新、安装、卸载 npm 全局包，并检查 npm 自身状态。

- **功能**: 列表、检测可更新、一键全量更新、指定包更新/卸载/安装、查看 npm 状态
- **特色**: 终端菜单式操作、中文提示、带确认的危险操作
- **使用说明**: 查看 `NPM全局更新检查/README.md`

## 📁 项目结构

```
utils/
├── WindowsShutdown/                                # Windows 关机助手
│   ├── MainWindow.xaml
│   ├── ...
│   └── README.md
├── 永久秒删/                                       # Windows永久删除工具
│   ├── PermanentDelete.ps1
│   ├── Add-PermanentDelete-ContextMenu.reg
│   └── ...
├── 右键菜单进入环境变量/                           # 环境变量快捷入口
│   ├── envvars_menu.reg
│   └── remove_envvars_menu.reg
├── 导出目录文件树结构，支持忽略文件夹和设置深度/   # 目录树导出工具
│   ├── Export-DirectoryTree.ps1          # 命令行交互版
│   ├── ExportTree-ContextMenu.ps1        # 右键菜单版（GUI）
│   ├── Add-ExportTree-ContextMenu.reg    # 添加右键菜单
│   ├── Remove-ExportTree-ContextMenu.reg # 移除右键菜单
│   └── 使用说明.md
├── NPM全局更新检查/                       # npm 全局包交互管理
│   ├── npm-manager.ps1
│   └── README.md
└── README.md                                       # 项目说明文件
```

## ✨ 快速开始

### WindowsShutdown
```bash
cd WindowsShutdown
dotnet publish -c Release -o bin\Release\publish
```

### 永久秒删
双击运行 `Add-PermanentDelete-ContextMenu.reg` 添加右键菜单

### 右键菜单进入环境变量
双击运行 `envvars_menu.reg` 添加右键菜单

### 目录结构导出工具
1. 复制 `ExportTree-ContextMenu.ps1` 到 `C:\Scripts\`
2. 双击运行 `Add-ExportTree-ContextMenu.reg` 添加右键菜单
3. 右键文件夹 → "输出结构树"

### NPM 全局更新检查
```powershell
cd "NPM全局更新检查"
powershell.exe -File .\npm-manager.ps1
```

## ⚠️ 注意事项

- 使用永久删除工具前请谨慎，删除后无法恢复
- WindowsShutdown 关机后无法撤销，请确认后再操作
- 修改注册表前建议备份
- 建议先备份重要数据
- 部分工具可能需要管理员权限

## 🤝 贡献

欢迎提交更多实用工具的Pull Request！

## 📄 许可证

MIT License
