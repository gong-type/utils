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

- **功能**: 右键菜单永久删除文件/文件夹
- **安装**: 运行 `Add-PermanentDelete-ContextMenu.reg`
- **卸载**: 运行 `Remove-PermanentDelete-ContextMenu.reg`
- **使用说明**: 查看 `使用说明.md`

## 📁 项目结构

```
utils/
├── WindowsShutdown/       # Windows 关机助手
│   ├── MainWindow.xaml
│   ├── MainWindow.xaml.cs
│   ├── App.xaml
│   ├── App.xaml.cs
│   ├── WindowsShutdown.csproj
│   └── README.md
├── 永久秒删/              # Windows永久删除工具
│   ├── PermanentDelete.ps1
│   ├── Add-PermanentDelete-ContextMenu.reg
│   ├── Remove-PermanentDelete-ContextMenu.reg
│   └── 使用说明.md
└── README.md              # 项目说明文件
```

## ✨ 快速开始

### WindowsShutdown
```bash
cd WindowsShutdown
dotnet publish -c Release -o bin\Release\publish
```

### 永久秒删
双击运行 `Add-PermanentDelete-ContextMenu.reg` 添加右键菜单

## ⚠️ 注意事项

- 使用永久删除工具前请谨慎，删除后无法恢复
- WindowsShutdown 关机后无法撤销，请确认后再操作
- 建议先备份重要数据
- 部分工具可能需要管理员权限

## 🤝 贡献

欢迎提交更多实用工具的Pull Request！

## 📄 许可证

MIT License
